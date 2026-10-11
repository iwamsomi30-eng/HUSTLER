import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/brand.dart';
import '../core/i18n.dart';

class SmsItem {
  final String donorName;
  final String contact;
  final double amount;
  final String purpose; // jina la mfuko / mchango
  final DateTime date;
  final String receiptNo;
  const SmsItem({
    required this.donorName,
    required this.contact,
    required this.amount,
    required this.purpose,
    required this.date,
    required this.receiptNo,
  });
}

class SmsResult {
  final int sent;
  final int failed;
  final int invalid; // namba za simu zisizo sahihi
  final bool permissionDenied;
  final bool unsupported;
  const SmsResult({this.sent = 0, this.failed = 0, this.invalid = 0, this.permissionDenied = false, this.unsupported = false});
  bool get nothing => sent == 0 && failed == 0 && invalid == 0 && !permissionDenied && !unsupported;
}

/// Inatuma SMS ya uthibitisho wa malipo kwa SIM ya simu (Android tu).
/// Native code iko kwenye MainActivity (inaandikwa na workflow wakati wa build).
class SmsService {
  static const _ch = MethodChannel('mfuko/sms');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Inarudisha namba kwa muundo wa kimataifa (+255XXXXXXXXX) au null kama si sahihi.
  static String? normalize(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'[\s\-().]'), '');
    if (s.isEmpty) return null;
    if (s.startsWith('00')) s = '+${s.substring(2)}';
    if (s.startsWith('+')) {
      return RegExp(r'^\+\d{10,15}$').hasMatch(s) ? s : null;
    }
    if (!RegExp(r'^\d+$').hasMatch(s)) return null;
    if (s.startsWith('255') && s.length == 12) return '+$s';
    if (s.startsWith('0') && s.length == 10) return '+255${s.substring(1)}';
    if (s.length == 9 && (s.startsWith('6') || s.startsWith('7'))) return '+255$s';
    return null;
  }

  static String _money(double v) {
    return v.round().toString();
  }

  static String message(SmsItem i) {
    final d = '${i.date.day.toString().padLeft(2, '0')}/${i.date.month.toString().padLeft(2, '0')}/${i.date.year}';
    final amt = _money(i.amount);
    if (L10n.instance.lang == 'en') {
      return 'Dear ${i.donorName}, your contribution of TZS $amt to ${i.purpose} was received on $d. Receipt: ${i.receiptNo}. Thank you, God bless you.';
    }
    return 'Mpendwa ${i.donorName}, mchango wako wa TZS $amt kwa ${i.purpose} umepokelewa tarehe $d. Risiti: ${i.receiptNo}. Asante, Mungu akubariki.';
  }

  /// Haitupi kosa kamwe: kuhifadhi data hakuwezi kuharibiwa na SMS.
  static Future<SmsResult> sendReceipts(List<SmsItem> items) async {
    final withContact = items.where((i) => i.contact.trim().isNotEmpty).toList();
    if (withContact.isEmpty) return const SmsResult();
    if (!supported) return const SmsResult(unsupported: true);

    final ready = <Map<String, String>>[];
    var invalid = 0;
    for (final i in withContact) {
      final to = normalize(i.contact);
      if (to == null) {
        invalid++;
      } else {
        ready.add({'to': to, 'text': message(i)});
      }
    }
    if (ready.isEmpty) return SmsResult(invalid: invalid);

    try {
      final ok = await _ch.invokeMethod<bool>('requestPermission') ?? false;
      if (!ok) return SmsResult(invalid: invalid, permissionDenied: true);
      final res = await _ch.invokeMethod<List<dynamic>>('send', {'messages': ready}) ?? const [];
      final sent = res.where((e) => e == true).length;
      return SmsResult(sent: sent, failed: ready.length - sent, invalid: invalid);
    } catch (_) {
      return SmsResult(failed: ready.length, invalid: invalid);
    }
  }

  // ---------------------------------------------------------------------------
  // Hatua ya 3: ujumbe wa marekebisho
  // ---------------------------------------------------------------------------

  /// Ujumbe unaomwarifu mchangiaji kuwa taarifa iliyotumwa awali kwenye risiti
  /// husika ilikuwa na hitilafu. [explanation] ni maelezo yaliyoandikwa na admin.
  static String correctionMessage({
    required String donorName,
    required String receiptNo,
    required String explanation,
  }) {
    var text = explanation.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isNotEmpty && !RegExp(r'[.!?]$').hasMatch(text)) text = '$text.';
    if (L10n.instance.lang == 'en') {
      return 'Dear $donorName, ${Brand.systemName}. Correction to the notice sent for receipt no. $receiptNo: $text We apologise for the inconvenience. Thank you, God bless you.';
    }
    return 'Mpendwa $donorName, ${Brand.systemName}. Marekebisho ya taarifa iliyotumwa kwa risiti namba $receiptNo: $text Samahani kwa usumbufu. Asante, Mungu akubariki.';
  }

  /// Idadi ya SMS (vipande) ambazo ujumbe utatumia: 160/153 kwa herufi za kawaida,
  /// 70/67 ikiwa kuna herufi maalum (Unicode).
  static int segments(String text) {
    if (text.isEmpty) return 0;
    final unicode = text.runes.any((r) => r > 126);
    final single = unicode ? 70 : 160;
    final multi = unicode ? 67 : 153;
    final len = text.runes.length;
    return len <= single ? 1 : (len / multi).ceil();
  }

  /// Inatuma ujumbe mmoja wa maandishi kwa namba moja. Haitupi kosa kamwe.
  static Future<SmsResult> sendText({required String contact, required String text}) async {
    if (contact.trim().isEmpty) return const SmsResult(invalid: 1);
    if (!supported) return const SmsResult(unsupported: true);
    final to = normalize(contact);
    if (to == null) return const SmsResult(invalid: 1);
    try {
      final ok = await _ch.invokeMethod<bool>('requestPermission') ?? false;
      if (!ok) return const SmsResult(permissionDenied: true);
      final res = await _ch.invokeMethod<List<dynamic>>('send', {
            'messages': [
              {'to': to, 'text': text}
            ]
          }) ??
          const [];
      final sent = res.where((e) => e == true).length;
      return SmsResult(sent: sent, failed: 1 - sent);
    } catch (_) {
      return const SmsResult(failed: 1);
    }
  }
}

import 'dart:math';
import 'brand.dart';

/// Utengenezaji wa namba ya risiti ya michango.
///
/// Muundo:
///   TAG-STK-YYYY-MMDD-HHMM-AA-NNNN-UUUUUU
///
///   TAG-STK   kifupi cha mfumo (Brand.receiptPrefix)
///   YYYY      mwaka
///   MMDD      mwezi na siku
///   HHMM      saa na dakika (mfumo wa saa 24)
///   AA        herufi mbili za kwanza za jina la mchango (FUNGU = FU)
///   NNNN      namba ya bahasha kwa FUNGU; kwa michango mingine ni namba ya
///             jina iliyotengenezwa na mfumo kwa mchangiaji (mfano MCH00001)
///   UUUUUU    msimbo wa kipekee wa risiti (herufi 6), unaothibitishwa kuwa
///             haujawahi kutumika kabla ya risiti kuhifadhiwa
///
/// Mfano: TAG-STK-2026-1011-1423-FU-125-7K3QX9
class ReceiptNo {
  ReceiptNo._();

  /// Herufi na tarakimu zisizochanganya (hakuna I, O, 0, 1) ili msimbo usomeke
  /// kwa urahisi kwenye SMS na kwa simu.
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const uniqueLength = 6;

  static final Random _rng = Random.secure();

  /// Herufi mbili za kwanza za jina la mchango. Herufi zisizo A-Z (nafasi,
  /// tarakimu, alama) zinarukwa; kama herufi hazifiki mbili, inajazwa na 'X'.
  static String typeCode(String contributionName) {
    final letters = contributionName
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '');
    if (letters.length >= 2) return letters.substring(0, 2);
    return letters.padRight(2, 'X');
  }

  /// Namba ya bahasha au ya jina kwa muundo salama wa risiti: herufi kubwa na
  /// tarakimu pekee (mfano "MCH-00001" -> "MCH00001", "b-45" -> "B45").
  static String numberPart(String raw) {
    final v = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return v.isEmpty ? '0' : v;
  }

  /// Msimbo wa kipekee wa herufi [uniqueLength].
  static String uniqueCode() {
    final b = StringBuffer();
    for (var i = 0; i < uniqueLength; i++) {
      b.write(_alphabet[_rng.nextInt(_alphabet.length)]);
    }
    return b.toString();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Inaunda namba ya risiti. [unique] ikikosekana, msimbo mpya unatengenezwa.
  static String build({
    required DateTime at,
    required String contributionName,
    required String number,
    String? unique,
  }) {
    final date = '${_two(at.month)}${_two(at.day)}';
    final time = '${_two(at.hour)}${_two(at.minute)}';
    return [
      Brand.receiptPrefix,
      at.year.toString().padLeft(4, '0'),
      date,
      time,
      typeCode(contributionName),
      numberPart(number),
      unique ?? uniqueCode(),
    ].join('-');
  }

  static final RegExp _pattern = RegExp(
    r'^TAG-STK-\d{4}-\d{4}-\d{4}-[A-Z]{2}-[A-Z0-9]+-[A-Z0-9]{6}$',
  );

  /// Kweli kama namba inafuata muundo mpya. Risiti za zamani (RC-...) zinarudisha
  /// false, lakini zinaendelea kuwa halali kwenye rekodi.
  static bool isValid(String receiptNo) => _pattern.hasMatch(receiptNo.trim().toUpperCase());
}

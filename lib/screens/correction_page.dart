import 'package:flutter/material.dart';
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/sms_service.dart';

/// Hatua ya 3: ukurasa wa kutuma ujumbe wa marekebisho kwa mchangiaji ambaye
/// alipokea taarifa isiyo sahihi. Admin anaweka namba ya risiti ya ujumbe wa awali,
/// mfumo unaleta taarifa za risiti hiyo, kisha admin anaandika maelezo ya marekebisho.
class CorrectionPage extends StatefulWidget {
  const CorrectionPage({super.key});

  @override
  State<CorrectionPage> createState() => _CorrectionPageState();
}

class _CorrectionPageState extends State<CorrectionPage> {
  static const _minMessageLength = 8;
  static const _maxMessageLength = 300;

  final _receipt = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();

  Map<String, Object?>? _record;
  List<Map<String, Object?>> _results = [];
  String? _receiptError;
  String? _phoneError;
  String? _messageError;
  bool _searching = false;
  bool _sending = false;
  bool _loadingHistory = true;
  List<Map<String, Object?>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _receipt.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- data

  Future<void> _loadHistory() async {
    try {
      final rows = await AppDb.instance.getCorrectionMessages();
      if (mounted) setState(() { _history = rows; _loadingHistory = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _find() async {
    final key = _receipt.text.trim();
    if (key.isEmpty) {
      setState(() { _receiptError = 'corr_receipt_required'; _record = null; _results = []; });
      return;
    }
    setState(() { _searching = true; _receiptError = null; _record = null; _results = []; });
    List<Map<String, Object?>> found = [];
    try {
      found = await AppDb.instance.searchContributionsForCorrection(key);
    } catch (_) {
      found = [];
    }
    if (!mounted) return;
    setState(() {
      _searching = false;
      _results = found;
      if (found.isEmpty) {
        _receiptError = 'corr_not_found';
      } else if (found.length == 1) {
        _select(found.first);
      }
    });
  }

  void _select(Map<String, Object?> r) {
    _record = r;
    _phone.text = '${r['contact'] ?? ''}'.trim();
    _phoneError = null;
  }

  // ------------------------------------------------------------- helpers

  String _donor() {
    final n = '${_record?['donor_name'] ?? ''}'.trim();
    return n.isEmpty ? tr('corr_donor') : n;
  }

  String _receiptNo() => '${_record?['receipt_no'] ?? _receipt.text}'.trim();

  String _purpose() {
    final r = _record;
    if (r == null) return '';
    final purpose = '${r['purpose'] ?? ''}'.trim();
    final fund = '${r['fund_name'] ?? ''}'.trim();
    if (r['kind'] == 'FUNGU') return fund.isEmpty ? purpose : fund;
    return fund.isEmpty ? purpose : '$purpose ($fund)';
  }

  String _date(Object? raw) {
    final d = DateTime.tryParse('${raw ?? ''}');
    if (d == null) return '${raw ?? ''}';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _dateTime(Object? raw) {
    final d = DateTime.tryParse('${raw ?? ''}');
    if (d == null) return '${raw ?? ''}';
    return '${_date(raw)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _money(Object? v) => '${safeNum(v).round()} TZS';

  String _composed() => SmsService.correctionMessage(
        donorName: _donor(),
        receiptNo: _receiptNo(),
        explanation: _message.text,
      );

  void _useTemplate() {
    final t = tr('corr_template_text');
    setState(() {
      _message.text = t;
      _message.selection = TextSelection.collapsed(offset: t.length);
      _messageError = null;
    });
  }

  void _clearForm() {
    setState(() {
      _receipt.clear();
      _phone.clear();
      _message.clear();
      _record = null;
      _results = [];
      _receiptError = null;
      _phoneError = null;
      _messageError = null;
    });
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        backgroundColor: error ? C.red : C.navyDark,
        duration: Duration(seconds: error ? 5 : 3),
      ));
  }

  // ---------------------------------------------------------------- send

  bool _validate() {
    String? phoneErr;
    final phone = _phone.text.trim();
    if (phone.isEmpty) {
      phoneErr = 'corr_phone_missing';
    } else if (SmsService.normalize(phone) == null) {
      phoneErr = 'corr_phone_invalid';
    }
    final msg = _message.text.trim();
    String? msgErr;
    if (msg.isEmpty) {
      msgErr = 'corr_message_required';
    } else if (msg.length < _minMessageLength) {
      msgErr = 'corr_message_short';
    }
    setState(() { _phoneError = phoneErr; _messageError = msgErr; });
    return phoneErr == null && msgErr == null;
  }

  Future<bool> _confirm(String text) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('corr_confirm_title')),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${tr('corr_confirm_body')} ${_donor()} (${_phone.text.trim()}):',
                  style: const TextStyle(color: C.muted, fontSize: 13)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
                child: Text(text, style: const TextStyle(color: C.text, fontSize: 13.5, height: 1.4)),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send, size: 18),
            label: Text(tr('corr_send')),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _send() async {
    if (_record == null || _sending) return;
    if (!_validate()) return;
    final text = _composed();
    if (!await _confirm(text)) return;

    setState(() => _sending = true);
    final res = await SmsService.sendText(contact: _phone.text.trim(), text: text);
    final ok = res.sent > 0;
    try {
      await AppDb.instance.addCorrectionMessage(
        receiptNo: _receiptNo(),
        donorName: _donor(),
        contact: _phone.text.trim(),
        message: text,
        status: ok ? 'SENT' : 'FAILED',
      );
      await AppDb.instance.audit('CORRECTION_SMS', 'receipt=${_receiptNo()}; status=${ok ? 'SENT' : 'FAILED'}');
    } catch (_) {
      // Historia isizuie mtumiaji; ujumbe umeshatumwa au umeshindwa tayari.
    }
    if (!mounted) return;
    setState(() => _sending = false);
    await _loadHistory();
    if (!mounted) return;
    if (ok) {
      _snack(tr('corr_sent_ok'));
      _clearForm();
    } else if (res.unsupported) {
      _snack(tr('sms_unsupported'), error: true);
    } else if (res.permissionDenied) {
      _snack(tr('sms_permission_denied'), error: true);
    } else if (res.invalid > 0) {
      _snack(tr('corr_phone_invalid'), error: true);
    } else {
      _snack(tr('corr_send_failed'), error: true);
    }
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.instance,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _loadHistory,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pagePad(context), 16, pagePad(context), 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _header(),
                const SizedBox(height: 16),
                _searchCard(),
                if (_results.length > 1) ...[
                  const SizedBox(height: 16),
                  _resultsCard(),
                ],
                if (_record != null) ...[
                  const SizedBox(height: 16),
                  _originalCard(),
                  const SizedBox(height: 16),
                  _composeCard(),
                ],
                const SizedBox(height: 22),
                _historyCard(),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
        child: child,
      );

  Widget _title(IconData icon, String text) => Row(children: [
        Icon(icon, size: 20, color: C.blue),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.navy))),
      ]);

  Widget _header() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: C.navy,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: C.navy.withOpacity(.12), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.mark_email_read_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('nav_corrections'), style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(tr('corr_subtitle'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
        ]),
      );

  Widget _searchCard() {
    final field = TextField(
      controller: _receipt,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _find(),
      onChanged: (_) {
        if (_record != null || _receiptError != null || _results.isNotEmpty) {
          setState(() { _record = null; _results = []; _receiptError = null; });
        }
      },
      decoration: InputDecoration(
        labelText: tr('corr_receipt_label'),
        hintText: tr('corr_receipt_hint'),
        prefixIcon: const Icon(Icons.search, size: 20),
        errorText: _receiptError == null ? null : tr(_receiptError!),
        errorMaxLines: 3,
      ),
    );
    final button = FilledButton.icon(
      onPressed: _searching ? null : _find,
      icon: _searching
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.search),
      label: Text(tr('corr_find')),
      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
    );
    return _card(
      child: LayoutBuilder(builder: (context, box) {
        final compact = box.maxWidth < 620;
        if (compact) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [field, const SizedBox(height: 12), button]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: field),
          const SizedBox(width: 12),
          Padding(padding: const EdgeInsets.only(top: 4), child: button),
        ]);
      }),
    );
  }

  Widget _resultsCard() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title(Icons.people_alt_outlined, '${tr('corr_pick')} (${_results.length})'),
        const SizedBox(height: 10),
        for (final r in _results)
          Builder(builder: (_) {
            final selected = identical(_record, r);
            final name = '${r['donor_name'] ?? ''}'.trim();
            return Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: selected ? C.blue.withOpacity(.08) : C.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? C.blue : C.border),
              ),
              child: ListTile(
                dense: true,
                onTap: () => setState(() {
                  _select(r);
                  _messageError = null;
                }),
                title: Text(name.isEmpty ? '-' : name,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: C.navy, fontSize: 13.5)),
                subtitle: Text(
                    '${tr('corr_ref_no')} ${r['ref_no'] ?? ''}  •  ${_money(r['amount'])}  •  ${_date(r['date'])}\n'
                    '${tr('corr_receipt_short')} ${r['receipt_no'] ?? ''}',
                    style: const TextStyle(color: C.muted, fontSize: 12, height: 1.35)),
                isThreeLine: true,
                trailing: Icon(selected ? Icons.check_circle : Icons.chevron_right,
                    color: selected ? C.blue : C.muted),
              ),
            );
          }),
      ]),
    );
  }

  Widget _kv(String label, String value, {IconData? icon}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: C.muted, fontSize: 13)),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(color: C.text, fontSize: 13.5, fontWeight: FontWeight.w700))),
        ]),
      );

  Widget _originalCard() {
    final r = _record!;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title(Icons.receipt_long, tr('corr_original_title')),
        const SizedBox(height: 10),
        _kv(tr('corr_receipt_short'), _receiptNo()),
        _kv(tr('corr_ref_no'), '${r['ref_no'] ?? ''}'.trim()),
        _kv(tr('corr_donor'), '${r['donor_name'] ?? ''}'.trim()),
        _kv(tr('corr_amount'), _money(r['amount'])),
        _kv(tr('corr_purpose'), _purpose()),
        _kv(tr('corr_date'), _date(r['date'])),
      ]),
    );
  }

  Widget _composeCard() {
    final preview = _message.text.trim().isEmpty ? '' : _composed();
    final parts = SmsService.segments(preview);
    final canSend = SmsService.supported && !_sending;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title(Icons.edit_note, tr('corr_message_label')),
        const SizedBox(height: 14),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          onChanged: (_) { if (_phoneError != null) setState(() => _phoneError = null); },
          decoration: InputDecoration(
            labelText: tr('corr_phone'),
            hintText: tr('corr_phone_hint'),
            prefixIcon: const Icon(Icons.phone_outlined, size: 20),
            errorText: _phoneError == null ? null : tr(_phoneError!),
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _message,
          minLines: 3,
          maxLines: 6,
          maxLength: _maxMessageLength,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() => _messageError = null),
          decoration: InputDecoration(
            labelText: tr('corr_message_label'),
            hintText: tr('corr_message_hint'),
            alignLabelWithHint: true,
            errorText: _messageError == null ? null : tr(_messageError!),
            errorMaxLines: 3,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _useTemplate,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: Text(tr('corr_template')),
          ),
        ),
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(tr('corr_preview'), style: const TextStyle(color: C.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(preview, style: const TextStyle(color: C.text, fontSize: 13.5, height: 1.4)),
              const SizedBox(height: 6),
              Text('${preview.runes.length} ${tr('corr_chars')}  •  $parts ${tr('corr_parts')}',
                  style: const TextStyle(color: C.muted, fontSize: 11.5)),
            ]),
          ),
        ],
        if (!SmsService.supported) ...[
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, size: 18, color: C.gold),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('sms_unsupported'), style: const TextStyle(color: C.muted, fontSize: 12.5))),
          ]),
        ],
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
            onPressed: canSend ? _send : null,
            icon: _sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            label: Text(_sending ? tr('corr_sending') : tr('corr_send')),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
          ),
          OutlinedButton.icon(
            onPressed: _sending ? null : _clearForm,
            icon: const Icon(Icons.clear_all),
            label: Text(tr('corr_clear')),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16)),
          ),
        ]),
      ]),
    );
  }

  Widget _historyCard() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _title(Icons.history, tr('corr_history')),
        const SizedBox(height: 10),
        if (_loadingHistory)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
        else if (_history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(tr('corr_history_empty'), style: const TextStyle(color: C.muted)),
          )
        else
          for (final h in _history) _historyTile(h),
      ]),
    );
  }

  Widget _historyTile(Map<String, Object?> h) {
    final sent = '${h['status']}' == 'SENT';
    final color = sent ? C.green : C.red;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${h['donor_name'] ?? ''}  •  ${tr('corr_receipt_short')} ${h['receipt_no'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: C.navy, fontSize: 13.5)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
            child: Text(sent ? tr('corr_status_sent') : tr('corr_status_failed'),
                style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('${_dateTime(h['created_at'])}  •  ${h['contact'] ?? ''}', style: const TextStyle(color: C.muted, fontSize: 12)),
        const SizedBox(height: 6),
        Text('${h['message'] ?? ''}', style: const TextStyle(color: C.text, fontSize: 13, height: 1.4)),
      ]),
    );
  }
}

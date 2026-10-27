import 'package:flutter/material.dart';
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/sms_service.dart';

/// Ujumbe wa dharura: admin anachagua watu kutoka orodha ya waliosajiliwa na kuwatumia
/// SMS wakati wowote, kupitia SIM ya simu hii.
class BroadcastPage extends StatefulWidget {
  const BroadcastPage({super.key});

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> {
  static const _minLength = 5;
  static const _maxLength = 480;

  final _q = TextEditingController();
  final _message = TextEditingController();
  List<Map<String, Object?>> _donors = [];
  final Set<int> _selected = {};
  List<Map<String, Object?>> _history = [];
  bool _loading = true;
  bool _sending = false;
  bool _greeting = true;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadHistory();
  }

  @override
  void dispose() {
    _q.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final my = ++_seq;
    List<Map<String, Object?>> rows = [];
    try {
      rows = await AppDb.instance.searchDonors(_q.text, limit: 1000);
    } catch (_) {}
    if (!mounted || my != _seq) return;
    setState(() {
      _donors = rows;
      _loading = false;
    });
  }

  Future<void> _loadHistory() async {
    try {
      final rows = await AppDb.instance.getBroadcasts();
      if (mounted) setState(() => _history = rows);
    } catch (_) {}
  }

  int _idOf(Map<String, Object?> d) => (d['id'] as num).toInt();
  bool _hasPhone(Map<String, Object?> d) => SmsService.normalize('${d['contact'] ?? ''}') != null;

  void _selectAllWithPhone() => setState(() {
        for (final d in _donors) {
          if (_hasPhone(d)) _selected.add(_idOf(d));
        }
      });

  void _clearSelection() => setState(_selected.clear);

  String _textFor(Map<String, Object?> d) {
    final body = _message.text.trim().replaceAll(RegExp(r'[ \t]+'), ' ');
    if (!_greeting) return body;
    final lead = L10n.instance.lang == 'en' ? 'Dear' : 'Mpendwa';
    return '$lead ${d['name']}, $body';
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.red.shade700 : C.teal,
      ));
  }

  Future<void> _send() async {
    if (_sending) return;
    final chosen = <Map<String, Object?>>[];
    for (final id in _selected) {
      final d = await AppDb.instance.getDonor(id);
      if (d != null) chosen.add(d);
    }
    if (chosen.isEmpty) return _snack(tr('broadcast_no_recipients'), error: true);
    if (_message.text.trim().length < _minLength) return _snack(tr('broadcast_message_short'), error: true);
    if (!mounted) return;

    final sample = _textFor(chosen.first);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('broadcast_confirm_title')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${tr('broadcast_confirm_to')}: ${chosen.length}', style: const TextStyle(fontWeight: FontWeight.w800, color: C.navy)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.border)),
              child: Text(sample, style: const TextStyle(fontSize: 13, color: C.text)),
            ),
            const SizedBox(height: 10),
            Text(tr('broadcast_confirm_message'), style: const TextStyle(fontSize: 12, color: C.muted)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.send, size: 18), label: Text(tr('broadcast_send'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _sending = true);
    final items = [
      for (final d in chosen) {'contact': '${d['contact'] ?? ''}', 'text': _textFor(d)},
    ];
    final r = await SmsService.sendMany(items);
    if (!mounted) return;
    setState(() => _sending = false);

    if (r.unsupported) return _snack(tr('sms_unsupported'), error: true);
    if (r.permissionDenied) return _snack(tr('sms_permission_denied'), error: true);

    try {
      await AppDb.instance.addBroadcast(
        message: _message.text.trim(),
        recipients: chosen.length,
        sent: r.sent,
        failed: r.failed,
        invalid: r.invalid,
        names: chosen.map((d) => '${d['name']}').join(', '),
      );
      await AppDb.instance.audit('EMERGENCY_MESSAGE', 'recipients=${chosen.length}; sent=${r.sent}; failed=${r.failed}; invalid=${r.invalid}');
    } catch (_) {}

    final b = StringBuffer('${tr('sms_sent')}: ${r.sent}');
    if (r.failed > 0) b.write('\n${tr('sms_failed')}: ${r.failed}');
    if (r.invalid > 0) b.write('\n${tr('sms_invalid')}: ${r.invalid}');
    _snack(b.toString(), error: r.sent == 0);
    if (r.sent > 0) {
      setState(() {
        _message.clear();
        _selected.clear();
      });
    }
    await _loadHistory();
  }

  String _dateTime(Object? raw) {
    final d = DateTime.tryParse('${raw ?? ''}');
    if (d == null) return '${raw ?? ''}';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.instance,
      builder: (context, _) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pagePad(context), 16, pagePad(context), 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _intro(),
              const SizedBox(height: 14),
              _recipientsCard(),
              const SizedBox(height: 14),
              _messageCard(),
              const SizedBox(height: 14),
              _historyCard(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
        child: child,
      );

  Widget _intro() => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: C.gold.withOpacity(.25), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.campaign_outlined, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('broadcast_title'), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(tr('broadcast_subtitle'), style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            ]),
          ),
        ]),
      );

  Widget _recipientsCard() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('broadcast_recipients'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.navy)),
        const SizedBox(height: 10),
        TextField(
          controller: _q,
          onChanged: (_) => _load(),
          decoration: InputDecoration(hintText: tr('donors_search'), prefixIcon: const Icon(Icons.search, size: 20)),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          OutlinedButton.icon(onPressed: _selectAllWithPhone, icon: const Icon(Icons.done_all, size: 18), label: Text(tr('broadcast_select_all'))),
          TextButton(onPressed: _selected.isEmpty ? null : _clearSelection, child: Text(tr('broadcast_clear'))),
          Text('${tr('broadcast_selected')}: ${_selected.length}', style: const TextStyle(fontWeight: FontWeight.w800, color: C.navy, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        if (_loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (_donors.isEmpty)
          Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(tr('donors_empty'), style: const TextStyle(color: C.muted))))
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 340),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _donors.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final d = _donors[i];
                final id = _idOf(d);
                final phone = _hasPhone(d);
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _selected.contains(id),
                  onChanged: phone ? (v) => setState(() => v == true ? _selected.add(id) : _selected.remove(id)) : null,
                  title: Text('${d['name']}', style: const TextStyle(fontWeight: FontWeight.w700, color: C.navy)),
                  subtitle: Text(
                    phone ? '${d['contact']}' : tr('broadcast_no_phone'),
                    style: TextStyle(fontSize: 12, color: phone ? C.muted : Colors.red.shade700),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _messageCard() {
    final text = _message.text.trim();
    final sample = _donors.isEmpty ? text : _textFor(_selected.isEmpty ? _donors.first : _donors.firstWhere((d) => _selected.contains(_idOf(d)), orElse: () => _donors.first));
    final segs = SmsService.segments(sample);
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('broadcast_message'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.navy)),
        const SizedBox(height: 10),
        TextField(
          controller: _message,
          maxLines: 5,
          minLines: 3,
          maxLength: _maxLength,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: tr('broadcast_message_hint'), alignLabelWithHint: true),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(tr('broadcast_greeting'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.navy)),
          value: _greeting,
          onChanged: (v) => setState(() => _greeting = v),
        ),
        if (text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${tr('broadcast_segments')}: $segs', style: const TextStyle(fontSize: 12, color: C.muted)),
          ),
        if (!SmsService.supported)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(tr('sms_unsupported'), style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: (_sending || !SmsService.supported) ? null : _send,
            icon: _sending
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 18),
            label: Text(tr('broadcast_send')),
          ),
        ),
      ]),
    );
  }

  Widget _historyCard() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('broadcast_history'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.navy)),
        const SizedBox(height: 8),
        if (_history.isEmpty)
          Text(tr('broadcast_history_empty'), style: const TextStyle(color: C.muted, fontSize: 13))
        else
          for (final h in _history)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '${_dateTime(h['created_at'])}  •  ${tr('broadcast_recipients')}: ${h['recipients']}  •  ${tr('sms_sent')}: ${h['sent']}'
                  '${(h['failed'] as num? ?? 0) > 0 ? '  •  ${tr('sms_failed')}: ${h['failed']}' : ''}',
                  style: const TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text('${h['message']}', style: const TextStyle(fontSize: 13, color: C.text)),
              ]),
            ),
      ]),
    );
  }
}

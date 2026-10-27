import 'package:flutter/material.dart';
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/sms_service.dart';

/// Jina la jinsia kwa kuonyesha: KE, ME au ME&KE (mume na mke).
String sexLabel(String sex) {
  switch (sex) {
    case 'KE':
      return tr('sex_female');
    case 'ME':
      return tr('sex_male');
    case 'ME&KE':
      return tr('sex_couple');
    default:
      return '—';
  }
}

/// Fomu ya kusajili mtu mpya au kuhariri usajili wake.
/// Inarudisha mstari wa mtu aliyehifadhiwa (kutoka jedwali la `donors`) au null ikighairiwa.
Future<Map<String, Object?>?> showDonorForm(
  BuildContext context, {
  Map<String, Object?>? donor,
  String initialName = '',
}) {
  return showDialog<Map<String, Object?>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DonorFormDialog(donor: donor, initialName: initialName),
  );
}

class _DonorFormDialog extends StatefulWidget {
  final Map<String, Object?>? donor;
  final String initialName;
  const _DonorFormDialog({required this.donor, required this.initialName});

  @override
  State<_DonorFormDialog> createState() => _DonorFormDialogState();
}

class _DonorFormDialogState extends State<_DonorFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _envelope;
  String _sex = '';
  String? _error;
  bool _saving = false;

  bool get _editing => widget.donor != null;

  @override
  void initState() {
    super.initState();
    final d = widget.donor;
    _name = TextEditingController(text: d == null ? widget.initialName : '${d['name'] ?? ''}');
    _contact = TextEditingController(text: d == null ? '' : '${d['contact'] ?? ''}');
    _envelope = TextEditingController(text: d == null ? '' : '${d['envelope_no'] ?? ''}');
    _sex = d == null ? '' : '${d['sex'] ?? ''}';
    if (!AppDb.validSexes.contains(_sex)) _sex = '';
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _envelope.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = AppDb.donorKey(_name.text);
    if (name.length < 2) return setState(() => _error = 'donor_name_required');
    if (name.length > 60) return setState(() => _error = 'donor_name_long');
    if (!AppDb.validSexes.contains(_sex)) return setState(() => _error = 'donor_sex_required');
    final contact = _contact.text.trim();
    if (contact.isNotEmpty && SmsService.normalize(contact) == null) {
      return setState(() => _error = 'donor_contact_invalid');
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = _editing
          ? await AppDb.instance.updateDonor(
              id: (widget.donor!['id'] as num).toInt(),
              name: name,
              sex: _sex,
              contact: contact,
              envelopeNo: _envelope.text,
            )
          : await AppDb.instance.registerDonor(
              name: name,
              sex: _sex,
              contact: contact,
              envelopeNo: _envelope.text,
            );
      if (mounted) Navigator.pop(context, saved);
    } on StateError catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.message == 'donor_exists' ? 'donor_exists' : 'donor_save_failed'; });
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = 'donor_save_failed'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr(_editing ? 'donor_form_edit' : 'donor_form_new')),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width < 560 ? double.maxFinite : 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: _name,
              autofocus: !_editing,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: tr('donor_name'), prefixIcon: const Icon(Icons.person_outline, size: 20)),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _sex.isEmpty ? null : _sex,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('sex')),
              items: [
                DropdownMenuItem(value: 'KE', child: Text(tr('sex_female'))),
                DropdownMenuItem(value: 'ME', child: Text(tr('sex_male'))),
                DropdownMenuItem(value: 'ME&KE', child: Text(tr('sex_couple'))),
              ],
              onChanged: (v) => setState(() => _sex = v ?? ''),
            ),
            if (_sex == 'ME&KE')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(tr('sex_couple_hint'), style: const TextStyle(fontSize: 11.5, color: C.muted)),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _contact,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: tr('contact'), hintText: '07xx xxx xxx', prefixIcon: const Icon(Icons.phone_outlined, size: 20)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _envelope,
              decoration: InputDecoration(labelText: '${tr('envelope_no')} (${tr('optional')})', prefixIcon: const Icon(Icons.markunread_mailbox_outlined, size: 20)),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(tr(_error!), style: TextStyle(color: Colors.red.shade700, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(tr('cancel'))),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(tr('save')),
        ),
      ],
    );
  }
}

/// Dirisha la kutafuta mtu aliyesajiliwa. Likikosa, admin anaweza kumsajili papo hapo.
/// Inarudisha mstari wa mtu aliyechaguliwa (au aliyesajiliwa upya) au null.
Future<Map<String, Object?>?> showDonorPicker(BuildContext context) {
  return showDialog<Map<String, Object?>>(
    context: context,
    builder: (_) => const _DonorPickerDialog(),
  );
}

class _DonorPickerDialog extends StatefulWidget {
  const _DonorPickerDialog();

  @override
  State<_DonorPickerDialog> createState() => _DonorPickerDialogState();
}

class _DonorPickerDialogState extends State<_DonorPickerDialog> {
  final _q = TextEditingController();
  List<Map<String, Object?>> _items = [];
  bool _loading = true;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final my = ++_seq;
    List<Map<String, Object?>> rows = [];
    try {
      rows = await AppDb.instance.searchDonors(_q.text, limit: 80);
    } catch (_) {}
    if (!mounted || my != _seq) return;
    setState(() {
      _items = rows;
      _loading = false;
    });
  }

  Future<void> _register() async {
    final saved = await showDonorForm(context, initialName: _q.text.trim());
    if (saved != null && mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return AlertDialog(
      title: Text(tr('donor_pick_title')),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width < 560 ? double.maxFinite : 480,
        height: (h * 0.55).clamp(260.0, 460.0),
        child: Column(children: [
          TextField(
            controller: _q,
            autofocus: true,
            onChanged: (_) => _load(),
            decoration: InputDecoration(
              hintText: tr('donors_search'),
              prefixIcon: const Icon(Icons.search, size: 20),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(tr('donor_pick_none'), textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
                          const SizedBox(height: 12),
                          FilledButton.icon(onPressed: _register, icon: const Icon(Icons.person_add_alt_1, size: 18), label: Text(tr('donor_register_new'))),
                        ]),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final d = _items[i];
                          final sub = [
                            if ('${d['sex'] ?? ''}'.isNotEmpty) '${d['sex']}',
                            if ('${d['contact'] ?? ''}'.isNotEmpty) '${d['contact']}',
                            if ('${d['envelope_no'] ?? ''}'.isNotEmpty) '${tr('envelope_no')}: ${d['envelope_no']}',
                          ].join('  •  ');
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            title: Text('${d['name']}', style: const TextStyle(fontWeight: FontWeight.w700, color: C.navy)),
                            subtitle: sub.isEmpty ? null : Text(sub, style: const TextStyle(fontSize: 12, color: C.muted)),
                            onTap: () => Navigator.pop(context, d),
                          );
                        },
                      ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
        if (!_loading && _items.isNotEmpty)
          OutlinedButton.icon(onPressed: _register, icon: const Icon(Icons.person_add_alt_1, size: 18), label: Text(tr('donor_register_new'))),
      ],
    );
  }
}

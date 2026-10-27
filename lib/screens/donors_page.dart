import 'package:flutter/material.dart';
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../widgets/donor_picker.dart';

/// Usajili wa watu: admin anasajili majina ya watu kwanza; baadaye, wakati wa kuingiza
/// michango, anamtafuta mtu aliyesajiliwa badala ya kuandika jina upya.
class DonorsPage extends StatefulWidget {
  const DonorsPage({super.key});

  @override
  State<DonorsPage> createState() => _DonorsPageState();
}

class _DonorsPageState extends State<DonorsPage> {
  final _q = TextEditingController();
  List<Map<String, Object?>> _items = [];
  int _total = 0;
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
    var total = 0;
    try {
      rows = await AppDb.instance.searchDonors(_q.text, limit: 1000);
      total = await AppDb.instance.donorCount();
    } catch (_) {}
    if (!mounted || my != _seq) return;
    setState(() {
      _items = rows;
      _total = total;
      _loading = false;
    });
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

  Future<void> _add() async {
    final saved = await showDonorForm(context, initialName: _q.text.trim());
    if (saved == null) return;
    _snack(tr('donor_saved'));
    await _load();
  }

  Future<void> _edit(Map<String, Object?> d) async {
    final saved = await showDonorForm(context, donor: d);
    if (saved == null) return;
    _snack(tr('donor_saved'));
    await _load();
  }

  Future<void> _delete(Map<String, Object?> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('donor_delete_title')),
        content: Text('${d['name']}\n\n${tr('donor_delete_message')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline),
            label: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppDb.instance.deleteDonor((d['id'] as num).toInt());
      _snack(tr('donor_deleted'));
      await _load();
    } catch (_) {
      _snack(tr('delete_failed'), error: true);
    }
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
              _toolbar(),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else if (_items.isEmpty)
                _empty()
              else
                ..._items.map(_card),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _intro() => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: C.teal.withOpacity(.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.how_to_reg_outlined, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('donors_title'), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(tr('donors_subtitle'), style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            ]),
          ),
        ]),
      );

  Widget _toolbar() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
        child: LayoutBuilder(builder: (context, c) {
          final search = TextField(
            controller: _q,
            onChanged: (_) => _load(),
            decoration: InputDecoration(
              hintText: tr('donors_search'),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _q.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _q.clear();
                        _load();
                      },
                    ),
            ),
          );
          final add = FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: Text(tr('donors_add')),
          );
          final count = Text('${tr('donors_registered')}: $_total', style: const TextStyle(color: C.muted, fontSize: 12, fontWeight: FontWeight.w700));
          if (c.maxWidth < 620) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              search,
              const SizedBox(height: 10),
              add,
              const SizedBox(height: 8),
              count,
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: search), const SizedBox(width: 12), add]),
            const SizedBox(height: 8),
            count,
          ]);
        }),
      );

  Widget _empty() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
        child: Center(child: Text(tr('donors_empty'), textAlign: TextAlign.center, style: const TextStyle(color: C.muted))),
      );

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(.14), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
      );

  Widget _card(Map<String, Object?> d) {
    final sex = '${d['sex'] ?? ''}';
    final contact = '${d['contact'] ?? ''}'.trim();
    final env = '${d['envelope_no'] ?? ''}'.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
      child: Row(children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: C.blue.withOpacity(.1),
          child: Icon(sex == 'ME&KE' ? Icons.people_alt_outlined : Icons.person_outline, color: C.blue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${d['name']}', style: const TextStyle(fontWeight: FontWeight.w800, color: C.navy, fontSize: 14)),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (sex.isNotEmpty) _chip(sex, sex == 'ME&KE' ? C.purple : (sex == 'KE' ? C.gold : C.teal)),
              if (contact.isNotEmpty) Text(contact, style: const TextStyle(fontSize: 12, color: C.muted)),
              if (env.isNotEmpty) Text('${tr('envelope_no')}: $env', style: const TextStyle(fontSize: 12, color: C.muted)),
            ]),
          ]),
        ),
        IconButton(tooltip: tr('edit'), icon: const Icon(Icons.edit_outlined, size: 19), onPressed: () => _edit(d)),
        IconButton(tooltip: tr('delete'), icon: Icon(Icons.delete_outline, size: 19, color: Colors.red.shade700), onPressed: () => _delete(d)),
      ]),
    );
  }
}

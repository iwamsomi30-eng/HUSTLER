import 'package:flutter/material.dart';

import '../core/contribution_matrix.dart';
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/matrix_export_service.dart';

/// Ukurasa wa mtoaji mmoja: taarifa zake zote kuanzia mwanzo hadi mwisho (A-Z).
class DonorProfilePage extends StatefulWidget {
  final String donorKey;
  final bool showNames;
  const DonorProfilePage({super.key, required this.donorKey, this.showNames = false});

  @override
  State<DonorProfilePage> createState() => _DonorProfilePageState();
}

class _DonorProfilePageState extends State<DonorProfilePage> {
  DonorRecord? _donor;
  bool _loading = true;
  late bool _showNames;

  @override
  void initState() {
    super.initState();
    _showNames = widget.showNames;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ledger = await AppDb.instance.getContributionLedger();
    final m = ContributionMatrix.build(ledger);
    DonorRecord? found;
    for (final d in m.donors) {
      if (d.key == widget.donorKey) found = d;
    }
    if (mounted) setState(() { _donor = found; _loading = false; });
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _money(num v) => '${v.round()} TZS';

  Future<void> _exportExcel() async {
    final d = _donor;
    if (d == null) return;
    final m = ScaffoldMessenger.of(context);
    try {
      final r = await MatrixExportService.saveDonorExcel(d);
      m.showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(r.cancelled ? tr('excel_cancelled') : '${tr('excel_saved')}: ${r.name}${r.displayPath != null ? '\n${r.displayPath}' : ''}'),
      ));
    } catch (_) {
      m.showSnackBar(SnackBar(content: Text(tr('dash_export_failed'))));
    }
  }

  Future<void> _exportPdf() async {
    final d = _donor;
    if (d == null) return;
    final m = ScaffoldMessenger.of(context);
    try {
      await MatrixExportService.shareDonorPdf(d);
    } catch (_) {
      m.showSnackBar(SnackBar(content: Text(tr('dash_export_failed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _donor;
    return ListenableBuilder(
      listenable: L10n.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(tr('donor_profile')),
          actions: [
            IconButton(onPressed: d == null ? null : _exportPdf, tooltip: 'PDF', icon: const Icon(Icons.picture_as_pdf)),
            IconButton(onPressed: d == null ? null : _exportExcel, tooltip: 'Excel', icon: const Icon(Icons.table_view)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : d == null
                ? Center(child: Text(tr('records_empty')))
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(pagePad(context), 16, pagePad(context), 36),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _hero(d),
                          const SizedBox(height: 14),
                          _byName(d),
                          const SizedBox(height: 14),
                          _entries(d),
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

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 150, child: Text(k, style: const TextStyle(fontSize: 12, color: C.muted))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.text))),
        ]),
      );

  Widget _hero(DonorRecord d) {
    final last = d.entries.isEmpty ? null : (d.entries.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b));
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(tr('donor_profile'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: C.navy))),
          Switch(value: _showNames, onChanged: (v) => setState(() => _showNames = v)),
          Text(tr('show_names'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        _kv(tr('col_name'), _showNames ? (d.name.isEmpty ? '—' : d.name) : '••••••••'),
        _kv(tr('env_or_donor_no'), d.idNo.isEmpty ? '—' : d.idNo),
        _kv(tr('contact'), _showNames ? (d.contact.isEmpty ? '—' : d.contact) : '••••••••'),
        _kv(tr('sex'), d.sex.isEmpty ? '—' : d.sex),
        _kv(tr('col_reg_date'), _date(d.firstDate)),
        if (last != null) _kv(tr('donor_last_gift'), _date(last)),
        const Divider(height: 24),
        Row(children: [
          Expanded(child: _metric(tr('donor_total'), _money(d.total))),
          const SizedBox(width: 10),
          Expanded(child: _metric(tr('donor_gift_count'), '${d.entries.length}')),
        ]),
      ]),
    );
  }

  Widget _metric(String label, String value) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.navy)),
        ]),
      );

  Widget _byName(DonorRecord d) {
    final totals = d.totalsByName().entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('donor_by_name'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.navy)),
        const SizedBox(height: 8),
        for (final e in totals)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700, color: C.text))),
              Text(_money(e.value), style: const TextStyle(fontWeight: FontWeight.w800, color: C.navy)),
            ]),
          ),
      ]),
    );
  }

  Widget _entries(DonorRecord d) {
    final list = [...d.entries]..sort((a, b) => b.date.compareTo(a.date));
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('donor_entries'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.navy)),
        const SizedBox(height: 8),
        for (final e in list)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 92, child: Text(_date(e.date), style: const TextStyle(fontSize: 12, color: C.muted))),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.contributionName, style: const TextStyle(fontWeight: FontWeight.w700, color: C.text)),
                  if (e.receiptNo.isNotEmpty) Text(e.receiptNo, style: const TextStyle(fontSize: 11, color: C.muted)),
                ]),
              ),
              Text(_money(e.amount), style: const TextStyle(fontWeight: FontWeight.w800, color: C.navy)),
            ]),
          ),
      ]),
    );
  }
}

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
    if (!mounted) return;
    final hadDonor = _donor != null;
    setState(() { _donor = found; _loading = false; });
    // Mchango wa mwisho ukifutwa, mtoaji hana tena rekodi: rudi kwenye orodha.
    if (found == null && hadDonor && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  /// Admin anaweza kufuta mchango wowote wa mtoaji, wakati wowote.
  Future<void> _deleteEntry(DonorEntry e) async {
    if (e.rowId <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete_record_title')),
        content: Text(
          '${tr('delete_record_message')}\n\n'
          '${e.contributionName}  •  ${_date(e.date)}\n'
          '${tr('amount')}: ${_money(e.amount)}'
          '${e.receiptNo.isEmpty ? '' : '\n${e.receiptNo}'}',
        ),
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppDb.instance.deleteContributionRow(id: e.rowId, isFungu: e.isFungu);
      messenger.showSnackBar(SnackBar(content: Text(tr('delete_contribution_success')), behavior: SnackBarBehavior.floating, backgroundColor: C.teal));
      await _load();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(tr('delete_failed')), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red.shade700));
    }
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
    final last = d.entries.isEmpty ? null : d.entries.reduce((a, b) => a.sortTime.isAfter(b.sortTime) ? a : b);
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
        if (last != null) _kv(tr('donor_last_gift'), last.timeLabel.isEmpty ? _date(last.date) : '${_date(last.date)}   ${last.timeLabel}'),
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
    final split = d.totalsByNameService();
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('donor_by_name'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.navy)),
        const SizedBox(height: 8),
        for (final e in totals) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Row(children: [
              Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700, color: C.text))),
              Text(_money(e.value), style: const TextStyle(fontWeight: FontWeight.w800, color: C.navy)),
            ]),
          ),
          // Mgawanyo kwa ibada: IBADA I / IBADA II, na mara ngapi.
          for (final p in split.where((p) => p.name == e.key))
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 2, bottom: 2),
              child: Row(children: [
                Expanded(child: Text('${tr('service')} ${serviceRoman(p.service)}  •  ×${p.count}', style: const TextStyle(fontSize: 12, color: C.muted))),
                Text(_money(p.amount), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.text)),
              ]),
            ),
        ],
      ]),
    );
  }

  Widget _entries(DonorRecord d) {
    // Kila mchango unaonekana peke yake, mpya juu, ukiwa na tarehe na saa.
    final list = [...d.entries]..sort((a, b) => b.sortTime.compareTo(a.sortTime));
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('donor_entries'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: C.navy)),
        const SizedBox(height: 8),
        for (final e in list)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 96,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_date(e.date), style: const TextStyle(fontSize: 12, color: C.muted)),
                  if (e.timeLabel.isNotEmpty)
                    Text(e.timeLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.text)),
                ]),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(e.contributionName, style: const TextStyle(fontWeight: FontWeight.w700, color: C.text))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: C.teal.withOpacity(.15), borderRadius: BorderRadius.circular(8)),
                      child: Text(e.service == 2 ? tr('ibada_two') : tr('ibada_one'), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: C.navy)),
                    ),
                  ]),
                  if (e.receiptNo.isNotEmpty) Text(e.receiptNo, style: const TextStyle(fontSize: 11, color: C.muted)),
                ]),
              ),
              Text(_money(e.amount), style: const TextStyle(fontWeight: FontWeight.w800, color: C.navy)),
              if (e.rowId > 0)
                IconButton(
                  tooltip: tr('delete'),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline, size: 19, color: Colors.red.shade700),
                  onPressed: () => _deleteEntry(e),
                ),
            ]),
          ),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

const _expenseCategories = <String>[
  'MICHANGO', 'MALIPO YA WAHUDUMU', 'MALIPO YA HUDUMA',
  'MALIPO YA UNUNUZI NA MATENGENEZO', 'UJENZI', 'IDARA', 'AKIBA',
];

class ExpenditureRecordsPage extends StatefulWidget {
  const ExpenditureRecordsPage({super.key});
  @override
  State<ExpenditureRecordsPage> createState() => _ExpenditureRecordsPageState();
}

class _ExpenditureRecordsPageState extends State<ExpenditureRecordsPage> {
  final _search = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  String _category = 'ALL';
  bool _loading = true;
  List<Map<String, Object?>> _records = [];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await AppDb.instance.getExpenditureBatches(search: _search.text, from: _from, to: _to, category: _category == 'ALL' ? null : _category);
      if (mounted) setState(() { _records = rows; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _message(tr('expense_read_failed'), error: true);
    }
  }

  String _date(Object? raw) {
    final d = DateTime.tryParse('${raw ?? ''}');
    if (d == null) return '${raw ?? ''}';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
  double _number(Object? value) => (value as num?)?.toDouble() ?? 0;
  String _money(Object? value) => _number(value).round().toString().replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (_) => ',');
  double get _filteredTotal => _records.fold<double>(0, (sum, row) => sum + _number(row['total']));

  Future<void> _pickDate(bool start) async {
    final initial = start ? (_from ?? DateTime.now()) : (_to ?? _from ?? DateTime.now());
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked == null) return;
    setState(() { if (start) { _from = picked; } else { _to = picked; } });
    await _load();
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value), behavior: SnackBarBehavior.floating, backgroundColor: error ? Colors.red.shade700 : C.teal));
  }

  Future<void> _showDetails(Map<String, Object?> batch) async {
    final id = (batch['id'] as num).toInt();
    final entries = await AppDb.instance.getExpenditureBatchDetails(id);
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('${batch['category']} • ${_date(batch['date'])}'),
      content: SizedBox(width: 650, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _detailLine('Mfuko', '${batch['fund_name']}'.isEmpty ? '—' : '${batch['fund_name']}'),
        if ('${batch['note']}'.trim().isNotEmpty) _detailLine('Maelezo', '${batch['note']}'),
        const Divider(height: 24),
        for (final entry in entries) Card(color: C.bg, elevation: 0, child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${entry['description']}', style: const TextStyle(fontWeight: FontWeight.w800, color: C.text)),
          const SizedBox(height: 5), Text('Mlipwa: ${entry['payee'] ?? '—'}   •   Ref: ${entry['reference'] ?? '—'}', style: const TextStyle(color: C.muted, fontSize: 12)),
          const SizedBox(height: 5), Text('${_money(entry['amount'])} TZS', style: const TextStyle(color: C.navy, fontWeight: FontWeight.w800)),
        ]))),
        const Divider(height: 24), Align(alignment: Alignment.centerRight, child: Text('JUMLA: ${_money(batch['total'])} TZS', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: C.navy))),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Funga')), FilledButton.icon(onPressed: () { Navigator.pop(dialogContext); _edit(batch); }, icon: const Icon(Icons.edit_outlined), label: Text(tr('edit')))],
    ));
  }

  Widget _detailLine(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 90, child: Text('$label:', style: const TextStyle(color: C.muted))), Expanded(child: Text(value, style: const TextStyle(color: C.text, fontWeight: FontWeight.w600)))]));

  Future<void> _edit(Map<String, Object?> batch) async {
    final id = (batch['id'] as num).toInt();
    final details = await AppDb.instance.getExpenditureBatchDetails(id);
    if (!mounted) return;
    final fund = TextEditingController(text: '${batch['fund_name'] ?? ''}');
    final note = TextEditingController(text: '${batch['note'] ?? ''}');
    final rows = details.map((e) => _EditExpenseRow(description: '${e['description'] ?? ''}', payee: '${e['payee'] ?? ''}', reference: '${e['reference'] ?? ''}', amount: '${e['amount'] ?? ''}')).toList();
    var editDate = DateTime.tryParse('${batch['date']}') ?? DateTime.now();
    var editCategory = _expenseCategories.contains(batch['category']) ? '${batch['category']}' : _expenseCategories.first;
    var saving = false;
    final saved = await showDialog<bool>(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) => AlertDialog(
      title: Text(tr('expense_edit_title')),
      content: SizedBox(width: 760, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: ctx, initialDate: editDate, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) setDialogState(() => editDate = d); }, icon: const Icon(Icons.calendar_month), label: Text('Tarehe: ${_date(editDate.toIso8601String())}')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: editCategory, isExpanded: true, decoration: const InputDecoration(labelText: 'Aina ya matumizi'), items: [for (final c in _expenseCategories) DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))], onChanged: (v) { if (v != null) setDialogState(() => editCategory = v); }),
        const SizedBox(height: 10), TextField(controller: fund, decoration: const InputDecoration(labelText: 'Mfuko / Source Fund')),
        const SizedBox(height: 10), TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Maelezo ya jumla')),
        const SizedBox(height: 14),
        for (var i = 0; i < rows.length; i++) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12)), child: Column(children: [
          TextField(controller: rows[i].description, decoration: const InputDecoration(labelText: 'Maelezo / Item')),
          const SizedBox(height: 8), TextField(controller: rows[i].payee, decoration: const InputDecoration(labelText: 'Mlipwa / Payee')),
          const SizedBox(height: 8), TextField(controller: rows[i].reference, decoration: const InputDecoration(labelText: 'Reference / Voucher')),
          const SizedBox(height: 8), TextField(controller: rows[i].amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Kiasi (TZS)')),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: rows.length == 1 ? null : () => setDialogState(() => rows.removeAt(i).dispose()), icon: const Icon(Icons.delete_outline), label: Text(tr('expense_remove_row')))),
        ])),
        OutlinedButton.icon(onPressed: () => setDialogState(() => rows.add(_EditExpenseRow())), icon: const Icon(Icons.add), label: Text(tr('expense_add_row'))),
      ]))),
      actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: Text(tr('cancel'))), FilledButton.icon(onPressed: saving ? null : () async {
        final valid = <Map<String, Object?>>[];
        for (final row in rows) {
          final amount = double.tryParse(row.amount.text.replaceAll(',', '').trim()) ?? 0;
          if (row.description.text.trim().isEmpty || amount <= 0) { _message(tr('expense_row_invalid'), error: true); return; }
          valid.add({'description': row.description.text.trim(), 'payee': row.payee.text.trim(), 'reference': row.reference.text.trim(), 'amount': amount});
        }
        setDialogState(() => saving = true);
        try { await AppDb.instance.updateExpenditureBatch(batchId: id, date: editDate.toIso8601String(), category: editCategory, fundName: fund.text, note: note.text, rows: valid); if (ctx.mounted) Navigator.pop(ctx, true); }
        catch (_) { setDialogState(() => saving = false); _message(tr('expense_edit_failed'), error: true); }
      }, icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined), label: Text(tr('save_changes')))],
    )));
    fund.dispose(); note.dispose(); for (final row in rows) { row.dispose(); }
    if (saved == true) { _message(tr('expense_edit_success')); await _load(); }
  }

  Future<void> _delete(Map<String, Object?> batch) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(tr('expense_delete_title')), content: Text('Una uhakika unataka kufuta ${batch['category']} ya tarehe ${_date(batch['date'])}? Hatua hii haiwezi kutenguliwa.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700), child: const Text('Futa'))]));
    if (ok != true) return;
    try { await AppDb.instance.deleteExpenditureBatch((batch['id'] as num).toInt()); _message(tr('expense_delete_success')); await _load(); } catch (_) { _message('Imeshindikana kufuta rekodi.', error: true); }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: L10n.instance, builder: (context, _) => RefreshIndicator(onRefresh: _load, child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(20, 20, 20, 36), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1250), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _header(), const SizedBox(height: 16), _filters(), const SizedBox(height: 14), _totals(), const SizedBox(height: 14),
    if (_loading) const Padding(padding: EdgeInsets.all(44), child: Center(child: CircularProgressIndicator())) else if (_records.isEmpty) _empty() else ..._records.map(_recordCard),
  ])))));

  Widget _header() => Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: C.navy.withOpacity(.12), blurRadius: 18, offset: const Offset(0, 8))]), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_long, color: Colors.white)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tr('nav_matumizi_records'), style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(tr('expense_records_subtitle'), style: const TextStyle(color: Colors.white70, fontSize: 13))])), IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh, color: Colors.white))]));

  Widget _filters() => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)), child: LayoutBuilder(builder: (context, box) {
    final compact = box.maxWidth < 800;
    final search = TextField(controller: _search, onSubmitted: (_) => _load(), onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: tr('expense_search_hint'), prefixIcon: const Icon(Icons.search), suffixIcon: _search.text.isEmpty ? null : IconButton(onPressed: () { _search.clear(); _load(); setState(() {}); }, icon: const Icon(Icons.clear))));
    final category = DropdownButtonFormField<String>(value: _category, isExpanded: true, decoration: const InputDecoration(labelText: 'Aina ya matumizi'), items: [DropdownMenuItem(value: 'ALL', child: Text(tr('expense_category_all'))), for (final c in _expenseCategories) DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))], onChanged: (v) { if (v != null) setState(() => _category = v); _load(); });
    final from = OutlinedButton.icon(onPressed: () => _pickDate(true), icon: const Icon(Icons.event), label: Text(_from == null ? 'Kuanzia' : _date(_from!.toIso8601String())));
    final to = OutlinedButton.icon(onPressed: () => _pickDate(false), icon: const Icon(Icons.event), label: Text(_to == null ? 'Hadi' : _date(_to!.toIso8601String())));
    final clear = TextButton.icon(onPressed: (_from == null && _to == null && _search.text.isEmpty && _category == 'ALL') ? null : () { setState(() { _from = null; _to = null; _category = 'ALL'; _search.clear(); }); _load(); }, icon: const Icon(Icons.filter_alt_off), label: Text(tr('clear_filters')));
    if (compact) return Column(children: [search, const SizedBox(height: 10), category, const SizedBox(height: 10), Row(children: [Expanded(child: from), const SizedBox(width: 8), Expanded(child: to)]), Align(alignment: Alignment.centerRight, child: clear)]);
    return Column(children: [Row(children: [Expanded(flex: 3, child: search), const SizedBox(width: 10), Expanded(flex: 2, child: category)]), const SizedBox(height: 10), Row(children: [from, const SizedBox(width: 8), to, const Spacer(), clear])]);
  }));

  Widget _totals() => LayoutBuilder(builder: (context, box) { final compact = box.maxWidth < 600; return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: C.teal.withOpacity(.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: C.teal.withOpacity(.25))), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: C.teal, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.payments_outlined, color: Colors.white)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tr('expense_filtered_total'), style: TextStyle(fontSize: compact ? 10 : 12, fontWeight: FontWeight.w800, color: C.muted)), const SizedBox(height: 4), Text('${_money(_filteredTotal)} TZS', style: TextStyle(fontSize: compact ? 20 : 24, fontWeight: FontWeight.w900, color: C.navy))])), Text('${_records.length} ${tr('expense_records_count')}', style: const TextStyle(color: C.teal, fontWeight: FontWeight.w800))])); });

  Widget _recordCard(Map<String, Object?> row) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)), child: LayoutBuilder(builder: (context, box) {
    final compact = box.maxWidth < 680;
    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${row['category']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: C.navy)), const SizedBox(height: 5), Text('${_date(row['date'])} • ${row['entries']} mistari', style: const TextStyle(color: C.muted, fontSize: 12)), if ('${row['fund_name']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: Text('Mfuko: ${row['fund_name']}', style: const TextStyle(color: C.text, fontSize: 12))), const SizedBox(height: 8), Text('${_money(row['total'])} TZS', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: C.teal))]);
    final actions = Wrap(spacing: 4, children: [IconButton(tooltip: 'Details', onPressed: () => _showDetails(row), icon: const Icon(Icons.visibility_outlined, color: C.navy)), IconButton(tooltip: 'Hariri', onPressed: () => _edit(row), icon: const Icon(Icons.edit_outlined, color: C.teal)), IconButton(tooltip: 'Futa', onPressed: () => _delete(row), icon: Icon(Icons.delete_outline, color: Colors.red.shade700))]);
    return compact ? Row(children: [Expanded(child: body), actions]) : Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: C.navy.withOpacity(.07), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_long, color: C.navy)), const SizedBox(width: 14), Expanded(child: body), actions]);
  })));

  Widget _empty() => Container(width: double.infinity, padding: const EdgeInsets.all(38), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)), child: Column(children: [const Icon(Icons.inbox_outlined, size: 46, color: C.muted), const SizedBox(height: 10), Text(tr('expense_empty'), textAlign: TextAlign.center, style: const TextStyle(color: C.muted))]));
}

class _EditExpenseRow {
  final TextEditingController description;
  final TextEditingController payee;
  final TextEditingController reference;
  final TextEditingController amount;
  _EditExpenseRow({String description = '', String payee = '', String reference = '', String amount = ''}) : description = TextEditingController(text: description), payee = TextEditingController(text: payee), reference = TextEditingController(text: reference), amount = TextEditingController(text: amount);
  void dispose() { description.dispose(); payee.dispose(); reference.dispose(); amount.dispose(); }
}

import 'package:flutter/material.dart';
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/contribution_export_service.dart';

class ContributionRecordsPage extends StatefulWidget {
  const ContributionRecordsPage({super.key});

  @override
  State<ContributionRecordsPage> createState() => _ContributionRecordsPageState();
}

class _ContributionRecordsPageState extends State<ContributionRecordsPage> {
  final _search = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  bool _loading = true;
  List<Map<String, Object?>> _days = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await AppDb.instance.getContributionDaySummaries(
      search: _search.text,
      from: _from,
      to: _to,
    );
    if (mounted) setState(() { _days = data; _loading = false; });
  }

  String _date(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _money(Object? value) {
    final n = safeNum(value);
    final s = n.round().toString();
    return '$s TZS';
  }

  Future<void> _pick(bool start) async {
    final initial = start ? (_from ?? DateTime.now()) : (_to ?? _from ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() { if (start) _from = picked; else _to = picked; });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.instance,
      builder: (context, _) => RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(pagePad(context), 16, pagePad(context), 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1220),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _header(),
                const SizedBox(height: 16),
                _filters(),
                const SizedBox(height: 18),
                if (_loading) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                else if (_days.isEmpty) _empty()
                else ..._days.map(_dayCard),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [C.navy, C.navyDark]),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: C.navy.withOpacity(.12), blurRadius: 18, offset: const Offset(0, 8))],
    ),
    child: Row(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.receipt_long, color: Colors.white)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('nav_michango_records'), style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(tr('records_subtitle'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ])),
      IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh, color: Colors.white)),
    ]),
  );

  Widget _filters() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
    child: LayoutBuilder(builder: (context, box) {
      final compact = box.maxWidth < 760;
      final search = TextField(
        controller: _search,
        onSubmitted: (_) => _load(),
        decoration: InputDecoration(
          hintText: tr('records_search_hint'),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _search.text.isEmpty ? null : IconButton(onPressed: () { _search.clear(); _load(); setState(() {}); }, icon: const Icon(Icons.clear)),
        ),
        onChanged: (_) => setState(() {}),
      );
      final from = OutlinedButton.icon(onPressed: () => _pick(true), icon: const Icon(Icons.event), label: Text(_from == null ? tr('from_date') : _date(_from!.toIso8601String())));
      final to = OutlinedButton.icon(onPressed: () => _pick(false), icon: const Icon(Icons.event), label: Text(_to == null ? tr('to_date') : _date(_to!.toIso8601String())));
      final clear = TextButton.icon(onPressed: (_from == null && _to == null && _search.text.isEmpty) ? null : () { setState(() { _from = null; _to = null; _search.clear(); }); _load(); }, icon: const Icon(Icons.filter_alt_off), label: Text(tr('clear_filters')));
      if (compact) return Column(children: [search, const SizedBox(height: 10), Row(children: [Expanded(child: from), const SizedBox(width: 8), Expanded(child: to)]), Align(alignment: Alignment.centerRight, child: clear)]);
      return Row(children: [Expanded(child: search), const SizedBox(width: 10), from, const SizedBox(width: 8), to, const SizedBox(width: 6), clear]);
    }),
  );

  Widget _dayCard(Map<String, Object?> row) {
    final day = (row['day'] ?? '').toString();
    final total = row['total'];
    final entries = (row['entries'] as num?)?.toInt() ?? 0;
    final batches = (row['batches'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ContributionDayDetailPage(day: day)));
            _load();
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
            child: Row(children: [
              Container(width: 54, height: 54, decoration: BoxDecoration(color: C.teal.withOpacity(.10), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.calendar_month, color: C.teal)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_date(day), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.text)),
                const SizedBox(height: 5),
                Text('$entries ${tr('records_entries')}  •  $batches ${tr('records_batches')}', style: const TextStyle(fontSize: 12, color: C.muted)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_money(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.navy)),
                const SizedBox(height: 5),
                Text(tr('view_details'), style: const TextStyle(fontSize: 12, color: C.teal, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: C.muted),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _empty() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(48),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
    child: Column(children: [
      const Icon(Icons.receipt_long_outlined, size: 52, color: C.muted),
      const SizedBox(height: 12),
      Text(tr('records_empty'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(tr('records_empty_sub'), textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
    ]),
  );
}

class ContributionDayDetailPage extends StatefulWidget {
  final String day;
  const ContributionDayDetailPage({super.key, required this.day});

  @override
  State<ContributionDayDetailPage> createState() => _ContributionDayDetailPageState();
}

class _ContributionDayDetailPageState extends State<ContributionDayDetailPage> {
  List<Map<String, Object?>> _rows = [];
  bool _loading = true;
  bool _showNames = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await AppDb.instance.getContributionDetailsForDay(widget.day);
    if (mounted) setState(() { _rows = rows; _loading = false; });
  }

  String _date(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _money(Object? value) {
    final n = safeNum(value);
    return '${n.round().toString()} TZS';
  }

  double _sumWhere(bool Function(Map<String, Object?>) test) =>
      _rows.where(test).fold<double>(0, (s, r) => s + safeNum(r['amount']));
  int _countWhere(bool Function(Map<String, Object?>) test) => _rows.where(test).length;
  double get _total => _sumWhere((_) => true);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(isPhone(context) ? _date(widget.day) : '${tr('nav_michango_records')} • ${_date(widget.day)}'),
      actions: [
        IconButton(onPressed: _loading ? null : () => ContributionExportService.sharePdf(day: widget.day, rows: _rows), tooltip: 'PDF', icon: const Icon(Icons.picture_as_pdf)),
        IconButton(onPressed: _loading ? null : () => ContributionExportService.shareExcel(day: widget.day, rows: _rows), tooltip: 'Excel', icon: const Icon(Icons.table_view)),
      ],
    ),
    body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(pagePad(context), 16, pagePad(context), 36),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1220), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _hero(),
          const SizedBox(height: 14),
          _toolbar(),
          const SizedBox(height: 14),
          if (_rows.isEmpty) _empty() else _groupedRows(),
        ]))),
      ),
    ),
  );

  Widget _hero() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
    child: LayoutBuilder(builder: (context, box) {
      final compact = box.maxWidth < 700;
      final cards = [
        _metric(tr('fungu'), _money(_sumWhere((r) => r['type'] == 'FUNGU')), '${_countWhere((r) => r['type'] == 'FUNGU')} ${tr('records_entries')}'),
        _metric(tr('other_contributions'), _money(_sumWhere((r) => r['type'] != 'FUNGU')), '${_countWhere((r) => r['type'] != 'FUNGU')} ${tr('records_entries')}'),
        _metric(tr('total'), _money(_total), '${_rows.length} ${tr('records_entries')}'),
      ];
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tr('record_day_title'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: C.navy)), const SizedBox(height: 4), Text(_date(widget.day), style: const TextStyle(color: C.muted))])), const Icon(Icons.verified_outlined, color: C.teal)]),
        const SizedBox(height: 16),
        if (compact) Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: c)]) else Row(children: [for (var i=0; i<cards.length; i++) Expanded(child: Padding(padding: EdgeInsets.only(right: i==cards.length-1?0:10), child: cards[i]))]),
      ]);
    }),
  );

  Widget _metric(String label, String value, String sub) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: C.muted)), const SizedBox(height: 5), Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: C.navy)), const SizedBox(height: 3), Text(sub, style: const TextStyle(fontSize: 11, color: C.muted))]));

  Widget _toolbar() => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)), child: Row(children: [const Icon(Icons.visibility_outlined, size: 19, color: C.muted), const SizedBox(width: 8), Expanded(child: Text(tr('real_names_admin_only'), style: const TextStyle(fontSize: 12, color: C.muted))), Switch(value: _showNames, onChanged: (v) => setState(() => _showNames = v)), Text(tr('show_names'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]));

  Widget _groupedRows() {
    final groups = <String, List<Map<String, Object?>>>{};
    for (final r in _rows) {
      final key = '${r['type']}|${r['service']}|${r['batch_id']}|${r['title']}';
      groups.putIfAbsent(key, () => []).add(r);
    }
    return Column(children: groups.entries.map((e) => _batchCard(e.value.first, e.value)).toList());
  }

  Widget _batchCard(Map<String, Object?> head, List<Map<String, Object?>> rows) {
    final isFungu = head['type'] == 'FUNGU';
    final total = rows.fold<double>(0, (s, r) => s + safeNum(r['amount']));
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: (isFungu ? C.teal : C.gold).withOpacity(.12), borderRadius: BorderRadius.circular(10)), child: Icon(isFungu ? Icons.mail_outline : Icons.volunteer_activism_outlined, color: isFungu ? C.teal : C.gold)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isFungu ? tr('fungu') : (head['title'] ?? tr('other_contributions')).toString(), style: const TextStyle(fontWeight: FontWeight.w800, color: C.text)), const SizedBox(height: 2), Text('IBADA ${head['service']} • ${rows.length} ${tr('records_entries')}', style: const TextStyle(fontSize: 12, color: C.muted))])), Text(_money(total), style: const TextStyle(fontWeight: FontWeight.w800, color: C.navy))]),
      const SizedBox(height: 12),
      if (isPhone(context)) ...rows.map((r) => _phoneRow(r, isFungu)) else SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(headingRowHeight: 38, dataRowMinHeight: 48, columns: [DataColumn(label: Text(isFungu ? tr('envelope_no') : 'MCH No.')), DataColumn(label: Text(tr('name'))), DataColumn(label: Text(tr('amount'))), DataColumn(label: Text(tr('contact'))), const DataColumn(label: Text('')),], rows: rows.map((r) => DataRow(cells: [DataCell(Text((isFungu ? r['envelope_no'] : r['name_no'])?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700))), DataCell(Text(_showNames ? (r['donor_name'] ?? '').toString() : (isFungu ? '••••••' : (r['name_no'] ?? '••••••')).toString())), DataCell(Text(_money(r['amount']))), DataCell(Text((r['contact'] ?? '—').toString())), DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(tooltip: tr('edit'), icon: const Icon(Icons.edit_outlined, size: 19), onPressed: () => _editRow(r)),
        IconButton(tooltip: tr('delete'), icon: Icon(Icons.delete_outline, size: 19, color: Colors.red.shade700), onPressed: () => _deleteRow(r)),
      ]))])).toList())),
    ])));
  }

  Widget _phoneRow(Map<String, Object?> r, bool isFungu) {
    final number = (isFungu ? r['envelope_no'] : r['name_no'])?.toString() ?? '';
    final name = _showNames ? (r['donor_name'] ?? '').toString() : (number.isEmpty ? '••••••' : number);
    final contact = (r['contact'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(color: const Color(0xFFFAFCFF), borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${isFungu ? tr('envelope_no') : 'MCH No.'}: ${number.isEmpty ? '—' : number}', style: const TextStyle(fontWeight: FontWeight.w800, color: C.navy, fontSize: 13)),
          const SizedBox(height: 3),
          Text(name.isEmpty ? '—' : name, style: const TextStyle(color: C.text, fontSize: 13)),
          if (contact.isNotEmpty) ...[const SizedBox(height: 2), Text(contact, style: const TextStyle(color: C.muted, fontSize: 12))],
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Padding(padding: const EdgeInsets.only(right: 8, top: 2), child: Text(_money(r['amount']), style: const TextStyle(fontWeight: FontWeight.w800, color: C.navy, fontSize: 13))),
          IconButton(tooltip: tr('edit'), visualDensity: VisualDensity.compact, icon: const Icon(Icons.edit_outlined, size: 19), onPressed: () => _editRow(r)),
          IconButton(tooltip: tr('delete'), visualDensity: VisualDensity.compact, icon: Icon(Icons.delete_outline, size: 19, color: Colors.red.shade700), onPressed: () => _deleteRow(r)),
        ]),
      ]),
    );
  }

  Future<void> _deleteRow(Map<String, Object?> row) async {
    final isFungu = row['type'] == 'FUNGU';
    final number = (isFungu ? row['envelope_no'] : row['name_no'])?.toString() ?? '';
    final amount = _money(row['amount']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete_record_title')),
        content: Text(
          '${tr('delete_record_message')}\\n\\n'
          '${isFungu ? tr('envelope_no') : 'MCH No.'}: $number\\n'
          '${tr('amount')}: $amount',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('cancel')),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline),
            label: Text(tr('delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppDb.instance.deleteContributionRow(
        id: (row['row_id'] as num).toInt(),
        isFungu: isFungu,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('delete_contribution_success')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: C.teal,
        ),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('delete_failed')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _editRow(Map<String, Object?> row) async {
    final updated = await showDialog<bool>(context: context, builder: (_) => _EditContributionDialog(row: row));
    if (updated == true) _load();
  }

  Widget _empty() => Container(width: double.infinity, padding: const EdgeInsets.all(44), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)), child: Center(child: Text(tr('records_empty'))));
}

class _EditContributionDialog extends StatefulWidget {
  final Map<String, Object?> row;
  const _EditContributionDialog({required this.row});
  @override State<_EditContributionDialog> createState() => _EditContributionDialogState();
}

class _EditContributionDialogState extends State<_EditContributionDialog> {
  late final TextEditingController _number;
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _amount;
  late final TextEditingController _contribution;
  bool _saving = false;

  bool get isFungu => widget.row['type'] == 'FUNGU';

  @override void initState() {
    super.initState();
    _number = TextEditingController(text: (widget.row[isFungu ? 'envelope_no' : 'name_no'] ?? '').toString());
    _name = TextEditingController(text: (widget.row['donor_name'] ?? '').toString());
    _contact = TextEditingController(text: (widget.row['contact'] ?? '').toString());
    _amount = TextEditingController(text: ((widget.row['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0));
    _contribution = TextEditingController(text: (widget.row['contribution_name'] ?? '').toString());
  }
  @override void dispose() { for (final c in [_number,_name,_contact,_amount,_contribution]) c.dispose(); super.dispose(); }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (_name.text.trim().isEmpty || amount == null || amount <= 0 || (_number.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('edit_invalid')), backgroundColor: Colors.red.shade700));
      return;
    }
    if (!isFungu && _contribution.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('other_name_required')), backgroundColor: Colors.red.shade700));
      return;
    }
    setState(() => _saving = true);
    try {
      if (isFungu) {
        await AppDb.instance.updateFunguContribution(id: (widget.row['row_id'] as num).toInt(), envelopeNo: _number.text, donorName: _name.text, contact: _contact.text, amount: amount);
      } else {
        await AppDb.instance.updateOtherContribution(id: (widget.row['row_id'] as num).toInt(), contributionName: _contribution.text, donorName: _name.text, contact: _contact.text, amount: amount);
      }
      if (mounted) Navigator.pop(context, true);
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override Widget build(BuildContext context) => AlertDialog(
    title: Text(tr('edit_record')),
    content: SizedBox(width: MediaQuery.sizeOf(context).width < 560 ? double.maxFinite : 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (!isFungu) _field(_contribution, tr('contribution_name')),
      _field(_number, isFungu ? tr('envelope_no') : 'MCH No.', enabled: false),
      _field(_name, tr('donor_name')),
      _field(_contact, tr('contact')),
      _field(_amount, tr('amount'), keyboard: TextInputType.number),
    ]))),
    actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(tr('cancel'))), FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(tr('save_changes')))],
  );

  Widget _field(TextEditingController c, String label, {bool enabled = true, TextInputType? keyboard}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: c, enabled: enabled, keyboardType: keyboard, decoration: InputDecoration(labelText: label)));
}

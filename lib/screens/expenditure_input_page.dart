import 'package:flutter/material.dart';
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

class ExpenditureInputPage extends StatefulWidget {
  const ExpenditureInputPage({super.key});
  @override
  State<ExpenditureInputPage> createState() => _ExpenditureInputPageState();
}

enum ExpenditureCategory {
  michango,
  wahudumu,
  huduma,
  ununuzi,
  ujenzi,
  idara,
  akiba,
}

extension ExpenditureCategoryX on ExpenditureCategory {
  String get code => switch (this) {
        ExpenditureCategory.michango => 'MICHANGO',
        ExpenditureCategory.wahudumu => 'MALIPO YA WAHUDUMU',
        ExpenditureCategory.huduma => 'MALIPO YA HUDUMA',
        ExpenditureCategory.ununuzi => 'MALIPO YA UNUNUZI NA MATENGENEZO',
        ExpenditureCategory.ujenzi => 'UJENZI',
        ExpenditureCategory.idara => 'IDARA',
        ExpenditureCategory.akiba => 'AKIBA',
      };

  IconData get icon => switch (this) {
        ExpenditureCategory.michango => Icons.volunteer_activism_outlined,
        ExpenditureCategory.wahudumu => Icons.groups_outlined,
        ExpenditureCategory.huduma => Icons.home_repair_service_outlined,
        ExpenditureCategory.ununuzi => Icons.shopping_cart_outlined,
        ExpenditureCategory.ujenzi => Icons.construction_outlined,
        ExpenditureCategory.idara => Icons.account_tree_outlined,
        ExpenditureCategory.akiba => Icons.savings_outlined,
      };
}

class _ExpenseRow {
  final description = TextEditingController();
  final payee = TextEditingController();
  final reference = TextEditingController();
  final amount = TextEditingController();
  bool get empty => description.text.trim().isEmpty && amount.text.trim().isEmpty;
  void dispose() { description.dispose(); payee.dispose(); reference.dispose(); amount.dispose(); }
}

class _ExpenditureInputPageState extends State<ExpenditureInputPage> {
  DateTime _date = DateTime.now();
  ExpenditureCategory _category = ExpenditureCategory.michango;
  final _fund = TextEditingController();
  final _note = TextEditingController();
  final List<_ExpenseRow> _rows = [_ExpenseRow()];
  bool _saving = false;

  @override
  void dispose() {
    _fund.dispose(); _note.dispose();
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  String _money(double value) => value.round().toString().replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'), (_) => ',');
  double _num(String v) => double.tryParse(v.replaceAll(',', '').trim()) ?? 0;
  double get _total => _rows.fold(0, (s, r) => s + _num(r.amount.text));

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100), helpText: tr('select_expenditure_date'));
    if (d != null) setState(() => _date = d);
  }

  void _addRow() => setState(() => _rows.add(_ExpenseRow()));
  void _removeRow(int i) { if (_rows.length == 1) return; final r = _rows.removeAt(i); r.dispose(); setState(() {}); }

  Future<void> _save() async {
    if (_saving) return;
    final valid = _rows.where((r) => !r.empty).toList();
    if (valid.isEmpty) return _snack(tr('expense_add_one'), error: true);
    for (final r in valid) {
      if (r.description.text.trim().isEmpty || _num(r.amount.text) <= 0) {
        return _snack(tr('expense_row_invalid'), error: true);
      }
    }
    setState(() => _saving = true);
    try {
      final batchId = await AppDb.instance.saveExpenditureBatch(
        date: _date.toIso8601String(), category: _category.code,
        fundName: _fund.text.trim(), note: _note.text.trim(),
        rows: [for (final r in valid) {
          'description': r.description.text.trim(),
          'payee': r.payee.text.trim(),
          'reference': r.reference.text.trim(),
          'amount': _num(r.amount.text),
        }],
      );
      final savedTotal = valid.fold<double>(0, (s, r) => s + _num(r.amount.text));
      await AppDb.instance.audit('EXPENDITURE_SAVED', 'batch=$batchId; category=${_category.code}; rows=${valid.length}; total=$savedTotal');
      for (final r in _rows) r.dispose();
      _rows
        ..clear()
        ..add(_ExpenseRow());
      _note.clear();
      setState(() {});
      _snack('${tr('saved_successfully')} — ${_money(savedTotal)} TZS');
    } catch (_) {
      _snack(tr('save_failed'), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text, {bool error = false}) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating, backgroundColor: error ? Colors.red.shade700 : C.teal));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: L10n.instance,
    builder: (_, __) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pagePad(context), 16, pagePad(context), 40),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1250), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _hero(), const SizedBox(height: 16), _contextCard(), const SizedBox(height: 16), _categoryBar(), const SizedBox(height: 12), _entryCard(),
      ]))),
    ),
  );

  Widget _hero() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.navy, C.navyDark]), borderRadius: BorderRadius.circular(18)),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: C.gold.withOpacity(.16), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.payments_outlined, color: C.gold, size: 30)),
      const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('MAINGIZO YA MATUMIZI', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('Ingiza matumizi, yahifadhiwe salama na yaingie moja kwa moja kwenye Muhtasari wa Matumizi.', style: TextStyle(color: Colors.white70, fontSize: 13))])),
    ]),
  );

  Widget _contextCard() => Card(
    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
    child: Padding(padding: const EdgeInsets.all(18), child: LayoutBuilder(builder: (_, c) {
      final narrow = c.maxWidth < 760;
      final fields = [
        _field('TAREHE YA MATUMIZI', TextField(controller: TextEditingController(text: '${_date.day.toString().padLeft(2,'0')}/${_date.month.toString().padLeft(2,'0')}/${_date.year}'), readOnly: true, onTap: _pickDate, decoration: _decoration(Icons.calendar_today_outlined))),
        _field('MFUKO / SOURCE FUND', TextField(controller: _fund, decoration: _decoration(Icons.account_balance_wallet_outlined, hint: 'Mf. Mfuko wa Ujenzi'))),
      ];
      return Flex(direction: narrow ? Axis.vertical : Axis.horizontal, crossAxisAlignment: CrossAxisAlignment.start, children: [for (var i=0;i<fields.length;i++) Expanded(flex: 1, child: Padding(padding: EdgeInsets.only(right: (!narrow && i==0)?10:0, bottom: narrow?10:0), child: fields[i]))]);
    })),
  );

  Widget _field(String label, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .4)), const SizedBox(height: 7), child]);
  InputDecoration _decoration(IconData icon, {String? hint}) => InputDecoration(prefixIcon: Icon(icon, size: 19), hintText: hint, filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: Colors.grey.shade300)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: Colors.grey.shade300)));

  Widget _categoryBar() => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)), child: Padding(padding: const EdgeInsets.all(14), child: Wrap(spacing: 8, runSpacing: 8, children: [for (final c in ExpenditureCategory.values) ChoiceChip(label: Text(c.code), avatar: Icon(c.icon, size: 18), selected: _category==c, onSelected: (_) => setState(() => _category=c))])));

  Widget _entryCard() => Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)), child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    LayoutBuilder(builder: (_, hc) {
      final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_category.code, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('${_rows.length} ${tr('expense_entries')}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))]);
      final totalText = Text('JUMLA: ${_money(_total)} TZS', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15));
      final addBtn = OutlinedButton.icon(onPressed: _addRow, icon: const Icon(Icons.add), label: Text(tr('add_row')));
      if (hc.maxWidth < 560) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [titleBlock, const SizedBox(height: 10), Row(children: [Expanded(child: totalText), addBtn])]);
      }
      return Row(children: [Expanded(child: titleBlock), totalText, const SizedBox(width: 12), addBtn]);
    }),
    const SizedBox(height: 14),
    ...List.generate(_rows.length, (i) => _row(i)),
    const SizedBox(height: 12),
    TextField(controller: _note, maxLines: 2, decoration: _decoration(Icons.notes_outlined, hint: 'Maelezo ya jumla / kumbukumbu (optional)')),
    const SizedBox(height: 16),
    Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.save_outlined), label: Text(_saving ? tr('saving') : 'SAVE MATUMIZI'))),
  ])));

  Widget _row(int i) {
    final r = _rows[i];
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.grey.shade200)), child: LayoutBuilder(builder: (_, c) {
      final narrow = c.maxWidth < 800;
      final children = [
        _field('MAELEZO / ITEM', TextField(controller:r.description, onChanged:(_)=>setState((){}), decoration:_decoration(Icons.description_outlined, hint:'Mf. Mshahara / vifaa'))),
        _field('MLIPWA / PAYEE', TextField(controller:r.payee, decoration:_decoration(Icons.person_outline, hint:'Jina (optional)'))),
        _field('REFERENCE', TextField(controller:r.reference, decoration:_decoration(Icons.tag, hint:'Voucher / invoice'))),
        _field('KIASI (TZS)', TextField(controller:r.amount, keyboardType:const TextInputType.numberWithOptions(decimal:true), onChanged:(_)=>setState((){}), decoration:_decoration(Icons.payments_outlined, hint:'0'))),
      ];
      if (narrow) return Column(children:[for(final x in children) Padding(padding:const EdgeInsets.only(bottom:8),child:x), Align(alignment:Alignment.centerRight,child:IconButton(onPressed:()=>_removeRow(i), icon:const Icon(Icons.delete_outline))) ]);
      return Row(crossAxisAlignment:CrossAxisAlignment.end, children:[Expanded(flex:3,child:children[0]),const SizedBox(width:8),Expanded(flex:2,child:children[1]),const SizedBox(width:8),Expanded(flex:2,child:children[2]),const SizedBox(width:8),Expanded(flex:2,child:children[3]),IconButton(onPressed:()=>_removeRow(i), icon:const Icon(Icons.delete_outline))]);
    })));
  }
}

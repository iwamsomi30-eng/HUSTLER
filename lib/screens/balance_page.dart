import 'package:flutter/material.dart';
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

const _cats = <String>[
  'MICHANGO','MALIPO YA WAHUDUMU','MALIPO YA HUDUMA',
  'MALIPO YA UNUNUZI NA MATENGENEZO','UJENZI','IDARA','AKIBA'
];

class BalancePage extends StatefulWidget {
  const BalancePage({super.key});
  @override State<BalancePage> createState() => _BalancePageState();
}

class _BalancePageState extends State<BalancePage> {
  DateTime? _from, _to;
  String _fund='ALL', _period='ALL';
  bool _loading=true; String? _error;
  Map<String,Object?> _stats={}; List<Map<String,Object?>> _funds=[]; List<Map<String,Object?>> _catsData=[]; List<String> _fundNames=[];

  String money(Object? v){ final n=v is num?v.toDouble():double.tryParse('$v')??0; return n.round().toString(); }
  double numv(Object? v)=>v is num?v.toDouble():double.tryParse('$v')??0;
  String date(DateTime d)=>'${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  Color catColor(String c){ switch(c){case 'MICHANGO':return C.blue;case 'MALIPO YA WAHUDUMU':return C.purple;case 'MALIPO YA HUDUMA':return C.teal;case 'MALIPO YA UNUNUZI NA MATENGENEZO':return C.gold;case 'UJENZI':return const Color(0xFF8D6E63);case 'IDARA':return const Color(0xFF546E7A);case 'AKIBA':return const Color(0xFF00897B);default:return C.navy;} }
  String catLabel(String c)=>c=='MALIPO YA UNUNUZI NA MATENGENEZO'?'UNUNUZI & MATENGENEZO':c;

  @override void initState(){super.initState();_load();}
  Future<void> _load() async { setState(() { _loading = true; }); try{ final r=await Future.wait([
    AppDb.instance.getBalanceOverallStats(from:_from,to:_to,fundName:_fund=='ALL'?null:_fund),
    AppDb.instance.getFundBalances(from:_from,to:_to),
    AppDb.instance.getBalanceExpenditureByCategory(from:_from,to:_to,fundName:_fund=='ALL'?null:_fund),
    AppDb.instance.getBalanceFundNames(),
  ]); if(!mounted)return; setState(() { _stats=Map<String,Object?>.from(r[0] as Map); _funds=(r[1] as List).map((e)=>Map<String,Object?>.from(e as Map)).toList(); _catsData=(r[2] as List).map((e)=>Map<String,Object?>.from(e as Map)).toList(); _fundNames=List<String>.from(r[3] as List); _loading=false; }); }catch(e){if(mounted)setState(() { _loading=false; _error='Imeshindikana kusoma taarifa za salio.'; });} }

  void period(String v){final n=DateTime.now();final t=DateTime(n.year,n.month,n.day);DateTime? f,to; if(v=='TODAY'){f=t;to=t;}else if(v=='WEEK'){f=t.subtract(Duration(days:n.weekday-1));to=t;}else if(v=='MONTH'){f=DateTime(n.year,n.month,1);to=t;}else if(v=='YEAR'){f=DateTime(n.year,1,1);to=t;}setState(() { _period=v; _from=f; _to=to; });_load();}
  Future<void> pick(bool from) async {final d=await showDatePicker(context:context,initialDate:from?(_from??DateTime.now()):(_to??DateTime.now()),firstDate:DateTime(2020),lastDate:DateTime(2100),helpText:from?tr('summary_from'):tr('summary_to'));if(d==null)return;setState(() { _period='CUSTOM'; if(from){_from=d;}else{_to=d;} });_load();}
  void clear(){setState(() { _period='ALL'; _from=null; _to=null; _fund='ALL'; });_load();}


  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: L10n.instance,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(pagePad(context), 16, pagePad(context), 42),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hero(),
                      const SizedBox(height: 16),
                      _filters(),
                      const SizedBox(height: 16),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(70),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null)
                        _errorCard()
                      else ...[
                        _statsGrid(),
                        const SizedBox(height: 16),
                        _fundTable(),
                        const SizedBox(height: 16),
                        _categoryTable(),
                        const SizedBox(height: 16),
                        _formulaNote(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

  Widget _hero() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: C.navy,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: C.navy.withOpacity(.14), blurRadius: 18, offset: const Offset(0, 7)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: C.teal.withOpacity(.2),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 27),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('balance_title'),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(tr('balance_subtitle'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _filters() => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _drop(
                tr('balance_period'),
                _period,
                {
                  'ALL': tr('balance_all_time'),
                  'TODAY': tr('balance_today'),
                  'WEEK': tr('balance_week'),
                  'MONTH': tr('balance_month'),
                  'YEAR': tr('balance_year'),
                  'CUSTOM': tr('balance_custom'),
                },
                period,
              ),
              _drop(
                tr('balance_fund'),
                _fund,
                {
                  'ALL': tr('balance_all_funds'),
                  for (final f in _fundNames) f: f,
                },
                (v) {
                  setState(() {
                    _fund = v;
                  });
                  _load();
                },
              ),
              OutlinedButton.icon(
                onPressed: () => pick(true),
                icon: const Icon(Icons.date_range),
                label: Text(_from == null ? tr('summary_from') : date(_from!)),
              ),
              OutlinedButton.icon(
                onPressed: () => pick(false),
                icon: const Icon(Icons.event),
                label: Text(_to == null ? tr('summary_to') : date(_to!)),
              ),
              TextButton.icon(
                onPressed: clear,
                icon: const Icon(Icons.clear),
                label: Text(tr('clear_filters')),
              ),
            ],
          ),
        ),
      );

  Widget _drop(String label, String value, Map<String, String> items, ValueChanged<String> on) {
    return SizedBox(
      width: 240,
      child: DropdownButtonFormField<String>(
        initialValue: items.containsKey(value) ? value : 'ALL',
        decoration: InputDecoration(labelText: label),
        items: items.entries
            .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) on(v);
        },
      ),
    );
  }

  Widget _statsGrid() {
    final income = numv(_stats['income']);
    final exp = numv(_stats['expenditure']);
    final bal = numv(_stats['balance']);
    return LayoutBuilder(
      builder: (c, bc) {
        final cols = bc.maxWidth > 900 ? 3 : 1;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 3.2,
          children: [
            _stat(tr('balance_income'), income, C.blue, Icons.south_west),
            _stat(tr('balance_expense'), exp, C.gold, Icons.north_east),
            _stat(
              tr('balance_net'),
              bal,
              bal >= 0 ? C.teal : Colors.red,
              bal >= 0 ? Icons.trending_up : Icons.warning_amber_rounded,
            ),
          ],
        );
      },
    );
  }

  Widget _stat(String title, double v, Color color, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        style: const TextStyle(color: C.muted, fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('TZS ${money(v)}',
                        style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _fundTable() {
    if (_funds.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(tr('balance_no_data'), style: const TextStyle(color: C.muted)),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('balance_fund_breakdown'),
                style: const TextStyle(color: C.navy, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  const DataColumn(label: Text('MFUKO')),
                  DataColumn(label: Text(tr('balance_income'))),
                  DataColumn(label: Text(tr('balance_expense'))),
                  const DataColumn(label: Text('SALIO')),
                ],
                rows: _funds.map((r) {
                  final b = numv(r['balance']);
                  return DataRow(cells: [
                    DataCell(Text('${r['fund_name']}')),
                    DataCell(Text('TZS ${money(r['income'])}')),
                    DataCell(Text('TZS ${money(r['expenditure'])}')),
                    DataCell(Text('TZS ${money(b)}',
                        style: TextStyle(color: b >= 0 ? C.teal : Colors.red, fontWeight: FontWeight.w800))),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('balance_expense_breakdown'),
                style: const TextStyle(color: C.navy, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ..._cats.map((c) {
              final found = _catsData.where((r) => r['category'] == c);
              final v = found.isEmpty ? 0 : numv(found.first['total']);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: catColor(c), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(catLabel(c), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text('TZS ${money(v)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: C.navy)),
                  ],
                ),
              );
            }),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(tr('balance_expense'), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(width: 18),
                Text('TZS ${money(_stats['expenditure'])}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: C.gold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulaNote() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: C.teal.withOpacity(.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.teal.withOpacity(.2)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.calculate_outlined, color: C.teal),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'SALIO = MAKUSANYO - MATUMIZI. Kila matumizi yanahusishwa na MFUKO uliowekwa kwenye Maingizo ya Matumizi, na makusanyo yanahusishwa na MFUKO uliowekwa kwenye Maingizo ya Michango.',
                style: TextStyle(color: C.text, height: 1.45),
              ),
            ),
          ],
        ),
      );

  Widget _errorCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 10),
              Expanded(child: Text(_error ?? 'Error')),
            ],
          ),
        ),
      );
}

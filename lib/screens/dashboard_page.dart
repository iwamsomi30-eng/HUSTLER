import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../services/overall_export_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _period = 'ALL';
  DateTime? _from;
  DateTime? _to;
  String _fund = 'ALL';
  bool _loading = true;
  String? _error;
  Map<String, Object?> _stats = {};
  List<Map<String,Object?>> _contrib = [];
  List<Map<String,Object?>> _expense = [];
  List<Map<String,Object?>> _funds = [];
  List<Map<String,Object?>> _daily = [];
  List<String> _fundNames = [];

  double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
  String _money(Object? v) => 'TZS ${_num(v).round().toString()}';
  String _date(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  @override
  void initState(){ super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading=true; _error=null; });
    try {
      final r=await Future.wait([
        AppDb.instance.getOverallDashboardStats(from:_from,to:_to,fundName:_fund=='ALL'?null:_fund),
        AppDb.instance.getOverallContributionBreakdown(from:_from,to:_to,fundName:_fund=='ALL'?null:_fund),
        AppDb.instance.getOverallExpenditureBreakdown(from:_from,to:_to,fundName:_fund=='ALL'?null:_fund),
        AppDb.instance.getOverallFundBreakdown(from:_from,to:_to,fundName:_fund=='ALL'?null:_fund),
        AppDb.instance.getOverallDailyTrend(from:_from,to:_to,fundName:_fund=='ALL'?null:_fund),
        AppDb.instance.getBalanceFundNames(),
      ]);
      if(!mounted)return;
      setState((){
        _stats=Map<String,Object?>.from(r[0] as Map);
        _contrib=(r[1] as List).map((e)=>Map<String,Object?>.from(e as Map)).toList();
        _expense=(r[2] as List).map((e)=>Map<String,Object?>.from(e as Map)).toList();
        _funds=(r[3] as List).map((e)=>Map<String,Object?>.from(e as Map)).toList();
        _daily=(r[4] as List).map((e)=>Map<String,Object?>.from(e as Map)).toList();
        _fundNames=List<String>.from(r[5] as List);
        _loading=false;
      });
    }catch(e){ if(!mounted)return; setState((){_loading=false;_error=tr('dash_load_failed');}); }
  }

  void _applyPeriod(String v){
    final now=DateTime.now(); final today=DateTime(now.year,now.month,now.day); DateTime? f,t;
    if(v=='TODAY'){f=today;t=today;}
    if(v=='WEEK'){f=today.subtract(Duration(days:now.weekday-1));t=today;}
    if(v=='MONTH'){f=DateTime(now.year,now.month,1);t=today;}
    if(v=='YEAR'){f=DateTime(now.year,1,1);t=today;}
    setState((){_period=v;_from=f;_to=t;}); _load();
  }

  Future<void> _pick(bool from) async {
    final initial=from?(_from??DateTime.now()):(_to??DateTime.now());
    final d=await showDatePicker(context:context,initialDate:initial,firstDate:DateTime(2020),lastDate:DateTime(2100),helpText:from?tr('dash_from'):tr('dash_to'));
    if(d==null)return;
    setState((){_period='CUSTOM';if(from)_from=d;else _to=d;}); _load();
  }

  void _clear(){setState((){_period='ALL';_from=null;_to=null;_fund='ALL';});_load();}

  Future<void> _export(bool pdf) async {
    try {
      if(pdf){
        await OverallExportService.sharePdf(from:_from,to:_to,stats:_stats,contributions:_contrib,categories:_expense,funds:_funds,daily:_daily);
      }else{
        await OverallExportService.shareExcel(from:_from,to:_to,stats:_stats,contributions:_contrib,categories:_expense,funds:_funds,daily:_daily);
      }
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(tr('dash_export_failed'))));}
  }

  @override
  Widget build(BuildContext context){
    return ListenableBuilder(listenable:L10n.instance,builder:(context,_){
      return RefreshIndicator(onRefresh:_load,child:SingleChildScrollView(physics:const AlwaysScrollableScrollPhysics(),padding:EdgeInsets.fromLTRB(pagePad(context),16,pagePad(context),40),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1400),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _hero(),const SizedBox(height:16),_filters(),const SizedBox(height:16),
        if(_loading)const Padding(padding:EdgeInsets.all(70),child:Center(child:CircularProgressIndicator())) else if(_error!=null)_errorCard() else ...[
          _kpis(),const SizedBox(height:16),_insights(),const SizedBox(height:16),_trendCard(),const SizedBox(height:16),
          _analysisGrid(),const SizedBox(height:16),_fundTable(),const SizedBox(height:16),_exportCard(),
        ],
      ])))));
    });
  }

  Widget _hero()=>Container(padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:C.navy,borderRadius:BorderRadius.circular(20),boxShadow:[BoxShadow(color:C.navy.withOpacity(.16),blurRadius:22,offset:const Offset(0,8))]),child:Row(children:[Container(width:58,height:58,decoration:BoxDecoration(color:Colors.white.withOpacity(.12),borderRadius:BorderRadius.circular(16)),child:const Icon(Icons.dashboard_customize_rounded,color:C.gold,size:31)),const SizedBox(width:15),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(tr('dash_title'),style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(tr('dash_sub'),style:const TextStyle(color:Colors.white70,fontSize:13))])),IconButton(onPressed:_load,tooltip:tr('dash_refresh'),icon:const Icon(Icons.refresh,color:Colors.white))]));

  Widget _filters()=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:C.border)),child:LayoutBuilder(builder:(context,b){
    final compact=b.maxWidth<900;
    final period=DropdownButtonFormField<String>(value:_period,isExpanded:true,decoration:InputDecoration(labelText:tr('dash_period')),items:[DropdownMenuItem(value:'ALL',child:Text(tr('dash_all'))),DropdownMenuItem(value:'TODAY',child:Text(tr('dash_today'))),DropdownMenuItem(value:'WEEK',child:Text(tr('dash_week'))),DropdownMenuItem(value:'MONTH',child:Text(tr('dash_month'))),DropdownMenuItem(value:'YEAR',child:Text(tr('dash_year'))),DropdownMenuItem(value:'CUSTOM',child:Text(tr('dash_custom')))],onChanged:(v){if(v!=null)_applyPeriod(v);});
    final fund=DropdownButtonFormField<String>(value:_fund,isExpanded:true,decoration:InputDecoration(labelText:tr('dash_fund')),items:[DropdownMenuItem(value:'ALL',child:Text(tr('dash_all_funds'))),..._fundNames.map((f)=>DropdownMenuItem(value:f,child:Text(f,overflow:TextOverflow.ellipsis)))],onChanged:(v){if(v==null)return;setState(()=>_fund=v);_load();});
    final from=OutlinedButton.icon(onPressed:()=>_pick(true),icon:const Icon(Icons.event),label:Text(_from==null?tr('dash_from'):_date(_from!)));
    final to=OutlinedButton.icon(onPressed:()=>_pick(false),icon:const Icon(Icons.event),label:Text(_to==null?tr('dash_to'):_date(_to!)));
    final clear=TextButton.icon(onPressed:_period=='ALL'&&_fund=='ALL'?null:_clear,icon:const Icon(Icons.filter_alt_off),label:Text(tr('clear_filters')));
    if(compact)return Column(children:[Row(children:[Expanded(child:period),const SizedBox(width:10),Expanded(child:fund)]),const SizedBox(height:10),Row(children:[Expanded(child:from),const SizedBox(width:8),Expanded(child:to)]),Align(alignment:Alignment.centerRight,child:clear)]);
    return Column(children:[Row(children:[Expanded(child:period),const SizedBox(width:10),Expanded(child:fund),const SizedBox(width:10),Expanded(child:from),const SizedBox(width:8),Expanded(child:to),const SizedBox(width:8),clear])]);
  }));

  Widget _kpis(){final income=_num(_stats['income']),exp=_num(_stats['expenditure']),bal=_num(_stats['balance']); final cards=[_kpi(Icons.savings,C.blue,tr('makusanyo'),income,tr('dash_income_sub'),currency:true), _kpi(Icons.payments_outlined,C.gold,tr('matumizi'),exp,tr('dash_expense_sub'),currency:true), _kpi(Icons.account_balance_wallet_rounded,bal>=0?C.teal:Colors.red,tr('salio'),bal,bal>=0?tr('dash_positive'):tr('dash_negative'),currency:true), _kpi(Icons.receipt_long,C.purple,tr('dash_entries'),_num(_stats['contributionEntries'])+_num(_stats['expenditureEntries']),tr('dash_entries_sub'))]; return LayoutBuilder(builder:(context,b){final n=b.maxWidth>=1050?4:(b.maxWidth>=650?2:1);final gap=14.0;final w=(b.maxWidth-gap*(n-1))/n;return Wrap(spacing:gap,runSpacing:gap,children:cards.map((c)=>SizedBox(width:w,child:c)).toList());});}
  Widget _kpi(IconData icon,Color color,String label,double value,String sub,{bool currency=false})=>Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:C.border)),child:Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:color.withOpacity(.10),borderRadius:BorderRadius.circular(13)),child:Icon(icon,color:color)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(color:C.muted,fontSize:11,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(currency?_money(value):value.toStringAsFixed(0),style:TextStyle(color:color,fontSize:19,fontWeight:FontWeight.w900)),const SizedBox(height:2),Text(sub,style:const TextStyle(color:C.muted,fontSize:10))]))]));

  Widget _insights(){
    final topExp=_expense.isEmpty?null:_expense.first; final topFund=_funds.isEmpty?null:_funds.reduce((a,b)=>_num(a['income'])>_num(b['income'])?a:b); final topCon=_contrib.isEmpty?null:_contrib.first;
    return LayoutBuilder(builder:(context,b){final n=b.maxWidth>=900?3:1;final w=(b.maxWidth-14*(n-1))/n;return Wrap(spacing:14,runSpacing:14,children:[SizedBox(width:w,child:_insight(Icons.trending_down,C.gold,tr('dash_top_expense'),topExp==null?tr('dash_no_data'): '${topExp['category']} • ${_money(topExp['total'])}')),SizedBox(width:w,child:_insight(Icons.account_balance,C.blue,tr('dash_top_fund'),topFund==null?tr('dash_no_data'):'${topFund['fund_name']} • ${_money(topFund['income'])}')),SizedBox(width:w,child:_insight(Icons.savings,C.teal,tr('dash_top_collection'),topCon==null?tr('dash_no_data'):'${topCon['type']=='FUNGU'?tr('fungu'):tr('other_contributions')} • ${_money(topCon['total'])}'))]);});
  }
  Widget _insight(IconData i,Color c,String title,String value)=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:c.withOpacity(.06),borderRadius:BorderRadius.circular(14),border:Border.all(color:c.withOpacity(.18))),child:Row(children:[Icon(i,color:c),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:TextStyle(color:c,fontSize:11,fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(value,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:C.navy,fontWeight:FontWeight.w800))]))]));

  Widget _trendCard()=>_panel(tr('dash_trend_title'),Icons.show_chart,Column(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(height:245,child:_TrendChart(data:_daily)),const SizedBox(height:8),Row(mainAxisAlignment:MainAxisAlignment.end,children:[_legend(C.blue,tr('makusanyo')),_legend(C.gold,tr('matumizi')),_legend(C.teal,tr('salio'))]) ]));
  Widget _legend(Color c,String t)=>Padding(padding:const EdgeInsets.only(left:14),child:Row(mainAxisSize:MainAxisSize.min,children:[Container(width:9,height:9,decoration:BoxDecoration(color:c,shape:BoxShape.circle)),const SizedBox(width:5),Text(t,style:const TextStyle(fontSize:10,color:C.muted,fontWeight:FontWeight.w700))]));

  Widget _analysisGrid()=>LayoutBuilder(builder:(context,b){final two=b.maxWidth>=900;final left=_categoryPanel(),right=_collectionPanel();return two?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:left),const SizedBox(width:14),Expanded(child:right)]):Column(children:[left,const SizedBox(height:14),right]);});
  Widget _categoryPanel()=>_panel(tr('dash_expense_breakdown'),Icons.pie_chart_outline,Column(children:[if(_expense.isEmpty)Text(tr('dash_no_data'),style:const TextStyle(color:C.muted)) else ..._expense.take(7).map((r){final total=_num(_stats['expenditure']);final v=_num(r['total']);final double pct=total<=0?0.0:v/total;return Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Column(children:[Row(children:[Expanded(child:Text('${r['category']}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))),Text(_money(v),style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:C.navy)),const SizedBox(width:8),Text('${(pct*100).toStringAsFixed(1)}%',style:const TextStyle(fontSize:10,color:C.muted))]),const SizedBox(height:5),ClipRRect(borderRadius:BorderRadius.circular(5),child:LinearProgressIndicator(value:pct,minHeight:7,backgroundColor:C.bg,color:_catColor('${r['category']}')))]));})]));
  Widget _collectionPanel()=>_panel(tr('dash_collection_breakdown'),Icons.savings_outlined,Column(children:[if(_contrib.isEmpty)Text(tr('dash_no_data'),style:const TextStyle(color:C.muted)) else ..._contrib.map((r){final v=_num(r['total']);final total=_contrib.fold<double>(0,(s,x)=>s+_num(x['total']));final double pct=total<=0?0.0:v/total;final isF='${r['type']}'=='FUNGU';return Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Column(children:[Row(children:[Icon(isF?Icons.mark_email_read_outlined:Icons.volunteer_activism_outlined,color:isF?C.blue:C.teal,size:19),const SizedBox(width:8),Expanded(child:Text(isF?tr('fungu'):tr('other_contributions'),style:const TextStyle(fontWeight:FontWeight.w700))),Text(_money(v),style:const TextStyle(fontWeight:FontWeight.w800,color:C.navy)),const SizedBox(width:8),Text('${(pct*100).toStringAsFixed(1)}%',style:const TextStyle(fontSize:10,color:C.muted))]),const SizedBox(height:5),ClipRRect(borderRadius:BorderRadius.circular(5),child:LinearProgressIndicator(value:pct,minHeight:7,backgroundColor:C.bg,color:isF?C.blue:C.teal))]));})]));

  Widget _fundTable()=>_panel(tr('dash_fund_title'),Icons.account_balance_wallet_outlined,Column(children:[if(_funds.isEmpty)Text(tr('dash_no_data'),style:const TextStyle(color:C.muted)) else SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(headingRowColor:MaterialStatePropertyAll(C.bg),columns:[DataColumn(label:Text(tr('dash_fund'))),DataColumn(label:Text(tr('makusanyo'))),DataColumn(label:Text(tr('matumizi'))),DataColumn(label:Text(tr('salio')))],rows:_funds.map((r){final b=_num(r['balance']);return DataRow(cells:[DataCell(Text('${r['fund_name']}',style:const TextStyle(fontWeight:FontWeight.w700))),DataCell(Text(_money(r['income']))),DataCell(Text(_money(r['expenditure']))),DataCell(Text(_money(b),style:TextStyle(color:b>=0?C.teal:Colors.red,fontWeight:FontWeight.w900)))]);}).toList()))]));

  Widget _exportCard()=>Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),border:Border.all(color:C.border)),child:LayoutBuilder(builder:(context,b){final compact=b.maxWidth<650;final actions=Row(mainAxisSize:MainAxisSize.min,children:[OutlinedButton.icon(onPressed:_loading?null:()=>_export(true),icon:const Icon(Icons.picture_as_pdf_outlined),label:Text(tr('dash_export_pdf'))),const SizedBox(width:8),ElevatedButton.icon(onPressed:_loading?null:()=>_export(false),icon:const Icon(Icons.table_view_outlined),label:Text(tr('dash_export_excel')))]);return compact?Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(tr('dash_export_title'),style:const TextStyle(color:C.navy,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(tr('dash_export_sub'),style:const TextStyle(color:C.muted,fontSize:11)),const SizedBox(height:12),actions]):Row(children:[const Icon(Icons.file_download_outlined,color:C.navy),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(tr('dash_export_title'),style:const TextStyle(color:C.navy,fontWeight:FontWeight.w900)),Text(tr('dash_export_sub'),style:const TextStyle(color:C.muted,fontSize:11))])),actions]);}));

  Widget _panel(String title,IconData icon,Widget child)=>Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:C.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(width:36,height:36,decoration:BoxDecoration(color:C.navy.withOpacity(.06),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:C.navy,size:19)),const SizedBox(width:10),Expanded(child:Text(title,style:const TextStyle(color:C.navy,fontSize:16,fontWeight:FontWeight.w900)))]),const SizedBox(height:15),child]));
  Widget _errorCard()=>_panel(tr('dash_error'),Icons.error_outline,Text(_error??'',style:const TextStyle(color:Colors.red)));
  Color _catColor(String c){switch(c){case'MICHANGO':return C.blue;case'MALIPO YA WAHUDUMU':return C.purple;case'MALIPO YA HUDUMA':return C.teal;case'MALIPO YA UNUNUZI NA MATENGENEZO':return C.gold;case'UJENZI':return const Color(0xFF8D6E63);case'IDARA':return const Color(0xFF546E7A);case'AKIBA':return const Color(0xFF00897B);default:return C.navy;}}
}

class _TrendChart extends StatelessWidget{
  final List<Map<String,Object?>> data; const _TrendChart({required this.data});
  @override Widget build(BuildContext context)=>data.isEmpty?Center(child:Text(tr('dash_no_trend'),style:const TextStyle(color:C.muted))):CustomPaint(painter:_TrendPainter(data),child:const SizedBox.expand());
}
class _TrendPainter extends CustomPainter{
  final List<Map<String,Object?>> data; _TrendPainter(this.data);
  double n(Object? v)=>(v as num?)?.toDouble()??0;
  @override void paint(Canvas canvas,Size size){
    final pad=const EdgeInsets.fromLTRB(48,16,18,30); final w=size.width-pad.left-pad.right; final h=size.height-pad.top-pad.bottom;
    double minY=0,maxY=0;
    for(final r in data){final i=n(r['income']),e=n(r['expenditure']),b=n(r['balance']);minY=math.min(minY,math.min(i,math.min(e,b)));maxY=math.max(maxY,math.max(i,math.max(e,b)));}
    if(maxY==minY){maxY=1;minY=0;} else {final span=maxY-minY;maxY+=span*.10;minY-=span*.10;}
    final grid=Paint()..color=C.border.withOpacity(.7)..strokeWidth=1; final income=Paint()..color=C.blue..strokeWidth=3..style=PaintingStyle.stroke; final expense=Paint()..color=C.gold..strokeWidth=3..style=PaintingStyle.stroke; final bal=Paint()..color=C.teal..strokeWidth=2.5..style=PaintingStyle.stroke;
    final zeroY=pad.top+h-(0-minY)/(maxY-minY)*h;
    for(var i=0;i<=4;i++){final y=pad.top+h*i/4;canvas.drawLine(Offset(pad.left,y),Offset(size.width-pad.right,y),grid);final label=maxY-(maxY-minY)*i/4;final tp=TextPainter(text:TextSpan(text:label.abs()>=1000000?'${(label/1000000).toStringAsFixed(1)}M':label.abs()>=1000?'${(label/1000).toStringAsFixed(0)}K':label.toStringAsFixed(0),style:const TextStyle(fontSize:9,color:C.muted)),textDirection:TextDirection.ltr)..layout();tp.paint(canvas,Offset(2,y-tp.height/2));}
    if(zeroY>=pad.top&&zeroY<=pad.top+h){final z=Paint()..color=C.border..strokeWidth=1.5;canvas.drawLine(Offset(pad.left,zeroY),Offset(size.width-pad.right,zeroY),z);}
    Offset point(int i,double v){final x=pad.left+(data.length==1?w/2:w*i/(data.length-1));final y=pad.top+h-(v-minY)/(maxY-minY)*h;return Offset(x,y);}
    void line(Paint p,String key){final path=Path();for(var i=0;i<data.length;i++){final q=point(i,n(data[i][key]));if(i==0)path.moveTo(q.dx,q.dy);else path.lineTo(q.dx,q.dy);}canvas.drawPath(path,p);}
    line(income,'income');line(expense,'expenditure');line(bal,'balance');
    final every=math.max(1,(data.length/6).ceil());for(var i=0;i<data.length;i+=every){final x=point(i,0).dx;final day='${data[i]['day']}';final label=day.length>=10?'${day.substring(8,10)}/${day.substring(5,7)}':day;final tp=TextPainter(text:TextSpan(text:label,style:const TextStyle(fontSize:9,color:C.muted)),textDirection:TextDirection.ltr)..layout();tp.paint(canvas,Offset(x-tp.width/2,size.height-20));}
  }
  @override bool shouldRepaint(covariant _TrendPainter old)=>old.data!=data;
}

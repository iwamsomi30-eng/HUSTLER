import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/db.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

const _categories = <String>[
  'MICHANGO',
  'MALIPO YA WAHUDUMU',
  'MALIPO YA HUDUMA',
  'MALIPO YA UNUNUZI NA MATENGENEZO',
  'UJENZI',
  'IDARA',
  'AKIBA',
];

class ExpenditureSummaryPage extends StatefulWidget {
  const ExpenditureSummaryPage({super.key});
  @override
  State<ExpenditureSummaryPage> createState() => _ExpenditureSummaryPageState();
}

class _ExpenditureSummaryPageState extends State<ExpenditureSummaryPage> {
  DateTime? _from;
  DateTime? _to;
  String _fund = 'ALL';
  String _category = 'ALL';
  String _period = 'ALL';
  bool _loading = true;
  String? _error;
  Map<String, Object?> _stats = const {};
  List<Map<String, Object?>> _categoriesData = const [];
  List<Map<String, Object?>> _fundsData = const [];
  List<Map<String, Object?>> _dailyData = const [];
  List<String> _fundNames = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _money(Object? value) {
    final n = value is num ? value : double.tryParse('$value') ?? 0;
    return n.round().toString();
  }

  double _number(Object? value) {
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }

  String _date(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _dateIso(String value) {
    final d = DateTime.tryParse(value);
    return d == null ? value : _date(d);
  }

  String _categoryLabel(String value) {
    if (value == 'MALIPO YA UNUNUZI NA MATENGENEZO') return 'UNUNUZI & MATENGENEZO';
    if (value == 'MALIPO YA WAHUDUMU') return 'WAHUDUMU';
    if (value == 'MALIPO YA HUDUMA') return 'HUDUMA';
    return value;
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'MICHANGO': return C.blue;
      case 'MALIPO YA WAHUDUMU': return C.purple;
      case 'MALIPO YA HUDUMA': return C.teal;
      case 'MALIPO YA UNUNUZI NA MATENGENEZO': return C.gold;
      case 'UJENZI': return const Color(0xFF8D6E63);
      case 'IDARA': return const Color(0xFF546E7A);
      case 'AKIBA': return const Color(0xFF00897B);
      default: return C.navy;
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<dynamic>([
        AppDb.instance.getExpenditureOverallStats(
          from: _from,
          to: _to,
          fundName: _fund == 'ALL' ? null : _fund,
          category: _category,
        ),
        AppDb.instance.getExpenditureCategorySummary(
          from: _from,
          to: _to,
          fundName: _fund == 'ALL' ? null : _fund,
          category: _category,
        ),
        AppDb.instance.getExpenditureFundSummary(
          from: _from,
          to: _to,
          category: _category,
          fundName: _fund == 'ALL' ? null : _fund,
        ),
        AppDb.instance.getExpenditureDailySummary(
          from: _from,
          to: _to,
          fundName: _fund == 'ALL' ? null : _fund,
          category: _category,
        ),
        AppDb.instance.getExpenditureFundNames(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = Map<String, Object?>.from(results[0] as Map);
        _categoriesData = (results[1] as List)
            .map((e) => Map<String, Object?>.from(e as Map))
            .toList();
        _fundsData = (results[2] as List)
            .map((e) => Map<String, Object?>.from(e as Map))
            .toList();
        _dailyData = (results[3] as List)
            .map((e) => Map<String, Object?>.from(e as Map))
            .toList();
        _fundNames = List<String>.from(results[4] as List);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Imeshindikana kusoma muhtasari wa matumizi.';
      });
    }
  }

  void _applyPeriod(String value) {
    final now = DateTime.now();
    DateTime? from;
    DateTime? to;
    final today = DateTime(now.year, now.month, now.day);
    if (value == 'TODAY') {
      from = today;
      to = today;
    } else if (value == 'WEEK') {
      from = today.subtract(Duration(days: now.weekday - 1));
      to = today;
    } else if (value == 'MONTH') {
      from = DateTime(now.year, now.month, 1);
      to = today;
    } else if (value == 'YEAR') {
      from = DateTime(now.year, 1, 1);
      to = today;
    }
    setState(() {
      _period = value;
      _from = from;
      _to = to;
    });
    _load();
  }

  Future<void> _pickDate(bool fromDate) async {
    final current = fromDate ? (_from ?? DateTime.now()) : (_to ?? DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: fromDate ? tr('summary_from') : tr('summary_to'),
    );
    if (d == null) return;
    setState(() {
      _period = 'CUSTOM';
      if (fromDate) {
        _from = d;
      } else {
        _to = d;
      }
    });
    _load();
  }

  void _clearFilters() {
    setState(() {
      _period = 'ALL';
      _from = null;
      _to = null;
      _fund = 'ALL';
      _category = 'ALL';
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: L10n.instance,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(pagePad(context), 16, pagePad(context), 40),
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
                        padding: EdgeInsets.all(60),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      _errorCard()
                    else ...[
                      _statCards(),
                      const SizedBox(height: 16),
                      _summaryTable(),
                      const SizedBox(height: 16),
                      _analyticsRow(),
                      const SizedBox(height: 16),
                      _fundSection(),
                      const SizedBox(height: 16),
                      _dailyTrend(),
                      const SizedBox(height: 12),
                      _scopeNote(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: C.navy,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: C.navy.withOpacity(.15), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: Colors.white.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('summary_title'), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(tr('summary_subtitle'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
      child: LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxWidth < 820;
          final period = DropdownButtonFormField<String>(
            value: _period,
            isExpanded: true,
            decoration: InputDecoration(labelText: tr('summary_period')),
            items: [
              DropdownMenuItem(value: 'ALL', child: Text(tr('summary_all_time'))),
              DropdownMenuItem(value: 'TODAY', child: Text(tr('summary_today'))),
              DropdownMenuItem(value: 'WEEK', child: Text(tr('summary_this_week'))),
              DropdownMenuItem(value: 'MONTH', child: Text(tr('summary_this_month'))),
              DropdownMenuItem(value: 'YEAR', child: Text(tr('summary_this_year'))),
              DropdownMenuItem(value: 'CUSTOM', child: Text(tr('summary_custom'))),
            ],
            onChanged: (v) { if (v != null) _applyPeriod(v); },
          );
          final fund = DropdownButtonFormField<String>(
            value: _fund,
            isExpanded: true,
            decoration: InputDecoration(labelText: tr('summary_fund')),
            items: [
              DropdownMenuItem(value: 'ALL', child: Text(tr('summary_all_funds'))),
              ..._fundNames.map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) { if (v == null) return; setState(() => _fund = v); _load(); },
          );
          final category = DropdownButtonFormField<String>(
            value: _category,
            isExpanded: true,
            decoration: InputDecoration(labelText: tr('summary_category')),
            items: [
              DropdownMenuItem(value: 'ALL', child: Text(tr('expense_category_all'))),
              ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) { if (v == null) return; setState(() => _category = v); _load(); },
          );
          final from = OutlinedButton.icon(onPressed: () => _pickDate(true), icon: const Icon(Icons.event), label: Text(_from == null ? tr('summary_from') : _date(_from!)));
          final to = OutlinedButton.icon(onPressed: () => _pickDate(false), icon: const Icon(Icons.event), label: Text(_to == null ? tr('summary_to') : _date(_to!)));
          final clear = TextButton.icon(onPressed: _period == 'ALL' && _fund == 'ALL' && _category == 'ALL' ? null : _clearFilters, icon: const Icon(Icons.filter_alt_off), label: Text(tr('clear_filters')));
          if (compact) {
            return Column(children: [
              Row(children: [Expanded(child: period), const SizedBox(width: 10), Expanded(child: fund)]),
              const SizedBox(height: 10), category,
              const SizedBox(height: 10),
              Row(children: [Expanded(child: from), const SizedBox(width: 8), Expanded(child: to)]),
              Align(alignment: Alignment.centerRight, child: clear),
            ]);
          }
          return Column(children: [
            Row(children: [Expanded(child: period), const SizedBox(width: 10), Expanded(child: fund), const SizedBox(width: 10), Expanded(child: category)]),
            const SizedBox(height: 10),
            Row(children: [from, const SizedBox(width: 8), to, const Spacer(), clear]),
          ]);
        },
      ),
    );
  }

  Widget _statCards() {
    final total = _number(_stats['total']);
    final entries = (_stats['entries'] as num?)?.toInt() ?? 0;
    final batches = (_stats['batches'] as num?)?.toInt() ?? 0;
    final active = _categoriesData.length;
    final cards = [
      _StatCard(icon: Icons.payments_outlined, color: C.teal, title: tr('summary_total_expenditure'), value: '${_money(total)} TZS', sub: tr('summary_total_expenditure_sub')),
      _StatCard(icon: Icons.category_outlined, color: C.blue, title: tr('summary_categories'), value: '$active / ${_categories.length}', sub: tr('summary_categories_sub')),
      _StatCard(icon: Icons.receipt_long_outlined, color: C.gold, title: tr('summary_entries'), value: '$entries', sub: '$batches ${tr('summary_batches')}'),
      _StatCard(icon: Icons.account_balance_wallet_outlined, color: C.purple, title: tr('summary_funds'), value: '${_fundsData.length}', sub: tr('summary_funds_sub')),
    ];
    return LayoutBuilder(builder: (context, box) {
      final columns = box.maxWidth >= 1050 ? 4 : box.maxWidth >= 700 ? 2 : 1;
      final width = (box.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(spacing: 12, runSpacing: 12, children: cards.map((c) => SizedBox(width: width, child: c)).toList());
    });
  }

  Widget _summaryTable() {
    final byCat = <String, Map<String, Object?>>{
      for (final r in _categoriesData) '${r['category']}': r,
    };
    final grand = _number(_stats['total']);
    return _Panel(
      title: tr('summary_breakdown_title'),
      icon: Icons.table_chart_outlined,
      trailing: Text('${_money(grand)} TZS', style: const TextStyle(color: C.navy, fontWeight: FontWeight.w900)),
      child: LayoutBuilder(builder: (context, box) {
        final compact = box.maxWidth < 700;
        if (compact) {
          return Column(children: [
            for (final c in _categories) _categoryListRow(c, byCat[c]),
            const Divider(height: 20),
            _grandRow(grand),
          ]);
        }
        return Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Expanded(flex: 5, child: Text('MAELEZO', style: TextStyle(fontWeight: FontWeight.w900, color: C.navy))),
              Expanded(flex: 2, child: Text('MISTARI', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, color: C.navy))),
              Expanded(flex: 3, child: Text('MATUMIZI (TZS)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w900, color: C.navy))),
            ]),
          ),
          const SizedBox(height: 4),
          for (final c in _categories) _tableRow(c, byCat[c]),
          const Divider(height: 24),
          _grandRow(grand),
        ]);
      }),
    );
  }

  Widget _tableRow(String category, Map<String, Object?>? row) {
    final total = _number(row?['total']);
    final entries = (row?['entries'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Expanded(flex: 5, child: Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: _categoryColor(category), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(category, style: const TextStyle(fontWeight: FontWeight.w700, color: C.text))),
        ])),
        Expanded(flex: 2, child: Text('$entries', textAlign: TextAlign.right, style: const TextStyle(color: C.muted, fontWeight: FontWeight.w700))),
        Expanded(flex: 3, child: Text(_money(total), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900, color: C.navy))),
      ]),
    );
  }

  Widget _categoryListRow(String category, Map<String, Object?>? row) {
    final total = _number(row?['total']);
    final grand = _number(_stats['total']);
    final pct = grand <= 0 ? 0.0 : total / grand;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(category, style: const TextStyle(fontWeight: FontWeight.w700, color: C.text))), Text('${_money(total)} TZS', style: const TextStyle(fontWeight: FontWeight.w900, color: C.navy))]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: math.min(1.0, pct).toDouble(), minHeight: 7, backgroundColor: C.bg, valueColor: AlwaysStoppedAnimation<Color>(_categoryColor(category))),
        ),
      ]),
    );
  }

  Widget _grandRow(double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: C.navy.withOpacity(.06), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(child: Text(tr('summary_grand_total'), style: const TextStyle(fontWeight: FontWeight.w900, color: C.navy))),
        Text('${_money(total)} TZS', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: C.navy)),
      ]),
    );
  }

  Widget _analyticsRow() {
    return LayoutBuilder(builder: (context, box) {
      final chart = _categoryChart();
      final insight = _insightCard();
      if (box.maxWidth >= 900) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: chart), const SizedBox(width: 16), Expanded(flex: 2, child: insight)]);
      }
      return Column(children: [chart, const SizedBox(height: 16), insight]);
    });
  }

  Widget _categoryChart() {
    final maxTotal = _categoriesData.fold<double>(0, (m, r) => math.max(m, _number(r['total'])));
    final lookup = <String, Map<String, Object?>>{for (final r in _categoriesData) '${r['category']}': r};
    return _Panel(
      title: tr('summary_chart_title'),
      icon: Icons.bar_chart_rounded,
      child: Column(children: [for (final c in _categories) _bar(c, _number(lookup[c]?['total']), maxTotal)]),
    );
  }

  Widget _bar(String category, double value, double maxValue) {
    final ratio = maxValue <= 0 ? 0.0 : value / maxValue;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SizedBox(width: 145, child: Text(_categoryLabel(category), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.text))),
        const SizedBox(width: 10),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Stack(children: [
          Container(height: 16, color: C.bg),
          FractionallySizedBox(widthFactor: ratio.clamp(0.0, 1.0).toDouble(), child: Container(height: 16, decoration: BoxDecoration(color: _categoryColor(category), borderRadius: BorderRadius.circular(6)))),
        ]))),
        const SizedBox(width: 10),
        SizedBox(width: 100, child: Text(_money(value), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: C.navy))),
      ]),
    );
  }

  Widget _insightCard() {
    final total = _number(_stats['total']);
    final top = _categoriesData.isEmpty ? null : _categoriesData.reduce((a, b) => _number(a['total']) >= _number(b['total']) ? a : b);
    final topName = top == null ? '-' : '${top['category']}';
    final topAmount = top == null ? 0.0 : _number(top['total']);
    final share = total <= 0 ? 0.0 : topAmount / total * 100;
    return _Panel(
      title: tr('summary_insights_title'),
      icon: Icons.lightbulb_outline,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _InsightLine(icon: Icons.trending_up, title: tr('summary_top_category'), value: topName, detail: '${_money(topAmount)} TZS • ${share.toStringAsFixed(1)}%'),
        const Divider(height: 22),
        _InsightLine(icon: Icons.event_note_outlined, title: tr('summary_active_days'), value: '${_dailyData.length}', detail: tr('summary_active_days_sub')),
        const Divider(height: 22),
        _InsightLine(icon: Icons.account_balance_wallet_outlined, title: tr('summary_fund_count'), value: '${_fundsData.length}', detail: tr('summary_fund_count_sub')),
      ]),
    );
  }

  Widget _fundSection() {
    return _Panel(
      title: tr('summary_fund_breakdown'),
      icon: Icons.account_balance_outlined,
      child: _fundsData.isEmpty ? _miniEmpty(tr('summary_no_funds')) : Column(children: [for (final row in _fundsData) _fundRow(row)]),
    );
  }

  Widget _fundRow(Map<String, Object?> row) {
    final total = _number(row['total']);
    final all = _number(_stats['total']);
    final pct = all <= 0 ? 0.0 : total / all;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(children: [
        Row(children: [Expanded(child: Text('${row['fund_name']}', style: const TextStyle(fontWeight: FontWeight.w800, color: C.text))), Text('${_money(total)} TZS', style: const TextStyle(fontWeight: FontWeight.w900, color: C.navy))]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: math.min(1.0, pct).toDouble(), minHeight: 6, backgroundColor: C.bg, valueColor: const AlwaysStoppedAnimation<Color>(C.teal))),
      ]),
    );
  }

  Widget _dailyTrend() {
    if (_dailyData.isEmpty) {
      return _Panel(title: tr('summary_daily_title'), icon: Icons.show_chart, child: _miniEmpty(tr('summary_no_daily')));
    }
    final recent = _dailyData.length > 14 ? _dailyData.sublist(_dailyData.length - 14) : _dailyData;
    final maxValue = recent.fold<double>(0, (m, r) => math.max(m, _number(r['total'])));
    return _Panel(
      title: tr('summary_daily_title'),
      icon: Icons.show_chart,
      child: SizedBox(
        height: 210,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final row in recent)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: maxValue <= 0 ? 0.0 : (_number(row['total']) / maxValue).clamp(0.04, 1.0).toDouble(),
                            child: Container(width: double.infinity, decoration: const BoxDecoration(color: C.teal, borderRadius: BorderRadius.vertical(top: Radius.circular(6)))),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(_dateIso('${row['day']}').substring(0, 5), style: const TextStyle(fontSize: 9, color: C.muted)),
                      const SizedBox(height: 3),
                      Text(_compactMoney(_number(row['total'])), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: C.navy)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _compactMoney(double value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.round().toString();
  }

  Widget _scopeNote() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: C.gold.withOpacity(.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.gold.withOpacity(.25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: C.gold),
        const SizedBox(width: 10),
        Expanded(child: Text(tr('summary_scope_note'), style: const TextStyle(fontSize: 12.5, color: C.text, height: 1.45))),
      ]),
    );
  }

  Widget _errorCard() {
    return _Panel(
      title: tr('summary_title'),
      icon: Icons.error_outline,
      child: Column(children: [
        const Icon(Icons.cloud_off_outlined, size: 44, color: C.muted),
        const SizedBox(height: 10),
        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: C.muted)),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: Text(tr('retry'))),
      ]),
    );
  }

  Widget _miniEmpty(String text) {
    return Padding(padding: const EdgeInsets.all(22), child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: C.muted))));
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  const _Panel({required this.title, required this.icon, required this.child, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: C.navy.withOpacity(.07), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: C.navy, size: 21)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: C.navy))),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String sub;
  const _StatCard({required this.icon, required this.color, required this.title, required this.value, required this.sub});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, color: C.navy, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: C.muted)),
        ])),
      ]),
    );
  }
}

class _InsightLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String detail;
  const _InsightLine({required this.icon, required this.title, required this.value, required this.detail});
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: C.teal, size: 21),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: C.navy, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(detail, style: const TextStyle(fontSize: 10.5, color: C.muted)),
      ])),
    ]);
  }
}

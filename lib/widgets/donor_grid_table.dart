import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import '../core/contribution_matrix.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

/// Inaruhusu kuburuta jedwali kwa mouse/touchpad pia (si kwa kidole tu).
class _AnyDeviceScroll extends MaterialScrollBehavior {
  const _AnyDeviceScroll();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

/// Jedwali la watoaji wote kwa aina zote za michango.
/// Safu za Na na Jina zinakaa kushoto wakati wa kuscroll kulia; aina asiyotoa mtoaji inabaki wazi.
class DonorGridTable extends StatefulWidget {
  final DonorGrid grid;
  final bool showNames;
  const DonorGridTable({super.key, required this.grid, required this.showNames});

  @override
  State<DonorGridTable> createState() => _DonorGridTableState();
}

class _DonorGridTableState extends State<DonorGridTable> {
  static const double _wNo = 44, _wName = 170, _wId = 96, _wSex = 64, _wCol = 100, _wTot = 104;
  static const double _rowH = 40, _headH = 52;

  final _h = ScrollController();
  final _vLeft = ScrollController();
  final _vRight = ScrollController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _vLeft.addListener(() => _link(_vLeft, _vRight));
    _vRight.addListener(() => _link(_vRight, _vLeft));
  }

  @override
  void dispose() {
    _h.dispose();
    _vLeft.dispose();
    _vRight.dispose();
    super.dispose();
  }

  void _link(ScrollController from, ScrollController to) {
    if (_syncing || !from.hasClients || !to.hasClients) return;
    _syncing = true;
    final target = from.offset.clamp(0.0, to.position.maxScrollExtent).toDouble();
    if ((to.offset - target).abs() > 0.5) to.jumpTo(target);
    _syncing = false;
  }

  String _money(double v) => v.round().toString();

  Widget _head(String text, double w) => Container(
        width: w,
        height: _headH,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(color: C.navy, border: Border(right: BorderSide(color: Colors.white.withOpacity(.25)))),
        child: Text(text, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
      );

  Widget _text(String t, double w, {bool left = true, bool bold = false}) => Container(
        width: w,
        height: _rowH,
        alignment: left ? Alignment.centerLeft : Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: C.text)),
      );

  Widget _amount(double? v) {
    final has = v != null && v > 0;
    return Container(
      width: _wCol,
      height: _rowH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: has ? C.teal.withOpacity(.12) : null,
        border: Border(left: BorderSide(color: C.border.withOpacity(.6))),
      ),
      // Aina ambayo mtoaji hakutoa inabaki wazi.
      child: has ? Text(_money(v), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.text)) : null,
    );
  }

  Widget _leftRow(int i, DonorGridRow d) => Container(
        color: i.isEven ? Colors.white : C.bg,
        child: Row(children: [
          _text('${i + 1}', _wNo, left: false),
          _text(widget.showNames ? (d.name.isEmpty ? '—' : d.name) : '••••••••', _wName),
        ]),
      );

  Widget _rightRow(int i, DonorGridRow d, List<String> cols) => Container(
        color: i.isEven ? Colors.white : C.bg,
        child: Row(children: [
          _text(d.idNo.isEmpty ? '—' : d.idNo, _wId),
          _text(d.sex.isEmpty ? '—' : d.sex, _wSex, left: false),
          for (final c in cols) _amount(d.amounts[c]),
          _text(d.total > 0 ? _money(d.total) : '', _wTot, left: false, bold: true),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final g = widget.grid;
    final cols = g.columns;
    final leftW = _wNo + _wName;
    final rightW = _wId + _wSex + _wCol * cols.length + _wTot;
    final listH = (g.rows.length * _rowH).clamp(_rowH * 2, 520.0).toDouble();
    final totalBg = C.gold.withOpacity(.18);

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.border)),
      clipBehavior: Clip.antiAlias,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Safu za kushoto (zinakaa mahali pamoja)
        Container(
          width: leftW,
          decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: C.border, width: 1.5))),
          child: Column(children: [
            Row(children: [_head(tr('col_no'), _wNo), _head(tr('col_name'), _wName)]),
            SizedBox(
              height: listH,
              child: ListView.builder(
                controller: _vLeft,
                itemCount: g.rows.length,
                itemExtent: _rowH,
                itemBuilder: (_, i) => _leftRow(i, g.rows[i]),
              ),
            ),
            Container(color: totalBg, child: Row(children: [_text('', _wNo), _text(tr('grand_total'), _wName, bold: true)])),
          ]),
        ),
        // Safu za kulia (zinasogea)
        Expanded(
          child: ScrollConfiguration(
            behavior: const _AnyDeviceScroll(),
            child: Scrollbar(
              controller: _h,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: _h,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: rightW,
                  child: Column(children: [
                    Row(children: [
                      _head(tr('env_or_donor_no'), _wId),
                      _head(tr('sex'), _wSex),
                      for (final c in cols) _head(c, _wCol),
                      _head(tr('total'), _wTot),
                    ]),
                    SizedBox(
                      height: listH,
                      child: ListView.builder(
                        controller: _vRight,
                        itemCount: g.rows.length,
                        itemExtent: _rowH,
                        itemBuilder: (_, i) => _rightRow(i, g.rows[i], cols),
                      ),
                    ),
                    Container(
                      color: totalBg,
                      child: Row(children: [
                        _text('', _wId),
                        _text('', _wSex),
                        for (final c in cols) _text((g.columnTotals[c] ?? 0) > 0 ? _money(g.columnTotals[c]!) : '', _wCol, left: false, bold: true),
                        _text(_money(g.grandTotal), _wTot, left: false, bold: true),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

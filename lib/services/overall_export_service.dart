import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import '../core/brand.dart';
import 'file_saver.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../core/i18n.dart';

class OverallExportService {
  static String money(Object? value) {
    final n = (value as num?)?.toDouble() ?? 0;
    return '${n.round().toString()} TZS';
  }

  static String periodLabel(DateTime? from, DateTime? to) {
    final f = from == null ? tr('dash_all') : _d(from);
    final t = to == null ? '' : ' - ${_d(to)}';
    return '$f$t';
  }

  static String _d(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<Uint8List> pdfBytes({
    required DateTime? from,
    required DateTime? to,
    required Map<String, Object?> stats,
    required List<Map<String, Object?>> contributions,
    required List<Map<String, Object?>> categories,
    required List<Map<String, Object?>> funds,
    required List<Map<String, Object?>> daily,
  }) async {
    final doc = pw.Document();
    final logo = await Brand.pdfLogo();
    final income = (stats['income'] as num?)?.toDouble() ?? 0;
    final expense = (stats['expenditure'] as num?)?.toDouble() ?? 0;
    final balance = (stats['balance'] as num?)?.toDouble() ?? income - expense;
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (_) => Brand.pdfHeader(logo: logo, title: tr('ovr_title'), trailing: periodLabel(from, to)),
      footer: (ctx) => pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('${tr('page')} ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8))),
      build: (_) => [
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: [tr('makusanyo').toUpperCase(), tr('matumizi').toUpperCase(), tr('salio').toUpperCase(), tr('ovr_contrib_lines'), tr('ovr_expense_lines')],
          data: [[money(income), money(expense), money(balance), '${stats['contributionEntries'] ?? 0}', '${stats['expenditureEntries'] ?? 0}']],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        ),
        pw.SizedBox(height: 16),
        pw.Text(tr('ovr_summary_title'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 7),
        pw.TableHelper.fromTextArray(
          headers: [tr('ovr_group'), tr('ovr_amount')],
          data: [
            ...contributions.map((r) => ['${tr('makusanyo')}: ${r['type'] == 'FUNGU' ? tr('fungu') : tr('other_contributions')}', money(r['total'])]),
            ...categories.map((r) => ['${tr('matumizi')}: ${r['category']}', money(r['total'])]),
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 16),
        pw.Text(tr('balance_fund_breakdown'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 7),
        pw.TableHelper.fromTextArray(
          headers: [tr('fund'), tr('makusanyo'), tr('matumizi'), tr('salio')],
          data: funds.map((r) => [fundLabel(r['fund_name']), money(r['income']), money(r['expenditure']), money(r['balance'])]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 16),
        pw.Text(tr('ovr_daily'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 7),
        pw.TableHelper.fromTextArray(
          headers: [tr('date_label'), tr('makusanyo'), tr('matumizi'), tr('ovr_daily_balance')],
          data: daily.map((r) => [r['day'] ?? '', money(r['income']), money(r['expenditure']), money(r['balance'])]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 7),
        ),
      ],
    ));
    return doc.save();
  }

  static Future<void> sharePdf({required DateTime? from, required DateTime? to, required Map<String, Object?> stats, required List<Map<String, Object?>> contributions, required List<Map<String, Object?>> categories, required List<Map<String, Object?>> funds, required List<Map<String, Object?>> daily}) async {
    final bytes = await pdfBytes(from: from, to: to, stats: stats, contributions: contributions, categories: categories, funds: funds, daily: daily);
    await Printing.sharePdf(bytes: bytes, filename: '${tr('file_overall')}_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  static Future<File> buildExcel({required DateTime? from, required DateTime? to, required Map<String, Object?> stats, required List<Map<String, Object?>> contributions, required List<Map<String, Object?>> categories, required List<Map<String, Object?>> funds, required List<Map<String, Object?>> daily}) async {
    final excel = Excel.createExcel();
    final sheet = excel[tr('ovr_sheet')];
    final title = [Brand.systemName, tr('ovr_title'), periodLabel(from, to)];
    for (var i = 0; i < title.length; i++) sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(title[i]);
    final headers = [tr('ovr_metric'), tr('ovr_value')];
    for (var c = 0; c < headers.length; c++) sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2)).value = TextCellValue(headers[c]);
    final metrics = [
      [tr('makusanyo').toUpperCase(), (stats['income'] as num?)?.toDouble() ?? 0],
      [tr('matumizi').toUpperCase(), (stats['expenditure'] as num?)?.toDouble() ?? 0],
      [tr('salio').toUpperCase(), (stats['balance'] as num?)?.toDouble() ?? 0],
      [tr('ovr_contrib_lines'), stats['contributionEntries'] ?? 0],
      [tr('ovr_expense_lines'), stats['expenditureEntries'] ?? 0],
    ];
    for (var r = 0; r < metrics.length; r++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 3)).value = TextCellValue(metrics[r][0].toString());
      final v = metrics[r][1];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 3)).value = v is num ? DoubleCellValue(v.toDouble()) : TextCellValue(v.toString());
    }
    var row = 10;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(tr('dash_collection_breakdown').toUpperCase()); row++;
    [tr('type_label'),tr('amount')].asMap().forEach((c,h)=>sheet.cell(CellIndex.indexByColumnRow(columnIndex:c,rowIndex:row)).value=TextCellValue(h)); row++;
    for (final r in contributions) { sheet.cell(CellIndex.indexByColumnRow(columnIndex:0,rowIndex:row)).value=TextCellValue(r['type']=='FUNGU'?tr('fungu'):tr('other_contributions')); sheet.cell(CellIndex.indexByColumnRow(columnIndex:1,rowIndex:row)).value=DoubleCellValue(((r['total'] as num?)?.toDouble()??0)); row++; }
    row += 2;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(tr('dash_expense_breakdown').toUpperCase());
    row++;
    final catHeaders = [tr('type_label'), tr('amount')];
    for (var c = 0; c < catHeaders.length; c++) sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row)).value = TextCellValue(catHeaders[c]);
    row++;
    for (final r in categories) { sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('${r['category']}'); sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = DoubleCellValue(((r['total'] as num?)?.toDouble() ?? 0)); row++; }
    row += 2;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(tr('balance_fund_breakdown').toUpperCase()); row++;
    [tr('fund'),'${tr('makusanyo')} (TZS)','${tr('matumizi')} (TZS)','${tr('salio')} (TZS)'].asMap().forEach((c,h)=>sheet.cell(CellIndex.indexByColumnRow(columnIndex:c,rowIndex:row)).value=TextCellValue(h)); row++;
    for (final r in funds) { sheet.cell(CellIndex.indexByColumnRow(columnIndex:0,rowIndex:row)).value=TextCellValue(fundLabel(r['fund_name'])); sheet.cell(CellIndex.indexByColumnRow(columnIndex:1,rowIndex:row)).value=DoubleCellValue(((r['income'] as num?)?.toDouble()??0)); sheet.cell(CellIndex.indexByColumnRow(columnIndex:2,rowIndex:row)).value=DoubleCellValue(((r['expenditure'] as num?)?.toDouble()??0)); sheet.cell(CellIndex.indexByColumnRow(columnIndex:3,rowIndex:row)).value=DoubleCellValue(((r['balance'] as num?)?.toDouble()??0)); row++; }
    row += 2;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex:0,rowIndex:row)).value=TextCellValue(tr('ovr_daily').toUpperCase()); row++;
    [tr('date_label'),'${tr('makusanyo')} (TZS)','${tr('matumizi')} (TZS)','${tr('ovr_daily_balance')} (TZS)'].asMap().forEach((c,h)=>sheet.cell(CellIndex.indexByColumnRow(columnIndex:c,rowIndex:row)).value=TextCellValue(h)); row++;
    for (final r in daily) { sheet.cell(CellIndex.indexByColumnRow(columnIndex:0,rowIndex:row)).value=TextCellValue('${r['day']}'); sheet.cell(CellIndex.indexByColumnRow(columnIndex:1,rowIndex:row)).value=DoubleCellValue(((r['income'] as num?)?.toDouble()??0)); sheet.cell(CellIndex.indexByColumnRow(columnIndex:2,rowIndex:row)).value=DoubleCellValue(((r['expenditure'] as num?)?.toDouble()??0)); sheet.cell(CellIndex.indexByColumnRow(columnIndex:3,rowIndex:row)).value=DoubleCellValue(((r['balance'] as num?)?.toDouble()??0)); row++; }
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, '${tr('file_overall')}_${DateTime.now().millisecondsSinceEpoch}.xlsx'));
    final bytes = excel.encode(); if (bytes == null) throw StateError(tr('excel_build_failed'));
    await file.writeAsBytes(bytes, flush: true); return file;
  }

  static Future<void> shareExcel({required DateTime? from, required DateTime? to, required Map<String, Object?> stats, required List<Map<String, Object?>> contributions, required List<Map<String, Object?>> categories, required List<Map<String, Object?>> funds, required List<Map<String, Object?>> daily}) async {
    final file = await buildExcel(from: from, to: to, stats: stats, contributions: contributions, categories: categories, funds: funds, daily: daily);
    await Share.shareXFiles([XFile(file.path)], text: '${tr('ovr_sheet')} - ${periodLabel(from, to)}');
  }

  /// Inahifadhi Excel moja kwa moja kwenye kifaa (Downloads).
  static Future<SavedFile> saveExcel({required DateTime? from, required DateTime? to, required Map<String, Object?> stats, required List<Map<String, Object?>> contributions, required List<Map<String, Object?>> categories, required List<Map<String, Object?>> funds, required List<Map<String, Object?>> daily}) async {
    final file = await buildExcel(from: from, to: to, stats: stats, contributions: contributions, categories: categories, funds: funds, daily: daily);
    final bytes = await file.readAsBytes();
    try { await file.delete(); } catch (_) {}
    return FileSaver.saveBytes(p.basename(file.path), bytes);
  }
}

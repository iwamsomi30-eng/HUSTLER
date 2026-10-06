import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class OverallExportService {
  static String money(Object? value) {
    final n = (value as num?)?.toDouble() ?? 0;
    return '${n.round().toString()} TZS';
  }

  static String periodLabel(DateTime? from, DateTime? to) {
    final f = from == null ? 'Taarifa zote' : _d(from);
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
    final income = (stats['income'] as num?)?.toDouble() ?? 0;
    final expense = (stats['expenditure'] as num?)?.toDouble() ?? 0;
    final balance = (stats['balance'] as num?)?.toDouble() ?? income - expense;
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (_) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('MFUKO WA MAPATO YA KANISA', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            pw.Text('OVERALL DASHBOARD & TRENDS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.Text(periodLabel(from, to), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      ),
      footer: (ctx) => pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Ukurasa ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8))),
      build: (_) => [
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: const ['MAKUSANYO', 'MATUMIZI', 'SALIO', 'MISTARI YA MAKUSANYO', 'MISTARI YA MATUMIZI'],
          data: [[money(income), money(expense), money(balance), '${stats['contributionEntries'] ?? 0}', '${stats['expenditureEntries'] ?? 0}']],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        ),
        pw.SizedBox(height: 16),
        pw.Text('Muhtasari wa Makusanyo na Matumizi', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 7),
        pw.TableHelper.fromTextArray(
          headers: const ['Kundi', 'Kiasi'],
          data: [
            ...contributions.map((r) => ['Makusanyo: ${r['type'] == 'FUNGU' ? 'FUNGU' : 'MICHANGO MINGINE'}', money(r['total'])]),
            ...categories.map((r) => ['Matumizi: ${r['category']}', money(r['total'])]),
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 16),
        pw.Text('Salio kwa Mfuko', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 7),
        pw.TableHelper.fromTextArray(
          headers: const ['Mfuko', 'Makusanyo', 'Matumizi', 'Salio'],
          data: funds.map((r) => [r['fund_name'] ?? '', money(r['income']), money(r['expenditure']), money(r['balance'])]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 16),
        pw.Text('Trend ya Kila Siku', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 7),
        pw.TableHelper.fromTextArray(
          headers: const ['Tarehe', 'Makusanyo', 'Matumizi', 'Salio la Siku'],
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
    await Printing.sharePdf(bytes: bytes, filename: 'overall_dashboard_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  static Future<File> buildExcel({required DateTime? from, required DateTime? to, required Map<String, Object?> stats, required List<Map<String, Object?>> contributions, required List<Map<String, Object?>> categories, required List<Map<String, Object?>> funds, required List<Map<String, Object?>> daily}) async {
    final excel = Excel.createExcel();
    final sheet = excel['Overall Dashboard'];
    final title = ['MFUKO WA MAPATO YA KANISA', 'OVERALL DASHBOARD & TRENDS', periodLabel(from, to)];
    for (var i = 0; i < title.length; i++) sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(title[i]);
    final headers = ['Metric', 'Value'];
    for (var c = 0; c < headers.length; c++) sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2)).value = TextCellValue(headers[c]);
    final metrics = [
      ['MAKUSANYO', (stats['income'] as num?)?.toDouble() ?? 0],
      ['MATUMIZI', (stats['expenditure'] as num?)?.toDouble() ?? 0],
      ['SALIO', (stats['balance'] as num?)?.toDouble() ?? 0],
      ['MISTARI YA MAKUSANYO', stats['contributionEntries'] ?? 0],
      ['MISTARI YA MATUMIZI', stats['expenditureEntries'] ?? 0],
    ];
    for (var r = 0; r < metrics.length; r++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r + 3)).value = TextCellValue(metrics[r][0].toString());
      final v = metrics[r][1];
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r + 3)).value = v is num ? DoubleCellValue(v.toDouble()) : TextCellValue(v.toString());
    }
    var row = 10;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('MAKUSANYO KWA AINA'); row++;
    ['Aina','Kiasi (TZS)'].asMap().forEach((c,h)=>sheet.cell(CellIndex.indexByColumnRow(columnIndex:c,rowIndex:row)).value=TextCellValue(h)); row++;
    for (final r in contributions) { sheet.cell(CellIndex.indexByColumnRow(columnIndex:0,rowIndex:row)).value=TextCellValue(r['type']=='FUNGU'?'FUNGU':'MICHANGO MINGINE'); sheet.cell(CellIndex.indexByColumnRow(columnIndex:1,rowIndex:row)).value=DoubleCellValue(((r['total'] as num?)?.toDouble()??0)); row++; }
    row += 2;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('MATUMIZI KWA KATEGORIA');
    row++;
    for (final h in ['Kategoria', 'Kiasi (TZS)']) sheet.cell(CellIndex.indexByColumnRow(columnIndex: ['Kategoria','Kiasi (TZS)'].indexOf(h), rowIndex: row)).value = TextCellValue(h);
    row++;
    for (final r in categories) { sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('${r['category']}'); sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = DoubleCellValue(((r['total'] as num?)?.toDouble() ?? 0)); row++; }
    row += 2;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue('SALIO KWA MFUKO'); row++;
    ['Mfuko','Makusanyo (TZS)','Matumizi (TZS)','Salio (TZS)'].asMap().forEach((c,h)=>sheet.cell(CellIndex.indexByColumnRow(columnIndex:c,rowIndex:row)).value=TextCellValue(h)); row++;
    for (final r in funds) { sheet.cell(CellIndex.indexByColumnRow(columnIndex:0,rowIndex:row)).value=TextCellValue('${r['fund_name']}'); sheet.cell(CellIndex.indexByColumnRow(columnIndex:1,rowIndex:row)).value=DoubleCellValue(((r['income'] as num?)?.toDouble()??0)); sheet.cell(CellIndex.indexByColumnRow(columnIndex:2,rowIndex:row)).value=DoubleCellValue(((r['expenditure'] as num?)?.toDouble()??0)); sheet.cell(CellIndex.indexByColumnRow(columnIndex:3,rowIndex:row)).value=DoubleCellValue(((r['balance'] as num?)?.toDouble()??0)); row++; }
    row += 2;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex:0,rowIndex:row)).value=TextCellValue('TREND YA KILA SIKU'); row++;
    ['Tarehe','Makusanyo (TZS)','Matumizi (TZS)','Salio la Siku (TZS)'].asMap().forEach((c,h)=>sheet.cell(CellIndex.indexByColumnRow(columnIndex:c,rowIndex:row)).value=TextCellValue(h)); row++;
    for (final r in daily) { sheet.cell(CellIndex.indexByColumnRow(columnIndex:0,rowIndex:row)).value=TextCellValue('${r['day']}'); sheet.cell(CellIndex.indexByColumnRow(columnIndex:1,rowIndex:row)).value=DoubleCellValue(((r['income'] as num?)?.toDouble()??0)); sheet.cell(CellIndex.indexByColumnRow(columnIndex:2,rowIndex:row)).value=DoubleCellValue(((r['expenditure'] as num?)?.toDouble()??0)); sheet.cell(CellIndex.indexByColumnRow(columnIndex:3,rowIndex:row)).value=DoubleCellValue(((r['balance'] as num?)?.toDouble()??0)); row++; }
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'overall_dashboard_${DateTime.now().millisecondsSinceEpoch}.xlsx'));
    final bytes = excel.encode(); if (bytes == null) throw StateError('Excel file haikuweza kutengenezwa.');
    await file.writeAsBytes(bytes, flush: true); return file;
  }

  static Future<void> shareExcel({required DateTime? from, required DateTime? to, required Map<String, Object?> stats, required List<Map<String, Object?>> contributions, required List<Map<String, Object?>> categories, required List<Map<String, Object?>> funds, required List<Map<String, Object?>> daily}) async {
    final file = await buildExcel(from: from, to: to, stats: stats, contributions: contributions, categories: categories, funds: funds, daily: daily);
    await Share.shareXFiles([XFile(file.path)], text: 'Overall Dashboard - ${periodLabel(from, to)}');
  }
}

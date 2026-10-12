import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../core/brand.dart';
import 'file_saver.dart';
import '../core/i18n.dart';

class ContributionExportService {
  /// Faragha: majina halisi ya watoaji HAYAWEKWI kwenye PDF/Excel.
  /// Mtoaji anatambulika kwa Namba ya Bahasha (FUNGU) au MCH No. (Michango Mingine).
  /// Namba ya simu nayo inaweza kumtambulisha mtu; iko OFF kwa chaguo-msingi.
  static const bool includeContact = false;

  static String idNumber(Map<String, Object?> r) {
    final v = r['type'] == 'FUNGU' ? r['envelope_no'] : r['name_no'];
    final t = '${v ?? ''}'.trim();
    return t.isEmpty ? '—' : t;
  }

  static double amountOf(Map<String, Object?> r) {
    final v = r['amount'];
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}'.replaceAll(',', '').trim()) ?? 0;
  }

  static String money(Object? value) {
    final n = value is num ? value.toDouble() : (double.tryParse('${value ?? ''}') ?? 0);
    return '${n.round().toString()} TZS';
  }

  static String safeDate(String day) => day.replaceAll('-', '');

  static Future<Uint8List> pdfBytes({
    required String day,
    required List<Map<String, Object?>> rows,
    required String title,
  }) async {
    final doc = pw.Document();
    final logo = await Brand.pdfLogo();
    final total = rows.fold<double>(0, (s, r) => s + amountOf(r));
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (_) => Brand.pdfHeader(logo: logo, title: title, trailing: '${tr('date_label')}: $day'),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('${tr('page')} ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
        ),
        build: (_) => [
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: [
              tr('type_label'), tr('service'), tr('env_or_donor_no'), tr('contribution_name'), tr('sex'),
              if (includeContact) tr('contact'),
              tr('amount'), tr('receipt'),
            ],
            data: rows.map((r) => [
              r['type'] == 'FUNGU' ? tr('fungu') : tr('other_contributions'),
              '${tr('service').toUpperCase()} ${(r['service'] as num?)?.toInt() ?? 1}',
              idNumber(r),
              r['contribution_name'] ?? (r['type'] == 'FUNGU' ? 'FUNGU' : ''),
              r['sex'] ?? '',
              if (includeContact) r['contact'] ?? '',
              money(r['amount']),
              r['receipt_no'] ?? '',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              child: pw.Text('${tr('grand_total')}: ${money(total)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Future<void> sharePdf({
    required String day,
    required List<Map<String, Object?>> rows,
  }) async {
    final bytes = await pdfBytes(day: day, rows: rows, title: tr('nav_michango_records'));
    await Printing.sharePdf(bytes: bytes, filename: '${tr('file_contributions')}_${safeDate(day)}.pdf');
  }

  static Future<File> buildExcel({
    required String day,
    required List<Map<String, Object?>> rows,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel[tr('michango')];
    final amountHeader = tr('amount');
    final headers = [tr('date_label'), tr('type_label'), tr('service'), tr('env_or_donor_no'), tr('contribution_name'), tr('sex'), if (includeContact) tr('contact'), amountHeader, tr('receipt_no')];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Center);
    }
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final values = <Object>[
        day,
        row['type'] == 'FUNGU' ? tr('fungu') : tr('other_contributions'),
        '${tr('service').toUpperCase()} ${(row['service'] as num?)?.toInt() ?? 1}',
        idNumber(row),
        (row['contribution_name'] ?? (row['type'] == 'FUNGU' ? 'FUNGU' : '')).toString(),
        (row['sex'] ?? '').toString(),
        if (includeContact) (row['contact'] ?? '').toString(),
        amountOf(row),
        (row['receipt_no'] ?? '').toString(),
      ];
      for (var c = 0; c < values.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        final v = values[c];
        cell.value = v is num ? DoubleCellValue(v.toDouble()) : TextCellValue(v.toString());
      }
    }
    final total = rows.fold<double>(0, (s, r) => s + amountOf(r));
    final amountCol = headers.indexOf(amountHeader);
    final totalRow = rows.length + 2;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: amountCol - 1, rowIndex: totalRow)).value = TextCellValue(tr('grand_total'));
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: amountCol, rowIndex: totalRow)).value = DoubleCellValue(total);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, '${tr('file_contributions')}_${safeDate(day)}.xlsx'));
    final bytes = excel.encode();
    if (bytes == null) throw StateError(tr('excel_build_failed'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> shareExcel({
    required String day,
    required List<Map<String, Object?>> rows,
  }) async {
    final file = await buildExcel(day: day, rows: rows);
    await Share.shareXFiles([XFile(file.path)], text: '${tr('nav_michango_records')} - $day');
  }

  /// Inahifadhi Excel moja kwa moja kwenye kifaa (Downloads).
  static Future<SavedFile> saveExcel({
    required String day,
    required List<Map<String, Object?>> rows,
  }) async {
    final file = await buildExcel(day: day, rows: rows);
    final bytes = await file.readAsBytes();
    try { await file.delete(); } catch (_) {}
    return FileSaver.saveBytes(p.basename(file.path), bytes);
  }
}

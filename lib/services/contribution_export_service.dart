import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

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
    return '${n.round().toString().replaceAllMapped(RegExp(r'(?=(\d{3})+$)'), (m) => ',')} TZS';
  }

  static String safeDate(String day) => day.replaceAll('-', '');

  static Future<Uint8List> pdfBytes({
    required String day,
    required List<Map<String, Object?>> rows,
    required String title,
  }) async {
    final doc = pw.Document();
    final total = rows.fold<double>(0, (s, r) => s + amountOf(r));
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('MFUKO WA MAPATO YA KANISA', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                pw.Text(title, style: const pw.TextStyle(fontSize: 10)),
              ]),
              pw.Text('Tarehe: $day', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Ukurasa ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
        ),
        build: (_) => [
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: [
              'Aina', 'Ibada', 'Namba (Bahasha / MCH)', 'Jina la Mchango',
              if (includeContact) 'Contact',
              'Kiasi (TZS)', 'Receipt',
            ],
            data: rows.map((r) => [
              r['type'] == 'FUNGU' ? 'FUNGU' : 'MCHANGO MENGINE',
              'IBADA ${(r['service'] as num?)?.toInt() ?? 1}',
              idNumber(r),
              r['contribution_name'] ?? (r['type'] == 'FUNGU' ? 'FUNGU' : ''),
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
              child: pw.Text('JUMLA KUU: ${money(total)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
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
    final bytes = await pdfBytes(day: day, rows: rows, title: 'Michango Records');
    await Printing.sharePdf(bytes: bytes, filename: 'michango_${safeDate(day)}.pdf');
  }

  static Future<File> buildExcel({
    required String day,
    required List<Map<String, Object?>> rows,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Michango'];
    final headers = ['Tarehe', 'Aina', 'Ibada', 'Namba (Bahasha / MCH)', 'Jina la Mchango', if (includeContact) 'Contact', 'Kiasi (TZS)', 'Receipt No.'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Center);
    }
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final values = <Object>[
        day,
        row['type'] == 'FUNGU' ? 'FUNGU' : 'MCHANGO MENGINE',
        'IBADA ${(row['service'] as num?)?.toInt() ?? 1}',
        idNumber(row),
        (row['contribution_name'] ?? (row['type'] == 'FUNGU' ? 'FUNGU' : '')).toString(),
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
    final amountCol = headers.indexOf('Kiasi (TZS)');
    final tr = rows.length + 2;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: amountCol - 1, rowIndex: tr)).value = TextCellValue('JUMLA KUU');
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: amountCol, rowIndex: tr)).value = DoubleCellValue(total);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'michango_${safeDate(day)}.xlsx'));
    final bytes = excel.encode();
    if (bytes == null) throw StateError('Excel file haikuweza kutengenezwa.');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> shareExcel({
    required String day,
    required List<Map<String, Object?>> rows,
  }) async {
    final file = await buildExcel(day: day, rows: rows);
    await Share.shareXFiles([XFile(file.path)], text: 'Michango Records - $day');
  }
}

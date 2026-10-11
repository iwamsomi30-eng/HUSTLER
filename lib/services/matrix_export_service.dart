import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/brand.dart';
import '../core/contribution_matrix.dart';
import '../core/i18n.dart';
import 'file_saver.dart';

/// Upakuaji wa jedwali la watoaji (wote) na taarifa za mtoaji mmoja.
/// Faragha: majina halisi na namba za simu HAVIWEKWI kwenye PDF/Excel;
/// mtoaji anatambulika kwa Namba ya Bahasha au MCH No.
class MatrixExportService {
  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  static String _stamp() {
    final n = DateTime.now();
    return '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
  }

  static String _id(DonorRecord d) => d.idNo.isEmpty ? '—' : d.idNo;
  static String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  static String _money(num v) => '${v.round()} TZS';
  static String _amt(double v) => v > 0 ? v.round().toString() : '';
  static String _monShort(int m) {
    final n = tr('month_$m');
    return n.length <= 3 ? n : n.substring(0, 3);
  }

  static pw.Widget _footer(pw.Context ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('${tr('page')} ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
      );

  // ───────────────────────── Jedwali la watoaji wote ─────────────────────────

  /// PDF: ukurasa mmoja (au zaidi) kwa kila mwaka, jumla ya kila mwezi.
  /// Maelezo ya wiki 1-5 yako kwenye Excel.
  static Future<Uint8List> matrixPdfBytes({required ContributionMatrix matrix, required String period}) async {
    final doc = pw.Document();
    final logo = await Brand.pdfLogo();
    for (final year in matrix.years) {
      final rows = matrix.donors;
      final headers = <String>[
        tr('col_no'), tr('env_or_donor_no'), tr('col_reg_date'), tr('sex'),
        for (var m = 1; m <= 12; m++) _monShort(m),
        tr('total'),
      ];
      final data = <List<String>>[
        for (var i = 0; i < rows.length; i++)
          <String>[
            '${i + 1}', _id(rows[i]), _d(rows[i].firstDate), rows[i].sex,
            for (var m = 1; m <= 12; m++) _amt(rows[i].monthTotal(year, m)),
            _amt(rows[i].yearTotal(year)),
          ],
      ];
      final grand = rows.fold<double>(0, (s, d) => s + d.yearTotal(year));
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (_) => Brand.pdfHeader(
          logo: logo,
          title: '${tr('nav_michango_records')} • ${tr('year_label')} $year',
          trailing: period,
        ),
        footer: _footer,
        build: (_) => [
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: data,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
            cellStyle: const pw.TextStyle(fontSize: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerRight,
            cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.centerLeft, 2: pw.Alignment.centerLeft, 3: pw.Alignment.center},
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              child: pw.Text('${tr('grand_total')} $year: ${_money(grand)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            ),
          ),
        ],
      ));
    }
    return doc.save();
  }

  /// Excel: karatasi moja kwa kila mwaka; kila mwezi una safu za wiki 1-5.
  static Uint8List matrixExcelBytes({required ContributionMatrix matrix, required String period}) {
    final excel = Excel.createExcel();
    for (final year in matrix.years) {
      final sheet = excel['$year'];
      void put(int c, int r, Object v, {bool bold = false}) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        cell.value = v is num ? DoubleCellValue(v.toDouble()) : TextCellValue(v.toString());
        if (bold) cell.cellStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Center);
      }

      put(0, 0, Brand.systemName, bold: true);
      put(0, 1, '${tr('nav_michango_records')} • ${tr('year_label')} $year • $period', bold: true);
      final fixed = <String>[tr('col_no'), tr('env_or_donor_no'), tr('col_reg_date'), tr('sex')];
      for (var i = 0; i < fixed.length; i++) {
        put(i, 4, fixed[i], bold: true);
      }
      for (var m = 1; m <= 12; m++) {
        final base = 4 + (m - 1) * 5;
        put(base, 3, tr('month_$m'), bold: true);
        for (var w = 1; w <= 5; w++) {
          put(base + w - 1, 4, '${tr('week_short')} $w', bold: true);
        }
      }
      const totalCol = 4 + 60;
      put(totalCol, 4, tr('total'), bold: true);

      var grand = 0.0;
      for (var i = 0; i < matrix.donors.length; i++) {
        final d = matrix.donors[i];
        final r = 5 + i;
        put(0, r, i + 1);
        put(1, r, _id(d));
        put(2, r, _d(d.firstDate));
        put(3, r, d.sex);
        for (var m = 1; m <= 12; m++) {
          for (var w = 1; w <= 5; w++) {
            final a = d.cell(year, m, w)?.amount ?? 0;
            if (a > 0) put(4 + (m - 1) * 5 + w - 1, r, a);
          }
        }
        final yt = d.yearTotal(year);
        grand += yt;
        put(totalCol, r, yt);
      }
      final tr0 = 5 + matrix.donors.length + 1;
      put(totalCol - 1, tr0, tr('grand_total'), bold: true);
      put(totalCol, tr0, grand, bold: true);
    }
    try {
      excel.delete('Sheet1');
    } catch (_) {}
    final bytes = excel.encode();
    if (bytes == null) throw StateError(tr('excel_build_failed'));
    return Uint8List.fromList(bytes);
  }

  static Future<void> shareMatrixPdf({required ContributionMatrix matrix, required String period}) async {
    final bytes = await matrixPdfBytes(matrix: matrix, period: period);
    await Printing.sharePdf(bytes: bytes, filename: '${tr('file_matrix')}_${_stamp()}.pdf');
  }

  static Future<SavedFile> saveMatrixExcel({required ContributionMatrix matrix, required String period}) {
    return FileSaver.saveBytes('${tr('file_matrix')}_${_stamp()}.xlsx', matrixExcelBytes(matrix: matrix, period: period));
  }

  // ───────────────────────── Mtoaji mmoja ─────────────────────────

  static List<DonorEntry> _sorted(DonorRecord d) => [...d.entries]..sort((a, b) => a.date.compareTo(b.date));

  /// Kisanduku cha taarifa za mtoaji husika: jina, namba, jinsia na tarehe ya usajili.
  static pw.Widget _donorInfoBox(DonorRecord d) {
    pw.Widget row(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.SizedBox(width: 130, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.Expanded(child: pw.Text(value.isEmpty ? '—' : value, style: const pw.TextStyle(fontSize: 10))),
          ]),
        );
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500, width: 0.8)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        row(tr('col_name'), d.name),
        row(tr('env_or_donor_no'), d.idNo),
        row(tr('sex'), d.sex),
        row(tr('col_reg_date'), _d(d.firstDate)),
      ]),
    );
  }

  static Future<Uint8List> donorPdfBytes(DonorRecord d) async {
    final doc = pw.Document();
    final logo = await Brand.pdfLogo();
    final entries = _sorted(d);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (_) => Brand.pdfHeader(logo: logo, title: tr('donor_profile'), trailing: '${tr('env_or_donor_no')}: ${_id(d)}'),
      footer: _footer,
      build: (_) => [
        pw.SizedBox(height: 8),
        _donorInfoBox(d),
        pw.SizedBox(height: 12),
        pw.Text(tr('donor_by_name'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: [tr('contribution_name'), tr('amount')],
          data: d.totalsByName().entries.map((e) => [e.key, _money(e.value)]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        ),
        pw.SizedBox(height: 12),
        pw.Text(tr('donor_entries'), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: [tr('date_label'), tr('contribution_name'), tr('amount'), tr('receipt')],
          data: entries.map((e) => [_d(e.date), e.contributionName, _money(e.amount), e.receiptNo]).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        ),
        pw.SizedBox(height: 12),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            child: pw.Text('${tr('grand_total')}: ${_money(d.total)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          ),
        ),
      ],
    ));
    return doc.save();
  }

  static Uint8List donorExcelBytes(DonorRecord d) {
    final excel = Excel.createExcel();
    final sheet = excel[tr('michango')];
    void put(int c, int r, Object v, {bool bold = false}) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
      cell.value = v is num ? DoubleCellValue(v.toDouble()) : TextCellValue(v.toString());
      if (bold) cell.cellStyle = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Center);
    }

    put(0, 0, Brand.systemName, bold: true);
    put(0, 1, '${tr('donor_profile')} • ${tr('env_or_donor_no')}: ${_id(d)}', bold: true);
    put(0, 2, '${tr('col_name')}: ${d.name.isEmpty ? '—' : d.name}   ${tr('col_reg_date')}: ${_d(d.firstDate)}   ${tr('sex')}: ${d.sex.isEmpty ? '—' : d.sex}');
    final headers = <String>[tr('date_label'), tr('contribution_name'), tr('amount'), tr('receipt_no')];
    for (var i = 0; i < headers.length; i++) {
      put(i, 4, headers[i], bold: true);
    }
    final entries = _sorted(d);
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      put(0, 5 + i, _d(e.date));
      put(1, 5 + i, e.contributionName);
      put(2, 5 + i, e.amount);
      put(3, 5 + i, e.receiptNo);
    }
    final tr0 = 5 + entries.length + 1;
    put(1, tr0, tr('grand_total'), bold: true);
    put(2, tr0, d.total, bold: true);
    try {
      excel.delete('Sheet1');
    } catch (_) {}
    final bytes = excel.encode();
    if (bytes == null) throw StateError(tr('excel_build_failed'));
    return Uint8List.fromList(bytes);
  }

  static Future<void> shareDonorPdf(DonorRecord d) async {
    final bytes = await donorPdfBytes(d);
    await Printing.sharePdf(bytes: bytes, filename: '${tr('file_donor')}_${_safe(_id(d))}.pdf');
  }

  static Future<SavedFile> saveDonorExcel(DonorRecord d) {
    return FileSaver.saveBytes('${tr('file_donor')}_${_safe(_id(d))}.xlsx', donorExcelBytes(d));
  }
}

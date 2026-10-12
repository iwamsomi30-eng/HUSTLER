import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Utambulisho mmoja wa mfumo: jina na logo vinatumika kila mahali
/// (skrini ya kuanza, kichwa cha app, PDF na Excel).
class Brand {
  static const systemName = 'TAG SHALOM TEMPLE KIBAMBA';
  static const systemNameShort = 'TAG SHALOM\nTEMPLE\nKIBAMBA';
  static const logoAsset = 'assets/logo.png';

  /// Kifupi kinachotumika kwenye namba ya risiti: TAG-STK-...
  static const receiptPrefix = 'TAG-STK';

  static pw.MemoryImage? _logo;

  /// Logo kwa ajili ya PDF. Inasomwa mara moja kisha inahifadhiwa.
  static Future<pw.MemoryImage> pdfLogo() async {
    if (_logo != null) return _logo!;
    final data = await rootBundle.load(logoAsset);
    _logo = pw.MemoryImage(data.buffer.asUint8List());
    return _logo!;
  }

  /// Kichwa cha kawaida cha PDF: logo upande wa kushoto, jina la mfumo
  /// na kichwa cha ripoti, na maelezo ya kulia (mfano tarehe).
  static pw.Widget pdfHeader({
    required pw.MemoryImage logo,
    required String title,
    required String trailing,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(logo, width: 42, height: 42),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(systemName, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text(title, style: const pw.TextStyle(fontSize: 10)),
            ]),
          ),
          pw.Text(trailing, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}

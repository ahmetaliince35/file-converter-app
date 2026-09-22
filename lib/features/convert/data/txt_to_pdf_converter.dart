import 'dart:io';
import 'package:pdf/pdf.dart' as pw_pdf;
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/files/temp_file_manager.dart';

class TxtToPdfConverter {
  static Future<File> convert(
      File txtFile, {
        void Function(double progress, String status)? onProgress,
      }) async {
    onProgress?.call(0.1, 'Metin dosyası okunuyor...');
    final lines = await txtFile.readAsLines();

    final pdf = pw.Document();
    const int linesPerPage = 45;
    final totalPages = (lines.length / linesPerPage).ceil().clamp(1, 99999);

    for (int i = 0; i < lines.length; i += linesPerPage) {
      final pageIndex = (i / linesPerPage).floor() + 1;
      onProgress?.call(
        0.1 + (0.8 * (pageIndex / totalPages)),
        'Sayfa oluşturuluyor: $pageIndex / $totalPages',
      );

      final end = (i + linesPerPage < lines.length) ? i + linesPerPage : lines.length;
      final pageLines = lines.sublist(i, end).join('\n');

      pdf.addPage(
        pw.Page(
          pageFormat: pw_pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Text(
            pageLines,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      );
    }

    onProgress?.call(0.95, 'PDF kaydediliyor...');
    final workingDir = await TempFileManager.workingDir;
    final outPath = '${workingDir.path}/Metin_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final outFile = File(outPath);
    await outFile.writeAsBytes(await pdf.save());

    return outFile;
  }
}
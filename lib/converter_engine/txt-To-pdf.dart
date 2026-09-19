import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TxtToPdfConverter {
  /// .txt dosyasını Türkçe karakter destekli, başlık ve sayfa numaralı profesyonel PDF yapar.
  static Future<File> convert(File inputFile) async {
    final content = await inputFile.readAsString();
    final fileName = p.basename(inputFile.path);

    final doc = pw.Document();

    // Türkçe karakterleri sorunsuz basmak için Google Fonts'tan Roboto fontu yüklenir
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8)),
          ),
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(
            fileName,
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Sayfa ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Text(
            content,
            style: pw.TextStyle(
              font: font,
              fontSize: 10.5,
              lineSpacing: 3,
            ),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final baseName = p.basenameWithoutExtension(inputFile.path);
    final outFile = File('${dir.path}/${baseName}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await outFile.writeAsBytes(await doc.save());
    return outFile;
  }
}
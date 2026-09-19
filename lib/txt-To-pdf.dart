import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class TxtToPdfConverter {
  /// [inputFile] bir .txt dosyasıdır. Dönüşüm tamamen cihazda yapılır.
  static Future<File> convert(File inputFile) async {
    final content = await inputFile.readAsString();
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            content,
            style: const pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );

    return _saveDoc(doc, inputFile);
  }

  static Future<File> _saveDoc(pw.Document doc, File inputFile) async {
    final dir = await getApplicationDocumentsDirectory();
    final baseName = inputFile.uri.pathSegments.last.split('.').first;
    final outFile = File('${dir.path}/$baseName.pdf');
    await outFile.writeAsBytes(await doc.save());
    return outFile;
  }
}
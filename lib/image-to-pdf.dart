import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ImageToPdfConverter {
  /// Tek bir görsel (jpg/png) için dönüşüm.
  static Future<File> convert(File inputFile) async {
    return convertMultiple([inputFile]);
  }

  /// Birden fazla görseli tek bir PDF'te birleştirir (her biri ayrı sayfa).
  static Future<File> convertMultiple(List<File> inputFiles) async {
    final doc = pw.Document();

    for (final file in inputFiles) {
      final bytes = await file.readAsBytes();
      final image = pw.MemoryImage(bytes);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final baseName = inputFiles.first.uri.pathSegments.last.split('.').first;
    final outFile = File('${dir.path}/$baseName.pdf');
    await outFile.writeAsBytes(await doc.save());
    return outFile;
  }
}
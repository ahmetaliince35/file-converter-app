import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ImageToPdfConverter {
  static Future<File> convert(File inputFile) async {
    return convertMultiple([inputFile]);
  }

  static Future<File> convertMultiple(List<File> inputFiles) async {
    final doc = pw.Document();

    for (final file in inputFiles) {
      final bytes = await file.readAsBytes();
      final image = pw.MemoryImage(bytes);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    final dir = await getTemporaryDirectory();
    final baseName = inputFiles.first.uri.pathSegments.last.split('.').first;
    final outFile = File(
      '${dir.path}/${baseName}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await outFile.writeAsBytes(await doc.save());
    return outFile;
  }
}

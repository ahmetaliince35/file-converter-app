import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfSplitterService {
  /// [sourcePdf]: Kaynak PDF dosyası
  /// [selectedPages]: Kullanıcının seçtiği sayfa indeksleri (0 tabanlı: 0, 1, 4 vb.)
  static Future<File> extractPages({
    required File sourcePdf,
    required List<int> selectedPages,
  }) async {
    if (selectedPages.isEmpty) {
      throw Exception('Lütfen ayıklanacak en az bir sayfa seçin.');
    }

    final inputBytes = await sourcePdf.readAsBytes();
    final inputDoc = PdfDocument(inputBytes: inputBytes);
    final outputDoc = PdfDocument();

    // Küçükten büyüğe sırala
    selectedPages.sort();

    for (final pageIndex in selectedPages) {
      if (pageIndex >= 0 && pageIndex < inputDoc.pages.count) {
        final sourcePage = inputDoc.pages[pageIndex];
        outputDoc.pageSettings.size = sourcePage.size;
        outputDoc.pageSettings.margins.all = 0;

        final template = sourcePage.createTemplate();
        outputDoc.pages.add().graphics.drawPdfTemplate(template, Offset.zero);
      }
    }

    inputDoc.dispose();

    final dir = await getTemporaryDirectory();
    final baseName = p.basenameWithoutExtension(sourcePdf.path);
    final outFile = File('${dir.path}/${baseName}_Secilenler_${DateTime.now().millisecondsSinceEpoch}.pdf');

    final outBytes = await outputDoc.save();
    await outFile.writeAsBytes(outBytes);
    outputDoc.dispose();

    return outFile;
  }

  /// PDF'in toplam sayfa sayısını okur
  static Future<int> getPageCount(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    final count = doc.pages.count;
    doc.dispose();
    return count;
  }
}
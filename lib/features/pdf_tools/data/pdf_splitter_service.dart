import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../core/files/temp_file_manager.dart';

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

    try {
      for (final pageIndex in selectedPages) {
        if (pageIndex >= 0 && pageIndex < inputDoc.pages.count) {
          final sourcePage = inputDoc.pages[pageIndex];
          outputDoc.pageSettings.size = sourcePage.size;
          outputDoc.pageSettings.margins.all = 0;

          final template = sourcePage.createTemplate();
          outputDoc.pages.add().graphics.drawPdfTemplate(template, Offset.zero);
        }
      }

      // Dosyayı converter_cache içine kaydederek depolama hijyenini koruyoruz:
      final workingDir = await TempFileManager.workingDir;
      final baseName = p.basenameWithoutExtension(sourcePdf.path);
      final outFile = File('${workingDir.path}/${baseName}_Secilenler_${DateTime.now().millisecondsSinceEpoch}.pdf');

      final outBytes = await outputDoc.save();
      await outFile.writeAsBytes(outBytes);

      return outFile;
    } finally {
      inputDoc.dispose();
      outputDoc.dispose();
    }
  }

  /// PDF'in toplam sayfa sayısını okur
  static Future<int> getPageCount(File pdfFile) async {
    final bytes = await pdfFile.readAsBytes();
    final doc = PdfDocument(inputBytes: bytes);
    try {
      return doc.pages.count;
    } finally {
      doc.dispose();
    }
  }
}
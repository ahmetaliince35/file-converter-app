import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DocumentScanAdapter {
  const DocumentScanAdapter();

  /// Kamera ile belgeleri tarayıp A4 PDF olarak döndürür.
  Future<File?> startScan({int pageLimit = 25}) async {
    try {
      final documentScanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormat: DocumentFormat.pdf,
          mode: ScannerMode.full,
          pageLimit: pageLimit,
          isGalleryImport: true,
        ),
      );

      final DocumentScanningResult result = await documentScanner.scanDocument();
      await documentScanner.close();

      final pdfUriString = result.pdf?.uri;
      if (pdfUriString == null) return null;

      final uri = Uri.parse(pdfUriString);
      final scannedFile = uri.isScheme('file') ? File.fromUri(uri) : File(pdfUriString);

      if (await scannedFile.exists()) {
        final tempDir = await getTemporaryDirectory();
        final targetPath = p.join(
          tempDir.path,
          'tarama_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
        return await scannedFile.copy(targetPath);
      }
      return null;
    } catch (e) {
      debugPrint('[DOCUMENT_SCAN_ADAPTER_ERROR] $e');
      return null;
    }
  }
}

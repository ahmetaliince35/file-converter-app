import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ZipCreatorService {
  /// Seçilen dosyaları tek bir .zip arşivi haline getirir (Ana işler için).
  static Future<File> createZipFromFiles(List<File> files) async {
    if (files.isEmpty) {
      throw Exception('Arşivlenecek dosya bulunamadı.');
    }

    final archive = Archive();

    for (final file in files) {
      final fileName = p.basename(file.path);
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
    }

    final encoder = ZipEncoder();
    final zipData = encoder.encode(archive);

    if (zipData == null) {
      throw Exception('ZIP arşivi oluşturulamadı.');
    }

    final dir = await getTemporaryDirectory();
    final zipFileName = 'Arsiv_${DateTime.now().millisecondsSinceEpoch}.zip';
    final zipFile = File('${dir.path}/$zipFileName');

    await zipFile.writeAsBytes(zipData);
    return zipFile;
  }

  /// Platform bağımlılığı olmadan, Isolate / compute dostu sıkıştırma.
  static Future<File> compressToPath({
    required List<String> inputPaths,
    required String outputPath,
  }) async {
    final archive = Archive();
    for (final path in inputPaths) {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final fileName = p.basename(path);
        archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
      }
    }

    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw Exception('ZIP verisi üretilemedi.');
    }

    final zipFile = File(outputPath);
    await zipFile.writeAsBytes(zipData);
    return zipFile;
  }
}
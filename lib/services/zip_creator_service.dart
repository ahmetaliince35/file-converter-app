import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ZipCreatorService {
  /// Seçilen dosyaları tek bir .zip arşivi haline getirir.
  static Future<File> createZipFromFiles(List<File> files) async {
    if (files.isEmpty) {
      throw Exception('Arşivlenecek dosya bulunamadı.');
    }

    final archive = Archive();

    for (final file in files) {
      final fileName = p.basename(file.path);
      final bytes = await file.readAsBytes();
      // Arşive her dosyayı ekliyoruz
      archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
    }

    // ZIP encoder ile sıkıştır
    final encoder = ZipEncoder();
    final zipData = encoder.encode(archive);

    if (zipData == null) {
      throw Exception('ZIP arşivi oluşturulamadı.');
    }

    final dir = await getApplicationDocumentsDirectory();
    final zipFileName = 'Arsiv_${DateTime.now().millisecondsSinceEpoch}.zip';
    final zipFile = File('${dir.path}/$zipFileName');

    await zipFile.writeAsBytes(zipData);
    return zipFile;
  }
}
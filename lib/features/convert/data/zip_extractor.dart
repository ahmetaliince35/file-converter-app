import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

class ZipExtractor {
  /// [inputFile] bir .zip dosyasıdır. Tüm içerik, dosya adıyla aynı isimde
  /// bir klasöre ayıklanır ve ayıklanan dosyaların listesi döndürülür.
  static Future<List<File>> extract(File inputFile) async {
    final bytes = await inputFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final docsDir = await getTemporaryDirectory();
    final baseName = inputFile.uri.pathSegments.last.split('.').first;
    final outDir = Directory('${docsDir.path}/extracted_$baseName');
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final extractedFiles = <File>[];

    for (final entry in archive) {
      final outPath = '${outDir.path}/${entry.name}';
      if (entry.isFile) {
        final data = entry.content as List<int>;
        final file = File(outPath);
        await file.create(recursive: true);
        await file.writeAsBytes(data);
        extractedFiles.add(file);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }

    return extractedFiles;
  }
}
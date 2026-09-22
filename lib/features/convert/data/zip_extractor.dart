import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../../core/files/temp_file_manager.dart';

class ZipExtractor {
  /// [inputFile] .zip arşivini ana UI thread'ini dondurmadan (compute/Isolate)
  /// ve disk taşmalarına karşı güvenli şekilde ayıklar.
  static Future<List<File>> extract(File inputFile) async {
    final workingDir = await TempFileManager.workingDir;
    final baseName = p.basenameWithoutExtension(inputFile.path);
    final targetDirPath = '${workingDir.path}/extracted_${baseName}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Ağır dosya okuma ve yazma işini arka plan iş parçacığına devrediyoruz:
      final extractedPaths = await compute(_extractWorker, {
        'inputPath': inputFile.path,
        'targetDirPath': targetDirPath,
      });

      return extractedPaths.map((path) => File(path)).toList();
    } catch (e) {
      // İşlem başarısız olursa açılan yarım klasörü temizle
      final targetDir = Directory(targetDirPath);
      if (await targetDir.exists()) {
        try {
          await targetDir.delete(recursive: true);
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Arka planda çalışan izole ayıklama motoru
  static List<String> _extractWorker(Map<String, String> args) {
    final inputPath = args['inputPath']!;
    final targetDirPath = args['targetDirPath']!;

    final targetDir = Directory(targetDirPath);
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final inputStream = InputFileStream(inputPath);
    final archive = ZipDecoder().decodeBuffer(inputStream);
    final extractedPaths = <String>[];

    final canonicalTargetDir = targetDir.resolveSymbolicLinksSync();

    for (final entry in archive) {
      // Zip Slip koruması: Çıkartılan dosya hedef dizinin dışına taşmamalı
      final outPath = p.normalize(p.join(targetDirPath, entry.name));
      if (!outPath.startsWith(canonicalTargetDir) && !outPath.startsWith(targetDirPath)) {
        continue; // Güvenlik dışı yolu atla
      }

      if (entry.isFile) {
        // Dosyanın yazılacağı üst klasör yoksa oluştur (Crash önleyici)
        final parentDir = Directory(p.dirname(outPath));
        if (!parentDir.existsSync()) {
          parentDir.createSync(recursive: true);
        }

        final outputStream = OutputFileStream(outPath);
        entry.writeContent(outputStream);
        outputStream.close();
        extractedPaths.add(outPath);
      } else {
        Directory(outPath).createSync(recursive: true);
      }
    }

    inputStream.close();
    return extractedPaths;
  }
}
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../../core/files/temp_file_manager.dart';

class ZipExtractor {
  static Future<List<File>> extract(File inputFile) async {
    if (!await inputFile.exists()) {
      throw FileSystemException('Kaynak zip dosyası bulunamadı', inputFile.path);
    }

    final workingDir = await TempFileManager.workingDir;
    if (!await workingDir.exists()) {
      await workingDir.create(recursive: true);
    }

    final baseName = p.basenameWithoutExtension(inputFile.path);
    final targetDirPath = p.join(
      workingDir.path,
      'extracted_${baseName}_${DateTime.now().millisecondsSinceEpoch}',
    );

    try {
      final extractedPaths = await compute(_extractWorker, {
        'inputPath': inputFile.path,
        'targetDirPath': targetDirPath,
      });

      return extractedPaths.map((path) => File(path)).toList();
    } catch (e) {
      final targetDir = Directory(targetDirPath);
      if (await targetDir.exists()) {
        try {
          await targetDir.delete(recursive: true);
        } catch (_) {}
      }
      rethrow;
    }
  }

  static List<String> _extractWorker(Map<String, String> args) {
    final inputPath = args['inputPath']!;
    final targetDirPath = args['targetDirPath']!;

    final targetDir = Directory(targetDirPath);
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final file = File(inputPath);
    final bytes = file.readAsBytesSync();

    // 1. Standart decode dene, olmazsa InputStream ile dene
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (_) {
      // Alternatif parser (Bazı Windows Zip formatları için)
      final input = InputStream(bytes);
      archive = ZipDecoder().decodeBuffer(input, verify: false);
    }

    if (archive.isEmpty) {
      throw Exception('Arşiv boş veya içeriği okunamadı.');
    }

    final extractedPaths = <String>[];
    final normalizedRoot = p.normalize(p.absolute(targetDirPath));

    for (final entry in archive) {
      final rawPath = entry.name.replaceAll('\\', '/');

      // Mac OS çöp dosyalarını atla
      if (rawPath.startsWith('__MACOSX') || p.basename(rawPath).startsWith('._')) {
        continue;
      }

      final fullPath = p.normalize(p.join(normalizedRoot, rawPath));

      // Zip-Slip koruması
      if (!fullPath.startsWith(normalizedRoot)) {
        continue;
      }

      if (entry.isFile) {
        final outFile = File(fullPath);
        final parent = outFile.parent;
        if (!parent.existsSync()) {
          parent.createSync(recursive: true);
        }

        // Bazı arşivlerde dosya içeriği null gelebilir
        final dynamic rawContent = entry.content;
        if (rawContent != null) {
          final data = rawContent as List<int>;
          outFile.writeAsBytesSync(data, flush: true);
          extractedPaths.add(fullPath);
        }
      } else {
        final dir = Directory(fullPath);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
      }
    }

    archive.clear();
    return extractedPaths;
  }
}
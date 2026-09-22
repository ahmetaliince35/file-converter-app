import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CacheCleanerService {
  /// Eski geçici önbellek ve thumbnail artıklarını temizler
  static Future<void> clearTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final List<FileSystemEntity> entities = tempDir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      // Sessizce geç
    }
  }
}
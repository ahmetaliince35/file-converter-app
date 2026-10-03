import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../../convert/data/universal_converter_service.dart';

class FileSelectionResult {
  final List<File> files;
  final String? errorMessage;
  final bool isCancelled;

  const FileSelectionResult({
    required this.files,
    this.errorMessage,
    this.isCancelled = false,
  });

  bool get hasFiles => files.isNotEmpty;
  bool get hasError => errorMessage != null;
}

/// Dosya seçimi ve seçilen dosyaların kararlılık kontrollerini yöneten servis.
class FileSelectorService {
  const FileSelectorService();

  /// Belirli uzantılardaki dosyaları seçer ve okunabilir durumda olduklarını doğrular.
  Future<FileSelectionResult> pickCategoryFiles({
    required List<String> extensions,
    bool allowMultiple = true,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        withData: false,
        type: FileType.custom,
        allowedExtensions: extensions,
      );

      if (result == null || result.files.isEmpty) {
        return const FileSelectionResult(files: [], isCancelled: true);
      }

      final validFiles = await _validateAndStabilizeFiles(result.files);
      if (validFiles.isEmpty) {
        return const FileSelectionResult(
          files: [],
          errorMessage: 'Dosya açılamadı veya kopyalanamadı.',
        );
      }

      return FileSelectionResult(files: validFiles);
    } catch (e) {
      return FileSelectionResult(
        files: [],
        errorMessage: 'Dosya seçilirken bir sorun oluştu: $e',
      );
    }
  }

  /// Evrensel dönüştürücü için tüm belgeleri ve 150+ kaynak kod/metin dosyasını seçer.
  /// Android/iOS sistem dosya yöneticilerinin nadir kod uzantılarını devre dışı bırakmasını engellemek için
  /// sistem düzeyinde FileType.any kullanılır, ardından medya ve ikili sistem dosyaları güvenle filtrelenir.
  Future<FileSelectionResult> pickUniversalFiles({
    List<String>? customExtensions,
    bool allowMultiple = true,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        withData: false,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) {
        return const FileSelectionResult(files: [], isCancelled: true);
      }

      final validFiles = await _validateAndStabilizeFiles(result.files);
      if (validFiles.isEmpty) {
        return const FileSelectionResult(
          files: [],
          errorMessage: 'Dosya açılamadı veya kopyalanamadı.',
        );
      }

      final accepted = <File>[];
      final rejected = <String>[];

      for (final file in validFiles) {
        final ext = p.extension(file.path).replaceFirst('.', '').toLowerCase();
        if (UniversalConverterService.blockedMediaExtensions.contains(ext)) {
          rejected.add('${p.basename(file.path)} (Medya)');
        } else if (UniversalConverterService.blockedBinaryExtensions.contains(ext)) {
          rejected.add('${p.basename(file.path)} (İkili)');
        } else if (customExtensions != null &&
            customExtensions.isNotEmpty &&
            !customExtensions.contains(ext)) {
          rejected.add('${p.basename(file.path)} (Farklı Tür)');
        } else {
          accepted.add(file);
        }
      }

      if (accepted.isEmpty && rejected.isNotEmpty) {
        return FileSelectionResult(
          files: [],
          errorMessage:
              'Seçilen dosya(lar) dönüştürülemez: ${rejected.join(', ')}. Ses, video ve resim dosyaları bu dönüştürücü kapsamı dışındadır.',
        );
      }

      return FileSelectionResult(files: accepted);
    } catch (e) {
      return FileSelectionResult(
        files: [],
        errorMessage: 'Dosya seçilirken bir sorun oluştu: $e',
      );
    }
  }

  /// Tüm dosya tiplerinden seçim yapar (örn. ZIP arşivi veya QR gönderim için).
  Future<FileSelectionResult> pickAnyFiles({
    bool allowMultiple = true,
    int? maxSizeBytes,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        withData: false,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) {
        await FilePicker.platform.clearTemporaryFiles();
        return const FileSelectionResult(files: [], isCancelled: true);
      }

      final validFiles = await _validateAndStabilizeFiles(result.files);

      if (validFiles.isEmpty) {
        await FilePicker.platform.clearTemporaryFiles();
        return const FileSelectionResult(
          files: [],
          errorMessage: 'Seçilen dosyalar okunamadı.',
        );
      }

      if (maxSizeBytes != null) {
        final oversized = validFiles.where((f) => f.existsSync() && f.lengthSync() > maxSizeBytes).toList();
        if (oversized.isNotEmpty) {
          await FilePicker.platform.clearTemporaryFiles();
          final limitMB = (maxSizeBytes / (1024 * 1024)).toStringAsFixed(0);
          return FileSelectionResult(
            files: [],
            errorMessage: 'Seçilen dosya $limitMB MB sınırını aşıyor!',
          );
        }
      }

      return FileSelectionResult(files: validFiles);
    } catch (e) {
      await FilePicker.platform.clearTemporaryFiles();
      return FileSelectionResult(
        files: [],
        errorMessage: 'Dosya seçilirken bir hata oluştu: $e',
      );
    }
  }

  /// Android / iOS dosya sağlayıcılarından gelen dosyaların tam olarak yazıldığını kontrol eder.
  Future<List<File>> _validateAndStabilizeFiles(List<PlatformFile> platformFiles) async {
    final validFiles = <File>[];

    for (final pf in platformFiles) {
      if (pf.path == null) continue;
      final file = File(pf.path!);

      int lastSize = -1;
      int stableCount = 0;

      for (int i = 0; i < 15; i++) {
        if (await file.exists()) {
          final currentSize = await file.length();
          if (currentSize > 0 && currentSize == lastSize) {
            stableCount++;
            if (stableCount >= 2) break;
          } else {
            stableCount = 0;
          }
          lastSize = currentSize;
        }
        await Future.delayed(const Duration(milliseconds: 80));
      }

      if (await file.exists()) {
        validFiles.add(file);
      }
    }

    return validFiles;
  }
}

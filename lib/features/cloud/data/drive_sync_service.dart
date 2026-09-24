import 'dart:async';
import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import '../../../../core/files/temp_file_manager.dart';
import '../../auth/data/google_auth_service.dart';

class DriveSyncService {
  final GoogleAuthService _authService;

  DriveSyncService(this._authService);

  drive.DriveApi _getDriveApi() {
    final client = _authService.authenticatedClient;
    if (client == null) {
      throw Exception('Google Drive oturumu açık değil veya yetkilendirme alınamadı.');
    }
    return drive.DriveApi(client);
  }

  Future<File> convertOfficeToPdfViaDrive(File inputFile) async {
    final driveApi = _getDriveApi();
    final fileName = inputFile.uri.pathSegments.last;
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;
    final ext = dotIndex != -1 ? fileName.substring(dotIndex + 1).toLowerCase() : '';

    String targetMimeType = 'application/vnd.google-apps.document';
    if (ext == 'xlsx' || ext == 'xls') {
      targetMimeType = 'application/vnd.google-apps.spreadsheet';
    } else if (ext == 'pptx' || ext == 'ppt') {
      targetMimeType = 'application/vnd.google-apps.presentation';
    }

    final driveFile = drive.File()
      ..name = 'temp_${DateTime.now().millisecondsSinceEpoch}_$fileName'
      ..mimeType = targetMimeType;

    final length = await inputFile.length();
    final media = drive.Media(inputFile.openRead(), length);

    final uploadedFile = await driveApi.files.create(driveFile, uploadMedia: media);
    final fileId = uploadedFile.id;

    if (fileId == null) {
      throw Exception('Google Drive dosyası oluşturulamadı.');
    }

    File? outFile;
    try {
      // Google Drive'ın dosyayı işleyip export'a hazır hale getirmesini retry ile bekle
      final responseMedia = await _retryExportWithBackoff(driveApi, fileId);

      final workingDir = await TempFileManager.workingDir;
      outFile = File('${workingDir.path}/${baseName}_${DateTime.now().millisecondsSinceEpoch}.pdf');

      // Üst klasör yoksa oluştur
      if (!await outFile.parent.exists()) {
        await outFile.parent.create(recursive: true);
      }

      final sink = outFile.openWrite();
      await responseMedia.stream.pipe(sink);
      await sink.flush();
      await sink.close();

      return outFile;
    } catch (e) {
      if (outFile != null && await outFile.exists()) {
        try { await outFile.delete(); } catch (_) {}
      }
      rethrow;
    } finally {
      try {
        await driveApi.files.delete(fileId);
      } catch (_) {}
    }
  }

  /// Drive dosya dönüşüm gecikmelerini aşmak için retry mekanizması
  Future<drive.Media> _retryExportWithBackoff(
      drive.DriveApi driveApi,
      String fileId, {
        int maxAttempts = 4,
      }) async {
    int attempts = 0;
    int delayMs = 600;

    while (attempts < maxAttempts) {
      try {
        attempts++;
        final res = await driveApi.files.export(
          fileId,
          'application/pdf',
          downloadOptions: drive.DownloadOptions.fullMedia,
        );
        return res as drive.Media;
      } catch (e) {
        if (attempts >= maxAttempts) rethrow;
        // Dosya henüz Google sunucularında işleniyorsa kısa bir süre bekle
        await Future.delayed(Duration(milliseconds: delayMs));
        delayMs *= 2; // 600ms, 1200ms, 2400ms...
      }
    }
    throw Exception('Google Drive dosya dönüşümü zaman aşımına uğradı.');
  }

  Future<drive.File> uploadPdfToDrive(File file) async {
    final driveApi = _getDriveApi();
    final fileName = file.uri.pathSegments.last;

    final driveFile = drive.File()
      ..name = fileName
      ..mimeType = 'application/pdf';

    final length = await file.length();
    final media = drive.Media(file.openRead(), length);
    return await driveApi.files.create(driveFile, uploadMedia: media);
  }
}
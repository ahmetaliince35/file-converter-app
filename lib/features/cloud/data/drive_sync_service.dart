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

    final media = drive.Media(inputFile.openRead(), inputFile.lengthSync());
    final uploadedFile = await driveApi.files.create(driveFile, uploadMedia: media);
    final fileId = uploadedFile.id;

    if (fileId == null) {
      throw Exception('Google Drive dosyası oluşturulamadı.');
    }

    File? outFile;
    try {
      final responseMedia = await driveApi.files.export(
        fileId,
        'application/pdf',
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final workingDir = await TempFileManager.workingDir;
      outFile = File('${workingDir.path}/${baseName}_${DateTime.now().millisecondsSinceEpoch}.pdf');

      final sink = outFile.openWrite();
      await responseMedia.stream.pipe(sink);
      await sink.flush(); // Bellekteki tamponları diske basıp kapat
      await sink.close();

      return outFile;
    } catch (e) {
      // İndirme yarıda kesilirse diskte bozuk 0 KB / yarım dosya kalmasın
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

  Future<drive.File> uploadPdfToDrive(File file) async {
    final driveApi = _getDriveApi();
    final fileName = file.uri.pathSegments.last;

    final driveFile = drive.File()
      ..name = fileName
      ..mimeType = 'application/pdf';

    final media = drive.Media(file.openRead(), file.lengthSync());
    return await driveApi.files.create(driveFile, uploadMedia: media);
  }
}
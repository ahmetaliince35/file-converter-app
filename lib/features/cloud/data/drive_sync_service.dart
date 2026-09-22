import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import '../../auth/data/google_auth_service.dart';

class DriveSyncService {
  final GoogleAuthService _authService;

  DriveSyncService(this._authService);

  /// Google AuthClient üzerinden Drive API istemcisi oluşturur
  drive.DriveApi _getDriveApi() {
    final client = _authService.authenticatedClient;
    if (client == null) {
      throw Exception('Google Drive oturumu açık değil veya yetkilendirme alınamadı.');
    }
    return drive.DriveApi(client);
  }

  /// Office dosyalarını (DOCX, XLSX, PPTX) Drive üzerinde PDF'e çevirip indirir
  Future<File> convertOfficeToPdfViaDrive(File inputFile) async {
    final driveApi = _getDriveApi();
    final fileName = inputFile.uri.pathSegments.last;
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;
    final ext = dotIndex != -1 ? fileName.substring(dotIndex + 1).toLowerCase() : '';

    // Google Docs formatlarına eşleme
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

    try {
      // PDF olarak dışa aktar (Export)
      final responseMedia = await driveApi.files.export(
        fileId,
        'application/pdf',
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final dir = await getTemporaryDirectory();
      final outFile = File('${dir.path}/$baseName.pdf');
      final sink = outFile.openWrite();
      await responseMedia.stream.pipe(sink);
      await sink.close();

      return outFile;
    } finally {
      // Geçici dosyayı Drive'dan sil
      try {
        await driveApi.files.delete(fileId);
      } catch (_) {}
    }
  }

  /// Oluşturulan yerel PDF dosyasını kullanıcının Google Drive'ına yedekler
  Future<drive.File> uploadPdfToDrive(File file) async {
    final driveApi = _getDriveApi();
    final fileName = file.uri.pathSegments.last;

    final driveFile = drive.File()
      ..name = fileName
      ..mimeType = 'application/pdf';

    final media = drive.Media(file.openRead(), file.lengthSync());

    // Dosyayı Drive ana dizinine yükler
    return await driveApi.files.create(driveFile, uploadMedia: media);
  }
}
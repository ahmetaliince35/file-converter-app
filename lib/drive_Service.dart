import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import '../GoogleAuthService.dart';

/// GoogleAuthService'ten aldığı authHeaders'ı kullanan basit bir
/// http.BaseClient. googleapis paketinin drive.DriveApi'sı bu client'ı
/// kullanarak isteklere Authorization başlığını otomatik ekler.
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

class DriveSyncService {
  final GoogleAuthService authService;

  DriveSyncService(this.authService);

  /// Uygulama tarafından oluşturulan/ayıklanan bir dosyayı kullanıcının
  /// Drive'ında "Dosya Converter" adlı klasöre yükler. İnternet bağlantısı
  /// SADECE bu fonksiyon çağrıldığında gereklidir.
  Future<String> uploadFile(File file, {String? folderName}) async {
    final headers = await authService.getAuthHeaders();
    final client = _GoogleAuthClient(headers);
    final api = drive.DriveApi(client);

    String? folderId;
    if (folderName != null) {
      folderId = await _getOrCreateFolder(api, folderName);
    }

    final fileName = file.uri.pathSegments.last;
    final media = drive.Media(file.openRead(), await file.length());

    final driveFile = drive.File()
      ..name = fileName
      ..parents = folderId != null ? [folderId] : null;

    final uploaded = await api.files.create(driveFile, uploadMedia: media);
    client.close();
    return uploaded.id ?? '';
  }

  Future<String> _getOrCreateFolder(drive.DriveApi api, String name) async {
    final query =
        "mimeType='application/vnd.google-apps.folder' and name='$name' and trashed=false";
    final result = await api.files.list(q: query, spaces: 'drive');

    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id!;
    }

    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';
    final created = await api.files.create(folder);
    return created.id!;
  }
}
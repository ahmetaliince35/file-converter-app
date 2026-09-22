import 'dart:io';

import '../../auth/data/google_auth_service.dart';
import '../../auth/data/microsoft_auth_service.dart';
import 'drive_sync_service.dart';
import 'microsoft_graph_service.dart';

/// Office belgelerini önce Microsoft Graph, yoksa Google Drive ile PDF'e çevirir.
class OfficeToPdfService {
  const OfficeToPdfService();

  Future<File> convert(
    File file, {
    required GoogleAuthService googleAuth,
    required MicrosoftAuthService microsoftAuth,
  }) async {
    if (microsoftAuth.isSignedIn) {
      final token = await microsoftAuth.getAccessToken();
      if (token != null) {
        return MicrosoftGraphService(token).convertOfficeToPdf(file);
      }
    }

    if (!googleAuth.isSignedIn) {
      final ok = await googleAuth.signIn();
      if (!ok) {
        throw Exception(
          'Office dönüşümü için bir Google veya Microsoft oturumu gereklidir.',
        );
      }
    }

    return DriveSyncService(googleAuth).convertOfficeToPdfViaDrive(file);
  }
}

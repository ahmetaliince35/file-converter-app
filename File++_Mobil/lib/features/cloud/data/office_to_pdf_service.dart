import 'dart:io';

import '../../auth/data/google_auth_service.dart';
import '../../auth/data/microsoft_auth_service.dart';
import 'drive_sync_service.dart';
import 'microsoft_graph_service.dart';

/// Office belgelerini önce Microsoft Graph, hata alırsa veya oturum yoksa Google Drive ile PDF'e çevirir.
class OfficeToPdfService {
  const OfficeToPdfService();

  Future<File> convert(
      File file, {
        required GoogleAuthService googleAuth,
        required MicrosoftAuthService microsoftAuth,
      }) async {
    // 1. Önce Microsoft Graph ile dene
    if (microsoftAuth.isSignedIn) {
      try {
        final token = await microsoftAuth.getAccessToken();
        if (token != null) {
          return await MicrosoftGraphService(token).convertOfficeToPdf(file);
        }
      } catch (_) {
        // Microsoft Graph ağ/token hatası verirse uygulamayı patlatma,
        // alttaki Google Drive fallback adımına devret.
      }
    }

    // 2. Microsoft yoksa veya başarısız olduysa Google Drive ile dene
    if (!googleAuth.isSignedIn) {
      final ok = await googleAuth.signIn();
      if (!ok) {
        throw Exception(
          'Office dönüşümü iptal edildi veya oturum açılamadı.',
        );
      }
    }

    return await DriveSyncService(googleAuth).convertOfficeToPdfViaDrive(file);
  }
}
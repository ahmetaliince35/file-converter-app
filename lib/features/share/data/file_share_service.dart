import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;

class QrShareServer {
  HttpServer? _server;

  /// Doğru yerel Wi-Fi IP'sini garantiye alır
  static Future<String?> getLocalIp() async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty && wifiIp != '0.0.0.0') {
        return wifiIp;
      }

      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('wlan') || name.contains('wifi') || name.contains('en0')) {
          for (final addr in interface.addresses) {
            if (!addr.isLoopback && !addr.isLinkLocal) {
              return addr.address;
            }
          }
        }
      }

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('IP tespit hatası: $e');
    }
    return null;
  }

  Future<String> start(File file) async {
    await stop();

    final ip = await getLocalIp();
    if (ip == null) {
      throw Exception('Wi-Fi IP adresi alınamadı. Lütfen Wi-Fi bağlantınızı kontrol edin.');
    }

    // Port 0 vererek sistemden anında boş ve garanti bir port talep ediyoruz (Çakışma önleyici)
    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      8080,
      shared: true,
    ).catchError((_) {
      // 8080 doluysa otomatik serbest bir porta geç
      return HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
    });

    final actualPort = _server!.port;
    final rawFileName = p.basename(file.path);
    final encodedFileName = Uri.encodeComponent(rawFileName);
    final fileLength = await file.length();

    _server!.listen(
          (HttpRequest request) async {
        try {
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          request.response.headers.add('Access-Control-Allow-Methods', 'GET, OPTIONS');
          request.response.headers.add('Access-Control-Allow-Headers', '*');

          if (request.method == 'OPTIONS') {
            request.response.statusCode = HttpStatus.ok;
            await request.response.close();
            return;
          }

          // RFC 5987 standardı: Türkçe ve özel karakterli dosya adlarını tarayıcılarda kusursuz korur
          request.response.headers.set(
            'Content-Disposition',
            'attachment; filename="$rawFileName"; filename*=UTF-8\'\'$encodedFileName',
          );
          request.response.headers.set(
            'Content-Type',
            'application/octet-stream',
          );
          request.response.contentLength = fileLength;

          await request.response.addStream(file.openRead());
        } catch (e) {
          debugPrint('Dosya aktarım hatası (kullanıcı indirmeyi kesmiş olabilir): $e');
        } finally {
          try {
            await request.response.close();
          } catch (_) {}
        }
      },
      onError: (err) {
        debugPrint('Sunucu dinleme hatası: $err');
      },
    );

    return 'http://$ip:$actualPort/download';
  }

  Future<void> stop() async {
    if (_server != null) {
      try {
        await _server!.close(force: true);
      } catch (_) {}
      _server = null;
    }
  }
}
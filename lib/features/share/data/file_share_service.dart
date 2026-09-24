import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;
import 'share_auth_helper.dart';

class ShareResult {
  final String qrUrl;
  final String webUrl;
  final String pin;

  ShareResult({
    required this.qrUrl,
    required this.webUrl,
    required this.pin,
  });
}

class QrShareServer {
  HttpServer? _server;

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

  Future<ShareResult> start(File file) async {
    await stop();

    final ip = await getLocalIp();
    if (ip == null) {
      throw Exception('Wi-Fi IP adresi alınamadı. Lütfen Wi-Fi bağlantınızı kontrol edin.');
    }

    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      8080,
      shared: true,
    ).catchError((_) {
      return HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
    });

    final actualPort = _server!.port;
    final rawFileName = p.basename(file.path);
    final encodedFileName = Uri.encodeComponent(rawFileName);
    final fileLength = await file.length();

    final pin = ShareAuthHelper.generatePin();
    final directToken = ShareAuthHelper.generateDirectToken();

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

          final path = request.uri.path;
          final queryPin = request.uri.queryParameters['pin'];
          final queryToken = request.uri.queryParameters['token'];

          // 1. İndirme İsteği: QR ile gelen token ya da tarayıcıdan girilen PIN kontrol edilir
          if (path == '/download') {
            final isAuthorized = (queryToken == directToken) || (queryPin == pin);
            if (isAuthorized) {
              request.response.headers.set(
                'Content-Disposition',
                'attachment; filename="$rawFileName"; filename*=UTF-8\'\'$encodedFileName',
              );
              request.response.headers.set('Content-Type', 'application/octet-stream');
              request.response.contentLength = fileLength;
              await request.response.addStream(file.openRead());
              return;
            } else {
              request.response.statusCode = HttpStatus.forbidden;
              request.response.headers.set('Content-Type', 'text/plain; charset=utf-8');
              request.response.write('Hatalı PIN kodu veya yetkisiz erişim!');
              return;
            }
          }

          // 2. Kök Dizin: Link açıldığında şifre giriş formu gösterilir
          if (path == '/' || path.isEmpty) {
            request.response.headers.set('Content-Type', 'text/html; charset=utf-8');
            request.response.write(ShareAuthHelper.buildPinHtml(fileName: rawFileName));
            return;
          }

          request.response.statusCode = HttpStatus.notFound;
        } catch (e) {
          debugPrint('Dosya aktarım hatası: $e');
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

    return ShareResult(
      qrUrl: 'http://$ip:$actualPort/download?token=$directToken',
      webUrl: 'http://$ip:$actualPort/',
      pin: pin,
    );
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
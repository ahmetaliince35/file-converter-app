import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;

class QrShareServer {
  HttpServer? _server;
  final int _port = 8080;

  /// Doğru yerel Wi-Fi IP'sini garantiye alır
  static Future<String?> getLocalIp() async {
    try {
      // 1. Öncelik: NetworkInfo eklentisi
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty && wifiIp != '0.0.0.0') {
        return wifiIp;
      }

      // 2. Öncelik: Ağ arayüzlerini filtrele (özellikle wlan0)
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // wlan veya wifi isimli arayüzü öne al
      for (final interface in interfaces) {
        if (interface.name.toLowerCase().contains('wlan') ||
            interface.name.toLowerCase().contains('wifi') ||
            interface.name.toLowerCase().contains('en0')) {
          for (final addr in interface.addresses) {
            if (!addr.isLoopback && !addr.isLinkLocal) {
              return addr.address;
            }
          }
        }
      }

      // Bulunamazsa standart döngü
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

    // shared: true arka plan thread çakışmalarını önler
    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      _port,
      shared: true,
    );

    final fileName = p.basename(file.path);
    final fileLength = await file.length();

    _server!.listen(
          (HttpRequest request) async {
        try {
          // CORS başlıkları ekle (Tarayıcı güvenlik engellerini aşmak için)
          request.response.headers.add('Access-Control-Allow-Origin', '*');
          request.response.headers.add('Access-Control-Allow-Methods', 'GET, OPTIONS');
          request.response.headers.add('Access-Control-Allow-Headers', '*');

          if (request.method == 'OPTIONS') {
            request.response.statusCode = HttpStatus.ok;
            await request.response.close();
            return;
          }

          request.response.headers.set(
            'Content-Disposition',
            'attachment; filename="$fileName"',
          );
          request.response.headers.set(
            'Content-Type',
            'application/octet-stream',
          );
          request.response.contentLength = fileLength;

          await request.response.addStream(file.openRead());
        } catch (e) {
          debugPrint('Dosya akıtılırken hata: $e');
        } finally {
          await request.response.close();
        }
      },
      onError: (err) {
        debugPrint('Sunucu dinleme hatası: $err');
      },
    );

    return 'http://$ip:$_port/download';
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }
}
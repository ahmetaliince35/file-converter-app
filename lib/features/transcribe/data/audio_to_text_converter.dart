import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/files/temp_file_manager.dart';

class AudioToTextConverter {
  static const String keyPrefKey = 'groq_api_key';

  static Future<String?> getSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyPrefKey);
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyPrefKey, key.trim());
  }

  /// Xiaomi'nin 'isom' / 'mp42' video konteyner imzasını saf ses 'M4A ' imzasına çevirir
  static Uint8List _patchM4aHeader(Uint8List originalBytes) {
    if (originalBytes.length < 32) return originalBytes;

    // Kopya bayt dizisi oluştur
    final patched = Uint8List.fromList(originalBytes);

    // ISO Base Media formatında 4..8 arası 'ftyp' olmalıdır
    // 0x66, 0x74, 0x79, 0x70 -> 'ftyp'
    if (patched[4] == 0x66 &&
        patched[5] == 0x74 &&
        patched[6] == 0x79 &&
        patched[7] == 0x70) {
      // 8..12 arasındaki major brand'i zorla 'M4A ' yap (0x4D, 0x34, 0x41, 0x20)
      patched[8] = 0x4D;  // M
      patched[9] = 0x34;  // 4
      patched[10] = 0x41; // A
      patched[11] = 0x20; // boşluk

      // 12..16 minör versiyonu sıfırla
      patched[12] = 0x00;
      patched[13] = 0x00;
      patched[14] = 0x02;
      patched[15] = 0x00;

      // 16..20 uyumlu brand listesinin ilkini de 'M4A ' yap
      if (patched.length >= 20) {
        patched[16] = 0x4D;
        patched[17] = 0x34;
        patched[18] = 0x41;
        patched[19] = 0x20;
      }
      debugPrint('[GROQ_DEBUG] M4A başlığı saf ses (M4A ) olarak yamalandı.');
    }
    return patched;
  }

  static Future<File> convert(File audioFile, {String language = 'tr'}) async {
    final apiKey = await getSavedApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Lütfen önce Groq API anahtarınızı girin.');
    }

    final rawBytes = await audioFile.readAsBytes();
    if (rawBytes.isEmpty) {
      throw Exception('Dosya içeriği boş!');
    }

    final cleanPath = audioFile.path.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    final ext = p.extension(cleanPath).toLowerCase().replaceAll('.', '').trim();

    // Eğer dosya m4a ise veya varsayılan uzantı yoksa başlığı yamala
    Uint8List sendBytes = rawBytes;
    String uploadExt = ext.isEmpty ? 'm4a' : ext;

    if (uploadExt == 'm4a') {
      sendBytes = _patchM4aHeader(rawBytes);
    } else if (uploadExt == 'opus') {
      uploadExt = 'ogg';
    }

    final boundary = '----DartBoundary${DateTime.now().millisecondsSinceEpoch}';
    final uri = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');

    final client = HttpClient();
    final request = await client.postUrl(uri);

    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$boundary',
    );

    // 1. Model
    request.write('--$boundary\r\n');
    request.write('Content-Disposition: form-data; name="model"\r\n\r\n');
    request.write('whisper-large-v3\r\n');

    // 2. Response format
    request.write('--$boundary\r\n');
    request.write('Content-Disposition: form-data; name="response_format"\r\n\r\n');
    request.write('json\r\n');

    // 3. Language
    if (language.isNotEmpty && language != 'auto') {
      request.write('--$boundary\r\n');
      request.write('Content-Disposition: form-data; name="language"\r\n\r\n');
      request.write('$language\r\n');
    }

    // 4. File: Doğrudan saf ses formatı 'audio/mp4' ve 'audio.m4a' olarak gönderilir
    request.write('--$boundary\r\n');
    request.write('Content-Disposition: form-data; name="file"; filename="audio.$uploadExt"\r\n');
    request.write('Content-Type: audio/mp4\r\n\r\n');
    request.add(sendBytes);
    request.write('\r\n');

    request.write('--$boundary--\r\n');

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    debugPrint('[GROQ_DEBUG] Durum Kodu: ${response.statusCode}');
    debugPrint('[GROQ_DEBUG] Yanıt: $responseBody');

    if (response.statusCode != 200) {
      client.close();
      throw Exception('Groq API Hatası (${response.statusCode}): $responseBody');
    }

    client.close();

    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final transcribedText = (data['text'] as String?)?.trim() ?? '';

    final workingDir = await TempFileManager.workingDir;
    final baseName = p.basenameWithoutExtension(cleanPath);
    final outputTxt = File(
      p.join(workingDir.path, '${baseName}_transkript_${DateTime.now().millisecondsSinceEpoch}.txt'),
    );

    await outputTxt.writeAsString(
      transcribedText.isEmpty ? 'Ses dosyasından konuşma algılanamadı.' : transcribedText,
      flush: true,
    );

    return outputTxt;
  }
}
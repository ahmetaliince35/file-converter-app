import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioToTextConverter {
  static const String keyPrefKey = 'deepgram_api_key';

  /// Kayıtlı Deepgram API anahtarını SharedPreferences üzerinden getirir
  static Future<String?> getSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyPrefKey);
  }

  /// Deepgram API anahtarını yerel depolamaya kaydeder
  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyPrefKey, key.trim());
  }

  /// Sesi metne çevirip doğrudan ham metin (String) olarak döner
  /// Düzenlenebilir not defteri / çalışma alanı için bu kullanılır.
  static Future<String> transcribe(File audioFile, {String language = 'tr'}) async {
    final apiKey = await getSavedApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Lütfen önce Deepgram API anahtarınızı girin.');
    }

    if (!await audioFile.exists() || await audioFile.length() == 0) {
      throw Exception('Dosya okunamadı veya içeriği boş!');
    }

    final fileLength = await audioFile.length();

    final queryParams = <String, String>{
      'model': 'nova-2',
      'smart_format': 'true',
      'punctuate': 'true',
    };

    if (language.isNotEmpty && language != 'auto') {
      queryParams['language'] = language;
    } else {
      queryParams['detect_language'] = 'true';
    }

    final uri = Uri.https('api.deepgram.com', '/v1/listen', queryParams);
    debugPrint('[DEEPGRAM_DEBUG] Stream ile gönderiliyor: ${audioFile.path} ($fileLength bayt)');

    final request = http.StreamedRequest('POST', uri);
    request.headers.addAll({
      'Authorization': 'Token $apiKey',
      'Content-Type': 'audio/*',
      'Content-Length': fileLength.toString(),
    });

    // Dosyayı sink'e pipe ediyoruz (Akışın tamamlanmasını garanti eder)
    audioFile.openRead().pipe(request.sink);

    final client = http.Client();
    http.StreamedResponse streamedResponse;

    try {
      // Büyük dosyalarda yükleme ve Deepgram analizi zaman alabileceğinden timeout süresini esnek tutuyoruz
      streamedResponse = await client.send(request).timeout(const Duration(minutes: 5));

      // Gövdeyi (body) client açıkken tamamen tüketiyoruz:
      final responseBody = await streamedResponse.stream.bytesToString();
      debugPrint('[DEEPGRAM_DEBUG] Durum Kodu: ${streamedResponse.statusCode}');

      if (streamedResponse.statusCode != 200) {
        debugPrint('[DEEPGRAM_DEBUG] Hata Yanıtı: $responseBody');
        throw Exception('Deepgram API Hatası (${streamedResponse.statusCode}): $responseBody');
      }

      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final channels = data['results']?['channels'] as List<dynamic>?;
      String transcribedText = '';

      if (channels != null && channels.isNotEmpty) {
        final alternatives = channels[0]['alternatives'] as List<dynamic>?;
        if (alternatives != null && alternatives.isNotEmpty) {
          transcribedText = (alternatives[0]['transcript'] as String?)?.trim() ?? '';
        }
      }

      if (transcribedText.isEmpty) {
        throw Exception('Ses dosyasından herhangi bir konuşma algılanamadı.');
      }

      return transcribedText;
    } finally {
      // client.close() işlemi yanıt gövdesi tamamen okunduktan sonra güvenle çalışır
      client.close();
    }
  }

  /// Sesi metne çevirip doğrudan bir .txt Dosyası (File) olarak kaydeder ve döner
  static Future<File> convert(File audioFile, {String language = 'tr'}) async {
    final transcribedText = await transcribe(audioFile, language: language);

    final tempDir = await getTemporaryDirectory();
    final cleanOriginalPath = audioFile.path.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    final baseName = p.basenameWithoutExtension(cleanOriginalPath);

    final outputTxt = File(
      p.join(tempDir.path, '${baseName.isEmpty ? 'ses' : baseName}_transkript_${DateTime.now().millisecondsSinceEpoch}.txt'),
    );

    await outputTxt.writeAsString(
      transcribedText.isEmpty ? 'Ses dosyasından konuşma algılanamadı.' : transcribedText,
      flush: true,
    );

    return outputTxt;
  }

  /// Deepgram Management API üzerinden kalan dolar miktarını ve tahmini saati sorgular
  /// (API anahtarının "Administrator" rolüne sahip olması gerekir)
  static Future<Map<String, dynamic>?> getRemainingBalance() async {
    final apiKey = await getSavedApiKey();
    if (apiKey == null || apiKey.isEmpty) return null;

    try {
      // 1. Proje ID'sini sorgula
      final projectsUri = Uri.parse('https://api.deepgram.com/v1/projects');
      final projRes = await http.get(
        projectsUri,
        headers: {'Authorization': 'Token $apiKey'},
      ).timeout(const Duration(seconds: 10));

      if (projRes.statusCode != 200) {
        debugPrint('[DEEPGRAM_BALANCE] Proje sorgusu başarısız (Kod: ${projRes.statusCode})');
        return null;
      }

      final projData = jsonDecode(projRes.body) as Map<String, dynamic>;
      final projects = projData['projects'] as List<dynamic>?;
      if (projects == null || projects.isEmpty) return null;

      final projectId = projects[0]['project_id'];

      // 2. Kalan bakiyeyi sorgula
      final balancesUri = Uri.parse('https://api.deepgram.com/v1/projects/$projectId/balances');
      final balRes = await http.get(
        balancesUri,
        headers: {'Authorization': 'Token $apiKey'},
      ).timeout(const Duration(seconds: 10));

      if (balRes.statusCode != 200) {
        debugPrint('[DEEPGRAM_BALANCE] Bakiye sorgusu başarısız (Kod: ${balRes.statusCode})');
        return null;
      }

      final balData = jsonDecode(balRes.body) as Map<String, dynamic>;
      final balances = balData['balances'] as List<dynamic>?;
      if (balances == null || balances.isEmpty) return null;

      double totalAmount = 0.0;
      for (final b in balances) {
        totalAmount += (b['amount'] as num?)?.toDouble() ?? 0.0;
      }

      // Nova-2 saatlik maliyet: ~$0.258
      final estimatedHours = (totalAmount / 0.258).floor();

      return {
        'amount': totalAmount,
        'hours': estimatedHours,
      };
    } catch (e) {
      debugPrint('[DEEPGRAM_BALANCE_ERROR] $e');
      return null;
    }
  }
}
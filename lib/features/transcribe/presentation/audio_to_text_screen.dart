import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../data/audio_to_text_converter.dart';
import '../presentation/widget/api_key_dialog.dart';

/// Ham istisnaları kullanıcıya gösterilebilir açıklayıcı metne çevirir.
String mapErrorMessage(Object error) {
  final text = error.toString().toLowerCase();

  // 1. Ağ ve Bağlantı Hataları
  if (text.contains('socketexception') ||
      text.contains('network') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused')) {
    return 'İnternet bağlantınızı kontrol edin.';
  }

  // 2. Yetkilendirme / Token Hataları
  if (text.contains('unauthorized') ||
      text.contains('401') ||
      text.contains('invalid api key')) {
    return 'Groq API anahtarınız geçersiz veya süresi dolmuş. Lütfen anahtarınızı kontrol edin.';
  }

  // 3. Zaman Aşımı Hataları
  if (text.contains('timeout')) {
    return 'İşlem zaman aşımına uğradı, lütfen tekrar deneyin.';
  }

  // 4. Bellek / Depolama Sınırı Hataları
  if (text.contains('outofmemory') || text.contains('out of memory')) {
    return 'Bellek yetersiz. Lütfen daha küçük bir dosya seçin.';
  }
  if (text.contains('no space left') || text.contains('os error: 28')) {
    return 'Cihazda yeterli depolama alanı kalmadı.';
  }

  // 5. Desteklenmeyen / Bozuk Dosya Formatları ve Xiaomi Uyarıları
  if (text.contains('unsupported_audio_format') ||
      text.contains('could not be decoded') ||
      text.contains('corrupt') ||
      text.contains('formatexception') ||
      text.contains('invalid archive')) {
    return 'Seçilen ses formatı çözülemedi. Lütfen standart bir MP3, WAV veya WhatsApp ses kaydı seçin. (Xiaomi cihazlarda Ses Kaydedici ayarlarından formatı MP3 yapabilirsiniz).';
  }

  // 6. Groq İstek Limiti (Rate Limit)
  if (text.contains('429') || text.contains('rate limit')) {
    return 'API istek limiti aşıldı. Lütfen bir dakika bekleyip tekrar deneyin.';
  }

  // Özel fırlatılan Exception mesajları
  final cleanMessage = error.toString().replaceAll('Exception:', '').trim();
  return cleanMessage.isNotEmpty ? cleanMessage : 'İşlem gerçekleştirilemedi.';
}

class AudioToTextScreen extends StatefulWidget {
  const AudioToTextScreen({super.key});

  @override
  State<AudioToTextScreen> createState() => _AudioToTextScreenState();
}

class _AudioToTextScreenState extends State<AudioToTextScreen> {
  String? _savedApiKey;
  bool _isLoadingKey = true;

  File? _selectedAudioFile;
  bool _isConverting = false;
  String _selectedLanguage = 'tr';

  final Map<String, String> _languages = {
    'tr': 'Türkçe',
    'en': 'İngilizce',
    'de': 'Almanca',
    'fr': 'Fransızca',
    'es': 'İspanyolca',
    'it': 'İtalyanca',
    'ru': 'Rusça',
    'ar': 'Arapça',
    'zh': 'Çince',
    'auto': 'Otomatik Algıla',
  };

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final key = await AudioToTextConverter.getSavedApiKey();
    if (mounted) {
      setState(() {
        _savedApiKey = key;
        _isLoadingKey = false;
      });
    }
  }

  Future<void> _pickAudioFile() async {
    HapticFeedback.lightImpact();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedAudioFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _startConversion() async {
    if (_selectedAudioFile == null) return;

    if (_savedApiKey == null || _savedApiKey!.isEmpty) {
      showApiKeyDialog(context, onSaved: _loadApiKey);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isConverting = true);

    try {
      final txtFile = await AudioToTextConverter.convert(
        _selectedAudioFile!,
        language: _selectedLanguage,
      );

      if (mounted) {
        Navigator.pop(context, txtFile);
      }
    } catch (e, stack) {
      debugPrint('GROQ_HATA: $e');
      debugPrint('GROQ_STACK: $stack');
      if (mounted) {
        setState(() => _isConverting = false);
        final friendlyError = mapErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Tamam',
              textColor: Colors.white,
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ses ➔ Metin Dönüştürücü'),
        actions: [
          IconButton(
            icon: const Icon(Icons.key_rounded),
            tooltip: 'API Anahtarı',
            onPressed: () => showApiKeyDialog(context, onSaved: _loadApiKey),
          ),
        ],
      ),
      body: _isLoadingKey
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildApiKeyCard(theme, colorScheme),
              const SizedBox(height: 20),

              // Dil Seçim Kutusu
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outlineVariant
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.translate_rounded,
                          color: colorScheme.primary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Konuşma Dili:',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLanguage,
                          borderRadius: BorderRadius.circular(12),
                          items: _languages.entries.map((entry) {
                            return DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: _isConverting
                              ? null
                              : (val) {
                            if (val != null) {
                              setState(() =>
                              _selectedLanguage = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Ses Dosyası Seçim Kartı
              GestureDetector(
                onTap: _isConverting ? null : _pickAudioFile,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedAudioFile != null
                          ? colorScheme.primary
                          : colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                      width: _selectedAudioFile != null ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedAudioFile != null
                            ? Icons.audiotrack_rounded
                            : Icons.cloud_upload_outlined,
                        size: 48,
                        color: _selectedAudioFile != null
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedAudioFile != null
                            ? p.basename(_selectedAudioFile!.path)
                            : 'Bir Ses Dosyası Seçin',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedAudioFile != null
                            ? '${(_selectedAudioFile!.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB • Değiştirmek için dokunun'
                            : 'WhatsApp Sesleri (.opus / .ogg), MP3, WAV',
                        style: TextStyle(
                            fontSize: 12, color: colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Bilgilendirme / Format İpucu Kartı
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: colorScheme.outlineVariant
                          .withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'WhatsApp sesleri (.opus/.ogg), MP3 ve WAV formatları doğrudan desteklenir. Dahili ses kaydedici kullanıyorsanız cihaz ayarlarından formatı MP3 olarak seçmeniz önerilir.',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Dönüştür Butonu
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: (_selectedAudioFile == null || _isConverting)
                    ? null
                    : _startConversion,
                icon: _isConverting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
                    : const Icon(Icons.bolt_rounded),
                label: Text(
                  _isConverting
                      ? 'Metne Dönüştürülüyor...'
                      : 'Metne Dönüştür (.TXT)',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApiKeyCard(ThemeData theme, ColorScheme colorScheme) {
    final hasKey = _savedApiKey != null && _savedApiKey!.isNotEmpty;

    if (hasKey) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Colors.teal, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Groq API Anahtarı Tanımlı',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    'Whisper Large-v3 hazır (Ultra hızlı)',
                    style: TextStyle(fontSize: 11, color: colorScheme.outline),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => showApiKeyDialog(context, onSaved: _loadApiKey),
              child: const Text('Değiştir'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.key_rounded, color: Colors.amber, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'API Anahtarı Gerekli',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Saniyeler içinde çeviri için ücretsiz Groq anahtarınızı ekleyin.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => showApiKeyDialog(context, onSaved: _loadApiKey),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }
}
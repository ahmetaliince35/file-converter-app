import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/audio_to_text_converter.dart';
import '../presentation/widget/api_key_dialog.dart';

String mapErrorMessage(Object error) {
  final text = error.toString().toLowerCase();

  if (text.contains('socketexception') ||
      text.contains('network') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused')) {
    return 'İnternet bağlantınızı kontrol edin.';
  }

  if (text.contains('unauthorized') ||
      text.contains('401') ||
      text.contains('invalid credentials') ||
      text.contains('token')) {
    return 'Deepgram API anahtarınız geçersiz. Lütfen anahtarınızı kontrol edin.';
  }

  if (text.contains('timeout')) {
    return 'İşlem zaman aşımına uğradı, lütfen tekrar deneyin.';
  }

  if (text.contains('outofmemory') || text.contains('out of memory')) {
    return 'Bellek yetersiz. Lütfen daha küçük bir ses dosyası seçin.';
  }

  if (text.contains('insufficient') || text.contains('payment_required') || text.contains('402')) {
    return 'Deepgram hesap krediniz tükenmiş görünüyor.';
  }

  if (text.contains('429') || text.contains('rate limit')) {
    return 'İstek limiti aşıldı. Lütfen bir dakika bekleyip tekrar deneyin.';
  }

  final cleanMessage = error.toString().replaceAll('Exception:', '').trim();
  return cleanMessage.isNotEmpty ? cleanMessage : 'İşlem gerçekleştirilemedi.';
}

class AudioToTextScreen extends StatefulWidget {
  final File? initialAudioFile;

  const AudioToTextScreen({super.key, this.initialAudioFile});

  @override
  State<AudioToTextScreen> createState() => _AudioToTextScreenState();
}

class _AudioToTextScreenState extends State<AudioToTextScreen> {
  String? _savedApiKey;
  bool _isLoadingKey = true;

  double? _remainingBalance;
  int? _remainingHours;
  bool _isLoadingBalance = false;

  File? _selectedAudioFile;
  bool _isConverting = false;
  String _selectedLanguage = 'tr';

  late final AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  final TextEditingController _textController = TextEditingController();

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
    if (widget.initialAudioFile != null) {
      _selectedAudioFile = widget.initialAudioFile;
    }
    _loadApiKey();
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() => _duration = newDuration);
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() => _position = newPosition);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final key = await AudioToTextConverter.getSavedApiKey();
    if (mounted) {
      setState(() {
        _savedApiKey = key;
        _isLoadingKey = false;
      });
      if (key != null && key.isNotEmpty) {
        _fetchBalance();
      }
    }
  }

  Future<void> _fetchBalance() async {
    setState(() => _isLoadingBalance = true);
    final balanceInfo = await AudioToTextConverter.getRemainingBalance();
    if (mounted) {
      setState(() {
        _isLoadingBalance = false;
        if (balanceInfo != null) {
          _remainingBalance = balanceInfo['amount'];
          _remainingHours = balanceInfo['hours'];
        }
      });
    }
  }

  Future<void> _pickAudioFile() async {
    HapticFeedback.lightImpact();

    // withData: false yapılarak büyük dosyaların RAM'e yüklenmesi engellenir
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'ogg', 'opus', 'aac', 'mp4', 'flac', 'webm'],
      withData: false,
    );

    if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
      final pickedPath = result.files.single.path!;
      final sourceFile = File(pickedPath);

      // 500 MB boyut sınırı kontrolü (OOM crash önleme)
      final size = await sourceFile.length();
      if (size > 500 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dosya boyutu çok büyük (Maks. 500 MB). Lütfen daha küçük bir kayıt seçin.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }

      final originalExt = p.extension(pickedPath).replaceAll('.', '').trim().toLowerCase();
      final ext = originalExt.isEmpty ? 'mp3' : originalExt;

      final tempDir = await getTemporaryDirectory();
      final safePath = p.join(
        tempDir.path,
        'audio_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );

      final targetFile = await sourceFile.copy(safePath);

      await _audioPlayer.stop();
      setState(() {
        _selectedAudioFile = targetFile;
        _position = Duration.zero;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (_selectedAudioFile == null) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(_selectedAudioFile!.path));
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
      final textResult = await AudioToTextConverter.transcribe(
        _selectedAudioFile!,
        language: _selectedLanguage,
      );

      _fetchBalance();

      if (mounted) {
        setState(() {
          _isConverting = false;
          if (_textController.text.trim().isNotEmpty) {
            _textController.text = '${_textController.text.trim()}\n\n$textResult';
          } else {
            _textController.text = textResult;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ses başarıyla metne çevrildi ve çalışma kağıdına aktarıldı!'),
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('DEEPGRAM_HATA: $e');
      debugPrint('DEEPGRAM_STACK: $stack');
      if (mounted) {
        setState(() => _isConverting = false);
        final friendlyError = mapErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Tamam',
              textColor: Colors.white,
              onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveAsTxtFile() async {
    final content = _textController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedilecek metin bulunamadı.')),
      );
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final outputTxt = File(
        p.join(tempDir.path, 'transkript_${DateTime.now().millisecondsSinceEpoch}.txt'),
      );
      await outputTxt.writeAsString(content, flush: true);

      if (mounted) {
        Navigator.pop(context, outputTxt);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('TXT kaydedilemedi: $e')),
      );
    }
  }

  // Büyük metinlerde bellek patlamasını ve TooManyPagesException crash'ini önleyen PDF üretici
  Future<void> _saveAsPdfFile() async {
    final content = _textController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedilecek metin bulunamadı.')),
      );
      return;
    }

    try {
      final pdf = pw.Document();

      // Türkçe karakterleri (ş, ğ, ı, ö, ç, ü) destekleyen fontları yükle
      final fontRegular = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();

      // Metni çok büyük dosyalarda tek bir paragraph'a vermeyip parça parça ekleyerek RAM'i koru
      final rawParagraphs = content.split('\n');
      final contentWidgets = <pw.Widget>[];

      contentWidgets.add(
        pw.Header(
          level: 0,
          child: pw.Text(
            'Ses Transkript Belgesi',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
        ),
      );
      contentWidgets.add(pw.Divider(thickness: 0.8, color: PdfColors.grey300));
      contentWidgets.add(pw.SizedBox(height: 10));

      // Paragrafları gruplayarak PDF belgesine yerleştir
      for (final pText in rawParagraphs) {
        final trimmed = pText.trim();
        if (trimmed.isEmpty) {
          contentWidgets.add(pw.SizedBox(height: 6));
        } else {
          contentWidgets.add(
            pw.Paragraph(
              text: trimmed,
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 10.5,
                lineSpacing: 2.2,
                color: PdfColors.grey900,
              ),
            ),
          );
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          maxPages: 1000, // Varsayılan 100 sayfa sınırını aşarak crash'i önler
          margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
          theme: pw.ThemeData.withFont(
            base: fontRegular,
            bold: fontBold,
          ),
          header: (ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text('File++ Transkript Stüdyosu', style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey500)),
          ),
          footer: (ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text('Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}', style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey500)),
          ),
          build: (pw.Context context) => contentWidgets,
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final outputPdf = File(
        p.join(tempDir.path, 'transkript_${DateTime.now().millisecondsSinceEpoch}.pdf'),
      );

      await outputPdf.writeAsBytes(await pdf.save());

      if (mounted) {
        Navigator.pop(context, outputPdf);
      }
    } catch (e) {
      debugPrint('[PDF_SAVE_HATA] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF oluşturulamadı: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final wordCount = _textController.text.trim().isEmpty
        ? 0
        : _textController.text.trim().split(RegExp(r'\s+')).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ses Transkript Stüdyosu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'Metni Kopyala',
            onPressed: () {
              if (_textController.text.trim().isNotEmpty) {
                Clipboard.setData(ClipboardData(text: _textController.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Metin panoya kopyalandı!')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.key_rounded, size: 20),
            tooltip: 'API Anahtarı',
            onPressed: () => showApiKeyDialog(context, onSaved: _loadApiKey),
          ),
        ],
      ),
      body: _isLoadingKey
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildApiKeyCard(theme, colorScheme),
              const SizedBox(height: 12),

              _buildAudioControlCard(colorScheme),
              const SizedBox(height: 12),

              // Dil Seçimi ve Metne Ekle Butonu
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedLanguage,
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(12),
                          dropdownColor: colorScheme.surface,
                          items: _languages.entries.map((entry) {
                            return DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value, style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: _isConverting
                              ? null
                              : (val) {
                            if (val != null) {
                              setState(() => _selectedLanguage = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: (_selectedAudioFile == null || _isConverting)
                          ? null
                          : _startConversion,
                      icon: _isConverting
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : const Icon(Icons.add_task_rounded, size: 18),
                      label: Text(
                        _isConverting ? 'Çözülüyor...' : 'Metne Ekle',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // TEMADAN BAĞIMSIZ SAF BEYAZ STÜDYO ÇALIŞMA ALANI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Transkript Not Defteri',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$wordCount kelime',
                          style: TextStyle(fontSize: 10, color: colorScheme.outline, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (_textController.text.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      onPressed: () => setState(() => _textController.clear()),
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                      label: const Text('Temizle', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // TEMADAN TAMAMEN BAĞIMSIZ BEYAZ KAĞIT DOKUSU
              Container(
                height: 320,
                decoration: BoxDecoration(
                  color: Colors.white, // Temadan bağımsız saf beyaz zemin
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  cursorColor: const Color(0xFF1E1E1E),
                  keyboardType: TextInputType.multiline,
                  // Yazı rengi temadan bağımsız net siyah
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF1E1E1E),
                    height: 1.5,
                    fontFamily: 'sans-serif',
                  ),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Çözümlenen ses metinleri bu alana aktarılır. Burayı dilediğiniz gibi düzenleyebilir, yeni sesler ekleyerek metinleri birleştirebilirsiniz...',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // İKİLİ DIŞA AKTARMA BUTONLARI (TXT & PDF)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _textController.text.trim().isEmpty ? null : _saveAsTxtFile,
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text(
                        'TXT Olarak Kaydet',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _textController.text.trim().isEmpty ? null : _saveAsPdfFile,
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: const Text(
                        'PDF Olarak Kaydet',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioControlCard(ColorScheme colorScheme) {
    final hasAudio = _selectedAudioFile != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasAudio ? colorScheme.primary.withValues(alpha: 0.4) : colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                  foregroundColor: colorScheme.primary,
                ),
                icon: Icon(hasAudio && _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                onPressed: hasAudio ? _togglePlayPause : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasAudio ? p.basename(_selectedAudioFile!.path) : 'Henüz ses seçilmedi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      hasAudio
                          ? '${(_selectedAudioFile!.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB • Dinlemek için oynatın'
                          : 'MP3, WAV, M4A, AAC, OGG (Maks. 500 MB)',
                      style: TextStyle(fontSize: 11, color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _isConverting ? null : _pickAudioFile,
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                label: Text(hasAudio ? 'Değiştir' : 'Ses Seç', style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (hasAudio && _duration > Duration.zero) ...[
            const SizedBox(height: 6),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                trackHeight: 2.5,
                activeTrackColor: colorScheme.primary,
                thumbColor: colorScheme.primary,
              ),
              child: Slider(
                min: 0,
                max: _duration.inMilliseconds.toDouble(),
                value: _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble(),
                onChanged: (val) async {
                  await _audioPlayer.seek(Duration(milliseconds: val.toInt()));
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApiKeyCard(ThemeData theme, ColorScheme colorScheme) {
    final hasKey = _savedApiKey != null && _savedApiKey!.isNotEmpty;

    if (hasKey) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Deepgram Nova-2 Hazır',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  if (_isLoadingBalance)
                    Text('Bakiye sorgulanıyor...', style: TextStyle(fontSize: 10.5, color: colorScheme.outline))
                  else if (_remainingBalance != null)
                    Text(
                      'Kalan Kredi: \$${_remainingBalance!.toStringAsFixed(2)} (~$_remainingHours saat)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                    )
                  else
                    Text(
                      'Tüm ses formatları destekleniyor',
                      style: TextStyle(fontSize: 10.5, color: colorScheme.outline),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: 'Yenile',
              onPressed: _fetchBalance,
            ),
            TextButton(
              onPressed: () => showApiKeyDialog(context, onSaved: _loadApiKey),
              child: const Text('Değiştir', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFD97706).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.key_rounded, color: Color(0xFFD97706), size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Deepgram API Anahtarı Gerekli (~750 saat ücretsiz)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          ElevatedButton(
            onPressed: () => showApiKeyDialog(context, onSaved: _loadApiKey),
            child: const Text('Ekle', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
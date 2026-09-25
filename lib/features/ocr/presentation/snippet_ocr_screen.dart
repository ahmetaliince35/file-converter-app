import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../../core/files/temp_file_manager.dart';

class SnippetOcrScreen extends StatefulWidget {
  const SnippetOcrScreen({super.key});

  @override
  State<SnippetOcrScreen> createState() => _SnippetOcrScreenState();
}

class _SnippetOcrScreenState extends State<SnippetOcrScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textController = TextEditingController();
  final TransformationController _transformController = TransformationController();

  File? _imageFile;
  ui.Image? _decodedUiImage;

  // Seçim kutusu durumları (Görsel alanı içinde bağıl konum)
  double _boxX = 50.0;
  double _boxY = 100.0;
  double _boxW = 200.0;
  double _boxH = 80.0;

  bool _isReading = false;
  final GlobalKey _viewportKey = GlobalKey();

  @override
  void dispose() {
    _textController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    HapticFeedback.lightImpact();
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return;

    final file = File(picked.path);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    setState(() {
      _imageFile = file;
      _decodedUiImage = frame.image;
      _boxX = 60.0;
      _boxY = 120.0;
      _boxW = 220.0;
      _boxH = 90.0;
      _textController.clear();
      _transformController.value = Matrix4.identity();
    });
  }

  // Kutunun içindeki kısmı kırpıp ML Kit'e verme
  Future<void> _processSelectedArea() async {
    if (_imageFile == null || _decodedUiImage == null) return;

    final renderBox = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final viewportSize = renderBox.size;
    final originalW = _decodedUiImage!.width;
    final originalH = _decodedUiImage!.height;

    // Mevcut zoom ve kaydırma matrisi
    final matrix = _transformController.value;
    final double zoom = matrix.getMaxScaleOnAxis();
    final double transX = matrix.storage[12];
    final double transY = matrix.storage[13];

    // Resmin viewport içindeki temel contain ölçeği
    final double baseScaleX = viewportSize.width / originalW;
    final double baseScaleY = viewportSize.height / originalH;
    final double baseScale = baseScaleX < baseScaleY ? baseScaleX : baseScaleY;

    final double renderedBaseW = originalW * baseScale;
    final double renderedBaseH = originalH * baseScale;
    final double baseOffsetX = (viewportSize.width - renderedBaseW) / 2;
    final double baseOffsetY = (viewportSize.height - renderedBaseH) / 2;

    // Ekrandaki kutunun orijinal piksel koordinatlarına dönüşümü
    final double screenBoxLeft = _boxX;
    final double screenBoxTop = _boxY;

    final double relativeLeft = (screenBoxLeft - transX - baseOffsetX * zoom) / (baseScale * zoom);
    final double relativeTop = (screenBoxTop - transY - baseOffsetY * zoom) / (baseScale * zoom);
    final double relativeW = _boxW / (baseScale * zoom);
    final double relativeH = _boxH / (baseScale * zoom);

    final int cropX = relativeLeft.clamp(0.0, originalW.toDouble() - 10).toInt();
    final int cropY = relativeTop.clamp(0.0, originalH.toDouble() - 10).toInt();
    final int cropW = relativeW.clamp(10.0, (originalW - cropX).toDouble()).toInt();
    final int cropH = relativeH.clamp(10.0, (originalH - cropY).toDouble()).toInt();

    setState(() => _isReading = true);
    HapticFeedback.mediumImpact();

    try {
      final rawBytes = await _imageFile!.readAsBytes();
      final decoded = img.decodeImage(rawBytes);

      if (decoded != null) {
        final cropped = img.copyCrop(
          decoded,
          x: cropX,
          y: cropY,
          width: cropW,
          height: cropH,
        );

        final workingDir = await TempFileManager.workingDir;
        final snippetFile = File(p.join(workingDir.path, 'ocr_crop_${DateTime.now().millisecondsSinceEpoch}.jpg'));
        await snippetFile.writeAsBytes(img.encodeJpg(cropped, quality: 95));

        final inputImage = InputImage.fromFile(snippetFile);
        final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
        final recognized = await recognizer.processImage(inputImage);
        await recognizer.close();

        await TempFileManager.deleteFile(snippetFile);

        setState(() {
          _textController.text = recognized.text.trim();
        });

        if (recognized.text.trim().isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seçili alanda yazı tespit edilemedi. Kutuyu ayarlayıp tekrar deneyin.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Okuma hatası: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    } finally {
      if (mounted) setState(() => _isReading = false);
    }
  }

  void _copyToClipboard() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Metin kopyalandı!'),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveAsTxt() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final workingDir = await TempFileManager.workingDir;
    final file = File(p.join(workingDir.path, 'OCR_Secim_${DateTime.now().millisecondsSinceEpoch}.txt'));
    await file.writeAsString(text);

    if (mounted) {
      Navigator.pop(context, file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bölgesel Metin Çıkar (OCR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          if (_imageFile != null)
            IconButton(
              tooltip: 'Görseli Sıfırla',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _transformController.value = Matrix4.identity(),
            ),
          if (_imageFile != null)
            IconButton(
              tooltip: 'Farklı Görsel Seç',
              icon: const Icon(Icons.add_photo_alternate_rounded),
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
        ],
      ),
      body: _imageFile == null ? _buildEmptyPicker(colorScheme) : _buildActiveWorkspace(colorScheme),
    );
  }

  Widget _buildEmptyPicker(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.crop_free_rounded, size: 40, color: Colors.teal),
            ),
            const SizedBox(height: 18),
            const Text('Fotoğrafı Büyüt ve Alanı Seç', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 8),
            Text(
              'Görseli iki parmağınızla serbestçe büyütün,\nkutuyu istediğiniz yazının üstüne getirip okutun.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: colorScheme.outline, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Kamera'),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Galeri'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveWorkspace(ColorScheme colorScheme) {
    return Column(
      children: [
        // Bilgi ve Yakınlaştırma İpucu
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          child: const Row(
            children: [
              Icon(Icons.pinch_rounded, size: 16, color: Colors.teal),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'İki parmakla resmi yakınlaştırıp kaydırabilirsiniz. Kutuyu sürükleyip boyutlandırın.',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),

        // ÜST ALAN: Zoomlanabilir Resim + Üzerinde Taşınabilir Kutu
        Expanded(
          flex: 5,
          child: ClipRect(
            key: _viewportKey,
            child: Container(
              color: Colors.black87,
              child: Stack(
                children: [
                  // 1. İki parmakla serbestçe büyütülebilen resim
                  InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 1.0,
                    maxScale: 6.0,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    child: Center(
                      child: Image.file(_imageFile!, fit: BoxFit.contain),
                    ),
                  ),

                  // 2. Taşınabilir ve Boyutlandırılabilir Seçim Kutusu
                  Positioned(
                    left: _boxX,
                    top: _boxY,
                    width: _boxW,
                    height: _boxH,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.cyanAccent, width: 2.2),
                        color: Colors.cyanAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Stack(
                        children: [
                          // Gövdeden tutunca tüm kutuyu taşıma
                          GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanUpdate: (details) {
                              setState(() {
                                _boxX += details.delta.dx;
                                _boxY += details.delta.dy;
                              });
                            },
                            child: const Center(
                              child: Icon(Icons.drag_indicator_rounded, color: Colors.white70, size: 20),
                            ),
                          ),

                          // Sağ alt köşeden tutunca kutuyu büyütme / küçültme
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  _boxW = (_boxW + details.delta.dx).clamp(60.0, 360.0);
                                  _boxH = (_boxH + details.delta.dy).clamp(35.0, 300.0);
                                });
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: Colors.cyanAccent,
                                  borderRadius: BorderRadius.only(topLeft: Radius.circular(8)),
                                ),
                                child: const Icon(Icons.aspect_ratio_rounded, size: 16, color: Colors.black87),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // "Bu Alanı Oku" Aksiyon Butonu
                  Positioned(
                    bottom: 14,
                    right: 14,
                    child: FloatingActionButton.extended(
                      heroTag: 'ocr_action_btn',
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      onPressed: _isReading ? null : _processSelectedArea,
                      icon: _isReading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : const Icon(Icons.document_scanner_rounded),
                      label: Text(_isReading ? 'Okunuyor...' : 'Alanı Oku', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),        // ALT ALAN: Okunan Metin Düzenleyici
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Okunan Metin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colorScheme.primary)),
                    if (_textController.text.isNotEmpty)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Temizle',
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() => _textController.clear()),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: TextField(
                      controller: _textController,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(fontSize: 13.5, height: 1.4),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Kutuyu yazının üzerine getirip "Alanı Oku" butonuna basın...',
                        hintStyle: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _textController.text.trim().isEmpty ? null : _copyToClipboard,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Kopyala'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _textController.text.trim().isEmpty ? null : _saveAsTxt,
                        icon: const Icon(Icons.save_as_rounded, size: 18),
                        label: const Text('TXT Kaydet'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_cropper/image_cropper.dart';

class SnippetOcrService {
  /// Kullanıcıya dikdörtgen seçim aracı açar ve kırpılan dosyayı döner
  static Future<File?> cropSelectedArea(File sourceFile) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourceFile.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Metin Alanını Seçin',
          toolbarColor: const Color(0xFF00796B),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF00796B),
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false, // Serbest dikdörtgen seçimi
        ),
        IOSUiSettings(
          title: 'Metin Alanını Seçin',
          aspectRatioLockEnabled: false,
        ),
      ],
    );

    if (cropped == null) return null;
    return File(cropped.path);
  }

  /// Kırpılan görsel parçasındaki metinleri ML Kit ile okur
  static Future<String> extractText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    // Latin script Türkçe karakterleri (ç, ğ, ı, ö, ş, ü) tam destekler
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognized = await recognizer.processImage(inputImage);
      return recognized.text.trim();
    } finally {
      await recognizer.close();
    }
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/app_providers.dart';
import 'core/files/temp_file_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Açılışı geciktirmeden ve çökme riski olmadan arka planda süpür:
  unawaited(
    TempFileManager.clearAll().catchError((error) {
      debugPrint('Açılış önbellek temizleme hatası: $error');
    }),
  );

  runApp(
    MultiProvider(
      providers: buildAppProviders(),
      child: const FileConverterApp(),
    ),
  );
}
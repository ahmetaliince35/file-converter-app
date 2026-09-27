import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/navigation/app_navigator.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_view_model.dart';
import '../features/auth/presentation/widgets/auth_gate.dart';

class FileConverterApp extends StatelessWidget {
  const FileConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeViewModel>();
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Dosya Dönüştürücü',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: theme.themeMode,
      home: const AuthGate(),
    );
  }
}

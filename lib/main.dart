import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/GoogleAuthService.dart';
import '/home-screen.dart';
import '/login-screen.dart';

void main() {
  runApp(const DosyaConverterApp());
}

class DosyaConverterApp extends StatelessWidget {
  const DosyaConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GoogleAuthService(),
      child: MaterialApp(
        title: 'Dosya Converter',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        home: const _RootRouter(),
      ),
    );
  }
}

/// Giriş yapılmasa da uygulama kullanılabilir (offline dönüştürme login
/// gerektirmez). Login sadece Drive senkronu için gereklidir.
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
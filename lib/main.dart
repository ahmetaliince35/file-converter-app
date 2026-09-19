import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/GoogleAuthService.dart';
import 'services/microsoft_auth_service.dart';
import 'Scenes/login-screen.dart';
import 'Scenes/home-screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GoogleAuthService()),
        ChangeNotifierProvider(create: (_) => MicrosoftAuthService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey, // Microsoft oturum açma penceresi için zorunludur
      debugShowCheckedModeBanner: false,
      title: 'Dosya Converter',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final googleAuth = context.watch<GoogleAuthService>();
    final msAuth = context.watch<MicrosoftAuthService>();

    final isSignedIn = googleAuth.isSignedIn || msAuth.isSignedIn;
    return isSignedIn ? const HomeScreen() : const LoginScreen();
  }
}
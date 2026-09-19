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
      navigatorKey: appNavigatorKey,
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

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // İlk render bittikten hemen sonra arka planda oturumları kontrol et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoogleAuthService>().initSilently();
      context.read<MicrosoftAuthService>().initSilently();
    });
  }

  @override
  Widget build(BuildContext context) {
    final googleAuth = context.watch<GoogleAuthService>();
    final msAuth = context.watch<MicrosoftAuthService>();

    // İki servis de henüz cihazdaki token'ları okumadıysa hafif bir splash göster
    if (googleAuth.isChecking && msAuth.isChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.description_outlined, size: 64, color: Colors.indigo),
              SizedBox(height: 16),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    final isSignedIn = googleAuth.isSignedIn || msAuth.isSignedIn;
    return isSignedIn ? const HomeScreen() : const LoginScreen();
  }
}
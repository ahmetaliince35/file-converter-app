import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../GoogleAuthService.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<GoogleAuthService>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_sync, size: 48, color: Colors.indigo),
          const SizedBox(height: 12),
          const Text(
            'Drive senkronu için Google hesabınızla giriş yapın.\n'
                'Not: Dönüştürme işlemleri giriş yapmadan da çalışır.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (auth.isSignedIn)
            Column(
              children: [
                Text('Giriş yapıldı: ${auth.currentUser?.email ?? ''}'),
                TextButton(
                  onPressed: () => auth.signOut(),
                  child: const Text('Çıkış Yap'),
                ),
              ],
            )
          else
            ElevatedButton.icon(
              onPressed: () => auth.signIn(),
              icon: const Icon(Icons.login),
              label: const Text('Google ile Giriş Yap'),
            ),
        ],
      ),
    );
  }
}
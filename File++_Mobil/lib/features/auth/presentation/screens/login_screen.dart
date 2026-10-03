import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/google_auth_service.dart';
import '../../data/microsoft_auth_service.dart';
import '../view_models/auth_view_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      final auth = context.read<GoogleAuthService>();
      final success = await auth.signIn();
      if (!mounted) return;

      if (success) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google girişi başarısız oldu veya iptal edildi.'),
            backgroundColor: Color(0xFFC46B6B),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleMicrosoftSignIn() async {
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      final msAuth = context.read<MicrosoftAuthService>();
      final success = await msAuth.signIn();
      if (!mounted) return;

      if (success) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microsoft girişi başarısız oldu veya iptal edildi.'),
            backgroundColor: Color(0xFFC46B6B),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGuestEntry() async {
    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    try {
      await context.read<AuthViewModel>().continueAsGuest();
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final googleAuth = context.watch<GoogleAuthService>();
    final msAuth = context.watch<MicrosoftAuthService>();
    final canGoBack = Navigator.canPop(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: canGoBack
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: colorScheme.onSurface, size: 20),
                tooltip: 'Geri Dön',
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: Stack(
        children: [
          // Arka Plan Hafif Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF090D16),
                          const Color(0xFF111827),
                          const Color(0xFF090D16),
                        ]
                      : [
                          const Color(0xFFF1F5F9),
                          const Color(0xFFFFFFFF),
                          const Color(0xFFEEF2FF),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Uygulama Logo & İkon
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colorScheme.primary, colorScheme.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Başlık ve Açıklama
                    Text(
                      'File++ Stüdyo',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        fontSize: 27,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Word, Excel, PDF, OCR ve ses dönüştürme araçları tek bir güçlü merkezde.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: colorScheme.outline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Özellik Rozetleri
                    const Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FeatureChip(icon: Icons.article_rounded, label: 'Office ➔ PDF', color: Color(0xFF4A7C9F)),
                        _FeatureChip(icon: Icons.document_scanner_rounded, label: 'Akıllı OCR', color: Color(0xFF5A7BA6)),
                        _FeatureChip(icon: Icons.graphic_eq_rounded, label: 'Nova-2 AI Ses', color: Color(0xFFC88A3A)),
                        _FeatureChip(icon: Icons.qr_code_rounded, label: 'Dosya Paylaşım', color: Color(0xFF4E8772)),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Bağlı Hesap Bilgisi (Varsa)
                    if (googleAuth.isSignedIn || msAuth.isSignedIn) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: (msAuth.isSignedIn ? const Color(0xFF4A7C9F) : const Color(0xFF4E8772))
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                msAuth.isSignedIn ? Icons.window_rounded : Icons.check_circle_rounded,
                                color: msAuth.isSignedIn ? const Color(0xFF4A7C9F) : const Color(0xFF4E8772),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msAuth.isSignedIn ? 'Microsoft Hesabı Bağlı' : 'Google Hesabı Bağlı',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                  ),
                                  Text(
                                    msAuth.isSignedIn
                                        ? (msAuth.userEmail ?? 'Office Cloud & OneDrive')
                                        : (googleAuth.currentUser?.email ?? 'Google Drive'),
                                    style: TextStyle(fontSize: 11, color: colorScheme.outline),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await context.read<AuthViewModel>().completeSignOut();
                              },
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: const Text('Çıkış', style: TextStyle(color: Color(0xFFC46B6B), fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Giriş Aksiyonları
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else ...[
                      // 1. Google Girişi
                      FilledButton(
                        onPressed: _handleGoogleSignIn,
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                          elevation: 1,
                          side: BorderSide(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Google ile Giriş Yap',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. Microsoft Girişi
                      FilledButton(
                        onPressed: _handleMicrosoftSignIn,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4A7C9F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.window_rounded, size: 19),
                            SizedBox(width: 12),
                            Text(
                              'Microsoft ile Giriş Yap (Office Cloud)',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(child: Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.4))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'veya',
                              style: TextStyle(
                                color: colorScheme.outline,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: colorScheme.outlineVariant.withValues(alpha: 0.4))),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 3. Misafir Girişi
                      OutlinedButton.icon(
                        onPressed: _handleGuestEntry,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: Icon(Icons.person_outline_rounded, size: 18, color: colorScheme.outline),
                        label: Text(
                          'Giriş Yapmadan Misafir Olarak Devam Et',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),

                      if (canGoBack) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded, size: 15),
                          label: const Text('Ana Ekrana Dön', style: TextStyle(fontSize: 12.5)),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
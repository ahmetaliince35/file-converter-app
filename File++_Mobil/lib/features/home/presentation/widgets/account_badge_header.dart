import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/data/google_auth_service.dart';
import '../../../auth/data/microsoft_auth_service.dart';

import '../../../auth/presentation/screens/login_screen.dart';

class AccountBadgeHeader extends StatelessWidget {
  const AccountBadgeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final googleAuth = context.watch<GoogleAuthService>();
    final msAuth = context.watch<MicrosoftAuthService>();

    final isMs = msAuth.isSignedIn;
    final isGoogle = googleAuth.isSignedIn;
    final isLinked = isMs || isGoogle;

    final String title;
    final String subtitle;
    final Color badgeColor;
    final IconData badgeIcon;

    if (isMs) {
      title = 'Microsoft 365 Aktif';
      subtitle = 'Office Cloud & OneDrive Hazır';
      badgeColor = const Color(0xFF4A7C9F);
      badgeIcon = Icons.window_rounded;
    } else if (isGoogle) {
      title = googleAuth.currentUser?.displayName ?? googleAuth.currentUser?.email ?? 'Google Hesabı';
      subtitle = 'Google Drive Senkronizasyonu';
      badgeColor = const Color(0xFF5B8E7D);
      badgeIcon = Icons.cloud_done_rounded;
    } else {
      title = 'Misafir Modu';
      subtitle = 'Giriş yaparak Drive & Office kullanın';
      badgeColor = colorScheme.outline;
      badgeIcon = Icons.offline_bolt_outlined;
    }

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(badgeIcon, size: 17, color: badgeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isLinked ? const Color(0xFF5B8E7D) : const Color(0xFFC88A3A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isLinked
                      ? badgeColor.withValues(alpha: 0.1)
                      : colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isLinked ? 'SENKRONİZE' : 'GİRİŞ YAP',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isLinked ? badgeColor : colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

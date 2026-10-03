import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuickActionsSection extends StatelessWidget {
  final VoidCallback onAudioToText;
  final VoidCallback onQrSend;
  final bool isBusy;

  const QuickActionsSection({
    super.key,
    required this.onAudioToText,
    required this.onQrSend,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HeroActionCard(
            title: 'Ses ➔ Metin',
            subtitle: 'AI Transkripsiyon',
            tag: 'Nova-2',
            icon: Icons.graphic_eq_rounded,
            accentColor: const Color(0xFFD97706),
            isDisabled: isBusy,
            onTap: () {
              HapticFeedback.lightImpact();
              onAudioToText();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HeroActionCard(
            title: 'PC Paylaş',
            subtitle: 'Wi-Fi / QR Aktarım',
            tag: 'Kablosuz',
            icon: Icons.qr_code_2_rounded,
            accentColor: const Color(0xFF6366F1),
            isDisabled: isBusy,
            onTap: () {
              HapticFeedback.lightImpact();
              onQrSend();
            },
          ),
        ),
      ],
    );
  }
}

class _HeroActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final bool isDisabled;

  const _HeroActionCard({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        splashColor: accentColor.withValues(alpha: 0.1),
        highlightColor: accentColor.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

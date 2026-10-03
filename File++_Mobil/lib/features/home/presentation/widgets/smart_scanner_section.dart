import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SmartScannerSection extends StatelessWidget {
  final VoidCallback onScanDoc;
  final VoidCallback onSnippetOcr;
  final bool isBusy;

  const SmartScannerSection({
    super.key,
    required this.onScanDoc,
    required this.onSnippetOcr,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.document_scanner_rounded,
                  size: 14,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Akıllı Tarama & Metin Çıkarma (OCR)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.2),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Expanded(
                child: _ToolTile(
                  title: 'Belge Tara',
                  subtitle: 'Kamera ➔ A4 PDF yap',
                  icon: Icons.document_scanner_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  isDisabled: isBusy,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onScanDoc();
                  },
                ),
              ),
              Container(
                width: 1,
                height: 48,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _ToolTile(
                  title: 'Metin Çıkar (OCR)',
                  subtitle: 'Kutudan yazı kopyala',
                  icon: Icons.crop_free_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  isDisabled: isBusy,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onSnippetOcr();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isDisabled;

  const _ToolTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: isDisabled ? null : onTap,
      splashColor: iconColor.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: colorScheme.outline,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

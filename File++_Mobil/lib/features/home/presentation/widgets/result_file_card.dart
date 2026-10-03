import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/processed_file_item.dart';

class ResultFileCard extends StatelessWidget {
  final ProcessedFileItem item;
  final VoidCallback onPreview;
  final VoidCallback onShare;
  final VoidCallback onQrShare;
  final VoidCallback onBackupDrive;
  final VoidCallback onDelete;
  final bool isBusy;

  const ResultFileCard({
    super.key,
    required this.item,
    required this.onPreview,
    required this.onShare,
    required this.onQrShare,
    required this.onBackupDrive,
    required this.onDelete,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = item.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isBusy ? null : onPreview,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Dosya Tipi İkon Rozeti
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.typeLabel,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.formattedSize,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Önizleme Göstergesi
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 8),

                // Aksiyon Düğmeleri
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ActionButton(
                      icon: Icons.share_rounded,
                      label: 'Paylaş',
                      color: const Color(0xFF3B82F6),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onShare();
                      },
                    ),
                    _ActionButton(
                      icon: Icons.qr_code_rounded,
                      label: 'QR Aktar',
                      color: const Color(0xFF6366F1),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onQrShare();
                      },
                    ),
                    _ActionButton(
                      icon: Icons.cloud_upload_outlined,
                      label: 'Drive',
                      color: const Color(0xFF4F46E5),
                      isDisabled: isBusy,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onBackupDrive();
                      },
                    ),
                    _ActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'Sil',
                      color: const Color(0xFFEF4444),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        onDelete();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isDisabled;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: isDisabled ? null : onTap,
      splashColor: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

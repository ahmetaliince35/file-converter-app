import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ResultFilesHeader extends StatelessWidget {
  final int count;
  final VoidCallback onClearAll;
  final VoidCallback onBackupAll;
  final VoidCallback onShareAll;
  final ValueChanged<String>? onSearchChanged;
  final String searchQuery;
  final bool isBusy;

  const ResultFilesHeader({
    super.key,
    required this.count,
    required this.onClearAll,
    required this.onBackupAll,
    required this.onShareAll,
    this.onSearchChanged,
    this.searchQuery = '',
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.task_alt_rounded,
                      size: 14,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Hazır Dosyalar ($count)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Temizle Butonu
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Tümünü Temizle',
                icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                color: Colors.red.shade400,
                onPressed: isBusy ? null : () => _showClearDialog(context),
              ),
              const SizedBox(width: 4),
              // Drive Yedekle
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.cloud_upload_outlined, size: 15),
                label: const Text('Yedekle', style: TextStyle(fontSize: 11.5)),
                onPressed: isBusy ? null : onBackupAll,
              ),
              const SizedBox(width: 6),
              // Paylaş
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                tooltip: 'Tümünü Paylaş',
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.share_rounded, size: 16),
                onPressed: isBusy ? null : onShareAll,
              ),
            ],
          ),
          if (count > 2 && onSearchChanged != null) ...[
            const SizedBox(height: 10),
            TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Dosyalarda ara...',
                hintStyle: TextStyle(fontSize: 12.5, color: colorScheme.outline),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () => onSearchChanged!(''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                isDense: true,
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tümünü Temizle'),
        content: const Text(
          'Oluşturulan tüm geçici sonuç dosyaları silinecektir. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () {
              Navigator.pop(ctx);
              onClearAll();
            },
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }
}

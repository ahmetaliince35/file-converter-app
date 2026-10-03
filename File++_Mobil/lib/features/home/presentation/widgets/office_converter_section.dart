import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OfficeConverterSection extends StatelessWidget {
  final VoidCallback onWordTap;
  final VoidCallback onExcelTap;
  final VoidCallback onPowerPointTap;
  final bool isBusy;

  const OfficeConverterSection({
    super.key,
    required this.onWordTap,
    required this.onExcelTap,
    required this.onPowerPointTap,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                  color: const Color(0xFF185ABD).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  size: 14,
                  color: Color(0xFF185ABD),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Office Belgeleri ➔ PDF',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.2),
              ),
              const Spacer(),
              Text(
                'Bulut Motoru',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.outline,
                ),
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
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: _OfficeCard(
                  title: 'Word',
                  ext: '.docx / .doc',
                  icon: Icons.article_rounded,
                  brandColor: const Color(0xFF185ABD),
                  isDisabled: isBusy,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onWordTap();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OfficeCard(
                  title: 'Excel',
                  ext: '.xlsx / .xls',
                  icon: Icons.table_chart_rounded,
                  brandColor: const Color(0xFF107C41),
                  isDisabled: isBusy,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onExcelTap();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OfficeCard(
                  title: 'PowerPoint',
                  ext: '.pptx / .ppt',
                  icon: Icons.slideshow_rounded,
                  brandColor: const Color(0xFFC43E1C),
                  isDisabled: isBusy,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onPowerPointTap();
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

class _OfficeCard extends StatelessWidget {
  final String title;
  final String ext;
  final IconData icon;
  final Color brandColor;
  final VoidCallback onTap;
  final bool isDisabled;

  const _OfficeCard({
    required this.title,
    required this.ext,
    required this.icon,
    required this.brandColor,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: brandColor.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        splashColor: brandColor.withValues(alpha: 0.16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: brandColor.withValues(alpha: 0.22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: brandColor, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: brandColor,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                ext,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
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

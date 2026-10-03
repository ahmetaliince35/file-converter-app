import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UniversalConverterSection extends StatelessWidget {
  final VoidCallback onConvertToPdf;
  final VoidCallback onConvertToTxt;
  final VoidCallback onOpenStudio;
  final bool isBusy;

  const UniversalConverterSection({
    super.key,
    required this.onConvertToPdf,
    required this.onConvertToTxt,
    required this.onOpenStudio,
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
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.transform_rounded,
                  size: 14,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Evrensel Dönüştürücü (Belgeler & Kodlar ➔ PDF / TXT)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: -0.2),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '35+ Format',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Büyük Kart
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Açıklama & Stüdyo Butonu
              InkWell(
                onTap: isBusy ? null : onOpenStudio,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.sync_alt_rounded, color: colorScheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Belge ve Kodları PDF veya TXT Yapın',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Word, Excel, PowerPoint, Kodlar, Veri Dosyaları, TXT ve ZIP',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10.5, color: colorScheme.outline),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Stüdyo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: colorScheme.primary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),

              // Hızlı Aksiyon Butonları (➔ PDF & ➔ TXT)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickConvertPill(
                        icon: Icons.picture_as_pdf_rounded,
                        label: '➔ PDF Olarak Dönüştür',
                        subLabel: 'Belge, ofis, kod veya arşiv',
                        color: const Color(0xFFDC2626),
                        isDisabled: isBusy,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onConvertToPdf();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickConvertPill(
                        icon: Icons.description_rounded,
                        label: '➔ TXT Olarak Ayıkla',
                        subLabel: 'DOCX, XLSX, kod, veri metni',
                        color: const Color(0xFFD97706),
                        isDisabled: isBusy,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onConvertToTxt();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickConvertPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subLabel;
  final Color color;
  final VoidCallback onTap;
  final bool isDisabled;

  const _QuickConvertPill({
    required this.icon,
    required this.label,
    required this.subLabel,
    required this.color,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: color.withValues(alpha: 0.16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/theme_view_model.dart';
import '../../../auth/presentation/view_models/auth_view_model.dart';
import '../../../transcribe/presentation/widget/api_key_dialog.dart';

class HomeAppBar extends StatelessWidget {
  const HomeAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeVm = context.watch<ThemeViewModel>();

    return SliverAppBar(
      floating: true,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
      toolbarHeight: 68,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.folder_copy_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'File++ Stüdyo',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  fontSize: 18,
                ),
              ),
              Text(
                'Dosya ve Belge Merkezi',
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
      actions: [
        // Tema Değiştirici
        IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          tooltip: themeVm.isDark ? 'Açık Tema' : 'Koyu Tema',
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              themeVm.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey(themeVm.isDark),
              size: 20,
              color: themeVm.isDark ? Colors.amber.shade400 : colorScheme.primary,
            ),
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            themeVm.toggle();
          },
        ),
        const SizedBox(width: 6),

        // Seçenekler Menüsü
        PopupMenuButton<String>(
          tooltip: 'Ayarlar ve Seçenekler',
          icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 6,
          onSelected: (value) async {
            if (value == 'key') {
              showApiKeyDialog(context);
            } else if (value == 'logout') {
              await context.read<AuthViewModel>().completeSignOut();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'key',
              child: Row(
                children: [
                  Icon(Icons.key_rounded, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Deepgram API Anahtarı',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, size: 20, color: Colors.red.shade400),
                  const SizedBox(width: 12),
                  Text(
                    'Oturumu Kapat',
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/theme_service.dart';
import '../../../core/theme/theme_liquid_transition.dart';

class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Temalar', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primary),
      ),
      body: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: AppThemeType.values.length,
            itemBuilder: (context, index) {
              final theme = AppThemeType.values[index];
              final isSelected = theme == themeService.currentTheme;

              return GestureDetector(
                onTap: () {
                  final navigator = Navigator.of(context);
                  final overlayState = Overlay.of(context);
                  final liquidColor = _getThemePreviewColor(theme);

                  OverlayEntry? entry;
                  entry = OverlayEntry(
                    builder: (_) => ThemeLiquidTransition(
                      color: liquidColor,
                      onMidpoint: () {
                        // Ekran tamamen kapandığında temayı değiştir
                        themeService.setTheme(theme);
                      },
                      onComplete: () {
                        // Animasyon bitince overlay'i kaldır ve ana sayfaya dön
                        entry?.remove();
                        navigator.popUntil((route) => route.isFirst);
                      },
                    ),
                  );
                  overlayState.insert(entry);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getThemePreviewColor(theme),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          themeService.getThemeName(theme),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: AppColors.primary),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getThemePreviewColor(AppThemeType theme) {
    switch (theme) {
      case AppThemeType.neonCyberpunk:
        return const Color(0xFFD900FF);
      case AppThemeType.sunsetFire:
        return const Color(0xFFD91656);
      case AppThemeType.slateIndigo:
        return const Color(0xFF6366F1);
      case AppThemeType.premiumCharcoal:
        return const Color(0xFFD4AF37);
    }
  }
}

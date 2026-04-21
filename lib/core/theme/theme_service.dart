import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

enum AppThemeType {
  neonCyberpunk,
  sunsetFire,
  slateIndigo,
  premiumCharcoal,
}

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'selected_theme';
  AppThemeType _currentTheme = AppThemeType.premiumCharcoal;

  AppThemeType get currentTheme => _currentTheme;

  ThemeService() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeIndex = prefs.getInt(_themeKey);
    if (savedThemeIndex != null && savedThemeIndex >= 0 && savedThemeIndex < AppThemeType.values.length) {
      _currentTheme = AppThemeType.values[savedThemeIndex];
    }
    _applyThemeColors(_currentTheme);
  }

  Future<void> setTheme(AppThemeType theme) async {
    _currentTheme = theme;
    _applyThemeColors(theme);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, theme.index);
    
    notifyListeners();
  }

  void _applyThemeColors(AppThemeType theme) {
    switch (theme) {
      case AppThemeType.neonCyberpunk:
        AppColors.background = Color(0xFF0D0D12);
        AppColors.surface = Color(0xFF1A1A24);
        AppColors.primary = Color(0xFFD900FF);
        AppColors.primaryVariant = Color(0xFF9000FF);
        AppColors.secondary = Color(0xFF00F0FF);
        AppColors.textPrimary = Colors.white;
        AppColors.textSecondary = Colors.white60;
        AppColors.error = Color(0xFFFF3366);
        break;
      case AppThemeType.sunsetFire:
        AppColors.background = Color(0xFF2A0325);
        AppColors.surface = Color(0xFF640D5F);
        AppColors.primary = Color(0xFFD91656);
        AppColors.primaryVariant = Color(0xFFEB5B00);
        AppColors.secondary = Color(0xFFFFB200);
        AppColors.textPrimary = Colors.white;
        AppColors.textSecondary = Colors.white70;
        AppColors.error = Color(0xFFFF4C4C);
        break;
      case AppThemeType.slateIndigo:
        AppColors.background = Color(0xFF0F172A);
        AppColors.surface = Color(0xFF1E293B);
        AppColors.primary = Color(0xFF6366F1);
        AppColors.primaryVariant = Color(0xFF818CF8);
        AppColors.secondary = Color(0xFF38BDF8);
        AppColors.textPrimary = Color(0xFFF8FAFC);
        AppColors.textSecondary = Color(0xFF94A3B8);
        AppColors.error = Color(0xFFF43F5E);
        break;
      case AppThemeType.premiumCharcoal:
        AppColors.background = Color(0xFF121212);
        AppColors.surface = Color(0xFF1E1E1E);
        AppColors.primary = Color(0xFFD4AF37);
        AppColors.primaryVariant = Color(0xFFFDE047);
        AppColors.secondary = Color(0xFFE5E5E5);
        AppColors.textPrimary = Color(0xFFFFFFFF);
        AppColors.textSecondary = Color(0xFFA3A3A3);
        AppColors.error = Color(0xFFEF4444);
        break;
    }
  }

  String getThemeName(AppThemeType theme) {
    switch (theme) {
      case AppThemeType.neonCyberpunk: return 'Neon Cyberpunk';
      case AppThemeType.sunsetFire: return 'Sunset Ateş';
      case AppThemeType.slateIndigo: return 'Sade İndigo';
      case AppThemeType.premiumCharcoal: return 'Premium Kömür';
    }
  }
}

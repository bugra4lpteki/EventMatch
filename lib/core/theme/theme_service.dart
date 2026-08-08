import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

enum AppThemeType {
  electricViolet,
  cyberGold,
  emeraldLuma,
  sunsetFire,
  midnightCobalt,
}

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'selected_theme';
  AppThemeType _currentTheme = AppThemeType.electricViolet;

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
      case AppThemeType.electricViolet:
        AppColors.background = const Color(0xFF08080C);
        AppColors.surface = const Color(0xFF12131F);
        AppColors.primary = const Color(0xFF8B5CF6);
        AppColors.primaryVariant = const Color(0xFFA78BFA);
        AppColors.secondary = const Color(0xFFEC4899);
        AppColors.accent = const Color(0xFF06B6D4);
        AppColors.textPrimary = Colors.white;
        AppColors.textSecondary = const Color(0xFF94A3B8);
        break;

      case AppThemeType.cyberGold:
        AppColors.background = const Color(0xFF06090E);
        AppColors.surface = const Color(0xFF0F172A);
        AppColors.primary = const Color(0xFF06B6D4);
        AppColors.primaryVariant = const Color(0xFF38BDF8);
        AppColors.secondary = const Color(0xFFF59E0B);
        AppColors.accent = const Color(0xFF3B82F6);
        AppColors.textPrimary = Colors.white;
        AppColors.textSecondary = const Color(0xFF94A3B8);
        break;

      case AppThemeType.emeraldLuma:
        AppColors.background = const Color(0xFF040D0A);
        AppColors.surface = const Color(0xFF0A1F18);
        AppColors.primary = const Color(0xFF10B981);
        AppColors.primaryVariant = const Color(0xFF34D399);
        AppColors.secondary = const Color(0xFF059669);
        AppColors.accent = const Color(0xFF2DD4BF);
        AppColors.textPrimary = Colors.white;
        AppColors.textSecondary = const Color(0xFF94A3B8);
        break;

      case AppThemeType.sunsetFire:
        AppColors.background = const Color(0xFF0D0608);
        AppColors.surface = const Color(0xFF1C0D13);
        AppColors.primary = const Color(0xFFFF5722);
        AppColors.primaryVariant = const Color(0xFFFF8A65);
        AppColors.secondary = const Color(0xFFFFC107);
        AppColors.accent = const Color(0xFFE91E63);
        AppColors.textPrimary = Colors.white;
        AppColors.textSecondary = const Color(0xFF94A3B8);
        break;

      case AppThemeType.midnightCobalt:
        AppColors.background = const Color(0xFF070B14);
        AppColors.surface = const Color(0xFF0F172A);
        AppColors.primary = const Color(0xFF2563EB);
        AppColors.primaryVariant = const Color(0xFF60A5FA);
        AppColors.secondary = const Color(0xFF38BDF8);
        AppColors.accent = const Color(0xFF2DD4BF);
        AppColors.textPrimary = Colors.white;
        AppColors.textSecondary = const Color(0xFF94A3B8);
        break;
    }
  }

  String getThemeName(AppThemeType theme) {
    switch (theme) {
      case AppThemeType.electricViolet: return 'Electric Violet & Pink 🔮';
      case AppThemeType.cyberGold: return 'Siber Mavi & Kehribar Altını ⚡';
      case AppThemeType.emeraldLuma: return 'Zümrüt Yeşili & Nane (Luma Style) 🟢';
      case AppThemeType.sunsetFire: return 'Gün Batımı Alevi & Kırmızı 🌅';
      case AppThemeType.midnightCobalt: return 'Gece Kobaltı & Buz Mavisi 🧊';
    }
  }
}


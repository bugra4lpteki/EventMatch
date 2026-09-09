import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

enum AppThemeType {
  electricViolet,
  cyberGold,
  emeraldLuma,
  sunsetFire,
  midnightCobalt,
  elegantWhite,
  elegantBlack,
}

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'selected_theme';
  AppThemeType _currentTheme = AppThemeType.electricViolet;

  AppThemeType get currentTheme => _currentTheme;

  /// Light tema mı kontrol et (beyaz tema için ThemeData.light() kullanılacak)
  bool get isLightTheme => _currentTheme == AppThemeType.elegantWhite;

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
        AppColors.surfaceLight = const Color(0xFF1E293B);
        AppColors.textMuted = const Color(0xFF64748B);
        AppColors.error = const Color(0xFFEF4444);
        AppColors.success = const Color(0xFF10B981);
        break;

      case AppThemeType.elegantWhite:
        // Şık beyaz tema — premium, temiz, aydınlık
        AppColors.background = const Color(0xFFF8F9FC);
        AppColors.surface = const Color(0xFFFFFFFF);
        AppColors.surfaceLight = const Color(0xFFF0F1F5);
        AppColors.primary = const Color(0xFF6C5CE7);
        AppColors.primaryVariant = const Color(0xFF8B7CF6);
        AppColors.secondary = const Color(0xFFE84393);
        AppColors.accent = const Color(0xFF00B894);
        AppColors.textPrimary = const Color(0xFF1A1A2E);
        AppColors.textSecondary = const Color(0xFF636E82);
        AppColors.textMuted = const Color(0xFF9CA3B0);
        AppColors.error = const Color(0xFFE74C3C);
        AppColors.success = const Color(0xFF00B894);
        break;

      case AppThemeType.elegantBlack:
        // Şık siyah tema — AMOLED, premium, derin karanlık
        AppColors.background = const Color(0xFF000000);
        AppColors.surface = const Color(0xFF0A0A0F);
        AppColors.surfaceLight = const Color(0xFF141419);
        AppColors.primary = const Color(0xFFD4A574);
        AppColors.primaryVariant = const Color(0xFFE8C9A0);
        AppColors.secondary = const Color(0xFFC9A0DC);
        AppColors.accent = const Color(0xFF7EC8E3);
        AppColors.textPrimary = const Color(0xFFF5F5F5);
        AppColors.textSecondary = const Color(0xFF8A8A9A);
        AppColors.textMuted = const Color(0xFF555566);
        AppColors.error = const Color(0xFFFF6B6B);
        AppColors.success = const Color(0xFF51CF66);
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
      case AppThemeType.elegantWhite: return 'Şık Beyaz & Lavanta 🤍';
      case AppThemeType.elegantBlack: return 'Şık Siyah & Rose Gold 🖤';
    }
  }
}


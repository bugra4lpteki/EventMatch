import 'package:flutter/material.dart';

class AppColors {
  // Aktif tema renkleri (ThemeService tarafından dinamik olarak yönetilebilir)
  static Color background = const Color(0xFF08080C); 
  static Color surface = const Color(0xFF12131F); 
  static Color surfaceLight = const Color(0xFF1B1C2E); 
  static Color primary = const Color(0xFF8B5CF6); // Electric Violet
  static Color primaryVariant = const Color(0xFFA78BFA); 
  static Color secondary = const Color(0xFFEC4899); // Neon Pink/Magenta
  static Color accent = const Color(0xFF06B6D4); // Cyber Cyan
  static Color textPrimary = const Color(0xFFFFFFFF); 
  static Color textSecondary = const Color(0xFF94A3B8); 
  static Color textMuted = const Color(0xFF64748B); 
  static Color error = const Color(0xFFEF4444); 
  static Color success = const Color(0xFF10B981); 

  // Gradients for modern UI Depth (dynamic — tema renklerine göre güncellenir)
  static LinearGradient get primaryGradient => LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get accentGradient => LinearGradient(
    colors: [accent, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get goldGradient => LinearGradient(
    colors: [const Color(0xFFF59E0B), error],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get glassGradient => LinearGradient(
    colors: [
      // Light temada koyu glass, dark temada beyaz glass
      _isLightBackground ? const Color(0x12000000) : const Color(0x20FFFFFF),
      _isLightBackground ? const Color(0x06000000) : const Color(0x08FFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Background'un light olup olmadığını kontrol eder
  static bool get _isLightBackground =>
      background.computeLuminance() > 0.5;
}


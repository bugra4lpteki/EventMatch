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

  // Gradients for modern UI Depth
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x20FFFFFF),
      Color(0x08FFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}


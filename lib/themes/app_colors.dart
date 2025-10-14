import 'package:flutter/material.dart';

/// Application color scheme that follows Material Design naming conventions
class AppColors {
  // Primary colors - Brand Purple (#42143d)
  static const Color primary = Color(0xFF42143d);
  static const Color onPrimary = Colors.white;
  static const MaterialColor primarySwatch = MaterialColor(0xFF42143d, {
    50: Color(0xFFF8F2F7),
    100: Color(0xFFE8D9E6),
    200: Color(0xFFD1B3D3),
    300: Color(0xFFBA8DC0),
    400: Color(0xFFA367AD),
    500: Color(0xFF42143d), // Primary color
    600: Color(0xFF3B1237),
    700: Color(0xFF340F31),
    800: Color(0xFF2D0D2B),
    900: Color(0xFF260A25),
  });

  // Secondary colors
  static const Color secondary = Color(0xFF42143d); // Same as primary
  static const Color onSecondary = Colors.white;

  // Background colors
  static const Color background = Colors.white;
  static const Color onBackground = Color(0xFF42143d);

  // Surface colors
  static const Color surface = Colors.white;
  static const Color onSurface = Color(0xFF42143d);

  // Error and status colors
  static const Color error = Colors.redAccent;
  static const Color onError = Colors.white;
  static const Color success = Color(0xFF4CAF50); // Green
  static const Color warning = Color(0xFFFFC107); // Amber
  static const Color info = Color(0xFF2196F3); // Blue

  // Additional utility colors
  static const Color divider = Color(0xFFE8E8E8);
  static const Color disabled = Color(0xFFE0E0E0);
  static const Color shadow = Color(0x1A000000); // Subtle shadow for white backgrounds

  // Text colors (variants)
  static const Color textPrimary = Color(0xFF42143d);
  static const Color textSecondary = Color(0xFF8B7A8A);
  static const Color textHint = Color(0xFFBAB0B9);
}

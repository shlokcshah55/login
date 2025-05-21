import 'package:flutter/material.dart';

/// Application color scheme that follows Material Design naming conventions
class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF008080); // Teal
  static const Color onPrimary = Colors.white;
  static const MaterialColor primarySwatch = MaterialColor(0xFF008080, {
    50: Color(0xFFE0F2F2),
    100: Color(0xFFB3E0E0),
    200: Color(0xFF80CCCC),
    300: Color(0xFF4DB9B9),
    400: Color(0xFF26AAAA),
    500: Color(0xFF008080), // Primary color
    600: Color(0xFF007878),
    700: Color(0xFF006D6D),
    800: Color(0xFF006363),
    900: Color(0xFF005050),
  });
  
  // Secondary colors
  static const Color secondary = Color(0xFFFF7F50); // Coral
  static const Color onSecondary = Colors.white;
  
  // Background colors
  static const Color background = Color(0xFFFAF0E6); // Linen (Off-white)
  static const Color onBackground = Color(0xFF333333); // Dark Grey
  
  // Surface colors
  static const Color surface = Colors.white; // Card/surface background
  static const Color onSurface = Color(0xFF333333); // Text on cards/surfaces
  
  // Error and status colors
  static const Color error = Colors.redAccent;
  static const Color onError = Colors.white;
  static const Color success = Color(0xFF4CAF50); // Green
  static const Color warning = Color(0xFFFFC107); // Amber
  static const Color info = Color(0xFF2196F3); // Blue
  
  // Additional utility colors
  static const Color divider = Color(0xFFE0E0E0);
  static const Color disabled = Color(0xFFCCCCCC);
  static const Color shadow = Color(0x40000000); // Semi-transparent black for shadows
  
  // Text colors (variants)
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
}

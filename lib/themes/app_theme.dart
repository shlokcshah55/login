import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_widget_themes.dart';

// Application theme
ThemeData buildThemeData() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Color scheme
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primarySwatch[300]!,
      onPrimaryContainer: AppColors.primarySwatch[900]!,
      secondary: const Color(0xFF42143D),
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondary.withOpacity(0.2),
      onSecondaryContainer: AppColors.secondary.withOpacity(0.9),
      tertiary: AppColors.info,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.info.withOpacity(0.2),
      onTertiaryContainer: AppColors.info.withOpacity(0.9),
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.error.withOpacity(0.2),
      onErrorContainer: AppColors.error.withOpacity(0.9),
      surface: AppColors.surface,
      onSurface: const Color(0xFF42143D),
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.divider,
    ),

    // Typography - Apply the text theme from AppTypography
    textTheme: AppTypography.textTheme,

    // Background color
    scaffoldBackgroundColor: AppColors.background,

    // Widget themes - Apply from AppWidgetThemes
    elevatedButtonTheme: AppWidgetThemes.elevatedButtonTheme,
    outlinedButtonTheme: AppWidgetThemes.outlinedButtonTheme,
    textButtonTheme: AppWidgetThemes.textButtonTheme,
    floatingActionButtonTheme: AppWidgetThemes.floatingActionButtonTheme,
    // cardTheme: AppWidgetThemes.cardTheme,
    bottomNavigationBarTheme: AppWidgetThemes.bottomNavigationBarTheme,
    appBarTheme: AppWidgetThemes.appBarTheme,
    inputDecorationTheme: AppWidgetThemes.inputDecorationTheme,
    dividerTheme: AppWidgetThemes.dividerTheme,
    checkboxTheme: AppWidgetThemes.checkboxTheme,
    // dialogTheme: AppWidgetThemes.dialogTheme,
  );
}


// Helper function to create a MaterialColor from a single color
MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  strengths.forEach((strength) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  });
  return MaterialColor(color.value, swatch);
}

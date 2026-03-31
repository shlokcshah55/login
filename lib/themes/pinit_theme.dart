import 'package:flutter/material.dart';
import 'package:login/themes/pinit_colors.dart';
import 'package:login/themes/app_colors.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/themes/app_widget_themes.dart';

/// Pinit theme builder — provides light and dark ThemeData.
///
/// Dark mode is the **primary** experience.
/// Both themes carry PinitColors as a ThemeExtension.
class PinitTheme {
  PinitTheme._();

  /// Dark theme (primary experience).
  static ThemeData dark() {
    const c = PinitColors.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: c.primaryPurple,
        onPrimary: Colors.white,
        secondary: c.softPurple,
        surface: c.surfaceBg,
        onSurface: c.textPrimary,
        error: AppColors.error,
        onError: AppColors.onError,
      ),
      scaffoldBackgroundColor: c.surfaceBg,
      textTheme: AppTypography.textTheme.apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      extensions: const [c],

      // Preserve existing widget themes where possible
      elevatedButtonTheme: AppWidgetThemes.elevatedButtonTheme,
      outlinedButtonTheme: AppWidgetThemes.outlinedButtonTheme,
      textButtonTheme: AppWidgetThemes.textButtonTheme,
      dividerTheme: AppWidgetThemes.dividerTheme,
    );
  }

  /// Light theme.
  static ThemeData light() {
    const c = PinitColors.light;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: c.primaryPurple,
        onPrimary: Colors.white,
        secondary: c.softPurple,
        surface: c.surfaceBg,
        onSurface: c.textPrimary,
        error: AppColors.error,
        onError: AppColors.onError,
      ),
      scaffoldBackgroundColor: c.surfaceBg,
      textTheme: AppTypography.textTheme.apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),
      extensions: const [c],

      // Preserve existing widget themes
      elevatedButtonTheme: AppWidgetThemes.elevatedButtonTheme,
      outlinedButtonTheme: AppWidgetThemes.outlinedButtonTheme,
      textButtonTheme: AppWidgetThemes.textButtonTheme,
      floatingActionButtonTheme: AppWidgetThemes.floatingActionButtonTheme,
      bottomNavigationBarTheme: AppWidgetThemes.bottomNavigationBarTheme,
      appBarTheme: AppWidgetThemes.appBarTheme,
      inputDecorationTheme: AppWidgetThemes.inputDecorationTheme,
      dividerTheme: AppWidgetThemes.dividerTheme,
      checkboxTheme: AppWidgetThemes.checkboxTheme,
    );
  }
}

/// Motion timing constants.
///
/// Used across all home screen widgets for consistent feel.
class PinitMotion {
  PinitMotion._();

  static const fast = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 350);

  static const curve = Curves.easeOutCubic;
  static const curveFast = Curves.fastOutSlowIn;
}

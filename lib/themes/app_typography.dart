import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Application typography styles.
///
/// `Rova` carries the brand voice while `Manrope` handles reading comfort.
class AppTypography {
  static const String brandFamily = 'Rova';
  static const String sansFamily = 'Manrope';
  static const double defaultBrandLetterSpacing = 0.24;
  static const double defaultBrandHeight = 1.08;

  static TextStyle brand({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: brandFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing ?? defaultBrandLetterSpacing,
      height: height ?? defaultBrandHeight,
    );
  }

  static TextStyle sans({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: sansFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle get displayLarge => brand(
        fontSize: 34,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        letterSpacing: -0.8,
        height: 0.96,
      );

  static TextStyle get displayMedium => brand(
        fontSize: 30,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        letterSpacing: -0.6,
        height: 0.98,
      );

  static TextStyle get displaySmall => brand(
        fontSize: 26,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        letterSpacing: -0.4,
        height: 1.0,
      );

  static TextStyle get headingLarge => brand(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
        height: 1.02,
      );

  static TextStyle get headingMedium => brand(
        fontSize: 22,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.04,
      );

  static TextStyle get headingSmall => brand(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.06,
      );

  static TextStyle get titleLarge => brand(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.04,
      );

  static TextStyle get titleMedium => brand(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.05,
      );

  static TextStyle get titleSmall => brand(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.08,
      );

  static TextStyle get bodyLarge => sans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.45,
      );

  static TextStyle get bodyMedium => sans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.45,
      );

  static TextStyle get bodySmall => sans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get labelLarge => brand(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.onPrimary,
        letterSpacing: 0.2,
        height: 1.0,
      );

  static TextStyle get labelMedium => brand(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.onPrimary,
        letterSpacing: 0.2,
        height: 1.0,
      );

  static TextStyle get labelSmall => brand(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.onPrimary,
        letterSpacing: 0.3,
        height: 1.0,
      );

  static TextStyle get caption => sans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.25,
        height: 1.35,
      );

  /// Creates a TextTheme using the shared brand and reading font split.
  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displaySmall,
        headlineLarge: headingLarge,
        headlineMedium: headingMedium,
        headlineSmall: headingSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      );
}

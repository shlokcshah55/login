import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_dimensions.dart';

/// Application widget theme extensions and presets
class AppWidgetThemes {
  /// Button themes
  static ElevatedButtonThemeData elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMedium),
      elevation: AppElevation.small,
    ),
  );
  
  static OutlinedButtonThemeData outlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      side: const BorderSide(color: AppColors.primary, width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMedium),
    ),
  );
  
  static TextButtonThemeData textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
  );
  
  /// Card theme
  static CardTheme cardTheme = CardTheme(
    color: AppColors.surface,
    elevation: AppElevation.medium,
    margin: AppSpacing.paddingSmall,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMedium),
    shadowColor: AppColors.shadow,
  );
  
  /// App bar theme
  static AppBarTheme appBarTheme = AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.onPrimary,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.onPrimary,
    ),
    iconTheme: const IconThemeData(
      color: AppColors.onPrimary,
    ),
  );
  
  /// Bottom navigation bar theme
  static BottomNavigationBarThemeData bottomNavigationBarTheme = 
      const BottomNavigationBarThemeData(
    backgroundColor: AppColors.surface,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.textSecondary,
    showSelectedLabels: false,
    showUnselectedLabels: false,
    type: BottomNavigationBarType.fixed,
    elevation: AppElevation.medium,
  );
  
  /// Floating action button theme
  static FloatingActionButtonThemeData floatingActionButtonTheme = 
      const FloatingActionButtonThemeData(
    backgroundColor: AppColors.secondary,
    foregroundColor: AppColors.onSecondary,
    elevation: AppElevation.medium,
  );
  
  /// Input decoration theme
  static InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface.withOpacity(0.8),
    border: OutlineInputBorder(
      borderRadius: AppRadius.radiusLarge,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.radiusLarge,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.radiusLarge,
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: AppRadius.radiusLarge,
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    hintStyle: GoogleFonts.poppins(color: AppColors.textHint),
    errorStyle: GoogleFonts.poppins(color: AppColors.error),
    contentPadding: const EdgeInsets.symmetric(
      vertical: 15.0,
      horizontal: 20.0,
    ),
  );
  
  /// Divider theme
  static DividerThemeData dividerTheme = const DividerThemeData(
    color: AppColors.divider,
    thickness: 1,
    space: AppSpacing.medium,
  );
  
  /// Checkbox theme
  static CheckboxThemeData checkboxTheme = CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.primary;
      }
      return Colors.transparent;
    }),
    checkColor: WidgetStateProperty.all(AppColors.onPrimary),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXS),
    side: const BorderSide(color: AppColors.primary),
  );
  
  /// Dialog theme
  static DialogTheme dialogTheme = DialogTheme(
    backgroundColor: AppColors.surface,
    elevation: AppElevation.large,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMedium),
  );
}

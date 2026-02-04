import 'package:flutter/material.dart';

/// Pinit Design System Colors
/// Editorial, premium, playful but refined
class PinitColors {
  PinitColors._();

  // Primary Brand Colors
  static const Color primary = Color(0xFFE85D4C);
  static const Color primaryDark = Color(0xFFD14A3A);
  static const Color primaryLight = Color(0xFFFF7A6B);

  // Accent (for highlights, badges, CTAs)
  static const Color accent = Color(0xFFFF5E5E);
  static const Color accentSoft = Color(0xFFFFE8E6);

  // Backgrounds
  static const Color background = Color(0xFFFAF9F7);
  static const Color surfaceLight = Color(0xFFF3F1EE);
  static const Color surfaceCard = Color(0xFFFFFFFF);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFFA3A3A3);
  static const Color textInverse = Color(0xFFFFFFFF);

  // Semantic Colors
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFFB800);
  static const Color error = Color(0xFFFF3B30);

  // Taste Chip Colors (soft, pastel variants)
  static const Color chipRamen = Color(0xFFFFE4D6);
  static const Color chipVeg = Color(0xFFD6F5E3);
  static const Color chipWine = Color(0xFFE8D6F5);
  static const Color chipDateNight = Color(0xFFFFF0D6);
  static const Color chipCheapEats = Color(0xFFD6EAF5);
  static const Color chipLateNight = Color(0xFFE0D6F5);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE85D4C),
      Color(0xFFFF7A6B),
    ],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFF8F6),
      Color(0xFFFFEDE9),
    ],
  );

  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFBFA),
      Color(0xFFFAF9F7),
    ],
  );

  static const LinearGradient overlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0x40000000),
    ],
  );

  // Map overlay gradient
  static const LinearGradient mapOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00FAF9F7),
      Color(0xFFFAF9F7),
    ],
  );

  // Match indicator colors
  static Color matchIndicator(int percentage) {
    if (percentage >= 75) return const Color(0xFF34C759);
    if (percentage >= 50) return const Color(0xFFFFB800);
    return const Color(0xFFE85D4C);
  }

  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}

/// Taste chip data with colors and emojis
class TasteChipData {
  final String label;
  final String emoji;
  final Color backgroundColor;
  final Color textColor;

  const TasteChipData({
    required this.label,
    required this.emoji,
    required this.backgroundColor,
    this.textColor = PinitColors.textPrimary,
  });

  static const List<TasteChipData> cuisineTags = [
    TasteChipData(
      label: 'Ramen',
      emoji: '🍜',
      backgroundColor: PinitColors.chipRamen,
    ),
    TasteChipData(
      label: 'Veg',
      emoji: '🥬',
      backgroundColor: PinitColors.chipVeg,
    ),
    TasteChipData(
      label: 'Wine Bars',
      emoji: '🍷',
      backgroundColor: PinitColors.chipWine,
    ),
    TasteChipData(
      label: 'Pizza',
      emoji: '🍕',
      backgroundColor: PinitColors.chipRamen,
    ),
    TasteChipData(
      label: 'Coffee',
      emoji: '☕',
      backgroundColor: PinitColors.chipDateNight,
    ),
    TasteChipData(
      label: 'Sushi',
      emoji: '🍣',
      backgroundColor: PinitColors.chipCheapEats,
    ),
  ];

  static const List<TasteChipData> vibeTags = [
    TasteChipData(
      label: 'Date night',
      emoji: '✨',
      backgroundColor: PinitColors.chipDateNight,
    ),
    TasteChipData(
      label: 'Cheap eats',
      emoji: '💰',
      backgroundColor: PinitColors.chipCheapEats,
    ),
    TasteChipData(
      label: 'Late night',
      emoji: '🌙',
      backgroundColor: PinitColors.chipLateNight,
    ),
    TasteChipData(
      label: 'Cozy',
      emoji: '🕯️',
      backgroundColor: PinitColors.chipWine,
    ),
  ];
}

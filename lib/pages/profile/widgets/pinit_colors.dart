import 'package:flutter/material.dart';

/// Pinit Design System Colors — Style.MD v2
/// Cream backgrounds · Aubergine brand · Warm shadows only
class PinitColors {
  PinitColors._();

  // ── Core palette ─────────────────────────────────────────────
  static const Color cream          = Color(0xFFFBF6F3);
  static const Color creamSunk      = Color(0xFFF4EDE6);
  static const Color creamDeep      = Color(0xFFECE2D8);
  static const Color aubergine      = Color(0xFF41133D);
  static const Color aubergineSoft  = Color(0xFF6B3866);
  static const Color mute           = Color(0xFF8A7A72);
  static const Color accent         = Color(0xFFEC3D2C);

  // ── Backwards-compat aliases ─────────────────────────────────
  static const Color background     = cream;
  static const Color surfaceLight   = creamSunk;
  static const Color surfaceCard    = cream;
  static const Color textPrimary    = aubergine;
  static const Color textSecondary  = aubergineSoft;
  static const Color textMuted      = mute;
  static const Color primary        = aubergine;
  static const Color accentSoft     = creamSunk;
  static const Color error          = accent;

  // ── Single allowed gradient (hero bg only) ────────────────────
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cream, creamSunk],
  );

  // ── Warm shadows (aubergine-tinted, never black/grey) ─────────
  /// shadow-card: 0 4px 16px rgba(65,19,61,0.08)
  static List<BoxShadow> cardShadow = const [
    BoxShadow(
      color: Color(0x1441133D),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// shadow-lift: 0 12px 32px rgba(65,19,61,0.12)
  static List<BoxShadow> elevatedShadow = const [
    BoxShadow(
      color: Color(0x1F41133D),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  /// shadow-soft: 0 2px 8px rgba(65,19,61,0.06)
  static List<BoxShadow> subtleShadow = const [
    BoxShadow(
      color: Color(0x0F41133D),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

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


static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFFB800);

  static Color matchIndicator(int percentage) {
    if (percentage >= 75) return const Color(0xFF34C759);
    if (percentage >= 50) return const Color(0xFFFFB800);
    return const Color(0xFFE85D4C);
  }

}



import 'package:flutter/material.dart';

/// Pinit color system — dual-scheme ThemeExtension.
///
/// Access via: `Theme.of(context).extension<PinitColors>()!`
///
/// Dark mode is the primary experience. Light mode mirrors structure
/// with inverted contrast.
@immutable
class PinitColors extends ThemeExtension<PinitColors> {
  // ── Surfaces ──
  final Color surfaceBg;
  final Color elevatedSurface;
  final Color searchSurface;

  // ── Purple system ──
  final Color primaryPurple;
  final Color softPurple;
  final Color glowAccent;

  // ── Text ──
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textOnPurple;

  // ── Chips ──
  final Color chipInactive;
  final Color chipActive; // = primaryPurple

  // ── Scrim ──
  final Color scrimStart;
  final Color scrimMid;

  const PinitColors({
    required this.surfaceBg,
    required this.elevatedSurface,
    required this.searchSurface,
    required this.primaryPurple,
    required this.softPurple,
    required this.glowAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnPurple,
    required this.chipInactive,
    required this.chipActive,
    required this.scrimStart,
    required this.scrimMid,
  });

  // pinit_colors.dart — updated values

  // ─── Dark scheme (PRIMARY experience) ──────────────────────────
  static const dark = PinitColors(
    surfaceBg:        Color(0xFF1A1D2E),   // cool deep navy — lighter, less heavy
    elevatedSurface:  Color(0xFF232738),   // lifted card surface
    searchSurface:    Color(0xFF2C3045),   // input layer

    primaryPurple:    Color(0xFFFF6B6B),   // warm coral accent — fun & inviting
    softPurple:       Color(0xFF2E3347),   // muted chip/overlay tone
    glowAccent:       Color(0xFFFFD93D),   // sunny yellow highlight — playful

    textPrimary:      Color(0xFFF5F5F7),
    textSecondary:    Color(0xFFB8BCC8),
    textMuted:        Color(0xFF7E8494),

    textOnPurple:     Color(0xFFFFFFFF),

    chipInactive:     Color(0x1FFFFFFF),
    chipActive:       Color(0xFFFF6B6B),

    scrimStart:       Color(0xE6141625),
    scrimMid:         Color(0x801A1D2E),
  );

  // ─── Light scheme ──────────────────────────────────────────────
  static const light = PinitColors(
    surfaceBg:        Color(0xFFF9FAFB),     // clean warm white
    elevatedSurface:  Color(0xFFFFFFFF),
    searchSurface:    Color(0xFFF0F1F5),     // soft grey input
    primaryPurple:    Color(0xFFE85D5D),     // coral accent
    softPurple:       Color(0xFFFFE8E8),     // soft coral tint
    glowAccent:       Color(0xFFFF8C42),     // warm orange highlight
    textPrimary:      Color(0xFF1A1D2E),     // navy-black
    textSecondary:    Color(0xFF5A5E6B),     // cool grey
    textMuted:        Color(0xFF9A9DAA),
    textOnPurple:     Color(0xFFFFFFFF),
    chipInactive:     Color(0xFFF0F1F5),
    chipActive:       Color(0xFFE85D5D),
    scrimStart:       Color(0xD9F9FAFB),
    scrimMid:         Color(0x80F9FAFB),
  );

  @override
  PinitColors copyWith({
    Color? surfaceBg,
    Color? elevatedSurface,
    Color? searchSurface,
    Color? primaryPurple,
    Color? softPurple,
    Color? glowAccent,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textOnPurple,
    Color? chipInactive,
    Color? chipActive,
    Color? scrimStart,
    Color? scrimMid,
  }) {
    return PinitColors(
      surfaceBg: surfaceBg ?? this.surfaceBg,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      searchSurface: searchSurface ?? this.searchSurface,
      primaryPurple: primaryPurple ?? this.primaryPurple,
      softPurple: softPurple ?? this.softPurple,
      glowAccent: glowAccent ?? this.glowAccent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textOnPurple: textOnPurple ?? this.textOnPurple,
      chipInactive: chipInactive ?? this.chipInactive,
      chipActive: chipActive ?? this.chipActive,
      scrimStart: scrimStart ?? this.scrimStart,
      scrimMid: scrimMid ?? this.scrimMid,
    );
  }

  @override
  PinitColors lerp(PinitColors? other, double t) {
    if (other is! PinitColors) return this;
    return PinitColors(
      surfaceBg: Color.lerp(surfaceBg, other.surfaceBg, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      searchSurface: Color.lerp(searchSurface, other.searchSurface, t)!,
      primaryPurple: Color.lerp(primaryPurple, other.primaryPurple, t)!,
      softPurple: Color.lerp(softPurple, other.softPurple, t)!,
      glowAccent: Color.lerp(glowAccent, other.glowAccent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textOnPurple: Color.lerp(textOnPurple, other.textOnPurple, t)!,
      chipInactive: Color.lerp(chipInactive, other.chipInactive, t)!,
      chipActive: Color.lerp(chipActive, other.chipActive, t)!,
      scrimStart: Color.lerp(scrimStart, other.scrimStart, t)!,
      scrimMid: Color.lerp(scrimMid, other.scrimMid, t)!,
    );
  }
}

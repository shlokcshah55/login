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
  surfaceBg:        Color(0xFF12091F),   // richer, more wine-toned base
  elevatedSurface:  Color(0xFF1E1233),   // subtle lift, keeps warmth
  searchSurface:    Color(0xFF2A1847),   // clearer separation for input layers

  primaryPurple:    Color(0xFF8B5CF6),   // more balanced (less blue, more violet)
  softPurple:       Color(0xFF2F1B4D),   // tighter + deeper harmony
  glowAccent:       Color(0xFFC4B5FD),   // softer, premium glow (less neon)

  textPrimary:      Color(0xFFF6F2FF),   // slight lavender tint
  textSecondary:    Color(0xFFB8AECF),   // warmer + more readable
  textMuted:        Color(0xFF7A728F),   // avoids dead grey

  textOnPurple:     Color(0xFFFFFFFF),

  chipInactive:     Color(0x14FFFFFF),   // slightly lighter than before (~8%)
  chipActive:       Color(0xFF8B5CF6),

  scrimStart:       Color(0xE612091F),
  scrimMid:         Color(0x8012091F),
);

  // ─── Light scheme ──────────────────────────────────────────────
  static const light = PinitColors(
    surfaceBg:        Color(0xFFF8F6FC),     // purple-tinted off-white
    elevatedSurface:  Color(0xFFFFFFFF),
    searchSurface:    Color(0xFFEDE5F7),     // slightly deeper
    primaryPurple:    Color(0xFF6B3FA0),     // richer, less corporate
    softPurple:       Color(0xFFE8DDF5),
    glowAccent:       Color(0xFF8B62C9),
    textPrimary:      Color(0xFF1A1425),     // purple-black
    textSecondary:    Color(0xFF5C5470),     // purple-grey
    textMuted:        Color(0xFF9A91AB),
    textOnPurple:     Color(0xFFFFFFFF),
    chipInactive:     Color(0xFFEDE5F7),
    chipActive:       Color(0xFF6B3FA0),
    scrimStart:       Color(0xD9F8F6FC),
    scrimMid:         Color(0x80F8F6FC),
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

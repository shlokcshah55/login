import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart' as svg;
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/themes/app_typography.dart';

// ─────────────────────────────────────────────────────────────
//  Colour palette for cuisine / place types
// ─────────────────────────────────────────────────────────────
class PinitMarkerPalette {
  static const Color italian = Color(0xFFE57373);
  static const Color chinese = Color(0xFF64B5F6);
  static const Color indian = Color(0xFFFFB74D);
  static const Color japanese = Color(0xFFBA68C8);
  static const Color mexican = Color(0xFF81C784);
  static const Color american = Color(0xFF9575CD);
  static const Color thai = Color(0xFF4FC3F7);
  static const Color french = Color(0xFFF06292);
  static const Color mediterranean = Color(0xFFFFD54F);
  static const Color cafe = Color(0xFF8D6E63);
  static const Color bar = Color(0xFF90A4AE);
  static const Color other = Color(0xFFB0BEC5);

  /// Default avatar colours for friends who haven't set a custom one.
  static const List<Color> avatarDefaults = [
    Color(0xFFF48FB1), // pink
    Color(0xFF80DEEA), // cyan
    Color(0xFFCE93D8), // purple
    Color(0xFFA5D6A7), // green
    Color(0xFFFFCC80), // amber
    Color(0xFF90CAF9), // blue
    Color(0xFFEF9A9A), // red
    Color(0xFFB0BEC5), // grey
  ];

  // ── Wavy iridescent palette ──
  // These cycle around the ring for the holographic "wavy" effect.
  static const List<Color> wavyGradient = [
    Color(0xFFE040FB), // magenta-pink
    Color(0xFF7C4DFF), // deep purple
    Color(0xFF448AFF), // blue
    Color(0xFF18FFFF), // cyan
    Color(0xFF69F0AE), // green
    Color(0xFFFFD740), // amber
    Color(0xFFFF6E40), // deep orange
    Color(0xFFE040FB), // back to magenta (seamless loop)
  ];

  static Color forCuisine(String? cuisine, String? types) {
    final c = (cuisine ?? '').toLowerCase();
    if (c.contains('italian')) return italian;
    if (c.contains('chinese')) return chinese;
    if (c.contains('indian')) return indian;
    if (c.contains('japanese') || c.contains('sushi')) return japanese;
    if (c.contains('mexican')) return mexican;
    if (c.contains('american')) return american;
    if (c.contains('thai')) return thai;
    if (c.contains('french')) return french;
    if (c.contains('mediterranean')) return mediterranean;
    if (c.contains('cafe') || c.contains('coffee')) return cafe;
    if (c.contains('bar') || c.contains('pub')) return bar;
    final t = (types ?? '').toLowerCase();
    if (t.contains('restaurant')) return const Color(0xFFC5ABAB);
    if (t.contains('hotel') || t.contains('lodging')) return american;
    if (t.contains('museum')) return japanese;
    if (t.contains('park')) return mexican;
    return other;
  }
}

class PinitMarkerBadgeType {
  static const String sparkle = 'sparkle';
  static const String liveMusic = 'live_music';
  static const String cocktails = 'cocktails';
  static const String outdoor = 'outdoor';
  static const String trending = 'trending';
  static const String late = 'late';

  static const Set<String> values = {
    sparkle,
    liveMusic,
    cocktails,
    outdoor,
    trending,
    late,
  };
}

// ─────────────────────────────────────────────────────────────
//  Main entry‑point for all marker bitmap generation
// ─────────────────────────────────────────────────────────────
class PinitMarkers {
  static final _BitmapCache _cache = _BitmapCache(maxEntries: 512);
  static final Map<String, Future<ui.Image?>> _emojiImageCache = {};
  static const String _openMojiAssetDirectory = 'lib/assets/openmoji-svg-color';
  static const List<String> _genericFallbackEmojis = [
    '🍽️',
    '☕',
    '🫕',
    '🍷',
    '🍴',
    '🥣',
    '🥐',
  ];

  static const List<String> _vibeTagsByIndex = [
    'cafe',
    'casual',
    'cozy',
    'coffee_shop',
    'bar',
    'elegant',
    'fine_dining',
    'food_truck',
    'hole_in_the_wall',
    'late_night',
    'live_music',
    'michelin_starred',
    'modern',
    'fast_food',
    'quiet',
    'romantic',
    'sports_bar',
    'trendy',
    'takeout_friendly',
    'pub',
    'grocery_store',
    'brunch',
    'outdoor_dining',
    'wavy',
    'bossman',
  ];

  static const Set<String> _invalidEmojiSentinels = {
    'none',
    'null',
    'nil',
    'n/a',
    'na',
    'undefined',
    'unknown',
  };

  static const Map<String, String> _vibeFallbackEmojis = {
    'cafe': '☕',
    'casual': '🍴',
    'cozy': '🕯️',
    'coffee_shop': '☕',
    'bar': '🍸',
    'elegant': '🥂',
    'fine_dining': '🍽️',
    'food_truck': '🌮',
    'hole_in_the_wall': '🍜',
    'late_night': '🌙',
    'live_music': '🎵',
    'michelin_starred': '⭐',
    'modern': '✨',
    'fast_food': '🍔',
    'quiet': '🤫',
    'romantic': '🌹',
    'sports_bar': '🍺',
    'trendy': '🪩',
    'takeout_friendly': '🥡',
    'pub': '🍻',
    'grocery_store': '🛒',
    'brunch': '🥐',
    'outdoor_dining': '🌿',
    'wavy': '🌊',
    'bossman': '🕴️',
  };

  static int _positiveModulo(int value, int modulus) {
    if (modulus == 0) return 0;
    final mod = value % modulus;
    return mod < 0 ? mod + modulus : mod;
  }

  static String? _sanitizeEmoji(String? emoji) {
    final trimmed = emoji?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final normalized = trimmed.toLowerCase();
    if (_invalidEmojiSentinels.contains(normalized)) {
      return null;
    }

    // Reject plain text placeholders like "burger" or ":pizza:" so we can
    // fall back to vibe icons / generic emojis instead of painting words.
    if (RegExp(r'[A-Za-z]').hasMatch(trimmed)) {
      return null;
    }

    return trimmed;
  }

  static String? _highestSupportedVibeTag(List<double>? vibeVector) {
    if (vibeVector == null || vibeVector.isEmpty) return null;

    String? topTag;
    double topScore = 0.0;

    for (var i = 0; i < vibeVector.length && i < _vibeTagsByIndex.length; i++) {
      final score = vibeVector[i];
      if (!score.isFinite || score <= topScore) continue;

      final tag = _vibeTagsByIndex[i];
      if (!_vibeFallbackEmojis.containsKey(tag)) continue;

      topTag = tag;
      topScore = score;
    }

    return topScore > 0.0 ? topTag : null;
  }

  static String _visualKeyFor({
    String? emoji,
    List<double>? vibeVector,
    int fallbackSeed = 0,
  }) {
    final sanitizedEmoji = _sanitizeEmoji(emoji);
    if (sanitizedEmoji != null) {
      return 'emoji:$sanitizedEmoji';
    }

    final topVibeTag = _highestSupportedVibeTag(vibeVector);
    if (topVibeTag != null) {
      return 'vibe:$topVibeTag';
    }

    final fallbackIndex =
        _positiveModulo(fallbackSeed, _genericFallbackEmojis.length);
    return 'generic:$fallbackIndex';
  }

  static String markerVisualKey({
    String? emoji,
    List<double>? vibeVector,
    int fallbackSeed = 0,
  }) {
    return _visualKeyFor(
      emoji: emoji,
      vibeVector: vibeVector,
      fallbackSeed: fallbackSeed,
    );
  }

  static _MarkerVisual _resolveMarkerVisual({
    String? emoji,
    List<double>? vibeVector,
    int fallbackSeed = 0,
  }) {
    // Marker content priority: explicit emoji, strongest supported vibe emoji,
    // then a deterministic pick from the generic emoji set.
    final sanitizedEmoji = _sanitizeEmoji(emoji);
    if (sanitizedEmoji != null) {
      return _MarkerVisual.emoji(sanitizedEmoji);
    }

    final topVibeTag = _highestSupportedVibeTag(vibeVector);
    if (topVibeTag != null) {
      return _MarkerVisual.emoji(
        _vibeFallbackEmojis[topVibeTag]!,
        key: 'vibe:$topVibeTag',
      );
    }

    final fallbackIndex =
        _positiveModulo(fallbackSeed, _genericFallbackEmojis.length);
    return _MarkerVisual.emoji(
      _genericFallbackEmojis[fallbackIndex],
      key: 'generic:$fallbackIndex',
    );
  }

  static const double _basePinBubbleDiameter = 32.0;
  static const double _popularPinBubbleDiameter = 36.0;
  static const double _selectedPinScale = 1.7;
  static const double _accentRatingThreshold = 4.5;
  static const double _pinBubbleWidthFactor = 1.18;
  static const double _pinBubbleHeightFactor = 0.92;
  static const double _hardShadowOffset = 3.0;
  static const Color _pinFillColor = pinit.PinitColors.creamDeep;
  static const Color _pinStrokeColor = pinit.PinitColors.aubergine;
  static const Color _pinAccentStrokeColor = pinit.PinitColors.accent;
  static const Color _pinWavyShadowColor = Color(0xFF1E9FA3);
  static const Color _pinBossmanShadowColor = Color(0xFF7A6852);
  static const Color _pinMatchShadowColor = Color(0xFFC65B88);
  static const Color _pinSavedShadowColor = Color(0xFFC98A2E);
  static const Color _pinSparkleShadowColor = Color(0xFFCCA03A);
  static const Color _pinLiveMusicShadowColor = Color(0xFFD45763);
  static const Color _pinCocktailShadowColor = Color(0xFF8B63C7);
  static const Color _pinOutdoorShadowColor = Color(0xFF4B9A68);
  static const Color _pinLateShadowColor = Color(0xFF5F63D3);
  static const Color _pinTrendingShadowColor = Color(0xFFE56A2E);
  static const Color _pinLabelColor = pinit.PinitColors.aubergine;
  static const Color _pinLabelMutedColor = pinit.PinitColors.aubergineSoft;

  // ── Brand colours ──
  static const Color _brandDark = Color(0xFF42143D);

  // ── Vibe thresholds ──
  /// A place is considered "wavy" when its wavy score exceeds this.
  static const double _wavyThreshold = 0.35;

  /// A place is considered "bossman" when its bossman score exceeds this
  /// AND it is *not* also wavy.
  static const double _bossmanThreshold = 0.35;

  static double _pinBubbleDiameterForSavedCount(int savedCount) {
    return savedCount > 5 ? _popularPinBubbleDiameter : _basePinBubbleDiameter;
  }

  static bool _isAccentMarker(double? rating) =>
      rating != null && rating > _accentRatingThreshold;

  static Color markerStrokeColorForRating(double? rating) {
    return _isAccentMarker(rating) ? _pinAccentStrokeColor : _pinStrokeColor;
  }

  static String markerChromeKey({double? rating}) {
    return _isAccentMarker(rating) ? 'accent' : 'aubergine';
  }

  static ({Color color, String key}) markerShadowStyle({
    double? rating,
    double wavyScore = 0.0,
    double bossmanScore = 0.0,
    int savedCount = 0,
    double matchScore = 0.0,
    String? badgeType,
    String? cuisine,
    String? types,
  }) {
    final isWavy = _isWavy(wavyScore, bossmanScore);
    final isBossman = _isBossman(wavyScore, bossmanScore);
    final isAccent = _isAccentMarker(rating);

    if (isBossman) {
      return (color: _pinBossmanShadowColor, key: 'bossman');
    }
    if (isWavy) {
      return (color: _pinWavyShadowColor, key: 'wavy');
    }

    switch (badgeType) {
      case PinitMarkerBadgeType.sparkle:
        return (color: _pinSparkleShadowColor, key: 'sparkle');
      case PinitMarkerBadgeType.liveMusic:
        return (color: _pinLiveMusicShadowColor, key: 'live_music');
      case PinitMarkerBadgeType.cocktails:
        return (color: _pinCocktailShadowColor, key: 'cocktails');
      case PinitMarkerBadgeType.outdoor:
        return (color: _pinOutdoorShadowColor, key: 'outdoor');
      case PinitMarkerBadgeType.late:
        return (color: _pinLateShadowColor, key: 'late');
      case PinitMarkerBadgeType.trending:
        return (color: _pinTrendingShadowColor, key: 'trending');
    }

    if (matchScore >= 0.72) {
      return (color: _pinMatchShadowColor, key: 'match');
    }
    if (savedCount >= 18) {
      return (color: _pinSavedShadowColor, key: 'saved');
    }
    if (isAccent) {
      return (color: _pinAccentStrokeColor, key: 'rating');
    }

    final cuisineShadow = _shadowTint(
      PinitMarkerPalette.forCuisine(cuisine, types),
    );
    return (
      color: cuisineShadow,
      key: 'c${cuisineShadow.toARGB32().toRadixString(16)}',
    );
  }

  static Color _shadowTint(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withSaturation((hsl.saturation * 0.72 + 0.10).clamp(0.18, 0.78))
        .withLightness((hsl.lightness * 0.58).clamp(0.28, 0.46))
        .toColor();
  }

  static Size _bubbleSizeForRadius(double radius) {
    return Size(
      radius * 2 * _pinBubbleWidthFactor,
      radius * 2 * _pinBubbleHeightFactor,
    );
  }

  static Rect _bubbleRectFor({
    required Offset centre,
    required double radius,
  }) {
    final size = _bubbleSizeForRadius(radius);
    return Rect.fromCenter(
      center: centre,
      width: size.width,
      height: size.height,
    );
  }

  static RRect _bubbleRRectFor({
    required Offset centre,
    required double radius,
    double inflate = 0,
  }) {
    final rect = _bubbleRectFor(
      centre: centre,
      radius: radius,
    ).inflate(inflate);
    return RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.height / 2),
    );
  }

  static Offset _hardShadowOffsetFor(double dpr) {
    return Offset(_hardShadowOffset * dpr, _hardShadowOffset * dpr);
  }

  // ==================================================================
  //  PUBLIC API — Single pin
  // ==================================================================

  /// Creates a single pin marker with:
  ///  • Gradient bubble with inner highlight
  ///  • Downward‑pointing teardrop tail
  ///  • Hard offset shadow whose colour reflects the marker state
  ///  • Optional avatar ring showing who recommended the place
  ///  • Optional text pill with the place name
  ///
  /// [wavyScore]    — value from vibe vector index 23 (0.0–1.0).
  /// [bossmanScore] — value from vibe vector index 24 (0.0–1.0).
  /// [savedCount]   — number of users who saved this place.
  static Future<Uint8List> createPinitMarker({
    String? emoji,
    required String name,
    double devicePixelRatio = 3.0,
    Color? surfaceColor,
    Color textColor = _pinLabelColor,
    bool selected = false,
    String? types,
    String? cuisine,
    bool showText = true,
    List<Color> avatarColors = const [],
    double wavyScore = 0.0,
    double bossmanScore = 0.0,
    int savedCount = 0,
    double matchScore = 0.0,
    String? badgeType,
    double? rating,
    List<double>? vibeVector,
    int fallbackSeed = 0,
  }) async {
    final fillColor = surfaceColor ?? _pinFillColor;
    final isAccent = _isAccentMarker(rating);
    final shadowStyle = markerShadowStyle(
      rating: rating,
      wavyScore: wavyScore,
      bossmanScore: bossmanScore,
      savedCount: savedCount,
      matchScore: matchScore,
      badgeType: badgeType,
      cuisine: cuisine,
      types: types,
    );
    final avatarKey = avatarColors.map((c) => c.toARGB32()).join(',');
    final visual = _resolveMarkerVisual(
      emoji: emoji,
      vibeVector: vibeVector,
      fallbackSeed: fallbackSeed,
    );

    final key =
        'pin7|${visual.key}|$name|${devicePixelRatio.toStringAsFixed(2)}'
        '|${fillColor.toARGB32()}|${shadowStyle.key}'
        '|${textColor.toARGB32()}|$selected|$showText|$avatarKey'
        '|${wavyScore.toStringAsFixed(2)}|${bossmanScore.toStringAsFixed(2)}'
        '|$savedCount|${matchScore.toStringAsFixed(2)}|${badgeType ?? 'none'}';

    final cached = _cache.get(key);
    if (cached != null) return cached;

    final b = await _renderSinglePin(
      visual: visual,
      name: name,
      dpr: devicePixelRatio,
      fillColor: fillColor,
      shadowColor: shadowStyle.color,
      isAccent: isAccent,
      textColor: textColor,
      selected: selected,
      showText: showText,
      avatarColors: avatarColors,
      wavyScore: wavyScore,
      bossmanScore: bossmanScore,
      savedCount: savedCount,
      matchScore: matchScore,
      badgeType: badgeType,
    );
    _cache.set(key, b);
    return b;
  }

  // ==================================================================
  //  PUBLIC API — Dense viewport dot
  // ==================================================================

  static Future<Uint8List> createCompactMapDot({
    double devicePixelRatio = 3.0,
    bool hasBeenTo = false,
  }) async {
    final key =
        'compact-dot|${devicePixelRatio.toStringAsFixed(2)}|been:$hasBeenTo';
    final cached = _cache.get(key);
    if (cached != null) return cached;

    final b = await _renderCompactMapDot(
      dpr: devicePixelRatio,
      hasBeenTo: hasBeenTo,
    );
    _cache.set(key, b);
    return b;
  }

  // ==================================================================
  //  PUBLIC API — Cluster (two-pin stack + overflow dots)
  // ==================================================================

  static Future<Uint8List> createClusterPinWithBadge({
    String? emoji,
    int pointCount = 2,
    double devicePixelRatio = 3.0,
    Color? surfaceColor,
    String? cuisine,
    String? types,
    List<Color> avatarColors = const [],
    double wavyScore = 0.0,
    double bossmanScore = 0.0,
    int savedCount = 0,
    double? rating,
    List<double>? vibeVector,
    int fallbackSeed = 0,
    bool hasBeenTo = false,
  }) async {
    final fillColor = surfaceColor ?? _pinFillColor;
    final isAccent = _isAccentMarker(rating);
    final shadowStyle = markerShadowStyle(
      rating: rating,
      wavyScore: wavyScore,
      bossmanScore: bossmanScore,
      savedCount: savedCount,
      cuisine: cuisine,
      types: types,
    );
    final avatarKey = avatarColors.map((c) => c.toARGB32()).join(',');
    final visual = _resolveMarkerVisual(
      emoji: emoji,
      vibeVector: vibeVector,
      fallbackSeed: fallbackSeed,
    );

    final key = 'cfan9|${visual.key}'
        '|${devicePixelRatio.toStringAsFixed(2)}|${fillColor.toARGB32()}'
        '|${shadowStyle.key}|$avatarKey'
        '|${wavyScore.toStringAsFixed(2)}|${bossmanScore.toStringAsFixed(2)}'
        '|$savedCount|$pointCount|been:$hasBeenTo';

    final cached = _cache.get(key);
    if (cached != null) return cached;

    final b = await _renderClusterFan(
      visual: visual,
      dpr: devicePixelRatio,
      fillColor: fillColor,
      shadowColor: shadowStyle.color,
      isAccent: isAccent,
      avatarColors: avatarColors,
      wavyScore: wavyScore,
      bossmanScore: bossmanScore,
      savedCount: savedCount,
      pointCount: pointCount,
      hasBeenTo: hasBeenTo,
    );
    _cache.set(key, b);
    return b;
  }

  // ==================================================================
  //  PUBLIC API — Legacy cluster (numbered circle, kept for compat)
  // ==================================================================

  static Future<Uint8List> createClusterMarker({
    required int count,
    double devicePixelRatio = 3.0,
    Color surfaceColor = _brandDark,
    Color textColor = const Color(0xFF1F2937),
    bool selected = false,
  }) {
    final key = 'cnum|$count|${devicePixelRatio.toStringAsFixed(2)}'
        '|${surfaceColor.toARGB32()}|${textColor.toARGB32()}|$selected';
    final cached = _cache.get(key);
    if (cached != null) return Future.value(cached);

    return _renderLegacyCluster(
      count: count,
      dpr: devicePixelRatio,
      surfaceColor: surfaceColor,
      textColor: textColor,
      selected: selected,
    ).then((b) {
      _cache.set(key, b);
      return b;
    });
  }

  // ══════════════════════════════════════════════════════════════
  //  PRIVATE — Vibe helpers
  // ══════════════════════════════════════════════════════════════

  /// Returns `true` when the place should get the wavy treatment.
  static bool _isWavy(double wavyScore, double bossmanScore) =>
      wavyScore >= _wavyThreshold;

  /// Returns `true` when the place should be visually muted.
  static bool _isBossman(double wavyScore, double bossmanScore) =>
      bossmanScore >= _bossmanThreshold && wavyScore < _wavyThreshold;

  // ══════════════════════════════════════════════════════════════
  //  PRIVATE — Shared drawing helpers
  // ══════════════════════════════════════════════════════════════

  static ({String glyph, Color color, double fontSize})? _badgeVisualForType(
      String? badgeType) {
    switch (badgeType) {
      case PinitMarkerBadgeType.sparkle:
        return (
          glyph: '✦',
          color: const Color(0xFFFFB800),
          fontSize: 5.2,
        );
      case PinitMarkerBadgeType.liveMusic:
        return (
          glyph: '♫',
          color: const Color(0xFFFF3B30),
          fontSize: 5.1,
        );
      case PinitMarkerBadgeType.cocktails:
        return (
          glyph: '🍸',
          color: const Color(0xFFBA68C8),
          fontSize: 5.0,
        );
      case PinitMarkerBadgeType.outdoor:
        return (
          glyph: '☀',
          color: const Color(0xFF34C759),
          fontSize: 5.2,
        );
      case PinitMarkerBadgeType.trending:
        return (
          glyph: '🔥',
          color: const Color(0xFFFF9500),
          fontSize: 5.0,
        );
      case PinitMarkerBadgeType.late:
        return (
          glyph: '🌙',
          color: const Color(0xFF5856D6),
          fontSize: 5.0,
        );
      default:
        return null;
    }
  }

  static void _drawPersonalityBadge(
    Canvas canvas, {
    required Offset centre,
    required double radius,
    required double dpr,
    String? badgeType,
  }) {
    final visual = _badgeVisualForType(badgeType);
    if (visual == null) return;

    final double badgeRadius = 6.2 * dpr;
    final bubbleRect = _bubbleRectFor(centre: centre, radius: radius);
    final Offset badgeCenter = Offset(
      bubbleRect.right - badgeRadius * 0.75,
      bubbleRect.top + badgeRadius * 0.78,
    );

    canvas.drawCircle(
      badgeCenter,
      badgeRadius + 1.2 * dpr,
      Paint()..color = Colors.white,
    );

    canvas.drawCircle(
      badgeCenter,
      badgeRadius,
      Paint()..color = visual.color,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: visual.glyph,
        style: TextStyle(
          fontSize: visual.fontSize * dpr,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        badgeCenter.dx - textPainter.width / 2,
        badgeCenter.dy - textPainter.height / 2 - 0.2 * dpr,
      ),
    );
  }

  /// Draws the teardrop pointer / tail beneath the bubble.
  static void _drawPointerTail(
    Canvas canvas, {
    required Offset bubbleCentre,
    required double bubbleRadius,
    required double dpr,
    required Color fillColor,
    required Color shadowColor,
    required Color outlineColor,
  }) {
    final bubbleRect = _bubbleRectFor(
      centre: bubbleCentre,
      radius: bubbleRadius,
    );
    final double tailHeight = bubbleRadius * 0.52;
    final double tailHalfW = bubbleRadius * 0.28;
    final double topY = bubbleRect.bottom - bubbleRect.height * 0.12;
    final double tipY = bubbleRect.bottom + tailHeight;

    final path = Path()
      ..moveTo(bubbleCentre.dx - tailHalfW, topY)
      ..cubicTo(
        bubbleCentre.dx - tailHalfW * 0.72,
        topY + tailHeight * 0.34,
        bubbleCentre.dx - tailHalfW * 0.18,
        tipY - tailHeight * 0.1,
        bubbleCentre.dx,
        tipY,
      )
      ..cubicTo(
        bubbleCentre.dx + tailHalfW * 0.18,
        tipY - tailHeight * 0.1,
        bubbleCentre.dx + tailHalfW * 0.72,
        topY + tailHeight * 0.34,
        bubbleCentre.dx + tailHalfW,
        topY,
      )
      ..close();

    final shadowPath = path.shift(_hardShadowOffsetFor(dpr));
    canvas.drawPath(
      shadowPath,
      Paint()..color = shadowColor,
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(bubbleCentre.dx, topY),
          Offset(bubbleCentre.dx, tipY),
          [
            Color.lerp(fillColor, Colors.white, 0.08)!,
            Color.lerp(fillColor, pinit.PinitColors.creamSunk, 0.75)!,
          ],
        ),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * dpr,
    );
  }

  /// Draws the segmented avatar ring around the bubble.
  static void _drawAvatarRing(
    Canvas canvas, {
    required Offset centre,
    required double innerRadius,
    required double dpr,
    required List<Color> colors,
  }) {
    if (colors.isEmpty) return;

    final double ringWidth = 2.4 * dpr;
    final double ringRadius = innerRadius + ringWidth / 2 + 1.2 * dpr;
    final double gapRadians = colors.length == 1 ? 0 : 0.08;
    final double totalGap = gapRadians * colors.length;
    final double arcPerSegment = (2 * math.pi - totalGap) / colors.length;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: ringRadius),
        startAngle,
        arcPerSegment,
        false,
        paint,
      );

      startAngle += arcPerSegment + gapRadians;
    }
  }

  /// Draws a single pin circle with gradient, shadow, and inner highlight.
  static Future<void> _drawPinBubble(
    Canvas canvas, {
    required Offset centre,
    required double radius,
    required double dpr,
    required Color fillColor,
    required Color shadowColor,
    required Color outlineColor,
    required _MarkerVisual visual,
    bool selected = false,
    bool showVisual = true,
  }) async {
    final shadowOffset = _hardShadowOffsetFor(dpr);
    final bubbleShape = _bubbleRRectFor(centre: centre, radius: radius);
    final shadowShape = bubbleShape.shift(shadowOffset);
    final bubbleRect = bubbleShape.outerRect;

    if (selected) {
      canvas.drawRRect(
        _bubbleRRectFor(
          centre: centre,
          radius: radius,
          inflate: 1.8 * dpr,
        ),
        Paint()..color = pinit.PinitColors.cream,
      );
    }

    canvas.drawRRect(
      shadowShape,
      Paint()..color = shadowColor,
    );

    canvas.drawRRect(
      bubbleShape,
      Paint()
        ..shader = ui.Gradient.linear(
          bubbleRect.topLeft,
          bubbleRect.bottomRight,
          [
            Color.lerp(fillColor, Colors.white, 0.24)!,
            fillColor,
            Color.lerp(fillColor, pinit.PinitColors.creamSunk, 0.76)!,
          ],
          [0.0, 0.54, 1.0],
        ),
    );

    canvas.drawRRect(
      bubbleShape,
      Paint()
        ..color = outlineColor.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9 * dpr,
    );

    if (!showVisual) {
      // Used for the background cluster shell.
    } else if (visual.emoji != null) {
      await _drawEmoji(
        canvas,
        centre: centre,
        size: radius * 1.5,
        emoji: visual.emoji!,
      );
    }

    canvas.drawRRect(
      _bubbleRRectFor(
        centre: centre,
        radius: radius,
        inflate: -1.15 * dpr,
      ),
      Paint()
        ..color = const Color(0x50FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * dpr,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(
            bubbleRect.left + bubbleRect.width * 0.34,
            bubbleRect.top + bubbleRect.height * 0.32,
          ),
          width: bubbleRect.width * 0.34,
          height: bubbleRect.height * 0.24,
        ),
        Radius.circular(bubbleRect.height * 0.14),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  static int _overflowDotCountForClusterSize(int pointCount) {
    if (pointCount <= 2) return 0;
    return math.min(3, pointCount - 2);
  }

  static void _drawClusterOverflowDots(
    Canvas canvas, {
    required Offset centre,
    required double radius,
    required double dpr,
    required int pointCount,
    required Color fillColor,
  }) {
    final dotCount = _overflowDotCountForClusterSize(pointCount);
    if (dotCount == 0) return;

    final bubbleRect = _bubbleRectFor(centre: centre, radius: radius);
    final baseCenter = Offset(
      bubbleRect.right + 0.9 * dpr,
      bubbleRect.top + 1.9 * dpr,
    );
    final dotRadius = 2.25 * dpr;
    final dotStepX = 3.8 * dpr;
    final dotStepY = 2.4 * dpr;
    final shadowOffset = _hardShadowOffsetFor(dpr) * 0.32;
    final shadowPaint = Paint()..color = fillColor.withValues(alpha: 0.26);
    final fillPaint = Paint()..color = fillColor;
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9 * dpr;

    for (var index = 0; index < dotCount; index++) {
      final dotCenter = Offset(
        baseCenter.dx - dotStepX * (dotCount - 1 - index),
        baseCenter.dy + dotStepY * index,
      );
      canvas.drawCircle(dotCenter + shadowOffset, dotRadius, shadowPaint);
      canvas.drawCircle(dotCenter, dotRadius, fillPaint);
      canvas.drawCircle(dotCenter, dotRadius, strokePaint);
    }
  }

  /// Draws an emoji centred at [centre].
  static Future<void> _drawEmoji(
    Canvas canvas, {
    required Offset centre,
    required double size,
    required String emoji,
  }) async {
    final image = await _loadEmojiImage(emoji);
    if (image != null) {
      final srcRect = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final dstRect = Rect.fromCenter(
        center: centre,
        width: size,
        height: size,
      );
      canvas.drawImageRect(
        image,
        srcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.high,
      );
      return;
    }

    _drawNativeEmoji(
      canvas,
      centre: centre,
      size: size,
      emoji: emoji,
    );
  }

  static void _drawNativeEmoji(
    Canvas canvas, {
    required Offset centre,
    required double size,
    required String emoji,
  }) {
    final p = TextPainter(
      text: TextSpan(text: emoji, style: TextStyle(fontSize: size)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    p.paint(canvas, Offset(centre.dx - p.width / 2, centre.dy - p.height / 2));
  }

  static Future<ui.Image?> _loadEmojiImage(String emoji) {
    final sanitizedEmoji = _sanitizeEmoji(emoji);
    if (sanitizedEmoji == null) return Future.value(null);

    return _emojiImageCache.putIfAbsent(
      sanitizedEmoji,
      () async {
        for (final assetPath in _emojiAssetCandidates(sanitizedEmoji)) {
          try {
            final pictureInfo = await svg.vg.loadPicture(
              svg.SvgAssetLoader(assetPath),
              null,
            );
            final width = pictureInfo.size.width.ceil().clamp(1, 512);
            final height = pictureInfo.size.height.ceil().clamp(1, 512);
            final image = await pictureInfo.picture.toImage(width, height);
            pictureInfo.picture.dispose();
            return image;
          } catch (_) {
            continue;
          }
        }
        return null;
      },
    );
  }

  static Iterable<String> _emojiAssetCandidates(String emoji) sync* {
    final seen = <String>{};
    for (final codePoints in [
      _emojiCodePoints(emoji, stripVariationSelectors: false),
      _emojiCodePoints(emoji, stripVariationSelectors: true),
    ]) {
      if (codePoints.isEmpty) continue;
      final assetPath = '$_openMojiAssetDirectory/${codePoints.join('-')}.svg';
      if (seen.add(assetPath)) {
        yield assetPath;
      }
    }
  }

  static List<String> _emojiCodePoints(
    String emoji, {
    required bool stripVariationSelectors,
  }) {
    return emoji.runes
        .where((codePoint) {
          if (!stripVariationSelectors) return true;
          return codePoint != 0xFE0F && codePoint != 0xFE0E;
        })
        .map((codePoint) => codePoint.toRadixString(16).toUpperCase())
        .toList();
  }

  // ══════════════════════════════════════════════════════════════
  //  RENDER — Single Pin
  // ══════════════════════════════════════════════════════════════

  static Future<Uint8List> _renderSinglePin({
    required _MarkerVisual visual,
    required String name,
    required double dpr,
    required Color fillColor,
    required Color shadowColor,
    required bool isAccent,
    required Color textColor,
    required bool selected,
    required bool showText,
    required List<Color> avatarColors,
    required double wavyScore,
    required double bossmanScore,
    required int savedCount,
    required double matchScore,
    String? badgeType,
  }) async {
    // ── Determine vibe mode ──
    final bool isBossman = _isBossman(wavyScore, bossmanScore);
    final Color effectiveFillColor = fillColor;
    final Color effectiveOutlineColor = _pinStrokeColor;

    final double selectionScale = selected ? _selectedPinScale : 1.0;
    final double bubR =
        _pinBubbleDiameterForSavedCount(savedCount) / 2 * dpr * selectionScale;
    final double tailH = bubR * 0.55;
    final double avatarRingExtra = avatarColors.isNotEmpty ? 3.6 * dpr : 0;
    final double ringSpace = avatarRingExtra;
    final double shadowExtra = _hardShadowOffset * dpr;
    final bubbleOuterSize = _bubbleSizeForRadius(bubR + ringSpace);

    // Text metrics
    final double fontSize = 4.6 * dpr;
    final double maxTextW = 52.0 * dpr;
    final double textGap = (selected ? 6.6 : 5.0) * dpr;
    final double pillPadH = 6.0 * dpr;
    final double pillPadV = 3.0 * dpr;
    final double pillRad = 5.0 * dpr;

    final tp = TextPainter(
      text: TextSpan(
        text: name,
        style: GoogleFonts.inter(
          color: isBossman ? _pinLabelMutedColor : textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1 * dpr,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    );
    if (showText) tp.layout(maxWidth: maxTextW);

    final double textW = showText ? tp.width : 0;
    final double textH = showText ? tp.height : 0;
    final double pillW = showText ? textW + pillPadH * 2 : 0;
    final double pillH = showText ? textH + pillPadV * 2 : 0;

    final double selBorder = selected ? 1.6 * dpr : 0;
    final double pad = selBorder + ringSpace + shadowExtra + 4;

    final double totalW = showText
        ? bubbleOuterSize.width + textGap + pillW
        : bubbleOuterSize.width;
    final double totalH = math.max(bubbleOuterSize.height, pillH) + tailH;

    final int outW = (totalW + pad * 2).ceil();
    final int outH = (totalH + pad * 2).ceil();

    final rec = ui.PictureRecorder();
    final c = Canvas(rec);

    final centre = Offset(
      bubbleOuterSize.width / 2 + pad,
      bubbleOuterSize.height / 2 + pad,
    );

    // 1. Pointer tail
    _drawPointerTail(c,
        bubbleCentre: centre,
        bubbleRadius: bubR,
        dpr: dpr,
        fillColor: effectiveFillColor,
        shadowColor: shadowColor,
        outlineColor: effectiveOutlineColor);

    // 2. Avatar ring
    if (avatarColors.isNotEmpty) {
      _drawAvatarRing(c,
          centre: centre, innerRadius: bubR, dpr: dpr, colors: avatarColors);
    }

    // 3. Bubble
    await _drawPinBubble(c,
        centre: centre,
        radius: bubR,
        dpr: dpr,
        fillColor: effectiveFillColor,
        shadowColor: shadowColor,
        outlineColor: effectiveOutlineColor,
        selected: selected,
        visual: visual);

    _drawPersonalityBadge(
      c,
      centre: centre,
      radius: bubR,
      dpr: dpr,
      badgeType: badgeType,
    );

    // 7. Pill label
    if (showText) {
      final double px =
          _bubbleRectFor(centre: centre, radius: bubR + ringSpace).right +
              textGap;
      final double py = centre.dy - pillH / 2;
      final pillShape = RRect.fromRectAndRadius(
        Rect.fromLTWH(px, py, pillW, pillH),
        Radius.circular(pillRad),
      );

      c.drawRRect(
        pillShape.shift(_hardShadowOffsetFor(dpr)),
        Paint()..color = shadowColor,
      );

      // Pill background
      c.drawRRect(
        pillShape,
        Paint()..color = pinit.PinitColors.cream.withValues(alpha: 0.96),
      );
      c.drawRRect(
        pillShape,
        Paint()
          ..color = effectiveOutlineColor.withValues(alpha: 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8 * dpr,
      );
      // Text
      tp.paint(c, Offset(px + pillPadH, py + pillPadV));
    }

    return _rasterise(rec, outW, outH);
  }

  // ══════════════════════════════════════════════════════════════
  //  RENDER — Cluster stack (one back pin + overflow dots)
  // ══════════════════════════════════════════════════════════════

  static Future<Uint8List> _renderClusterFan({
    required _MarkerVisual visual,
    required double dpr,
    required Color fillColor,
    required Color shadowColor,
    required bool isAccent,
    required List<Color> avatarColors,
    required double wavyScore,
    required double bossmanScore,
    required int savedCount,
    required int pointCount,
    required bool hasBeenTo,
  }) async {
    // ── Vibe mode ──
    final Color effectiveFillColor = fillColor;
    final Color effectiveOutlineColor = _pinStrokeColor;

    final double bubR = _pinBubbleDiameterForSavedCount(savedCount) / 2 * dpr;
    final double tailH = bubR * 0.55;
    final double shadowExtra = _hardShadowOffset * dpr;
    final double avatarRingExtra = avatarColors.isNotEmpty ? 3.6 * dpr : 0;
    final double ringSpace = avatarRingExtra;
    final bubbleOuterSize = _bubbleSizeForRadius(bubR + ringSpace);
    final Offset backPinOffset = Offset(-bubR * 0.34, -bubR * 0.28);
    final double backPinExtraLeft = bubR * 0.52;
    final double backPinExtraTop = bubR * 0.44;
    final int overflowDotCount = _overflowDotCountForClusterSize(pointCount);
    final double badgeExtraTop = overflowDotCount == 0 ? 4.0 * dpr : 11.5 * dpr;
    final double overflowDotsExtraRight =
        overflowDotCount == 0 ? 0.0 : 3.4 * dpr;
    final double leftPad = shadowExtra + avatarRingExtra + backPinExtraLeft;
    final double rightPad =
        shadowExtra + avatarRingExtra + overflowDotsExtraRight;
    final double topPad =
        shadowExtra + avatarRingExtra + backPinExtraTop + badgeExtraTop;
    final double bottomPad = shadowExtra + 2.0 * dpr;

    final int outW = (bubbleOuterSize.width + leftPad + rightPad).ceil();
    final int outH =
        (bubbleOuterSize.height + topPad + bottomPad + tailH).ceil();

    final rec = ui.PictureRecorder();
    final c = Canvas(rec);

    final Offset mainCentre = Offset(
      leftPad + bubbleOuterSize.width / 2,
      topPad + bubbleOuterSize.height / 2,
    );
    final Offset backCentre = mainCentre + backPinOffset;
    final double backRadius = bubR * 0.94;
    final Color backFillColor = Color.lerp(
      effectiveFillColor,
      pinit.PinitColors.cream,
      0.18,
    )!;
    final Color backOutlineColor = Color.lerp(
      effectiveOutlineColor,
      pinit.PinitColors.cream,
      0.08,
    )!;

    _drawPointerTail(c,
        bubbleCentre: backCentre,
        bubbleRadius: backRadius,
        dpr: dpr,
        fillColor: backFillColor.withValues(alpha: 0.96),
        shadowColor: shadowColor.withValues(alpha: 0.82),
        outlineColor: backOutlineColor.withValues(alpha: 0.74));

    await _drawPinBubble(c,
        centre: backCentre,
        radius: backRadius,
        dpr: dpr,
        fillColor: backFillColor.withValues(alpha: 0.96),
        shadowColor: shadowColor.withValues(alpha: 0.82),
        outlineColor: backOutlineColor.withValues(alpha: 0.82),
        visual: visual,
        showVisual: false);

    // ─── 1. Pointer tail ─────────────────────────────────────
    _drawPointerTail(c,
        bubbleCentre: mainCentre,
        bubbleRadius: bubR,
        dpr: dpr,
        fillColor: effectiveFillColor,
        shadowColor: shadowColor,
        outlineColor: effectiveOutlineColor);

    // ─── 2. Avatar ring ──────────────────────────────────────
    if (avatarColors.isNotEmpty) {
      _drawAvatarRing(c,
          centre: mainCentre,
          innerRadius: bubR,
          dpr: dpr,
          colors: avatarColors);
    }

    // ─── 3. Main pin ─────────────────────────────────────────
    await _drawPinBubble(c,
        centre: mainCentre,
        radius: bubR,
        dpr: dpr,
        fillColor: effectiveFillColor,
        shadowColor: shadowColor,
        outlineColor: effectiveOutlineColor,
        visual: visual);

    // ─── 6. Overflow dots for hidden pins ────────────────────
    _drawClusterOverflowDots(
      c,
      centre: mainCentre,
      radius: bubR,
      dpr: dpr,
      pointCount: pointCount,
      fillColor:
          hasBeenTo ? pinit.PinitColors.warning : pinit.PinitColors.aubergine,
    );

    return _rasterise(rec, outW, outH);
  }

  // ══════════════════════════════════════════════════════════════
  //  RENDER — Dense viewport dot
  // ══════════════════════════════════════════════════════════════

  static Future<Uint8List> _renderCompactMapDot({
    required double dpr,
    required bool hasBeenTo,
  }) async {
    final fillColor =
        hasBeenTo ? pinit.PinitColors.warning : pinit.PinitColors.aubergine;
    final dotRadius = 4.0 * dpr;
    final strokeWidth = 1.0 * dpr;
    final shadowRadius = dotRadius + 0.8 * dpr;
    final shadowOffset = Offset(1.4 * dpr, 1.8 * dpr);
    final pad = 4.0 * dpr;

    final outW = (dotRadius * 2 + shadowOffset.dx + pad * 2).ceil();
    final outH = (dotRadius * 2 + shadowOffset.dy + pad * 2).ceil();

    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final center = Offset(
      pad + dotRadius,
      pad + dotRadius,
    );

    canvas.drawCircle(
      center + shadowOffset,
      shadowRadius,
      Paint()..color = fillColor.withValues(alpha: 0.18),
    );

    canvas.drawCircle(
      center,
      dotRadius,
      Paint()..color = fillColor,
    );

    canvas.drawCircle(
      center,
      dotRadius,
      Paint()
        ..color = pinit.PinitColors.cream.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    canvas.drawCircle(
      Offset(center.dx - 0.9 * dpr, center.dy - 1.0 * dpr),
      1.2 * dpr,
      Paint()..color = Colors.white.withValues(alpha: 0.42),
    );

    return _rasterise(rec, outW, outH);
  }

  // ══════════════════════════════════════════════════════════════
  //  RENDER — Legacy numbered cluster (kept for compatibility)
  // ══════════════════════════════════════════════════════════════

  static Future<Uint8List> _renderLegacyCluster({
    required int count,
    required double dpr,
    required Color surfaceColor,
    required Color textColor,
    required bool selected,
  }) async {
    final double diameter = 14.0 * dpr;
    final double borderW = 1.4 * dpr;
    final String label = count > 99 ? '99+' : count.toString();

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: AppTypography.brand(
          color: Colors.white,
          fontSize: diameter * 0.45,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final double selBW = selected ? borderW : 0;
    final double pad = selBW + 3 * dpr;
    final int outW = (diameter + pad * 2).ceil();
    final int outH = (diameter + pad * 2).ceil();

    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final Offset ctr = Offset(diameter / 2 + pad, diameter / 2 + pad);

    if (selected) {
      c.drawCircle(ctr, diameter / 2 + selBW, Paint()..color = Colors.white);
    }
    c.drawCircle(ctr, diameter / 2, Paint()..color = surfaceColor);
    tp.paint(c, Offset(ctr.dx - tp.width / 2, ctr.dy - tp.height / 2));

    return _rasterise(rec, outW, outH);
  }

  // ══════════════════════════════════════════════════════════════
  //  Rasterisation helper
  // ══════════════════════════════════════════════════════════════

  static Future<Uint8List> _rasterise(
      ui.PictureRecorder rec, int w, int h) async {
    final picture = rec.endRecording();
    final ui.Image img = await picture.toImage(w, h);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}

// ─────────────────────────────────────────────────────────────
//  Marker visual selection
// ─────────────────────────────────────────────────────────────
class _MarkerVisual {
  const _MarkerVisual._({
    required this.key,
    this.emoji,
  });

  final String key;
  final String? emoji;

  factory _MarkerVisual.emoji(String emoji, {String? key}) {
    return _MarkerVisual._(
      key: key ?? 'emoji:$emoji',
      emoji: emoji,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  LRU bitmap cache
// ─────────────────────────────────────────────────────────────
class _BitmapCache {
  final int maxEntries;
  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();

  _BitmapCache({required this.maxEntries});

  Uint8List? get(String key) {
    final value = _cache.remove(key);
    if (value != null) _cache[key] = value;
    return value;
  }

  void set(String key, Uint8List value) {
    if (_cache.length >= maxEntries) _cache.remove(_cache.keys.first);
    _cache[key] = value;
  }
}

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

// ─────────────────────────────────────────────────────────────
//  Main entry‑point for all marker bitmap generation
// ─────────────────────────────────────────────────────────────
class PinitMarkers {
  static final _BitmapCache _cache = _BitmapCache(maxEntries: 256);

  /// Logical bubble diameter — bumped up for better readability & presence.
  static const double pinBubbleDiameter = 32.0;

  // ── Brand colours ──
  static const Color _brandDark = Color(0xFF42143D);

  // ── Vibe thresholds ──
  /// A place is considered "wavy" when its wavy score exceeds this.
  static const double _wavyThreshold = 0.35;

  /// A place is considered "bossman" when its bossman score exceeds this
  /// AND it is *not* also wavy.
  static const double _bossmanThreshold = 0.35;

  // ── Saved-count glow mapping ──
  /// Minimum glow intensity (used when savedCount == 0).
  static const double _glowIntensityMin = 0.18;

  /// Maximum glow intensity (reached when savedCount >= _savedCountCap).
  static const double _glowIntensityMax = 0.52;

  /// savedCount at (or above) which glow is maxed out.
  static const int _savedCountCap = 20;

  /// Maps a savedCount to a glow intensity value.
  static double _glowForSavedCount(int savedCount) {
    if (savedCount <= 0) return _glowIntensityMin;
    final double t = (savedCount / _savedCountCap).clamp(0.0, 1.0);
    // Ease-out curve so even a few saves make a visible difference.
    final double ease = 1.0 - math.pow(1.0 - t, 2.5);
    return _glowIntensityMin + (_glowIntensityMax - _glowIntensityMin) * ease;
  }

  // ==================================================================
  //  PUBLIC API — Single pin
  // ==================================================================

  /// Creates a single pin marker with:
  ///  • Soft outer glow (intensity driven by [savedCount])
  ///  • Gradient bubble with inner highlight
  ///  • Downward‑pointing teardrop tail
  ///  • Optional avatar ring showing who recommended the place
  ///  • Optional text pill with the place name
  ///  • **Wavy shimmer ring** when [wavyScore] > threshold
  ///  • **Bossman de-saturation** when [bossmanScore] > threshold
  ///
  /// [wavyScore]    — value from vibe vector index 23 (0.0–1.0).
  /// [bossmanScore] — value from vibe vector index 24 (0.0–1.0).
  /// [savedCount]   — number of users who saved this place.
  static Future<Uint8List> createPinitMarker({
    required String emoji,
    required String name,
    double devicePixelRatio = 3.0,
    Color? surfaceColor,
    Color textColor = const Color(0xFF6B4A8E),
    bool selected = false,
    String? types,
    String? cuisine,
    bool showText = true,
    List<Color> avatarColors = const [],
    double wavyScore = 0.0,
    double bossmanScore = 0.0,
    int savedCount = 0,
    double matchScore = 0.0,
  }) {
    final color =
        surfaceColor ?? PinitMarkerPalette.forCuisine(cuisine, types);
    final avatarKey = avatarColors.map((c) => c.value).join(',');
    final key = 'pin3|$emoji|$name|${devicePixelRatio.toStringAsFixed(2)}'
        '|${color.value}|${textColor.value}|$selected|$showText|$avatarKey'
        '|${wavyScore.toStringAsFixed(2)}|${bossmanScore.toStringAsFixed(2)}'
        '|$savedCount|${matchScore.toStringAsFixed(2)}';
    final cached = _cache.get(key);
    if (cached != null) return Future.value(cached);

    return _renderSinglePin(
      emoji: emoji,
      name: name,
      dpr: devicePixelRatio,
      color: color,
      textColor: textColor,
      selected: selected,
      showText: showText,
      avatarColors: avatarColors,
      wavyScore: wavyScore,
      bossmanScore: bossmanScore,
      savedCount: savedCount,
      matchScore: matchScore,
    ).then((b) {
      _cache.set(key, b);
      return b;
    });
  }

  // ==================================================================
  //  PUBLIC API — Cluster (stacked fan + badge)
  // ==================================================================

  static Future<Uint8List> createClusterPinWithBadge({
    required String emoji,
    required int remainingCount,
    double devicePixelRatio = 3.0,
    Color? surfaceColor,
    String? cuisine,
    String? types,
    List<Color> avatarColors = const [],
    double wavyScore = 0.0,
    double bossmanScore = 0.0,
    int savedCount = 0,
  }) {
    final color =
        surfaceColor ?? PinitMarkerPalette.forCuisine(cuisine, types);
    final avatarKey = avatarColors.map((c) => c.value).join(',');
    final key = 'cfan4|$emoji|$remainingCount'
        '|${devicePixelRatio.toStringAsFixed(2)}|${color.value}|$avatarKey'
        '|${wavyScore.toStringAsFixed(2)}|${bossmanScore.toStringAsFixed(2)}'
        '|$savedCount';
    final cached = _cache.get(key);
    if (cached != null) return Future.value(cached);

    return _renderClusterFan(
      emoji: emoji,
      remainingCount: remainingCount,
      dpr: devicePixelRatio,
      color: color,
      avatarColors: avatarColors,
      wavyScore: wavyScore,
      bossmanScore: bossmanScore,
      savedCount: savedCount,
    ).then((b) {
      _cache.set(key, b);
      return b;
    });
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
        '|${surfaceColor.value}|${textColor.value}|$selected';
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

  /// Desaturates [color] by blending toward a neutral grey.
  /// [amount] 0.0 = no change, 1.0 = fully grey.
  static Color _desaturate(Color color, double amount) {
    // Convert to HSL, reduce saturation, convert back.
    final hsl = HSLColor.fromColor(color);
    final muted = hsl.withSaturation(
      (hsl.saturation * (1.0 - amount)).clamp(0.0, 1.0),
    );
    // Also nudge lightness slightly toward the middle for a "flat" feel.
    final flatLightness =
        muted.lightness + (0.55 - muted.lightness) * amount * 0.3;
    return muted
        .withLightness(flatLightness.clamp(0.0, 1.0))
        .toColor();
  }

  // ══════════════════════════════════════════════════════════════
  //  PRIVATE — Shared drawing helpers
  // ══════════════════════════════════════════════════════════════

  /// Draws the soft outer glow behind a pin.  Uses two stacked blurred
  /// circles at different radii for a natural fall‑off.
  static void _drawGlow(
    Canvas canvas, {
    required Offset centre,
    required double radius,
    required double dpr,
    required Color color,
    double intensity = 0.28,
  }) {
    // Outer wide glow
    canvas.drawCircle(
      centre,
      radius * 1.7,
      Paint()
        ..color = color.withOpacity(intensity * 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.9),
    );
    // Inner tighter glow
    canvas.drawCircle(
      centre,
      radius * 1.15,
      Paint()
        ..color = color.withOpacity(intensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.45),
    );
  }

  /// Draws a secondary iridescent glow for wavy pins — two extra
  /// blurred circles in contrasting hues offset slightly to create a
  /// colour-fringe / holographic feel around the pin.
  static void _drawWavyGlow(
    Canvas canvas, {
    required Offset centre,
    required double radius,
    required double dpr,
    required double wavyScore,
  }) {
    // Intensity scales with how wavy the place is (0.35 → subtle, 1.0 → vivid).
    final double t =
        ((wavyScore - _wavyThreshold) / (1.0 - _wavyThreshold)).clamp(0.0, 1.0);
    final double alpha = 0.12 + 0.16 * t; // 0.12–0.28

    // Magenta halo — offset left
    canvas.drawCircle(
      Offset(centre.dx - radius * 0.25, centre.dy),
      radius * 1.35,
      Paint()
        ..color = const Color(0xFFE040FB).withOpacity(alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.7),
    );

    // Cyan halo — offset right
    canvas.drawCircle(
      Offset(centre.dx + radius * 0.25, centre.dy),
      radius * 1.35,
      Paint()
        ..color = const Color(0xFF18FFFF).withOpacity(alpha * 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.7),
    );
  }

  /// Draws a shimmering iridescent ring around wavy pins.
  /// The ring uses a sweep gradient that cycles through vibrant hues,
  /// giving it an oil-slick / holographic look.
  static void _drawWavyRing(
    Canvas canvas, {
    required Offset centre,
    required double innerRadius,
    required double dpr,
    required double wavyScore,
  }) {
    // Ring geometry — sits just outside the white border.
    final double ringWidth = 2.2 * dpr;
    final double ringRadius = innerRadius + ringWidth / 2 + 1.6 * dpr;

    // Opacity scales with wavyScore intensity.
    final double t =
        ((wavyScore - _wavyThreshold) / (1.0 - _wavyThreshold)).clamp(0.0, 1.0);
    final double ringOpacity = 0.65 + 0.35 * t; // 0.65–1.0

    // Build the sweep gradient stops from the wavy palette.
    final colors = PinitMarkerPalette.wavyGradient
        .map((c) => c.withOpacity(ringOpacity))
        .toList();
    final stops = List<double>.generate(
      colors.length,
      (i) => i / (colors.length - 1),
    );

    final paint = Paint()
      ..shader = ui.Gradient.sweep(
        centre,
        colors,
        stops,
        TileMode.clamp,
        0, // startAngle
        2 * math.pi, // endAngle
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(centre, ringRadius, paint);
  }

  /// Draws a shimmer ring for high match score locations (>50%).
  /// More intense shimmer for higher match scores.
  static void _drawMatchScoreShimmer(
    Canvas canvas, {
    required Offset centre,
    required double outerRadius,
    required double dpr,
    required double matchScore,
  }) {
    // Ring geometry — outside the avatar ring
    final double shimmerWidth = 1.8 * dpr;
    final double shimmerRadius = outerRadius + shimmerWidth / 2 + 2.0 * dpr;

    // Intensity scales with match score (0.5–1.0)
    final double t = ((matchScore - 0.5) / 0.5).clamp(0.0, 1.0);
    final double shimmerOpacity = 0.3 + 0.5 * t; // 0.3–0.8

    // Warm golden shimmer for high match scores
    final Color baseColor = Color.lerp(
      const Color(0xFFFFB800),
      const Color(0xFFFF6B9D),
      (t * 0.3).clamp(0.0, 1.0),
    )!;

    // Draw dual-layer glow for depth
    // Outer soft glow
    canvas.drawCircle(
      centre,
      shimmerRadius + 1.5 * dpr,
      Paint()
        ..color = baseColor.withOpacity(shimmerOpacity * 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * dpr),
    );

    // Inner shimmer ring
    canvas.drawCircle(
      centre,
      shimmerRadius,
      Paint()
        ..color = baseColor.withOpacity(shimmerOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = shimmerWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Draws the teardrop pointer / tail beneath the bubble.
  static void _drawPointerTail(
    Canvas canvas, {
    required Offset bubbleCentre,
    required double bubbleRadius,
    required double dpr,
    required Color color,
  }) {
    final double tailHeight = bubbleRadius * 0.55;
    final double tailHalfW = bubbleRadius * 0.32;

    final double topY = bubbleCentre.dy + bubbleRadius * 0.75;
    final double tipY = bubbleCentre.dy + bubbleRadius + tailHeight;

    final path = Path()
      ..moveTo(bubbleCentre.dx - tailHalfW, topY)
      ..quadraticBezierTo(
        bubbleCentre.dx,
        tipY + 1.0 * dpr,
        bubbleCentre.dx + tailHalfW,
        topY,
      )
      ..close();

    // Tail shadow
    canvas.drawPath(
      path.shift(Offset(0, 1.0 * dpr)),
      Paint()
        ..color = const Color(0x25000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * dpr),
    );

    // Tail fill
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(bubbleCentre.dx, topY),
          Offset(bubbleCentre.dx, tipY),
          [
            color,
            Color.lerp(color, Colors.black, 0.18)!,
          ],
        ),
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
    final double arcPerSegment =
        (2 * math.pi - totalGap) / colors.length;

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
  static Offset _drawPinBubble(
    Canvas canvas, {
    required Offset centre,
    required double radius,
    required double dpr,
    required Color color,
    bool selected = false,
    double shadowOpacity = 0.18,
  }) {
    final double shadowOffY = 2.0 * dpr;
    final double shadowSigma = 3.0 * dpr;
    final double borderW = 1.6 * dpr;

    // Drop shadow
    canvas.drawCircle(
      Offset(centre.dx, centre.dy + shadowOffY),
      radius,
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, shadowOpacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowSigma),
    );

    // Selection ring
    if (selected) {
      canvas.drawCircle(
        centre,
        radius + borderW + 1.2 * dpr,
        Paint()..color = Colors.white,
      );
    }

    // White border ring
    canvas.drawCircle(
      centre,
      radius + 1.0 * dpr,
      Paint()..color = Colors.white.withOpacity(0.92),
    );

    // Radial gradient fill — light source top‑left
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(centre.dx - radius * 0.35, centre.dy - radius * 0.35),
          radius * 1.6,
          [
            Color.lerp(color, Colors.white, 0.30)!,
            color,
            Color.lerp(color, Colors.black, 0.15)!,
          ],
          [0.0, 0.45, 1.0],
        ),
    );

    // Inner highlight ring — glossy feel
    canvas.drawCircle(
      centre,
      radius - 1.0 * dpr,
      Paint()
        ..color = const Color(0x50FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * dpr,
    );

    // Top specular dot
    canvas.drawCircle(
      Offset(centre.dx - radius * 0.22, centre.dy - radius * 0.28),
      radius * 0.18,
      Paint()..color = Colors.white.withOpacity(0.35),
    );

    return centre;
  }

  /// Draws an emoji centred at [centre].
  static void _drawEmoji(
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

  // ══════════════════════════════════════════════════════════════
  //  RENDER — Single Pin
  // ══════════════════════════════════════════════════════════════

  static Future<Uint8List> _renderSinglePin({
    required String emoji,
    required String name,
    required double dpr,
    required Color color,
    required Color textColor,
    required bool selected,
    required bool showText,
    required List<Color> avatarColors,
    required double wavyScore,
    required double bossmanScore,
    required int savedCount,
    required double matchScore,
  }) async {
    // ── Determine vibe mode ──
    final bool isWavy = _isWavy(wavyScore, bossmanScore);
    final bool isBossman = _isBossman(wavyScore, bossmanScore);

    // ── Apply bossman desaturation to the base colour ──
    final Color effectiveColor = isBossman
        ? _desaturate(color, 0.55) // noticeably muted
        : color;

    // ── Compute glow intensity from saved count ──
    final double glowIntensity = _glowForSavedCount(savedCount);

    final double bubR = pinBubbleDiameter / 2 * dpr;
    final double tailH = bubR * 0.55;
    final double glowExtra = bubR * 0.9;
    final double avatarRingExtra =
        avatarColors.isNotEmpty ? 3.6 * dpr : 0;
    // Wavy ring sits outside the avatar ring, so reserve extra space.
    final double wavyRingExtra = isWavy ? 4.0 * dpr : 0;
    final double shadowExtra = 5.0 * dpr;

    // Text metrics
    final double fontSize = 4.6 * dpr;
    final double maxTextW = 52.0 * dpr;
    final double textGap = 5.0 * dpr;
    final double pillPadH = 6.0 * dpr;
    final double pillPadV = 3.0 * dpr;
    final double pillRad = 5.0 * dpr;

    final tp = TextPainter(
      text: TextSpan(
        text: name,
        style: GoogleFonts.inter(
          color: isBossman
              ? const Color(0xFF6E6E7A) // muted text for bossman
              : const Color(0xFF1A1A2E),
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

    final double ringSpace = avatarRingExtra + wavyRingExtra;
    final double selBorder = selected ? 1.6 * dpr : 0;
    final double pad =
        selBorder + glowExtra + ringSpace + shadowExtra + 4;

    final double totalW = showText
        ? (bubR + ringSpace) * 2 + textGap + pillW
        : (bubR + ringSpace) * 2;
    final double totalH =
        math.max((bubR + ringSpace) * 2, pillH) + tailH;

    final int outW = (totalW + pad * 2).ceil();
    final int outH = (totalH + pad * 2 + shadowExtra).ceil();

    final rec = ui.PictureRecorder();
    final c = Canvas(rec);

    final centre = Offset(
      bubR + ringSpace + pad,
      bubR + ringSpace + pad,
    );

    // 1. Base glow (intensity driven by savedCount)
    _drawGlow(c,
        centre: centre,
        radius: bubR,
        dpr: dpr,
        color: effectiveColor,
        intensity: glowIntensity);

    // 1b. Extra iridescent glow for wavy pins
    if (isWavy) {
      _drawWavyGlow(c,
          centre: centre,
          radius: bubR,
          dpr: dpr,
          wavyScore: wavyScore);
    }

    // 2. Pointer tail
    _drawPointerTail(c,
        bubbleCentre: centre,
        bubbleRadius: bubR,
        dpr: dpr,
        color: effectiveColor);

    // 3. Wavy shimmer ring (outermost decorative ring)
    if (isWavy) {
      _drawWavyRing(c,
          centre: centre,
          innerRadius: bubR + avatarRingExtra,
          dpr: dpr,
          wavyScore: wavyScore);
    }

    // 3b. Match score shimmer ring (>50% match)
    if (matchScore > 0.3) {
      _drawMatchScoreShimmer(c,
          centre: centre,
          outerRadius: bubR + avatarRingExtra,
          dpr: dpr,
          matchScore: matchScore);
    }

    // 4. Avatar ring
    if (avatarColors.isNotEmpty) {
      _drawAvatarRing(c,
          centre: centre,
          innerRadius: bubR,
          dpr: dpr,
          colors: avatarColors);
    }

    // 5. Bubble
    _drawPinBubble(c,
        centre: centre,
        radius: bubR,
        dpr: dpr,
        color: effectiveColor,
        selected: selected);

    // 6. Emoji
    _drawEmoji(c, centre: centre, size: bubR * 1.2, emoji: emoji);

    // 7. Pill label
    if (showText) {
      final double px =
          centre.dx + bubR + ringSpace + textGap;
      final double py = centre.dy - pillH / 2;

      // Pill shadow
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(px, py + 1.0 * dpr, pillW, pillH),
          Radius.circular(pillRad),
        ),
        Paint()
          ..color = const Color(0x20000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 * dpr),
      );
      // Pill background
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(px, py, pillW, pillH),
          Radius.circular(pillRad),
        ),
        Paint()..color = const Color(0xF0FFFFFF),
      );
      // Pill subtle border — wavy pins get a faint iridescent border
      if (isWavy) {
        final borderPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(px, py),
            Offset(px + pillW, py + pillH),
            [
              const Color(0xFFE040FB).withOpacity(0.35),
              const Color(0xFF448AFF).withOpacity(0.35),
              const Color(0xFF18FFFF).withOpacity(0.35),
            ],
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7 * dpr;
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(px, py, pillW, pillH),
            Radius.circular(pillRad),
          ),
          borderPaint,
        );
      } else {
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(px, py, pillW, pillH),
            Radius.circular(pillRad),
          ),
          Paint()
            ..color = const Color(0x18000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5 * dpr,
        );
      }
      // Text
      tp.paint(c, Offset(px + pillPadH, py + pillPadV));
    }

    return _rasterise(rec, outW, outH);
  }

  // ══════════════════════════════════════════════════════════════
  //  RENDER — Cluster Fan (ghost circles + badge)
  // ══════════════════════════════════════════════════════════════

  static Future<Uint8List> _renderClusterFan({
    required String emoji,
    required int remainingCount,
    required double dpr,
    required Color color,
    required List<Color> avatarColors,
    required double wavyScore,
    required double bossmanScore,
    required int savedCount,
  }) async {
    // ── Vibe mode ──
    final bool isWavy = _isWavy(wavyScore, bossmanScore);
    final bool isBossman = _isBossman(wavyScore, bossmanScore);
    final Color effectiveColor = isBossman ? _desaturate(color, 0.55) : color;
    final double glowIntensity = _glowForSavedCount(savedCount);

    final double bubR = pinBubbleDiameter / 2 * dpr;
    final double tailH = bubR * 0.55;
    final double glowExtra = bubR * 0.9;
    final double shadowExtra = 5.0 * dpr;
    final double avatarRingExtra =
        avatarColors.isNotEmpty ? 3.6 * dpr : 0;
    final double wavyRingExtra = isWavy ? 4.0 * dpr : 0;

    final int ghosts = remainingCount.clamp(1, 3);

    final double fanDistance = bubR * 0.55;
    final double fanArcStart = -0.50;
    final double fanArcEnd = 0.50;
    final double scaleStep = 0.04;
    final double opacityStep = 0.10;

    final double extraForGhosts = fanDistance + bubR * 0.3;
    final double pad = shadowExtra + glowExtra + extraForGhosts +
        avatarRingExtra + wavyRingExtra;
    final double canvasW = bubR * 2 + pad * 2;
    final double canvasH = bubR * 2 + pad * 2 + shadowExtra + tailH;

    final int outW = canvasW.ceil();
    final int outH = canvasH.ceil();

    final rec = ui.PictureRecorder();
    final c = Canvas(rec);

    final Offset mainCentre = Offset(outW / 2, outH / 2 - tailH / 2);

    // ─── 1. Ghost circles ────────────────────────────────────
    for (int i = ghosts; i >= 1; i--) {
      final double t = ghosts == 1 ? 0.5 : (i - 1) / (ghosts - 1);
      final double angle = ui.lerpDouble(fanArcStart, fanArcEnd, t)!;

      final double dist = fanDistance * (0.7 + 0.3 * i);
      final double gx = mainCentre.dx + math.cos(angle) * dist;
      final double gy = mainCentre.dy - math.sin(angle) * dist;
      final double gr = bubR * (1.0 - scaleStep * i);
      final double gOpacity = (0.92 - opacityStep * i).clamp(0.55, 0.92);

      final Offset gc = Offset(gx, gy);

      c.drawCircle(
        Offset(gc.dx, gc.dy + 1.2 * dpr),
        gr,
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, 0.08 * i)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 * dpr),
      );

      final ghostColor = Color.lerp(
          effectiveColor, const Color(0xFFE8E4EC), 0.15 + 0.08 * i)!;
      c.drawCircle(
          gc, gr, Paint()..color = ghostColor.withOpacity(gOpacity));

      c.drawCircle(
        gc,
        gr + 0.8 * dpr,
        Paint()..color = Colors.white.withOpacity(0.80),
      );

      c.drawCircle(
          gc, gr, Paint()..color = ghostColor.withOpacity(gOpacity));

      c.drawCircle(
        gc,
        gr,
        Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8 * dpr,
      );
    }

    // ─── 2. Glow (savedCount-driven) ─────────────────────────
    _drawGlow(c,
        centre: mainCentre,
        radius: bubR,
        dpr: dpr,
        color: effectiveColor,
        intensity: (glowIntensity * 1.15).clamp(0.0, 0.60));

    // 2b. Wavy iridescent glow
    if (isWavy) {
      _drawWavyGlow(c,
          centre: mainCentre,
          radius: bubR,
          dpr: dpr,
          wavyScore: wavyScore);
    }

    // ─── 3. Pointer tail ─────────────────────────────────────
    _drawPointerTail(c,
        bubbleCentre: mainCentre,
        bubbleRadius: bubR,
        dpr: dpr,
        color: effectiveColor);

    // ─── 4. Wavy ring ────────────────────────────────────────
    if (isWavy) {
      _drawWavyRing(c,
          centre: mainCentre,
          innerRadius: bubR + avatarRingExtra,
          dpr: dpr,
          wavyScore: wavyScore);
    }
    // ─── 5. Avatar ring ──────────────────────────────────────
    if (avatarColors.isNotEmpty) {
      _drawAvatarRing(c,
          centre: mainCentre,
          innerRadius: bubR,
          dpr: dpr,
          colors: avatarColors);
    }

    // ─── 6. Main pin ─────────────────────────────────────────
    _drawPinBubble(c,
        centre: mainCentre,
        radius: bubR,
        dpr: dpr,
        color: effectiveColor);

    // ─── 7. Emoji ────────────────────────────────────────────
    _drawEmoji(c, centre: mainCentre, size: bubR * 1.2, emoji: emoji);

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
        style: GoogleFonts.poppins(
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

    _drawGlow(c,
        centre: ctr,
        radius: diameter / 2,
        dpr: dpr,
        color: surfaceColor,
        intensity: 0.18);

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
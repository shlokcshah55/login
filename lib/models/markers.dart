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

  /// Logical bubble diameter used across all pin types so that
  /// callers can compute icon‑size ratios.
  static const double pinBubbleDiameter = 22.0;

  // ── Brand colours ──
  static const Color _brandDark = Color(0xFF42143D);

  // ==================================================================
  //  PUBLIC API — Single pin
  // ==================================================================

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
  }) {
    final color =
        surfaceColor ?? PinitMarkerPalette.forCuisine(cuisine, types);
    final key = 'pin|$emoji|$name|${devicePixelRatio.toStringAsFixed(2)}'
        '|${color.value}|${textColor.value}|$selected|$showText';
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
    ).then((b) {
      _cache.set(key, b);
      return b;
    });
  }

  // ==================================================================
  //  PUBLIC API — Cluster (stacked fan + badge)
  // ==================================================================

  /// A cluster pin that looks like a *stack of cards* fanned out behind a
  /// main pin, with a small "+N" badge.  Much more visually distinct than
  /// a plain numbered circle while still feeling like real places.
  static Future<Uint8List> createClusterPinWithBadge({
    required String emoji,
    required int remainingCount,
    double devicePixelRatio = 3.0,
    Color? surfaceColor,
    String? cuisine,
    String? types,
  }) {
    final color =
        surfaceColor ?? PinitMarkerPalette.forCuisine(cuisine, types);
    final key = 'cfan|$emoji|$remainingCount'
        '|${devicePixelRatio.toStringAsFixed(2)}|${color.value}';
    final cached = _cache.get(key);
    if (cached != null) return Future.value(cached);

    return _renderClusterFan(
      emoji: emoji,
      remainingCount: remainingCount,
      dpr: devicePixelRatio,
      color: color,
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
  //  PRIVATE — Shared drawing helpers
  // ══════════════════════════════════════════════════════════════

  /// Draws a single pin circle with gradient, shadow, and inner highlight.
  /// Returns the centre used so callers can position emoji / text relative.
  static Offset _drawPinBubble(
    Canvas canvas, {
    required Offset centre,
    required double radius,
    required double dpr,
    required Color color,
    bool selected = false,
    double shadowOpacity = 0.15,
  }) {
    final double shadowOffY = 1.5 * dpr;
    final double shadowSigma = 2.5 * dpr;
    final double borderW = 1.4 * dpr;

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
        radius + borderW + 1.0 * dpr,
        Paint()..color = Colors.white,
      );
    }

    // Radial gradient fill  — light source top‑left
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(centre.dx - radius * 0.35, centre.dy - radius * 0.35),
          radius * 1.6,
          [
            Color.lerp(color, Colors.white, 0.25)!,
            color,
            Color.lerp(color, Colors.black, 0.12)!,
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    // Inner highlight ring
    canvas.drawCircle(
      centre,
      radius - 0.8 * dpr,
      Paint()
        ..color = const Color(0x40FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7 * dpr,
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
  }) async {
    final double bubR = pinBubbleDiameter / 2 * dpr; // bubble radius
    final double shadowExtra = 4.0 * dpr;

    // Text metrics
    final double fontSize = 4.2 * dpr;
    final double maxTextW = 48.0 * dpr;
    final double textGap = 4.0 * dpr;
    final double pillPadH = 5.0 * dpr;
    final double pillPadV = 2.5 * dpr;
    final double pillRad = 4.0 * dpr;

    final tp = TextPainter(
      text: TextSpan(
        text: name,
        style: GoogleFonts.inter(
          color: const Color(0xFF1A1A2E),
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15 * dpr,
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

    final double selBorder = selected ? 1.4 * dpr : 0;
    final double pad = selBorder + shadowExtra + 2;

    final double totalW = showText ? bubR * 2 + textGap + pillW : bubR * 2;
    final double totalH = math.max(bubR * 2, pillH);

    final int outW = (totalW + pad * 2).ceil();
    final int outH = (totalH + pad * 2 + shadowExtra).ceil();

    final rec = ui.PictureRecorder();
    final c = Canvas(rec);

    final centre = Offset(bubR + pad, bubR + pad);

    // Bubble
    _drawPinBubble(c,
        centre: centre, radius: bubR, dpr: dpr, color: color, selected: selected);

    // Emoji
    _drawEmoji(c, centre: centre, size: bubR * 1.3, emoji: emoji);

    // Pill label
    if (showText) {
      final double px = centre.dx + bubR + textGap;
      final double py = centre.dy - pillH / 2;

      // Shadow
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(px, py + 0.8 * dpr, pillW, pillH),
          Radius.circular(pillRad),
        ),
        Paint()
          ..color = const Color(0x1A000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * dpr),
      );
      // Background
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(px, py, pillW, pillH),
          Radius.circular(pillRad),
        ),
        Paint()..color = const Color(0xEBFFFFFF),
      );
      // Text
      tp.paint(c, Offset(px + pillPadH, py + pillPadV));
    }

    return _rasterise(rec, outW, outH);
  }

  // ══════════════════════════════════════════════════════════════
  //  RENDER — Cluster Fan  (the new pretty one)
  // ══════════════════════════════════════════════════════════════
  //
  //  Visual design:
  //  • 2–3 "ghost" circles fan out *behind* the main pin in a
  //    clockwise arc (roughly 4 o'clock → 2 o'clock direction).
  //  • Each ghost is:
  //       – smaller (progressive scale‑down)
  //       – lighter / more transparent
  //       – has its own soft shadow for depth
  //       – thin white stroke border for separation
  //  • The main pin sits on top, identical to a single pin.
  //  • A compact pill badge sits at top‑right with "+N".
  //
  //  The result instantly reads as "a stack of places" without
  //  any heavy numbered circle.
  // ──────────────────────────────────────────────────────────────

  static Future<Uint8List> _renderClusterFan({
    required String emoji,
    required int remainingCount,
    required double dpr,
    required Color color,
  }) async {
    final double bubR = pinBubbleDiameter / 2 * dpr;
    final double shadowExtra = 4.0 * dpr;

    // How many ghost circles to show (cap at 3 for cleanliness)
    final int ghosts = remainingCount.clamp(1, 3);

    // Fan geometry — ghosts spread in an arc behind the main pin
    // Angle 0 = right, π/2 = down.  We fan from ~-35° to ~+35° (upper-right)
    final double fanDistance = bubR * 0.55; // how far ghosts offset from centre
    final double fanArcStart = -0.50; // radians (~-29°)
    final double fanArcEnd = 0.50; // radians (~+29°)
    final double scaleStep = 0.08; // each ghost shrinks by this fraction
    final double opacityStep = 0.22; // each ghost fades by this amount

    // Badge sizing
    final double badgeH = 9.0 * dpr;
    final double badgePadH = 3.5 * dpr;
    final double badgeFontSize = 3.4 * dpr;
    final double badgeBorder = 1.2 * dpr;

    // Canvas sizing — generous padding for ghosts + badge
    final double extraForGhosts = fanDistance + bubR * 0.3;
    final double pad = shadowExtra + extraForGhosts + badgeH;
    final double canvasW = bubR * 2 + pad * 2;
    final double canvasH = bubR * 2 + pad * 2 + shadowExtra;

    final int outW = canvasW.ceil();
    final int outH = canvasH.ceil();

    final rec = ui.PictureRecorder();
    final c = Canvas(rec);

    // Main bubble centre
    final Offset mainCentre = Offset(outW / 2, outH / 2);

    // ─── 1. Ghost circles (back → front) ───
    for (int i = ghosts; i >= 1; i--) {
      // Spread angle for this ghost
      final double t = ghosts == 1 ? 0.5 : (i - 1) / (ghosts - 1);
      final double angle = ui.lerpDouble(fanArcStart, fanArcEnd, t)!;

      final double dist = fanDistance * (0.7 + 0.3 * i); // farther ghosts push out more
      final double gx = mainCentre.dx + math.cos(angle) * dist;
      final double gy = mainCentre.dy - math.sin(angle) * dist; // negative = upward
      final double gr = bubR * (1.0 - scaleStep * i);
      final double gOpacity = (0.85 - opacityStep * i).clamp(0.15, 0.85);

      final Offset gc = Offset(gx, gy);

      // Ghost shadow
      c.drawCircle(
        Offset(gc.dx, gc.dy + 1.0 * dpr),
        gr,
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, 0.06 * i)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.0 * dpr),
      );

      // Ghost fill — desaturated + transparent version of main colour
      final ghostColor = Color.lerp(color, const Color(0xFFD0D0D8), 0.35 + 0.1 * i)!;
      c.drawCircle(
        gc,
        gr,
        Paint()..color = ghostColor.withOpacity(gOpacity),
      );

      // White stroke border for clean separation
      c.drawCircle(
        gc,
        gr,
        Paint()
          ..color = Colors.white.withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 * dpr,
      );
    }

    // ─── 2. Main pin ───
    _drawPinBubble(c,
        centre: mainCentre, radius: bubR, dpr: dpr, color: color);

    // ─── 3. Emoji ───
    _drawEmoji(c, centre: mainCentre, size: bubR * 1.3, emoji: emoji);

    // ─── 4. Badge pill (top‑right) ───
    final String label = remainingCount > 99 ? '+99' : '+$remainingCount';
    final badgeTp = TextPainter(
      text: TextSpan(
        text: label,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: badgeFontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final double pillW = badgeTp.width + badgePadH * 2;
    final double pillH = badgeH;
    final Offset badgeCentre = Offset(
      mainCentre.dx + bubR * 0.60,
      mainCentre.dy - bubR * 0.60,
    );

    // Badge shadow
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(badgeCentre.dx, badgeCentre.dy + 0.6 * dpr),
          width: pillW + badgeBorder * 2,
          height: pillH + badgeBorder * 2,
        ),
        Radius.circular(pillH),
      ),
      Paint()
        ..color = const Color(0x30000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * dpr),
    );

    // White outline
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: badgeCentre,
          width: pillW + badgeBorder * 2,
          height: pillH + badgeBorder * 2,
        ),
        Radius.circular(pillH),
      ),
      Paint()..color = Colors.white,
    );

    // Dark fill
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: badgeCentre, width: pillW, height: pillH),
        Radius.circular(pillH),
      ),
      Paint()..color = _brandDark.withOpacity(0.92),
    );

    // Badge text
    badgeTp.paint(
      c,
      Offset(
        badgeCentre.dx - badgeTp.width / 2,
        badgeCentre.dy - badgeTp.height / 2,
      ),
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
    final double diameter = 12.0 * dpr;
    final double borderW = 1.2 * dpr;
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
    final double pad = selBW + 2 * dpr;
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

import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Color palette for different place types
class PinitMarkerPalette {
  static const Color italian = Color(0xFFE57373); // Red
  static const Color chinese = Color(0xFF64B5F6); // Blue
  static const Color indian = Color(0xFFFFB74D); // Orange
  static const Color japanese = Color(0xFFBA68C8); // Purple
  static const Color mexican = Color(0xFF81C784); // Green
  static const Color american = Color(0xFF9575CD); // Deep Purple
  static const Color thai = Color(0xFF4FC3F7); // Light Blue
  static const Color french = Color(0xFFF06292); // Pink
  static const Color mediterranean = Color(0xFFFFD54F); // Yellow
  static const Color cafe = Color(0xFF8D6E63); // Brown
  static const Color bar = Color(0xFF90A4AE); // Blue Grey
  static const Color other = Color(0xFFB0BEC5); // Default Grey

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
    // fallback to type
    final t = (types ?? '').toLowerCase();
    if (t.contains('restaurant')) return italian;
    if (t.contains('hotel') || t.contains('lodging')) return american;
    if (t.contains('museum')) return japanese;
    if (t.contains('park')) return mexican;
    return other;
  }
}

class PinitMarkers {
  static final _BitmapCache _cache = _BitmapCache(maxEntries: 256);

  /// Creates a Pinit marker with emoji and name
  static Future<BitmapDescriptor> createPinitMarker({
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
    final color = surfaceColor ?? PinitMarkerPalette.forCuisine(cuisine, types);
    final cacheKey = _pinCacheKey(
      emoji: emoji,
      name: name,
      devicePixelRatio: devicePixelRatio,
      surfaceColor: color,
      textColor: textColor,
      selected: selected,
      showText: showText,
    );
    final cached = _cache.get(cacheKey);
    if (cached != null) return Future.value(cached);

    return _renderPinitMarker(
      emoji: emoji,
      name: name,
      devicePixelRatio: devicePixelRatio,
      surfaceColor: color,
      textColor: textColor,
      selected: selected,
      showText: showText,
    ).then((bitmap) {
      _cache.set(cacheKey, bitmap);
      return bitmap;
    });
  }

  static Future<BitmapDescriptor> createClusterMarker({
    required int count,
    double devicePixelRatio = 3.0,
    Color surfaceColor = const Color(0xFF42143D),
    Color textColor = const Color(0xFF1F2937),
    bool selected = false,
  }) {
    final cacheKey = _clusterCacheKey(
      count: count,
      devicePixelRatio: devicePixelRatio,
      surfaceColor: surfaceColor,
      textColor: textColor,
      selected: selected,
    );
    final cached = _cache.get(cacheKey);
    if (cached != null) return Future.value(cached);

    return _renderClusterMarker(
      count: count,
      devicePixelRatio: devicePixelRatio,
      surfaceColor: surfaceColor,
      textColor: textColor,
      selected: selected,
    ).then((bitmap) {
      _cache.set(cacheKey, bitmap);
      return bitmap;
    });
  }

  // Static style configuration - no zoom-based changes
  static const PinitMarkerStyle _staticStyle = PinitMarkerStyle(
    bubbleDiameter: 12.0,
    fontSize: 4,
    maxTextWidth: 40,
    paddingX: 2.5,
    paddingY: 1.5,
    textGap: 2.0,
    borderWidth: 1.2,
    showText: true,
  );

  static Future<BitmapDescriptor> _renderPinitMarker({
    required String emoji,
    required String name,
    required double devicePixelRatio,
    required Color surfaceColor,
    required Color textColor,
    required bool selected,
    required bool showText,
  }) async {
    final style = PinitMarkerStyle(
      bubbleDiameter: 12.0,
      fontSize: 4,
      maxTextWidth: 40,
      paddingX: 2.5,
      paddingY: 1.5,
      textGap: 2.0,
      borderWidth: 1.2,
      showText: showText,
    );
    // Emoji size: fontSize 30 for 56px circle = ~0.54 ratio
    final emojiSize = style.bubbleDiameter * 0.54;

    // Prepare text painter for name label
    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: GoogleFonts.poppins(
          color: Colors.black,
          fontSize: style.fontSize,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    );
    if (style.showText) {
      textPainter.layout(maxWidth: style.maxTextWidth);
    }

    // Calculate text dimensions
    final double textWidth = style.showText ? textPainter.width : 0;

    // Total width: circle + gap + text (if showing text)
    final double totalWidth = style.showText
        ? style.bubbleDiameter + style.textGap + textWidth
        : style.bubbleDiameter;
    final double totalHeight = style.bubbleDiameter;

    // Add padding for white border when selected
    final double borderWidth = selected ? style.borderWidth : 0;
    final double padding = borderWidth + 2;

    final int outW = ((totalWidth + padding * 2) * devicePixelRatio).ceil();
    final int outH = ((totalHeight + padding * 2) * devicePixelRatio).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(devicePixelRatio);

    // Calculate positions
    final double bubbleCenterX = style.bubbleDiameter / 2 + padding;
    final double bubbleCenterY = style.bubbleDiameter / 2 + padding;
    final Offset bubbleCenter = Offset(bubbleCenterX, bubbleCenterY);

    // === Draw Pin Circle ===
    // White border when selected (4px in reference, scaled)
    if (selected) {
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        bubbleCenter,
        style.bubbleDiameter / 2 + borderWidth,
        borderPaint,
      );
    }

    // Main solid colored circle
    _drawBubbleCircle(
      canvas: canvas,
      center: bubbleCenter,
      diameter: style.bubbleDiameter,
      color: surfaceColor,
    );

    // Emoji centered in circle
    final emojiPainter = TextPainter(
      text: TextSpan(text: emoji, style: TextStyle(fontSize: emojiSize)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    emojiPainter.paint(
      canvas,
      Offset(
        bubbleCenter.dx - emojiPainter.width / 2,
        bubbleCenter.dy - emojiPainter.height / 2,
      ),
    );

    // === Draw Name Label ===
    if (style.showText) {
      final double textX =
          bubbleCenterX + style.bubbleDiameter / 2 + style.textGap;
      final double textY = bubbleCenterY - textPainter.height / 2;

      // Draw white halo (stroke) first
      final haloTextPainter = TextPainter(
        text: TextSpan(
          text: name,
          style: GoogleFonts.poppins(
            fontSize: style.fontSize,
            fontWeight: FontWeight.w900,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = Colors.white,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: style.maxTextWidth);
      haloTextPainter.paint(canvas, Offset(textX, textY));

      // Draw black text fill on top (do NOT use foreground)
      final fillTextPainter = TextPainter(
        text: TextSpan(
          text: name,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: style.fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: style.maxTextWidth);
      fillTextPainter.paint(canvas, Offset(textX, textY));
    }

    final picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(outW, outH);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  static Future<BitmapDescriptor> _renderClusterMarker({
    required int count,
    required double devicePixelRatio,
    required Color surfaceColor,
    required Color textColor,
    required bool selected,
  }) async {
    const style = _staticStyle;
    final double diameter = style.bubbleDiameter;
    final String label = count > 99 ? '99+' : count.toString();

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: style.bubbleDiameter * 0.45,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    // Add padding for border when selected
    final double borderWidth = selected ? style.borderWidth : 0;
    final double padding = borderWidth + 2;

    final int outW = ((diameter + padding * 2) * devicePixelRatio).ceil();
    final int outH = ((diameter + padding * 2) * devicePixelRatio).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(devicePixelRatio);

    final Offset center =
        Offset(diameter / 2 + padding, diameter / 2 + padding);

    // Draw white border when selected
    if (selected) {
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, diameter / 2 + borderWidth, borderPaint);
    }

    // Draw solid colored circle for cluster (no white background)
    canvas.drawCircle(
      center,
      diameter / 2,
      Paint()..color = surfaceColor,
    );

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(outW, outH);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  static void _drawBubbleCircle({
    required Canvas canvas,
    required Offset center,
    required double diameter,
    required Color color,
  }) {
    final double radius = diameter / 2;

    // White circle fill
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    // Colored border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  static String _pinCacheKey({
    required String emoji,
    required String name,
    required double devicePixelRatio,
    required Color surfaceColor,
    required Color textColor,
    required bool selected,
    required bool showText,
  }) {
    return 'pin|$emoji|$name|'
        '${devicePixelRatio.toStringAsFixed(2)}|'
        '${surfaceColor.value}|${textColor.value}|$selected|$showText';
  }

  static String _clusterCacheKey({
    required int count,
    required double devicePixelRatio,
    required Color surfaceColor,
    required Color textColor,
    required bool selected,
  }) {
    return 'cluster|$count|'
        '${devicePixelRatio.toStringAsFixed(2)}|'
        '${surfaceColor.value}|${textColor.value}|$selected';
  }

  static double mathMax(double a, double b) => a > b ? a : b;
}

class PinitMarkerStyle {
  final double bubbleDiameter;
  final double fontSize;
  final double maxTextWidth;
  final double paddingX;
  final double paddingY;
  final double textGap;
  final double borderWidth;
  final bool showText;

  const PinitMarkerStyle({
    required this.bubbleDiameter,
    required this.fontSize,
    required this.maxTextWidth,
    required this.paddingX,
    required this.paddingY,
    required this.textGap,
    required this.borderWidth,
    required this.showText,
  });
}

class _BitmapCache {
  final int maxEntries;
  final LinkedHashMap<String, BitmapDescriptor> _cache = LinkedHashMap();

  _BitmapCache({required this.maxEntries});

  BitmapDescriptor? get(String key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value;
    }
    return value;
  }

  void set(String key, BitmapDescriptor value) {
    if (_cache.length >= maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }
}

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/markers.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('visited compact dots render with the warning orange fill', () async {
    final bytes = await PinitMarkers.createCompactMapDot(
      devicePixelRatio: 1.0,
      hasBeenTo: true,
    );

    final image = await _decodeImage(bytes);
    final pixel = await _samplePixel(image, x: 8, y: 8);

    expect(pixel.value, PinitColors.warning.value);
  });

  test('visited cluster markers render differently from default ones',
      () async {
    final defaultBytes = await PinitMarkers.createClusterPinWithBadge(
      devicePixelRatio: 1.0,
      pointCount: 5,
      fallbackSeed: 1,
    );
    final visitedBytes = await PinitMarkers.createClusterPinWithBadge(
      devicePixelRatio: 1.0,
      pointCount: 5,
      fallbackSeed: 1,
      hasBeenTo: true,
    );

    expect(listEquals(defaultBytes, visitedBytes), isFalse);
  });
}

Future<ui.Image> _decodeImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

Future<Color> _samplePixel(
  ui.Image image, {
  required int x,
  required int y,
}) async {
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (bytes == null) {
    throw StateError('Failed to read image pixel data.');
  }

  final offset = ((y * image.width) + x) * 4;
  final red = bytes.getUint8(offset);
  final green = bytes.getUint8(offset + 1);
  final blue = bytes.getUint8(offset + 2);
  final alpha = bytes.getUint8(offset + 3);
  return Color.fromARGB(alpha, red, green, blue);
}

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show NetworkAssetBundle;

/// Cache of already-decoded friend profile photos as `ui.Image` so the
/// marker renderer can paint them synchronously inside its canvas pass.
///
/// Keys are the raw image URL strings. Misses kick off an async fetch +
/// decode and the resulting Future is stored so concurrent callers wait
/// on the same network round-trip.
class FriendAvatarLoader {
  FriendAvatarLoader._();

  static final Map<String, Future<ui.Image?>> _inFlight = {};
  static final Map<String, ui.Image> _decoded = {};

  /// Pre-load a set of avatar URLs and return the decoded images in the
  /// same order. Failed/empty URLs yield null entries which the renderer
  /// falls back to a placeholder for.
  static Future<List<ui.Image?>> loadAll(Iterable<String?> urls) async {
    final list = urls.toList();
    final futures = <Future<ui.Image?>>[];
    for (final url in list) {
      if (url == null || url.isEmpty) {
        futures.add(Future.value(null));
        continue;
      }
      futures.add(_loadOne(url));
    }
    return Future.wait(futures);
  }

  /// Synchronous lookup — returns null if the URL hasn't been decoded yet.
  /// Use [loadAll] first if you need the data, then this for paint passes.
  static ui.Image? peek(String? url) {
    if (url == null || url.isEmpty) return null;
    return _decoded[url];
  }

  static Future<ui.Image?> _loadOne(String url) {
    final cached = _decoded[url];
    if (cached != null) return Future.value(cached);

    final inFlight = _inFlight[url];
    if (inFlight != null) return inFlight;

    final future = _fetchAndDecode(url);
    _inFlight[url] = future;
    return future;
  }

  static Future<ui.Image?> _fetchAndDecode(String url) async {
    try {
      final byteData = await NetworkAssetBundle(Uri.parse(url))
          .load(url)
          .timeout(const Duration(seconds: 6));
      final codec = await ui.instantiateImageCodec(
        byteData.buffer.asUint8List(),
        targetWidth: 96, // small — markers render at ~24-30 logical px
      );
      final frame = await codec.getNextFrame();
      _decoded[url] = frame.image;
      return frame.image;
    } catch (_) {
      return null;
    } finally {
      _inFlight.remove(url);
    }
  }

  /// Visible for tests / cache-control surfaces.
  static void clear() {
    _decoded.clear();
    _inFlight.clear();
  }
}

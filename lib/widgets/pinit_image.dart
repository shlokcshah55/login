import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/utils/photo_urls.dart';

/// Disk cache for every remote photo. Variant URLs are immutable, so a long
/// stale period is safe; the object cap keeps the cache bounded.
class PinitImageCache {
  PinitImageCache._();

  static const String key = 'pinit_images';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 90),
      maxNrOfCacheObjects: 2000,
    ),
  );
}

/// The one way to show a remote photo.
///
/// Picks the right pre-generated variant for the size role, decodes at that
/// width (no full-resolution decode for a thumbnail), shares one disk cache,
/// and shows a quiet cream placeholder instead of a spinner.
class PinitImage extends StatelessWidget {
  /// A location photo. [url] is the stored (card) URL; [size] selects the
  /// variant to fetch.
  const PinitImage.location({
    super.key,
    required this.url,
    this.size = PhotoSize.card,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallback,
    this.fallbackUrl,
  }) : avatarDiameter = null;

  /// A user avatar or collection cover, resized by the CDN to [diameter]
  /// logical pixels (times the device pixel ratio).
  const PinitImage.avatar({
    super.key,
    required this.url,
    required double diameter,
    this.fit = BoxFit.cover,
    this.fallback,
  })  : avatarDiameter = diameter,
        fallbackUrl = null,
        size = PhotoSize.thumb,
        width = diameter,
        height = diameter;

  final String? url;
  final PhotoSize size;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallback;
  final double? avatarDiameter;

  /// Tried when [url] fails to load. Defaults, for CDN location photos, to
  /// the same photo in Supabase Storage (see [PhotoUrls.legacyFor]).
  final String? fallbackUrl;

  /// The URL actually fetched for a location photo [url] at [size].
  static String resolveLocation(String url, PhotoSize size) {
    final normalized = PhotoUrls.normalize(url, fallbackSize: size) ?? url;
    return PhotoUrls.variant(normalized, size) ?? normalized;
  }

  /// Downloads a location photo into the shared disk cache, so a later
  /// [PinitImage.location] with the same [url] and [size] needs no network.
  static Future<void> precacheLocation(
    BuildContext context,
    String url, {
    PhotoSize size = PhotoSize.card,
  }) {
    return precacheImage(
      CachedNetworkImageProvider(
        resolveLocation(url, size),
        cacheManager: PinitImageCache.instance,
        maxWidth: size.width,
      ),
      context,
      onError: (_, __) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final raw = url;
    if (raw == null || raw.isEmpty) return _fallback();

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final String resolved;
    final int decodeWidth;
    if (avatarDiameter != null) {
      final px = (avatarDiameter! * dpr).ceil();
      resolved = PhotoUrls.avatar(raw, px) ?? raw;
      decodeWidth = px;
    } else {
      resolved = resolveLocation(raw, size);
      decodeWidth = size.width;
    }

    final secondary = avatarDiameter == null
        ? (fallbackUrl ?? PhotoUrls.legacyFor(resolved))
        : null;

    return _network(
      resolved,
      decodeWidth,
      onError: secondary == null || secondary == resolved
          ? _fallback()
          : _network(secondary, decodeWidth, onError: _fallback()),
    );
  }

  Widget _network(String imageUrl, int decodeWidth, {required Widget onError}) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: PinitImageCache.instance,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: decodeWidth,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) => onError,
    );
  }

  Widget _placeholder() => SizedBox(
        width: width,
        height: height,
        child: const ColoredBox(color: PinitColors.creamSunk),
      );

  Widget _fallback() =>
      fallback ??
      SizedBox(
        width: width,
        height: height,
        child: const ColoredBox(
          color: PinitColors.creamSunk,
          child: Center(
            child: Icon(FeatherIcons.image, size: 20, color: PinitColors.mute),
          ),
        ),
      );
}

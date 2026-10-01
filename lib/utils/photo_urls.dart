/// Size roles for pre-generated location photo variants (WebP, in R2).
enum PhotoSize {
  thumb(320),
  card(720),
  hero(1440);

  const PhotoSize(this.width);
  final int width;
}

/// Single source of truth for photo URLs served from the Cloudflare CDN.
///
/// Key layout in the R2 bucket:
///  - locations: `l/{locationId}/{n}_{thumb|card|hero}.webp` (n = 0 primary, 1..9 extras)
///  - avatars:   `u/{storagePath}` (served through Cloudflare Image Transformations)
///  - covers:    `c/{collectionId}/cover.{ext}` (same transform path as avatars)
///
/// While [baseUrl] is unset (before cutover) every method is a no-op and
/// [normalize] returns its input unchanged.
class PhotoUrls {
  PhotoUrls._();

  static String _baseUrl = '';

  /// Set once at startup from `PHOTO_CDN_BASE_URL`. Trailing slashes are ignored.
  static void configure(String? baseUrl) {
    _baseUrl = (baseUrl ?? '').trim().replaceAll(RegExp(r'/+$'), '');
  }

  static bool get isConfigured => _baseUrl.isNotEmpty;

  /// Pre-generated WebP variant for a location photo. [index] 0 is the primary.
  static String? location(
    String locationId,
    PhotoSize size, {
    int index = 0,
  }) {
    if (!isConfigured || locationId.isEmpty) return null;
    return '$_baseUrl/l/$locationId/${index}_${size.name}.webp';
  }

  /// Resized (WebP/AVIF via `format=auto`) rendition of a stored avatar or
  /// cover URL. Returns [url] unchanged when it is not hosted on the CDN.
  static String? avatar(String? url, int width) {
    if (url == null || url.isEmpty) return url;
    final normalized = normalize(url) ?? url;
    if (!isConfigured || !normalized.startsWith('$_baseUrl/')) {
      return normalized;
    }
    final path = normalized.substring(_baseUrl.length + 1);
    return '$_baseUrl/cdn-cgi/image/width=$width,fit=cover,format=auto/$path';
  }

  static final RegExp _variantSuffix = RegExp(r'_(thumb|card|hero)\.webp$');

  /// Swaps the size role of a CDN location variant URL (e.g. the stored
  /// `card` URL into `thumb`). Any other URL is returned unchanged.
  static String? variant(String? url, PhotoSize size) {
    if (url == null || !_variantSuffix.hasMatch(url)) return url;
    return url.replaceFirst(_variantSuffix, '_${size.name}.webp');
  }

  static final RegExp _legacy = RegExp(
    r'^https?://[^/]+/storage/v1/object/public/'
    r'(profile_photos|collection_covers|location_photos)/([^?#]+)(\?[^#]*)?$',
  );
  static final RegExp _legacyLocationName =
      RegExp(r'^(.+?)(?:_(\d+))?\.[A-Za-z0-9]+$');

  /// Rewrites legacy Supabase Storage public URLs to the CDN. Covers rows not
  /// yet migrated and old startup-cache snapshots. [fallbackSize] only applies
  /// to legacy location photo URLs.
  static String? normalize(
    String? url, {
    PhotoSize fallbackSize = PhotoSize.card,
  }) {
    if (url == null || url.isEmpty || !isConfigured) return url;
    final match = _legacy.firstMatch(url);
    if (match == null) return url;
    final bucket = match.group(1)!;
    final path = match.group(2)!;
    final query = match.group(3) ?? '';
    switch (bucket) {
      case 'profile_photos':
        return '$_baseUrl/u/$path$query';
      case 'collection_covers':
        return '$_baseUrl/c/$path$query';
      default:
        final name = _legacyLocationName.firstMatch(path);
        if (name == null) return url;
        final index = int.tryParse(name.group(2) ?? '') ?? 0;
        return location(name.group(1)!, fallbackSize, index: index);
    }
  }
}

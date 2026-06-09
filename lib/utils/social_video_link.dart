enum SocialVideoPlatform {
  tiktok,
  instagram,
}

class SocialVideoLink {
  const SocialVideoLink({
    required this.originalUrl,
    required this.normalizedUrl,
    required this.platform,
  });

  final String originalUrl;
  final String normalizedUrl;
  final SocialVideoPlatform platform;

  String get platformValue {
    switch (platform) {
      case SocialVideoPlatform.tiktok:
        return 'tiktok';
      case SocialVideoPlatform.instagram:
        return 'instagram';
    }
  }

  static SocialVideoLink? parse(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) return null;

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return null;

    final host = uri.host.toLowerCase();
    final path = uri.path.trim();
    if (path.isEmpty || path == '/') return null;

    final platform = _platformFor(host, path);
    if (platform == null) return null;

    final normalized = Uri(
      scheme: 'https',
      host: host,
      path: uri.path,
    );

    return SocialVideoLink(
      originalUrl: trimmed,
      normalizedUrl: normalized.toString(),
      platform: platform,
    );
  }

  static SocialVideoPlatform? _platformFor(String host, String path) {
    if (host == 'tiktok.com' ||
        host == 'vm.tiktok.com' ||
        host == 'vt.tiktok.com' ||
        host.endsWith('.tiktok.com')) {
      return SocialVideoPlatform.tiktok;
    }

    if ((host == 'instagram.com' || host.endsWith('.instagram.com')) &&
        path.toLowerCase().startsWith('/reel/')) {
      return SocialVideoPlatform.instagram;
    }

    return null;
  }
}

SocialVideoPlatform? socialVideoPlatformFrom({
  String? platform,
  String? sourceUrl,
}) {
  final normalizedPlatform = platform?.trim().toLowerCase();
  switch (normalizedPlatform) {
    case 'tiktok':
      return SocialVideoPlatform.tiktok;
    case 'instagram':
    case 'reel':
    case 'reels':
      return SocialVideoPlatform.instagram;
  }

  final parsed = sourceUrl == null ? null : SocialVideoLink.parse(sourceUrl);
  return parsed?.platform;
}

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/video_insights.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/utils/social_video_link.dart';

class SharedSocialPostsSection extends StatelessWidget {
  const SharedSocialPostsSection({
    super.key,
    required this.posts,
    required this.onPostTap,
  });

  final List<SocialVideoPost> posts;
  final ValueChanged<SocialVideoPost> onPostTap;

  String _headingFor(List<SocialVideoPost> visiblePosts) {
    final allTikTok = visiblePosts.every(
      (post) =>
          socialVideoPlatformFrom(sourceUrl: post.sourceVideoUrl) ==
          SocialVideoPlatform.tiktok,
    );
    return allTikTok ? 'Seen on TikTok' : 'Seen on Socials';
  }

  @override
  Widget build(BuildContext context) {
    final visiblePosts = _deduplicateSocialPosts(posts);
    if (visiblePosts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: PinitColors.aubergine,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                FeatherIcons.play,
                size: 16,
                color: PinitColors.cream,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _headingFor(visiblePosts),
                    style: GoogleFonts.dmSans(
                      color: PinitColors.aubergine,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  Text(
                    '${visiblePosts.length} shared ${visiblePosts.length == 1 ? 'post' : 'posts'} from this place',
                    style: GoogleFonts.dmSans(
                      color: PinitColors.aubergineSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 126,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: visiblePosts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return _SocialPostCard(
                post: visiblePosts[index],
                onTap: () => onPostTap(visiblePosts[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

List<SocialVideoPost> _deduplicateSocialPosts(List<SocialVideoPost> posts) {
  final visiblePosts = <SocialVideoPost>[];
  final seen = <String>{};

  for (final post in posts) {
    final key = _socialPostDeduplicationKey(post.sourceVideoUrl);
    if (key.isEmpty || !seen.add(key)) continue;
    visiblePosts.add(post);
  }

  return visiblePosts;
}

String _socialPostDeduplicationKey(String sourceVideoUrl) {
  final parsed = SocialVideoLink.parse(sourceVideoUrl);
  final normalized = parsed?.normalizedUrl ?? sourceVideoUrl.trim();
  return normalized.replaceFirst(RegExp(r'/+$'), '');
}

class _SocialPostCard extends StatelessWidget {
  const _SocialPostCard({
    required this.post,
    required this.onTap,
  });

  final SocialVideoPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final platformStyle = _SocialPlatformStyle.fromUrl(post.sourceVideoUrl);
    final dish = post.recommendedDish?.trim();
    final description = post.videoDescription?.trim();
    final subtitle = dish != null && dish.isNotEmpty
        ? 'Try $dish'
        : description != null && description.isNotEmpty
            ? description
            : _fallbackSubtitle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          width: 218,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                PinitColors.cream,
                platformStyle.tint,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: platformStyle.accent.withValues(alpha: 0.22),
              width: 1.2,
            ),
            boxShadow: PinitColors.subtleShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: platformStyle.iconBackground,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: platformStyle.accent.withValues(alpha: 0.28),
                          blurRadius: 0,
                          offset: const Offset(3, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _PlatformMark(
                        style: platformStyle,
                        size: 20,
                        color: PinitColors.cream,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.displayHandle,
                          style: GoogleFonts.dmSans(
                            color: PinitColors.aubergine,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        _PlatformBadge(style: platformStyle),
                      ],
                    ),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: PinitColors.cream.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      FeatherIcons.externalLink,
                      size: 13,
                      color: PinitColors.aubergineSoft,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: PinitColors.cream.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    color: PinitColors.aubergineSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.22,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _fallbackSubtitle {
    final platform = socialVideoPlatformFrom(sourceUrl: post.sourceVideoUrl);
    if (platform == SocialVideoPlatform.instagram) return 'Open shared Reel';
    return 'Open shared TikTok';
  }
}

class _PlatformBadge extends StatelessWidget {
  const _PlatformBadge({required this.style});

  final _SocialPlatformStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: style.badgeBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlatformMark(
            style: style,
            size: 10,
            color: style.accent,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              style.label,
              style: GoogleFonts.dmSans(
                color: PinitColors.aubergine,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialPlatformStyle {
  const _SocialPlatformStyle({
    required this.label,
    required this.accent,
    required this.iconBackground,
    required this.tint,
    required this.badgeBackground,
    this.icon,
    this.svgMarkup,
  });

  final String label;
  final Color accent;
  final Color iconBackground;
  final Color tint;
  final Color badgeBackground;
  final IconData? icon;
  final String? svgMarkup;

  static _SocialPlatformStyle fromUrl(String sourceVideoUrl) {
    final platform = socialVideoPlatformFrom(sourceUrl: sourceVideoUrl);
    if (platform == SocialVideoPlatform.instagram) {
      return _instagram;
    }
    return _tiktok;
  }

  static final _tiktok = _SocialPlatformStyle(
    label: 'TikTok',
    accent: PinitColors.teal,
    iconBackground: PinitColors.aubergine,
    tint: PinitColors.teal.withValues(alpha: 0.11),
    badgeBackground: PinitColors.teal.withValues(alpha: 0.12),
    svgMarkup: _tiktokSvgMarkup,
  );

  static final _instagram = _SocialPlatformStyle(
    label: 'Instagram',
    icon: FeatherIcons.instagram,
    accent: PinitColors.accent,
    iconBackground: PinitColors.accent,
    tint: PinitColors.accent.withValues(alpha: 0.10),
    badgeBackground: PinitColors.accent.withValues(alpha: 0.11),
  );
}

class _PlatformMark extends StatelessWidget {
  const _PlatformMark({
    required this.style,
    required this.size,
    required this.color,
  });

  final _SocialPlatformStyle style;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final svgMarkup = style.svgMarkup;
    if (svgMarkup != null) {
      return SvgPicture.string(
        svgMarkup,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    return Icon(
      style.icon,
      size: size,
      color: color,
    );
  }
}

const String _tiktokSvgMarkup = '''
<svg fill="#000000" width="800px" height="800px" viewBox="0 0 32 32" version="1.1" xmlns="http://www.w3.org/2000/svg">
<title>tiktok</title>
<path d="M16.656 1.029c1.637-0.025 3.262-0.012 4.886-0.025 0.054 2.031 0.878 3.859 2.189 5.213l-0.002-0.002c1.411 1.271 3.247 2.095 5.271 2.235l0.028 0.002v5.036c-1.912-0.048-3.71-0.489-5.331-1.247l0.082 0.034c-0.784-0.377-1.447-0.764-2.077-1.196l0.052 0.034c-0.012 3.649 0.012 7.298-0.025 10.934-0.103 1.853-0.719 3.543-1.707 4.954l0.020-0.031c-1.652 2.366-4.328 3.919-7.371 4.011l-0.014 0c-0.123 0.006-0.268 0.009-0.414 0.009-1.73 0-3.347-0.482-4.725-1.319l0.040 0.023c-2.508-1.509-4.238-4.091-4.558-7.094l-0.004-0.041c-0.025-0.625-0.037-1.25-0.012-1.862 0.49-4.779 4.494-8.476 9.361-8.476 0.547 0 1.083 0.047 1.604 0.136l-0.056-0.008c0.025 1.849-0.050 3.699-0.050 5.548-0.423-0.153-0.911-0.242-1.42-0.242-1.868 0-3.457 1.194-4.045 2.861l-0.009 0.030c-0.133 0.427-0.21 0.918-0.21 1.426 0 0.206 0.013 0.41 0.037 0.61l-0.002-0.024c0.332 2.046 2.086 3.59 4.201 3.59 0.061 0 0.121-0.001 0.181-0.004l-0.009 0c1.463-0.044 2.733-0.831 3.451-1.994l0.010-0.018c0.267-0.372 0.45-0.822 0.511-1.311l0.001-0.014c0.125-2.237 0.075-4.461 0.087-6.698 0.012-5.036-0.012-10.060 0.025-15.083z"></path>
</svg>
''';

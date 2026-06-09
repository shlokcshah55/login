import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
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

  String get _heading {
    final allTikTok = posts.every(
      (post) =>
          socialVideoPlatformFrom(sourceUrl: post.sourceVideoUrl) ==
          SocialVideoPlatform.tiktok,
    );
    return allTikTok ? 'Seen on TikTok' : 'Seen on Socials';
  }

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();

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
                    _heading,
                    style: GoogleFonts.dmSans(
                      color: PinitColors.aubergine,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    '${posts.length} shared ${posts.length == 1 ? 'post' : 'posts'} from this place',
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
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return _SocialPostCard(
                post: posts[index],
                onTap: () => onPostTap(posts[index]),
              );
            },
          ),
        ),
      ],
    );
  }
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
          width: 210,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PinitColors.creamDeep, width: 1.2),
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
                      color: PinitColors.aubergine,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: PinitColors.accent.withValues(alpha: 0.28),
                          blurRadius: 0,
                          offset: const Offset(3, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      FeatherIcons.video,
                      size: 17,
                      color: PinitColors.cream,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      post.displayHandle,
                      style: GoogleFonts.dmSans(
                        color: PinitColors.aubergine,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    FeatherIcons.externalLink,
                    size: 14,
                    color: PinitColors.aubergineSoft,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  color: PinitColors.aubergineSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.22,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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

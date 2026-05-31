import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/widgets/home/expanded_card/helpers/similar_place.dart';
import 'package:login/widgets/home/expanded_card/helpers/vibe_display.dart';

/// "You might also like" — horizontal carousel of vibe-similar places.
/// Tapping a card delegates to [onPlaceTap] (parent decides whether to
/// navigate or close).
class SimilarPlacesSection extends StatelessWidget {
  const SimilarPlacesSection({
    super.key,
    required this.similarPlaces,
    required this.onPlaceTap,
  });

  final List<SimilarPlace> similarPlaces;
  final ValueChanged<SimilarPlace> onPlaceTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SIMILAR VIBES',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: PinitColors.aubergineSoft,
            letterSpacing: 0.12 * 11,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Text(
                'You might also like',
                style: TextStyle(
                  fontFamily: 'Rova',
                  fontFamilyFallback: ['Naria'],
                  fontSize: 28,
                  fontWeight: FontWeight.w100,
                  color: PinitColors.aubergine,
                  letterSpacing: 1.3,
                  height: 1.05,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${similarPlaces.length} found',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: PinitColors.mute,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: similarPlaces.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              return _SimilarPlaceCard(
                similar: similarPlaces[index],
                isLast: index == similarPlaces.length - 1,
                onTap: () => onPlaceTap(similarPlaces[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SimilarPlaceCard extends StatelessWidget {
  const _SimilarPlaceCard({
    required this.similar,
    required this.isLast,
    required this.onTap,
  });

  final SimilarPlace similar;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loc = similar.location;
    final simPercent = (similar.similarity * 100).round();
    final imageUrl = loc.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    final isWavy = loc.vibe != null && loc.vibe!.wavyScore >= 0.35;
    // ≥70% similarity earns the accent treatment so genuinely strong
    // matches stand out across the carousel.
    final isStrongSim = similar.similarity >= 0.70;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        margin: EdgeInsets.only(right: isLast ? 0 : 12),
        decoration: BoxDecoration(
          color: PinitColors.creamSunk,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isStrongSim || isWavy)
                ? PinitColors.accent
                : PinitColors.creamDeep,
            width: (isStrongSim || isWavy) ? 2.0 : 1.5,
          ),
          boxShadow: (isStrongSim || isWavy) ? PinitColors.subtleShadow : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + similarity badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: 96,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const _SimilarImagePlaceholder(),
                          errorWidget: (_, __, ___) =>
                              const _SimilarImagePlaceholder(),
                        )
                      : const _SimilarImagePlaceholder(),
                ),
                // Similarity pill — top right. Accent on strong matches,
                // aubergine elsewhere — keeps the carousel from being
                // a flat row of identical cards.
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isStrongSim
                          ? PinitColors.accent
                          : PinitColors.aubergine,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$simPercent% MATCH',
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: PinitColors.cream,
                        letterSpacing: 0.15 * 9,
                      ),
                    ),
                  ),
                ),
                // Wavy sparkle — only show when not already accented by
                // a strong match, otherwise we double up on accent.
                if (isWavy && !isStrongSim)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: PinitColors.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '✨ WAVY',
                        style: GoogleFonts.dmSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: PinitColors.cream,
                          letterSpacing: 0.15 * 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + emoji
                    Row(
                      children: [
                        if (loc.emoji != null && loc.emoji!.isNotEmpty) ...[
                          Text(loc.emoji!,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            loc.name,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: PinitColors.aubergine,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Rating + cuisine row
                    Row(
                      children: [
                        if (loc.rating != null) ...[
                          const Icon(Icons.star_rounded,
                              size: 12, color: PinitColors.aubergine),
                          const SizedBox(width: 3),
                          Text(
                            loc.rating!.toStringAsFixed(1),
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: PinitColors.aubergineSoft,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (loc.cuisinePrimary != null)
                          Expanded(
                            child: Text(
                              loc.cuisinePrimary!,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: PinitColors.mute,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),

                    const Spacer(),

                    // Shared vibes
                    if (similar.sharedVibes.isNotEmpty)
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: similar.sharedVibes.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: PinitColors.cream,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: PinitColors.creamDeep, width: 1),
                            ),
                            child: Text(
                              vibeDisplayName(tag).toLowerCase(),
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: PinitColors.aubergineSoft,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimilarImagePlaceholder extends StatelessWidget {
  const _SimilarImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      width: double.infinity,
      decoration: const BoxDecoration(color: PinitColors.creamDeep),
      child: const Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 28,
          color: PinitColors.aubergineSoft,
        ),
      ),
    );
  }
}

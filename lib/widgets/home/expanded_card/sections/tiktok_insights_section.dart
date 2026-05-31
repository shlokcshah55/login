import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/video_extras.dart';
import 'package:login/models/video_insights.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/widgets/home/expanded_card/full_text_sheet.dart';
import 'package:login/widgets/home/expanded_card/helpers/vibe_display.dart';

/// TikTok / Reel insights section — appears in the expanded card only
/// when the location was saved from a social video AND structured
/// insight data exists.
///
/// Layout hierarchy (top to bottom):
///   1. Section header ("FROM THIS TIKTOK" + Rova sub-head)
///   2. Creator quote block — the creator's take, styled as editorial quote
///   3. Key dishes strip — horizontal scrollable dish cards
///   4. Special offer banner — accent-colored, per-user offer from video_extras
///   5. Video vibe pills — "Vibes from this video" as compact chips
///
/// Interaction model: the section is read-only and editorial in feel.
/// Dish cards are tappable for future save-to-list functionality.
/// The section degrades gracefully — each sub-block only renders if
/// its data is non-null/non-empty.
class TikTokInsightsSection extends StatelessWidget {
  const TikTokInsightsSection({
    super.key,
    required this.insight,
    this.videoExtras,
  });

  /// Global video insights (shared across all users who saved this video).
  final VideoInsight insight;

  /// Per-user video extras (special offers, personal notes).
  final VideoExtras? videoExtras;

  bool get _hasCreatorNotes =>
      insight.creatorNotes != null && insight.creatorNotes!.trim().isNotEmpty;

  bool get _hasDishes =>
      insight.keyDishes != null && insight.keyDishes!.isNotEmpty;

  bool get _hasOffers =>
      videoExtras?.specialOffers != null &&
      videoExtras!.specialOffers!.isNotEmpty;

  bool get _hasVibeSignals =>
      insight.vibeSignals != null && insight.vibeSignals!.isNotEmpty;

  bool get _hasAnyContent =>
      _hasCreatorNotes || _hasDishes || _hasOffers || _hasVibeSignals;

  String get _sourceLabel {
    final url = insight.sourceVideoUrl.toLowerCase();
    if (url.contains('instagram.com')) return 'REEL';
    if (url.contains('tiktok.com')) return 'TIKTOK';
    return 'SOCIAL VIDEO';
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAnyContent) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          'FROM THIS $_sourceLabel',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: PinitColors.accent,
            letterSpacing: 0.12 * 11,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'What they said',
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

        // 1. Creator quote
        if (_hasCreatorNotes) ...[
          const SizedBox(height: 16),
          _CreatorQuoteBlock(
            notes: insight.creatorNotes!,
            handle: insight.creatorHandle,
            sentiment: insight.sentiment,
          ),
        ],

        // 2. Key dishes
        if (_hasDishes) ...[
          const SizedBox(height: 20),
          _DishesStrip(dishes: insight.keyDishes!),
        ],

        // 3. Special offers (per-user)
        if (_hasOffers) ...[
          const SizedBox(height: 20),
          ...videoExtras!.specialOffers!.map(
            (offer) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OfferBanner(offer: offer),
            ),
          ),
        ],

        // 4. Video vibe pills
        if (_hasVibeSignals) ...[
          const SizedBox(height: 16),
          _VideoVibePills(vibeSignals: insight.vibeSignals!),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Sub-components
// ═══════════════════════════════════════════════════════════════════

/// Editorial-style quote block showing the creator's take on the place.
/// Uses a subtle left accent bar and the creator's @handle as attribution.
class _CreatorQuoteBlock extends StatelessWidget {
  const _CreatorQuoteBlock({
    required this.notes,
    this.handle,
    this.sentiment,
  });

  final String notes;
  final String? handle;
  final String? sentiment;

  IconData get _sentimentIcon {
    switch (sentiment) {
      case 'positive':
        return Icons.sentiment_satisfied_alt_rounded;
      case 'negative':
        return Icons.sentiment_dissatisfied_rounded;
      case 'mixed':
        return Icons.sentiment_neutral_rounded;
      default:
        return Icons.format_quote_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent bar
          Container(
            width: 3,
            height: 48,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              color: PinitColors.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"$notes"',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: PinitColors.aubergine,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
                if (handle != null && handle!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _sentimentIcon,
                        size: 14,
                        color: PinitColors.aubergineSoft,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '@$handle',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: PinitColors.aubergineSoft,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontally scrollable strip of dish cards. Each card shows the
/// dish name, an optional creator description, and price. Compact
/// format — no images, just text, consistent with the editorial feel.
class _DishesStrip extends StatelessWidget {
  const _DishesStrip({required this.dishes});

  final List<DishHighlight> dishes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.restaurant_menu_rounded,
              size: 14,
              color: PinitColors.aubergineSoft,
            ),
            const SizedBox(width: 6),
            Text(
              'Dishes mentioned',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: PinitColors.aubergineSoft,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dishes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _DishCard(dish: dishes[i]),
          ),
        ),
      ],
    );
  }
}

/// Individual dish card in the horizontal strip.
class _DishCard extends StatelessWidget {
  const _DishCard({required this.dish});

  final DishHighlight dish;

  @override
  Widget build(BuildContext context) {
    final hasDescription =
        dish.description != null && dish.description!.trim().isNotEmpty;
    final hasPrice = dish.price != null && dish.price!.trim().isNotEmpty;

    final card = Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PinitColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  dish.name,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PinitColors.aubergine,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasPrice) ...[
                const SizedBox(width: 6),
                Text(
                  dish.price!,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PinitColors.accent,
                  ),
                ),
              ],
            ],
          ),
          if (hasDescription) ...[
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                dish.description!,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: PinitColors.aubergineSoft,
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );

    if (!hasDescription) return card;

    return Semantics(
      button: true,
      label: 'Read full dish notes',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showExpandedCardTextSheet(
          context: context,
          title: dish.name,
          eyebrow: 'Dish notes',
          preserveEyebrowCase: true,
          meta: hasPrice ? dish.price : null,
          text: dish.description!,
        ),
        child: card,
      ),
    );
  }
}

/// Accent-colored banner for special offers extracted from the TikTok.
/// Shows the offer text, optional code, and expiry date.
class _OfferBanner extends StatelessWidget {
  const _OfferBanner({required this.offer});

  final SpecialOffer offer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF3E0),
            Color(0xFFFFF8F0),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFCC80),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Text('🎁', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.offer,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92620A),
                    height: 1.35,
                  ),
                ),
                if (offer.code != null || offer.validUntil != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (offer.code != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFFCC80).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            offer.code!,
                            style: GoogleFonts.dmMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF92620A),
                            ),
                          ),
                        ),
                      ],
                      if (offer.code != null && offer.validUntil != null)
                        const SizedBox(width: 8),
                      if (offer.validUntil != null)
                        Text(
                          'Until ${offer.validUntil}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: const Color(0xFFB8860B),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact vibe pills showing the video's vibe signals. These are
/// supplementary to the global vibe tags — they show what THIS specific
/// video conveys about the place.
class _VideoVibePills extends StatelessWidget {
  const _VideoVibePills({required this.vibeSignals});

  final Map<String, double> vibeSignals;

  @override
  Widget build(BuildContext context) {
    // Sort by score descending, take top 5
    final sorted = vibeSignals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(5).toList();

    if (top.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.music_note_rounded,
              size: 14,
              color: PinitColors.aubergineSoft,
            ),
            const SizedBox(width: 6),
            Text(
              'Vibes from this video',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: PinitColors.aubergineSoft,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: top.map((entry) {
            final icon = vibeIcons[entry.key] ?? Icons.label_rounded;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: PinitColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: PinitColors.accent.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: PinitColors.accent),
                  const SizedBox(width: 5),
                  Text(
                    vibeDisplayName(entry.key),
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PinitColors.accent,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

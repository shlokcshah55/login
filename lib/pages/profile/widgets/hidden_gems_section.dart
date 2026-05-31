import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:login/pages/profile/widgets/location_mosaic_grid.dart';
import 'pinit_colors.dart';

// ─────────────────────────────────────────────────────────────
//  Vibe tag display config – mirrors location_carousel.dart
// ─────────────────────────────────────────────────────────────
class _VibeTagStyle {
  final String label;
  final IconData icon;
  final Color color;
  const _VibeTagStyle(this.label, this.icon, this.color);
}

const Map<String, _VibeTagStyle> _vibeStyles = {
  'cafe': _VibeTagStyle('Café', FeatherIcons.coffee, Color(0xFFA0522D)),
  'casual': _VibeTagStyle('Casual', FeatherIcons.smile, Color(0xFF5B9BD5)),
  'cozy': _VibeTagStyle('Cozy', FeatherIcons.home, Color(0xFFE8915A)),
  'coffee_shop':
      _VibeTagStyle('Coffee', FeatherIcons.coffee, Color(0xFF6F4E37)),
  'bar': _VibeTagStyle('Bar', FeatherIcons.moon, Color(0xFF7B68EE)),
  'elegant': _VibeTagStyle('Elegant', FeatherIcons.feather, Color(0xFFB8860B)),
  'fine_dining':
      _VibeTagStyle('Fine Dining', FeatherIcons.award, Color(0xFFC9A96E)),
  'food_truck':
      _VibeTagStyle('Food Truck', FeatherIcons.truck, Color(0xFFFF6347)),
  'hole_in_the_wall':
      _VibeTagStyle('Hidden Gem', FeatherIcons.key, Color(0xFFCD853F)),
  'late_night':
      _VibeTagStyle('Late Night', FeatherIcons.moon, Color(0xFF483D8B)),
  'live_music':
      _VibeTagStyle('Live Music', FeatherIcons.music, Color(0xFFDC143C)),
  'bougie': _VibeTagStyle('Bougie', FeatherIcons.star, Color(0xFFFFD700)),
  'modern': _VibeTagStyle('Modern', FeatherIcons.zap, Color(0xFF00CED1)),
  'fast_food':
      _VibeTagStyle('Fast Food', FeatherIcons.fastForward, Color(0xFFFF4500)),
  'quiet': _VibeTagStyle('Quiet', FeatherIcons.volumeX, Color(0xFF8FBC8F)),
  'romantic': _VibeTagStyle('Romantic', FeatherIcons.heart, Color(0xFFFF69B4)),
  'sports_bar': _VibeTagStyle('Sports Bar', FeatherIcons.tv, Color(0xFF228B22)),
  'trendy': _VibeTagStyle('Trendy', FeatherIcons.trendingUp, Color(0xFFFF1493)),
  'takeout_friendly':
      _VibeTagStyle('Takeaway', FeatherIcons.package, Color(0xFF20B2AA)),
  'pub': _VibeTagStyle('Pub', FeatherIcons.home, Color(0xFF8B4513)),
  'shop': _VibeTagStyle('Shop', FeatherIcons.shoppingCart, Color(0xFF3CB371)),
  'brunch': _VibeTagStyle('Brunch', FeatherIcons.sun, Color(0xFFFFA07A)),
  'outdoor_dining':
      _VibeTagStyle('Outdoor', FeatherIcons.wind, Color(0xFF87CEEB)),
  'wavy': _VibeTagStyle('Wavy', FeatherIcons.activity, Color(0xFF6C5CE7)),
  'bossman': _VibeTagStyle('Bossman', FeatherIcons.shield, Color(0xFF636E72)),
};

/// Places this user saved early, before the hype.
class HiddenGemsSection extends StatelessWidget {
  final List<LocationModel> locations;

  const HiddenGemsSection({
    Key? key,
    required this.locations,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HIDDEN GEMS',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: PinitColors.aubergineSoft,
                  letterSpacing: 0.12 * 11,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hidden Gems',
                style: TextStyle(
                  fontFamily: 'Rova',
                  fontFamilyFallback: ['Naria'],
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: PinitColors.aubergine,
                  letterSpacing: 1.0,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Saved early, before the hype',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: PinitColors.aubergineSoft,
                ),
              ),
            ],
          ),
        ),

        // ── Horizontal scroll cards ──
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: locations.length,
            itemBuilder: (context, index) =>
                _HiddenGemCard(location: locations[index]),
          ),
        ),
      ],
    );
  }
}

class HottestSharedPlacesSection extends StatelessWidget {
  final List<LocationModel> locations;
  final Key? spotlightKey;

  const HottestSharedPlacesSection({
    super.key,
    required this.locations,
    this.spotlightKey,
  });

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RepaintBoundary(
          key: spotlightKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hottest shared places',
                  style: TextStyle(
                    fontFamily: 'Rova',
                    fontFamilyFallback: ['Naria'],
                    fontSize: 28,
                    fontWeight: FontWeight.w100,
                    color: PinitColors.aubergine,
                    letterSpacing: 1.0,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Top places people have pinned from social media',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: PinitColors.aubergineSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LocationMosaicGrid(
            locations: locations,
            resolveSharedVideoUrlOnOpen: true,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Individual card – image-dominant, mirrors _CarouselCard
// ─────────────────────────────────────────────────────────────
class _HiddenGemCard extends StatelessWidget {
  final LocationModel location;
  const _HiddenGemCard({required this.location});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel:
            MaterialLocalizations.of(context).modalBarrierDismissLabel,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (ctx, anim, _) => ExpandedLocationCard(
          location: location,
          onClose: () => Navigator.of(ctx).pop(),
        ),
        transitionBuilder: (ctx, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        decoration: BoxDecoration(
          color: PinitColors.cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: PinitColors.aubergine,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: PinitColors.aubergine,
              blurRadius: 0,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left: Image column ──
              SizedBox(
                width: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(context),
                    // Subtle bottom-up scrim
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00000000),
                              Color(0x33000000),
                            ],
                            stops: [0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Emoji circle (top-left)
                    if (location.emoji != null && location.emoji!.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: PinitColors.cream,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: PinitColors.aubergine,
                              width: 1.4,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            location.emoji!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Vertical divider ──
              Container(
                width: 1.5,
                color: PinitColors.aubergine,
              ),

              // ── Right: Info column ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Top label strip
                    Container(
                      color: PinitColors.creamSunk,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: Row(
                        children: [
                          const Icon(
                            FeatherIcons.key,
                            size: 11,
                            color: PinitColors.mute,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'EARLY SAVE',
                              style: GoogleFonts.dmSans(
                                fontSize: 9,
                                color: PinitColors.mute,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.9,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (location.rating != null) ...[
                            _CompactRating(
                              rating: location.rating!,
                              reviewCount: location.userRatingsTotal,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Body
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            // Name
                            Text(
                              location.name,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: PinitColors.aubergine,
                                height: 1.15,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            if (_summaryText != null)
                              Text(
                                _summaryText!,
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: PinitColors.mute,
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const Spacer(),
                            // Tags row
                            SizedBox(
                              height: 20,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                children: [
                                  if (location.priceLevel != null &&
                                      location.priceLevel! > 0)
                                    _PinitPill(
                                      label: '£' * location.priceLevel!,
                                      filled: true,
                                    ),
                                  if (location.cuisine != null &&
                                      location.cuisine!.isNotEmpty)
                                    _PinitPill(label: location.cuisine!),
                                  ..._topVibeTags.map((entry) {
                                    final style = _vibeStyles[entry.key];
                                    if (style == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return _PinitPill(
                                      label: style.label,
                                      icon: style.icon,
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? get _summaryText {
    if (location.generatedSummary != null &&
        location.generatedSummary!.isNotEmpty) return location.generatedSummary;
    if (location.editorialSummary != null &&
        location.editorialSummary!.isNotEmpty) return location.editorialSummary;
    if (location.recommendedDishes != null &&
        location.recommendedDishes!.isNotEmpty) {
      return 'Try: ${location.recommendedDishes}';
    }
    if (location.vicinity != null && location.vicinity!.isNotEmpty) {
      return location.vicinity;
    }
    return null;
  }

  List<MapEntry<String, double>> get _topVibeTags {
    if (location.vibe == null) return [];
    return location.vibe!
        .topTags(3)
        .where((e) => e.value > 0.3 && e.key != 'bossman')
        .take(2)
        .toList();
  }

  Widget _buildImage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = location.imageUrl ?? location.photoReference;

    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => Container(
          color: cs.surfaceContainerHighest,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => _imageFallback(cs),
      );
    }
    return _imageFallback(cs);
  }

  Widget _imageFallback(ColorScheme cs) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primaryContainer.withValues(alpha: 0.3),
              cs.surfaceContainerHighest,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            location.emoji ?? '📍',
            style: const TextStyle(fontSize: 48),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Micro-widgets – identical to location_carousel.dart equivalents
// ─────────────────────────────────────────────────────────────

/// Compact rating used inside the top label strip
class _CompactRating extends StatelessWidget {
  final double rating;
  final int? reviewCount;
  const _CompactRating({required this.rating, this.reviewCount});

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(FeatherIcons.star, size: 11, color: PinitColors.aubergine),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.dmSans(
            color: PinitColors.aubergine,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            height: 1.0,
            letterSpacing: 0.2,
          ),
        ),
        if (reviewCount != null && reviewCount! > 0) ...[
          const SizedBox(width: 3),
          Text(
            '(${_formatCount(reviewCount!)})',
            style: GoogleFonts.dmSans(
              color: PinitColors.mute,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ],
    );
  }
}

/// Universal pinit pill – used for tags, status, vibes.
/// - default: cream-sunk fill, aubergine ink, cream-deep border
/// - filled : aubergine fill, cream ink (active state)
class _PinitPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool filled;

  const _PinitPill({
    required this.label,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final Color border;

    if (filled) {
      bg = PinitColors.aubergine;
      fg = PinitColors.cream;
      border = PinitColors.aubergine;
    } else {
      bg = PinitColors.creamSunk;
      fg = PinitColors.aubergine;
      border = PinitColors.creamDeep;
    }

    return Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.4,
                height: 1.0,
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

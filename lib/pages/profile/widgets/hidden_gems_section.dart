import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  'cafe':             _VibeTagStyle('Café',        FeatherIcons.coffee,       Color(0xFFA0522D)),
  'casual':           _VibeTagStyle('Casual',       FeatherIcons.smile,        Color(0xFF5B9BD5)),
  'cozy':             _VibeTagStyle('Cozy',         FeatherIcons.home,         Color(0xFFE8915A)),
  'coffee_shop':      _VibeTagStyle('Coffee',       FeatherIcons.coffee,       Color(0xFF6F4E37)),
  'bar':              _VibeTagStyle('Bar',          FeatherIcons.moon,         Color(0xFF7B68EE)),
  'elegant':          _VibeTagStyle('Elegant',      FeatherIcons.feather,      Color(0xFFB8860B)),
  'fine_dining':      _VibeTagStyle('Fine Dining',  FeatherIcons.award,        Color(0xFFC9A96E)),
  'food_truck':       _VibeTagStyle('Food Truck',   FeatherIcons.truck,        Color(0xFFFF6347)),
  'hole_in_the_wall': _VibeTagStyle('Hidden Gem',   FeatherIcons.key,          Color(0xFFCD853F)),
  'late_night':       _VibeTagStyle('Late Night',   FeatherIcons.moon,         Color(0xFF483D8B)),
  'live_music':       _VibeTagStyle('Live Music',   FeatherIcons.music,        Color(0xFFDC143C)),
  'michelin_starred': _VibeTagStyle('Michelin',     FeatherIcons.star,         Color(0xFFFFD700)),
  'modern':           _VibeTagStyle('Modern',       FeatherIcons.zap,          Color(0xFF00CED1)),
  'fast_food':        _VibeTagStyle('Fast Food',    FeatherIcons.fastForward,  Color(0xFFFF4500)),
  'quiet':            _VibeTagStyle('Quiet',        FeatherIcons.volumeX,      Color(0xFF8FBC8F)),
  'romantic':         _VibeTagStyle('Romantic',     FeatherIcons.heart,        Color(0xFFFF69B4)),
  'sports_bar':       _VibeTagStyle('Sports Bar',   FeatherIcons.tv,           Color(0xFF228B22)),
  'trendy':           _VibeTagStyle('Trendy',       FeatherIcons.trendingUp,   Color(0xFFFF1493)),
  'takeout_friendly': _VibeTagStyle('Takeaway',     FeatherIcons.package,      Color(0xFF20B2AA)),
  'pub':              _VibeTagStyle('Pub',          FeatherIcons.home,         Color(0xFF8B4513)),
  'grocery_store':    _VibeTagStyle('Grocery',      FeatherIcons.shoppingCart, Color(0xFF3CB371)),
  'brunch':           _VibeTagStyle('Brunch',       FeatherIcons.sun,          Color(0xFFFFA07A)),
  'outdoor_dining':   _VibeTagStyle('Outdoor',      FeatherIcons.wind,         Color(0xFF87CEEB)),
  'wavy':             _VibeTagStyle('Wavy',         FeatherIcons.activity,     Color(0xFF6C5CE7)),
  'bossman':          _VibeTagStyle('Bossman',      FeatherIcons.shield,       Color(0xFF636E72)),
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

// ─────────────────────────────────────────────────────────────
//  Individual card – image-dominant, mirrors _CarouselCard
// ─────────────────────────────────────────────────────────────
class _HiddenGemCard extends StatelessWidget {
  final LocationModel location;
  const _HiddenGemCard({required this.location});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
        width: 210,
        margin: const EdgeInsets.only(right: 12, bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. Full-bleed image ──
              _buildImage(context),

              // ── 2. Gradient scrim ──
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.18),
                        Colors.black.withValues(alpha: 0.78),
                      ],
                      stops: const [0.0, 0.35, 1.0],
                    ),
                  ),
                ),
              ),

              // ── 3. Top-left: early badge + optional emoji ──
              Positioned(
                top: 10,
                left: 10,
                child: Row(
                  children: [
                    // Minimal frosted-glass badge — same language as the card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          color: Colors.black.withValues(alpha: 0.30),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FeatherIcons.key,
                                  size: 10, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'early save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Emoji bubble if present
                    if (location.emoji != null &&
                        location.emoji!.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          location.emoji!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── 4. Bottom glass overlay ──
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20)),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.30),
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Name + rating
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  location.name,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: PinitColors.aubergine,
                                    letterSpacing: -0.3,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (location.rating != null) ...[
                                const SizedBox(width: 6),
                                _RatingChip(rating: location.rating!),
                              ],
                            ],
                          ),

                          // Summary
                          if (_summaryText != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              _summaryText!,
                              style: GoogleFonts.dmSans(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          const SizedBox(height: 7),

                          // Tags row
                          SizedBox(
                            height: 22,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              children: [
                                if (location.priceLevel != null &&
                                    location.priceLevel! > 0)
                                  _InfoPill(
                                    text: '£' * location.priceLevel!,
                                    bgColor: const Color(0xFF00B894)
                                        .withValues(alpha: 0.25),
                                    textColor: const Color(0xFF55EFC4),
                                    fontWeight: FontWeight.w800,
                                  ),
                                if (location.cuisine != null &&
                                    location.cuisine!.isNotEmpty)
                                  _InfoPill(
                                    text: location.cuisine!,
                                    bgColor:
                                        Colors.white.withValues(alpha: 0.15),
                                    textColor: Colors.white,
                                  ),
                                ..._topVibeTags.map((entry) {
                                  final style = _vibeStyles[entry.key];
                                  if (style == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return _InfoPill(
                                    text: style.label,
                                    icon: style.icon,
                                    bgColor:
                                        style.color.withValues(alpha: 0.25),
                                    textColor: Color.lerp(
                                        style.color, Colors.white, 0.5)!,
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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

class _RatingChip extends StatelessWidget {
  final double rating;
  const _RatingChip({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Colors.amber.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(FeatherIcons.star, size: 9, color: Colors.amber),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color bgColor;
  final Color textColor;
  final FontWeight fontWeight;

  const _InfoPill({
    required this.text,
    this.icon,
    required this.bgColor,
    required this.textColor,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
        border:
            Border.all(color: textColor.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: fontWeight,
              fontSize: 10,
              letterSpacing: 0.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'pinit_colors.dart';

/// Places currently trending that this user has saved
class TrendingNowSection extends StatelessWidget {
  final List<LocationModel> locations;

  const TrendingNowSection({
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
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: PinitColors.surfaceLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  FeatherIcons.trendingUp,
                  size: 17,
                  color: PinitColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Popping Right Now',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: PinitColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Trending places you\'ve saved',
                      style: TextStyle(
                        fontSize: 13,
                        color: PinitColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Cards ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: locations
                .map((location) => _TrendingCard(location: location))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final LocationModel location;
  const _TrendingCard({required this.location});

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
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: PinitColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: PinitColors.cardShadow,
        ),
        child: Row(
          children: [
            // ── Image corner ──
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16)),
              child: SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(context),
                    // Subtle dark scrim — carousel language on a thumbnail
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.45),
                            ],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Open/closed dot in bottom-left of thumbnail
                    if (location.openNow != null)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: location.openNow!
                                ? const Color(0xFF00B894)
                                : const Color(0xFFE17055),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Info ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      location.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PinitColors.textPrimary,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Summary / vicinity
                    if (_summaryText != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        _summaryText!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PinitColors.textSecondary,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Pills row — carousel style
                    Row(
                      children: [
                        if (location.priceLevel != null &&
                            location.priceLevel! > 0) ...[
                          _Pill(
                            text: '£' * location.priceLevel!,
                            bgColor:
                                const Color(0xFF00B894).withValues(alpha: 0.12),
                            textColor: const Color(0xFF00B894),
                            fontWeight: FontWeight.w800,
                          ),
                          const SizedBox(width: 5),
                        ],
                        if (location.cuisine != null &&
                            location.cuisine!.isNotEmpty)
                          _Pill(
                            text: location.cuisine!,
                            bgColor: PinitColors.surfaceLight,
                            textColor: PinitColors.textSecondary,
                          ),
                        const Spacer(),
                        if (location.rating != null)
                          _RatingChip(rating: location.rating!),
                      ],
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

  String? get _summaryText {
    if (location.generatedSummary != null &&
        location.generatedSummary!.isNotEmpty) return location.generatedSummary;
    if (location.editorialSummary != null &&
        location.editorialSummary!.isNotEmpty) return location.editorialSummary;
    if (location.vicinity != null && location.vicinity!.isNotEmpty) {
      return location.vicinity;
    }
    return null;
  }

  Widget _buildImage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = location.imageUrl ?? location.photoReference;

    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: cs.surfaceContainerHighest),
        errorWidget: (_, __, ___) => _imageFallback(cs),
      );
    }
    return _imageFallback(cs);
  }

  Widget _imageFallback(ColorScheme cs) => Container(
        color: cs.surfaceContainerHighest,
        child: Center(
          child: Text(
            location.emoji ?? '📍',
            style: const TextStyle(fontSize: 28),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Micro-widgets
// ─────────────────────────────────────────────────────────────

class _RatingChip extends StatelessWidget {
  final double rating;
  const _RatingChip({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Colors.amber.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Color(0xFFF59E0B),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(FeatherIcons.star, size: 9, color: Color(0xFFF59E0B)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;
  final FontWeight fontWeight;

  const _Pill({
    required this.text,
    required this.bgColor,
    required this.textColor,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: fontWeight,
          fontSize: 10.5,
          letterSpacing: 0.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

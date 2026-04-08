import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'pinit_colors.dart';

/// Places currently trending — displayed as an Instagram Explore-style mosaic.
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
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              const Text(
                'Popping Right Now',
                style: TextStyle(
                  fontFamily: 'Rova',
                  fontSize: 28,
                  fontWeight: FontWeight.w100,
                  color: PinitColors.aubergine,
                  letterSpacing: 1.9,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hot places people have saved',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: PinitColors.aubergineSoft,
                ),
              ),
            ],
          ),
        ),

        // ── Mosaic grid ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _MosaicGrid(locations: locations),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Mosaic grid — groups of 3 with alternating large-tile side
// ─────────────────────────────────────────────────────────────────────────────

class _MosaicGrid extends StatelessWidget {
  final List<LocationModel> locations;
  const _MosaicGrid({required this.locations});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final totalWidth = constraints.maxWidth;

        // Tile dimensions derived from available width
        final smallWidth = (totalWidth - gap) / 3;
        final bigWidth = (totalWidth - gap) * 2 / 3;
        const infoBarHeight = 52.0;
        final smallHeight = smallWidth * 1.3 + infoBarHeight;
        final bigHeight = smallHeight * 2 + gap;

        // Split into groups of 3
        final rows = <Widget>[];
        for (var i = 0; i < locations.length; i += 3) {
          final chunk = locations.sublist(i, min(i + 3, locations.length));
          final rowIndex = i ~/ 3;

          if (rows.isNotEmpty) rows.add(const SizedBox(height: gap));

          if (chunk.length == 1) {
            rows.add(SizedBox(
              height: smallHeight,
              child: _MosaicTile(location: chunk[0]),
            ));
          } else if (chunk.length == 2) {
            rows.add(SizedBox(
              height: smallHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: smallWidth,
                    child: _MosaicTile(location: chunk[0]),
                  ),
                  const SizedBox(width: gap),
                  Expanded(child: _MosaicTile(location: chunk[1])),
                ],
              ),
            ));
          } else {
            // 3 tiles: big + two smalls, alternating sides
            final bigTile = SizedBox(
              width: bigWidth,
              height: bigHeight,
              child: _MosaicTile(location: chunk[0]),
            );
            final smallStack = SizedBox(
              width: smallWidth,
              height: bigHeight,
              child: Column(
                children: [
                  SizedBox(
                    height: smallHeight,
                    child: _MosaicTile(location: chunk[1]),
                  ),
                  const SizedBox(height: gap),
                  Expanded(child: _MosaicTile(location: chunk[2])),
                ],
              ),
            );

            rows.add(SizedBox(
              height: bigHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rowIndex.isEven
                    ? [bigTile, const SizedBox(width: gap), smallStack]
                    : [smallStack, const SizedBox(width: gap), bigTile],
              ),
            ));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Individual mosaic tile
// ─────────────────────────────────────────────────────────────────────────────

class _MosaicTile extends StatelessWidget {
  final LocationModel location;
  const _MosaicTile({required this.location});

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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PinitColors.aubergine, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: PinitColors.aubergine,
              blurRadius: 0,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.5),
          child: Container(
            decoration: const BoxDecoration(
              color: PinitColors.creamSunk,
            ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Image ──
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(context),
                    // Subtle bottom scrim so info bar edge feels clean
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 28,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.18),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Open/closed dot
                    if (location.openNow != null)
                      Positioned(
                        top: 8,
                        left: 8,
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

              // ── Info bar ──
              Container(
                height: 52,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                color: PinitColors.cream,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        location.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PinitColors.aubergine,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (location.rating != null) ...[
                      const SizedBox(width: 6),
                      _RatingChip(rating: location.rating!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
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

// ─────────────────────────────────────────────────────────────────────────────
//  Micro-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _RatingChip extends StatelessWidget {
  final double rating;
  const _RatingChip({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(7),
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
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(FeatherIcons.star, size: 8, color: Color(0xFFF59E0B)),
        ],
      ),
    );
  }
}

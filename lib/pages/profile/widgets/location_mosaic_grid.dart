import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pinit_colors.dart';

/// Instagram Explore-style mosaic grid of locations.
///
/// Groups locations into chunks of 3 with a large tile + two small tiles
/// and alternates the large tile left/right each row.
class LocationMosaicGrid extends StatelessWidget {
  const LocationMosaicGrid({
    super.key,
    required this.locations,
    this.gap = 6,
    this.resolveSharedVideoUrlOnOpen = false,
  });

  final List<LocationModel> locations;
  final double gap;
  final bool resolveSharedVideoUrlOnOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;

        // Tile dimensions derived from available width.
        final smallWidth = (totalWidth - gap) / 3;
        final bigWidth = (totalWidth - gap) * 2 / 3;
        const infoBarHeight = 76.0;
        final smallHeight = smallWidth * 1.3 + infoBarHeight;
        final bigHeight = smallHeight * 2 + gap;

        final rows = <Widget>[];
        for (var i = 0; i < locations.length; i += 3) {
          final chunk = locations.sublist(i, min(i + 3, locations.length));
          final rowIndex = i ~/ 3;

          if (rows.isNotEmpty) rows.add(SizedBox(height: gap));

          if (chunk.length == 1) {
            rows.add(SizedBox(
              height: smallHeight,
              child: _MosaicTile(
                location: chunk[0],
                resolveSharedVideoUrlOnOpen: resolveSharedVideoUrlOnOpen,
                isLarge: true,
              ),
            ));
          } else if (chunk.length == 2) {
            rows.add(SizedBox(
              height: smallHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: smallWidth,
                    child: _MosaicTile(
                      location: chunk[0],
                      resolveSharedVideoUrlOnOpen: resolveSharedVideoUrlOnOpen,
                      isLarge: false,
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: _MosaicTile(
                      location: chunk[1],
                      resolveSharedVideoUrlOnOpen: resolveSharedVideoUrlOnOpen,
                      isLarge: true,
                    ),
                  ),
                ],
              ),
            ));
          } else {
            final bigTile = SizedBox(
              width: bigWidth,
              height: bigHeight,
              child: _MosaicTile(
                location: chunk[0],
                resolveSharedVideoUrlOnOpen: resolveSharedVideoUrlOnOpen,
                isLarge: true,
              ),
            );
            final smallStack = SizedBox(
              width: smallWidth,
              height: bigHeight,
              child: Column(
                children: [
                  SizedBox(
                    height: smallHeight,
                    child: _MosaicTile(
                      location: chunk[1],
                      resolveSharedVideoUrlOnOpen: resolveSharedVideoUrlOnOpen,
                      isLarge: false,
                    ),
                  ),
                  SizedBox(height: gap),
                  Expanded(
                    child: _MosaicTile(
                      location: chunk[2],
                      resolveSharedVideoUrlOnOpen: resolveSharedVideoUrlOnOpen,
                      isLarge: false,
                    ),
                  ),
                ],
              ),
            );

            rows.add(SizedBox(
              height: bigHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rowIndex.isEven
                    ? [bigTile, SizedBox(width: gap), smallStack]
                    : [smallStack, SizedBox(width: gap), bigTile],
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

class _MosaicTile extends StatelessWidget {
  const _MosaicTile({
    required this.location,
    required this.resolveSharedVideoUrlOnOpen,
    required this.isLarge,
  });

  final LocationModel location;
  final bool resolveSharedVideoUrlOnOpen;
  final bool isLarge;

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
          resolveSharedVideoUrlOnOpen: resolveSharedVideoUrlOnOpen,
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
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImage(context),
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
                      if (location.hasSocialVideos)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _TikTokCountBadge(
                            count: location.socialVideoCount,
                          ),
                        ),
                      if (_socialVideoUrl != null)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: _TikTokPlayButton(
                            onTap: _openSocialVideo,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  height: isLarge ? 76 : 68,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  color: PinitColors.cream,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              location.name,
                              style: GoogleFonts.dmSans(
                                fontSize: isLarge ? 13 : 12,
                                fontWeight: FontWeight.w800,
                                color: PinitColors.aubergine,
                                letterSpacing: -0.2,
                                height: 1.15,
                              ),
                              maxLines: isLarge ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (location.rating != null) ...[
                            const SizedBox(width: 6),
                            _RatingChip(rating: location.rating!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitle,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: PinitColors.aubergineSoft,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isLarge && _dishLabel != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          _dishLabel!,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: PinitColors.aubergine,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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

  String? get _socialVideoUrl {
    final url = location.socialVideoUrl?.trim();
    return url == null || url.isEmpty ? null : url;
  }

  String? get _dishLabel {
    final dish = location.tiktokRecommendedDish?.trim();
    if (dish == null || dish.isEmpty) return null;
    return 'TikTok pick: $dish';
  }

  String get _subtitle {
    if (location.hasSocialVideos) {
      final count = location.socialVideoCount;
      if (count <= 1) return '1 TikTok shared here';
      return '$count TikToks shared here';
    }
    final vicinity = location.vicinity?.trim();
    if (vicinity != null && vicinity.isNotEmpty) return vicinity;
    return 'Shared place';
  }

  Future<void> _openSocialVideo() async {
    final url = _socialVideoUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

class _TikTokCountBadge extends StatelessWidget {
  const _TikTokCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count <= 1 ? 'TikTok' : '$count TikToks';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: PinitColors.aubergine.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: PinitColors.cream.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            FeatherIcons.video,
            size: 10,
            color: PinitColors.cream,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: PinitColors.cream,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TikTokPlayButton extends StatelessWidget {
  const _TikTokPlayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: PinitColors.cream,
          shape: BoxShape.circle,
          border: Border.all(color: PinitColors.aubergine, width: 1.4),
          boxShadow: const [
            BoxShadow(
              color: PinitColors.aubergine,
              blurRadius: 0,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: const Icon(
          FeatherIcons.play,
          size: 15,
          color: PinitColors.aubergine,
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(7),
        border:
            Border.all(color: Colors.amber.withValues(alpha: 0.25), width: 0.5),
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

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A single rich tile for a location in the Explore bottom sheet.
class ExploreLocationTile extends StatelessWidget {
  final LocationModel location;
  final double? distanceKm;
  final VoidCallback? onTap;
  final VoidCallback? onSave;

  const ExploreLocationTile({
    super.key,
    required this.location,
    this.distanceKm,
    this.onTap,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vibeTopTags = location.vibe?.topTags(3) ?? [];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              // ── Image ──
              _buildImage(isDark),
              // ── Info ──
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildNameRow(isDark),
                      const SizedBox(height: 4),
                      _buildMetaRow(isDark),
                      if (location.editorialSummary != null &&
                          location.editorialSummary!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          location.editorialSummary!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white60
                                : Colors.black54,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (vibeTopTags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildVibeTags(vibeTopTags, isDark),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(bool isDark) {
    return SizedBox(
      width: 100,
      height: 110,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (location.imageUrl != null && location.imageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: location.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: Center(
                  child: Text(
                    location.emoji ?? '📍',
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: Center(
                  child: Text(
                    location.emoji ?? '📍',
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
            )
          else
            Container(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              child: Center(
                child: Text(
                  location.emoji ?? '📍',
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
          // Match score badge
          if (location.matchScore != null && location.matchScore! > 0)
            Positioned(
              top: 6,
              left: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C5CE7).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(location.matchScore! * 100).round()}%',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNameRow(bool isDark) {
    return Row(
      children: [
        if (location.emoji != null) ...[
          Text(location.emoji!, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            location.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaRow(bool isDark) {
    final metaItems = <Widget>[];
    final mutedColor = isDark ? Colors.white54 : Colors.black45;
    final metaStyle = GoogleFonts.poppins(fontSize: 11, color: mutedColor);

    // Rating
    if (location.rating != null) {
      metaItems.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFC107)),
          const SizedBox(width: 2),
          Text(location.rating!.toStringAsFixed(1), style: metaStyle),
          if (location.userRatingsTotal != null)
            Text(' (${location.userRatingsTotal})', style: metaStyle),
        ],
      ));
    }

    // Price
    if (location.priceBucket != null && location.priceBucket!.isNotEmpty) {
      metaItems.add(Text(location.priceBucket!, style: metaStyle));
    }

    // Cuisine
    if (location.cuisinePrimary != null &&
        location.cuisinePrimary!.isNotEmpty) {
      metaItems.add(Text(location.cuisinePrimary!, style: metaStyle));
    }

    return Wrap(
      spacing: 8,
      children: metaItems
          .expand((w) => [
                w,
                Text('·', style: metaStyle),
              ])
          .toList()
        ..removeLast(), // remove trailing dot
    );
  }

  Widget _buildVibeTags(List<MapEntry<String, double>> tags, bool isDark) {
    const tagColors = {
      'romantic': Color(0xFFE84393),
      'trendy': Color(0xFF6C5CE7),
      'casual': Color(0xFF00B894),
      'upscale': Color(0xFFFDAA5E),
      'cozy': Color(0xFFE17055),
      'lively': Color(0xFF0984E3),
      'family_friendly': Color(0xFF00CEC9),
      'outdoor_dining': Color(0xFF55EFC4),
      'late_night': Color(0xFF2D3436),
      'live_music': Color(0xFFD63031),
    };

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tags.map((entry) {
        final color = tagColors[entry.key] ?? const Color(0xFF636E72);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.25 : 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Text(
            entry.key.replaceAll('_', ' '),
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? color.withValues(alpha: 0.9) : color,
            ),
          ),
        );
      }).toList(),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/utils/geo_types.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

enum _SavedSort { none, lastAdded, alphabetical, highestRated }

// ─────────────────────────────────────────────────────────────
//  Vibe tag display config – mirrors location_carousel.dart
// ─────────────────────────────────────────────────────────────
class _VibeTagStyle {
  final String label;
  final IconData icon;
  const _VibeTagStyle(this.label, this.icon);
}

const Map<String, _VibeTagStyle> _vibeStyles = {
  'cafe': _VibeTagStyle('Café', FeatherIcons.coffee),
  'casual': _VibeTagStyle('Casual', FeatherIcons.smile),
  'cozy': _VibeTagStyle('Cozy', FeatherIcons.home),
  'coffee_shop': _VibeTagStyle('Coffee', FeatherIcons.coffee),
  'bar': _VibeTagStyle('Bar', FeatherIcons.moon),
  'elegant': _VibeTagStyle('Elegant', FeatherIcons.feather),
  'fine_dining': _VibeTagStyle('Fine Dining', FeatherIcons.award),
  'food_truck': _VibeTagStyle('Food Truck', FeatherIcons.truck),
  'hole_in_the_wall': _VibeTagStyle('Hidden Gem', FeatherIcons.key),
  'late_night': _VibeTagStyle('Late Night', FeatherIcons.moon),
  'live_music': _VibeTagStyle('Live Music', FeatherIcons.music),
  'bougie': _VibeTagStyle('Bougie', FeatherIcons.star),
  'modern': _VibeTagStyle('Modern', FeatherIcons.zap),
  'fast_food': _VibeTagStyle('Fast Food', FeatherIcons.fastForward),
  'quiet': _VibeTagStyle('Quiet', FeatherIcons.volumeX),
  'romantic': _VibeTagStyle('Romantic', FeatherIcons.heart),
  'sports_bar': _VibeTagStyle('Sports Bar', FeatherIcons.tv),
  'trendy': _VibeTagStyle('Trendy', FeatherIcons.trendingUp),
  'takeout_friendly': _VibeTagStyle('Takeaway', FeatherIcons.package),
  'pub': _VibeTagStyle('Pub', FeatherIcons.home),
  'shop': _VibeTagStyle('Shop', FeatherIcons.shoppingCart),
  'brunch': _VibeTagStyle('Brunch', FeatherIcons.sun),
  'outdoor_dining': _VibeTagStyle('Outdoor', FeatherIcons.wind),
  'wavy': _VibeTagStyle('Wavy', FeatherIcons.activity),
  'bossman': _VibeTagStyle('Bossman', FeatherIcons.shield),
};

class CarouselListPage extends StatefulWidget {
  final List<LocationModel> locations;
  final String title;
  final LocationListType? listType;

  const CarouselListPage({
    Key? key,
    required this.locations,
    required this.title,
    this.listType,
  }) : super(key: key);

  @override
  State<CarouselListPage> createState() => _CarouselListPageState();
}

class _CarouselListPageState extends State<CarouselListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _SavedSort _savedSort = _SavedSort.none;

  bool get _isSavedSeeAll => widget.listType == LocationListType.saved;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LocationModel> get _visibleLocations {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? List<LocationModel>.from(widget.locations)
        : widget.locations
            .where((loc) => loc.name.toLowerCase().contains(query))
            .toList();

    if (!_isSavedSeeAll) return filtered;

    switch (_savedSort) {
      case _SavedSort.none:
        return filtered;
      case _SavedSort.lastAdded:
        return filtered;
      case _SavedSort.alphabetical:
        filtered.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        return filtered;
      case _SavedSort.highestRated:
        filtered.sort((a, b) {
          final aRating = a.rating;
          final bRating = b.rating;
          if (aRating == null && bRating == null) return 0;
          if (aRating == null) return 1;
          if (bRating == null) return -1;
          final ratingCompare = bRating.compareTo(aRating);
          if (ratingCompare != 0) return ratingCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return filtered;
    }
  }

  String _labelForSavedSort(_SavedSort sort) {
    switch (sort) {
      case _SavedSort.none:
        return 'None';
      case _SavedSort.lastAdded:
        return 'Last added';
      case _SavedSort.alphabetical:
        return 'Alphabetical';
      case _SavedSort.highestRated:
        return 'Highest rated';
    }
  }

  _SavedSort _nextSavedSort(_SavedSort current) {
    switch (current) {
      case _SavedSort.none:
        return _SavedSort.lastAdded;
      case _SavedSort.lastAdded:
        return _SavedSort.alphabetical;
      case _SavedSort.alphabetical:
        return _SavedSort.highestRated;
      case _SavedSort.highestRated:
        return _SavedSort.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleLocations;
    return Scaffold(
      backgroundColor: PinitColors.cream,
      appBar: AppBar(
        backgroundColor: PinitColors.cream,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Icon(
              FeatherIcons.arrowLeft,
              color: PinitColors.aubergine,
              size: 24,
            ),
          ),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            fontFamily: 'Rova',
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: PinitColors.aubergine,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    textInputAction: TextInputAction.search,
                    cursorColor: PinitColors.aubergine,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PinitColors.aubergine,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by name',
                      hintStyle: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: PinitColors.mute,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: PinitColors.aubergineSoft,
                      ),
                      suffixIcon: _query.trim().isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: PinitColors.aubergineSoft,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      fillColor: PinitColors.creamSunk,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: PinitColors.creamDeep,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: PinitColors.aubergine,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isSavedSeeAll) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      setState(() => _savedSort = _nextSavedSort(_savedSort));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: PinitColors.cream,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: PinitColors.aubergine,
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: PinitColors.aubergine,
                            blurRadius: 0,
                            offset: Offset(3, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.swap_vert_rounded,
                            size: 14,
                            color: PinitColors.aubergine,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _labelForSavedSort(_savedSort),
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: PinitColors.aubergine,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                      child: Text(
                        'No matches.',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: PinitColors.mute,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: visible.length,
                    itemBuilder: (context, index) =>
                        _ListCard(location: visible[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  List card – image-left / info-right, mirrors carousel card
// ─────────────────────────────────────────────────────────────
class _ListCard extends StatelessWidget {
  final LocationModel location;
  const _ListCard({required this.location});

  bool get _isWavy => (location.vibe?.wavyScore ?? 0) > 0.45;

  @override
  Widget build(BuildContext context) {
    final manager = Provider.of<LocationListManager?>(context);
    final walkEta = _walkEtaLabel(manager?.currentPosition);
    print('walkEta: $walkEta'); // Debugging: check the computed ETA label
    final Color borderColor =
        _isWavy ? PinitColors.accent : PinitColors.aubergine;
    final Color shadowColor =
        _isWavy ? PinitColors.accent : PinitColors.aubergine;

    return GestureDetector(
      onTap: () {
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel:
              MaterialLocalizations.of(context).modalBarrierDismissLabel,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (ctx, anim, secondAnim) => ExpandedLocationCard(
            location: location,
            onClose: () => Navigator.of(ctx).pop(),
          ),
          transitionBuilder: (ctx, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 110,
        decoration: BoxDecoration(
          color: PinitColors.cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
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
                width: 120,
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
                          width: 32,
                          height: 32,
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
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    // Open / closed pill (bottom-left of image)
                    if (location.openNow != null)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: _PinitPill(
                          label: location.openNow! ? 'OPEN' : 'CLOSED',
                          icon: location.openNow!
                              ? FeatherIcons.checkCircle
                              : FeatherIcons.xCircle,
                          filled: true,
                        ),
                      ),
                  ],
                ),
              ),

              // ── Vertical divider ──
              Container(
                width: 1.5,
                color: borderColor,
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
                          horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            location.preference == LocationPreference.saved
                                ? FeatherIcons.heart
                                : location.preference ==
                                        LocationPreference.recommended
                                    ? FeatherIcons.award
                                    : location.preference ==
                                            LocationPreference.bubble
                                        ? FeatherIcons.users
                                        : FeatherIcons.mapPin,
                            size: 11,
                            color: PinitColors.mute,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _topStripLabel(),
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                color: PinitColors.mute,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (walkEta != null) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.directions_walk_rounded,
                                  size: 12,
                                  color: PinitColors.mute,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  walkEta,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    color: PinitColors.mute,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                              if (location.rating != null) ...[
                                const SizedBox(width: 6),
                                _CompactRating(
                                  rating: location.rating!,
                                  reviewCount: location.userRatingsTotal,
                                ),
                              ],
                              if (location.matchScore != null &&
                                  location.matchScore! > 0.1) ...[
                                const SizedBox(width: 6),
                                _MatchBadge(
                                    score:
                                        (location.matchScore! * 100).round()),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            // Name
                            Text(
                              location.name,
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: PinitColors.aubergine,
                                height: 1.15,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            if (_summaryText != null)
                              Text(
                                _summaryText!,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: PinitColors.mute,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
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
                                    final isWavyTag = entry.key == 'wavy';
                                    return _PinitPill(
                                      label: style.label,
                                      icon: style.icon,
                                      accent: isWavyTag,
                                    );
                                  }),
                                  if (location.isOpenLate == true)
                                    const _PinitPill(
                                      label: 'Late Night',
                                      icon: FeatherIcons.moon,
                                    ),
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

  // ── Computed helpers ──

  String _topStripLabel() {
    if (location.preference == LocationPreference.saved) return 'SAVED';
    if (location.preference == LocationPreference.recommended) {
      return 'TOP PICK';
    }
    if (location.preference == LocationPreference.bubble) {
      return 'BUBBLE PICK';
    }
    if (location.preference == LocationPreference.search) return 'MATCH';
    if (location.savedCount != null && location.savedCount! > 0) {
      return '${location.savedCount} SAVES';
    }
    if (location.cuisine != null && location.cuisine!.isNotEmpty) {
      return location.cuisine!.toUpperCase();
    }
    return 'NEARBY';
  }

  String? _walkEtaLabel(LatLng? userPosition) {
    if (userPosition == null || location.lat == null || location.lng == null) {
      return null;
    }

    final km = _haversineKm(
      userPosition.latitude,
      userPosition.longitude,
      location.lat!,
      location.lng!,
    );
    final minutes = math.max(1, (km * 12).round()); // ~5km/h
    if (minutes < 60) return '$minutes min';
    return null;
  }

  double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  String? get _summaryText {
    if (location.generatedSummary != null &&
        location.generatedSummary!.isNotEmpty) {
      return location.generatedSummary!;
    }
    if (location.editorialSummary != null &&
        location.editorialSummary!.isNotEmpty) {
      return location.editorialSummary!;
    }
    if (location.recommendedDishes != null &&
        location.recommendedDishes!.isNotEmpty) {
      return 'Try: ${location.recommendedDishes!}';
    }
    if (location.vicinity != null && location.vicinity!.isNotEmpty) {
      return location.vicinity!;
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
    final url = location.imageUrl ?? location.photoReference;

    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => _imagePlaceholder(),
        errorWidget: (_, __, error) => _imageError(),
      );
    }
    return _imageEmpty();
  }

  Widget _imagePlaceholder() => Container(
        color: PinitColors.creamSunk,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(PinitColors.aubergineSoft),
            ),
          ),
        ),
      );

  Widget _imageError() => Container(
        color: PinitColors.creamSunk,
        child: const Center(
          child: Icon(FeatherIcons.image,
              size: 28, color: PinitColors.aubergineSoft),
        ),
      );

  Widget _imageEmpty() => Container(
        color: PinitColors.creamSunk,
        child: Center(
          child: Text(
            location.emoji ?? '📍',
            style: const TextStyle(fontSize: 40),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
//  Micro-widgets – reused from location_carousel.dart
// ─────────────────────────────────────────────────────────────

/// Compact rating in the top label strip
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

/// Match-score badge for the top strip
class _MatchBadge extends StatelessWidget {
  final int score;
  const _MatchBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = PinitColors.matchIndicator(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Text(
        '$score%',
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Universal pinit pill – used for tags, status, vibes
class _PinitPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool filled;
  final bool accent;

  const _PinitPill({
    required this.label,
    this.icon,
    this.filled = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final Color border;

    if (accent) {
      bg = PinitColors.accent;
      fg = PinitColors.cream;
      border = PinitColors.accent;
    } else if (filled) {
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

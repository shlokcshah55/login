import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:developer';

// ─────────────────────────────────────────────────────────────
//  Vibe tag display config: label, icon, colour
// ─────────────────────────────────────────────────────────────
class _VibeTagStyle {
  final String label;
  final IconData icon;
  final Color color;
  const _VibeTagStyle(this.label, this.icon, this.color);
}

const Map<String, _VibeTagStyle> _vibeStyles = {
  'cafe':             _VibeTagStyle('Café',          FeatherIcons.coffee,    Color(0xFFA0522D)),
  'casual':           _VibeTagStyle('Casual',         FeatherIcons.smile,     Color(0xFF5B9BD5)),
  'cozy':             _VibeTagStyle('Cozy',           FeatherIcons.home,      Color(0xFFE8915A)),
  'coffee_shop':      _VibeTagStyle('Coffee',         FeatherIcons.coffee,    Color(0xFF6F4E37)),
  'bar':              _VibeTagStyle('Bar',            FeatherIcons.moon,      Color(0xFF7B68EE)),
  'elegant':          _VibeTagStyle('Elegant',        FeatherIcons.feather,   Color(0xFFB8860B)),
  'fine_dining':      _VibeTagStyle('Fine Dining',    FeatherIcons.award,     Color(0xFFC9A96E)),
  'food_truck':       _VibeTagStyle('Food Truck',     FeatherIcons.truck,     Color(0xFFFF6347)),
  'hole_in_the_wall': _VibeTagStyle('Hidden Gem',     FeatherIcons.key,       Color(0xFFCD853F)),
  'late_night':       _VibeTagStyle('Late Night',     FeatherIcons.moon,      Color(0xFF483D8B)),
  'live_music':       _VibeTagStyle('Live Music',     FeatherIcons.music,     Color(0xFFDC143C)),
  'michelin_starred':  _VibeTagStyle('Michelin',       FeatherIcons.star,      Color(0xFFFFD700)),
  'modern':           _VibeTagStyle('Modern',         FeatherIcons.zap,       Color(0xFF00CED1)),
  'fast_food':        _VibeTagStyle('Fast Food',      FeatherIcons.fastForward, Color(0xFFFF4500)),
  'quiet':            _VibeTagStyle('Quiet',          FeatherIcons.volumeX,   Color(0xFF8FBC8F)),
  'romantic':         _VibeTagStyle('Romantic',        FeatherIcons.heart,     Color(0xFFFF69B4)),
  'sports_bar':       _VibeTagStyle('Sports Bar',     FeatherIcons.tv,        Color(0xFF228B22)),
  'trendy':           _VibeTagStyle('Trendy',         FeatherIcons.trendingUp, Color(0xFFFF1493)),
  'takeout_friendly': _VibeTagStyle('Takeaway',       FeatherIcons.package,   Color(0xFF20B2AA)),
  'pub':              _VibeTagStyle('Pub',            FeatherIcons.home,      Color(0xFF8B4513)),
  'grocery_store':    _VibeTagStyle('Grocery',        FeatherIcons.shoppingCart, Color(0xFF3CB371)),
  'brunch':           _VibeTagStyle('Brunch',         FeatherIcons.sun,       Color(0xFFFFA07A)),
  'outdoor_dining':   _VibeTagStyle('Outdoor',        FeatherIcons.wind,      Color(0xFF87CEEB)),
  'wavy':             _VibeTagStyle('Wavy 🌊',        FeatherIcons.activity,  Color(0xFFFF6B6B)),
  'bossman':          _VibeTagStyle('Bossman',        FeatherIcons.shield,    Color(0xFF636E72)),
};

class LocationCarousel extends StatelessWidget {
  final PageController pageController;
  final List<LocationModel> locations;
  final String? selectedMarkerId;
  final bool bottomNavVisible;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<LocationModel> onLocationSelected;
  final void Function(LocationModel location)? onSwipeUp;
  final void Function(LocationModel location)? onSwipeDown;

  const LocationCarousel({
    Key? key,
    required this.pageController,
    required this.locations,
    required this.selectedMarkerId,
    required this.bottomNavVisible,
    required this.onPageChanged,
    required this.onLocationSelected,
    this.onSwipeUp,
    this.onSwipeDown,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuint,
      height: bottomNavVisible ? 185.0 : 215.0,
      child: PageView.builder(
        controller: pageController,
        itemCount: locations.length,
        pageSnapping: true,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemBuilder: (context, index) {
          final location = locations[index];
          final isSelected =
              selectedMarkerId == location.locationId.toString();
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuint,
            margin: EdgeInsets.symmetric(
              horizontal: 6.0,
              vertical: isSelected ? 0 : 8.0,
            ),
            transform: isSelected
                ? Matrix4.identity()
                : (Matrix4.identity()..scale(0.96)),
            transformAlignment: Alignment.center,
            child: _SwipeableCard(
              location: location,
              isSelected: isSelected,
              bottomNavVisible: bottomNavVisible,
              onLocationSelected: onLocationSelected,
              onSwipeUp: onSwipeUp,
              onSwipeDown: onSwipeDown,
            ),
          );
        },
        onPageChanged: onPageChanged,
      ),
    );
  }
}

/// Wraps a [_CarouselCard] with vertical swipe gesture detection.
/// Swipe up → shortlist; swipe down → save.
/// Shows animated vertical translation + opacity for tactile feedback.
class _SwipeableCard extends StatefulWidget {
  final LocationModel location;
  final bool isSelected;
  final bool bottomNavVisible;
  final ValueChanged<LocationModel> onLocationSelected;
  final void Function(LocationModel)? onSwipeUp;
  final void Function(LocationModel)? onSwipeDown;

  const _SwipeableCard({
    required this.location,
    required this.isSelected,
    required this.bottomNavVisible,
    required this.onLocationSelected,
    this.onSwipeUp,
    this.onSwipeDown,
  });

  @override
  State<_SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<_SwipeableCard>
    with SingleTickerProviderStateMixin {
  double _dragY = 0;
  bool _showShortlistConfirmed = false;
  Timer? _shortlistFeedbackTimer;
  static const _threshold = 60.0;

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    setState(() => _dragY += d.delta.dy);
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (_dragY < -_threshold && widget.onSwipeUp != null) {
      // Swiped up → shortlist
      _shortlistFeedbackTimer?.cancel();
      setState(() => _showShortlistConfirmed = true);
      _shortlistFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() => _showShortlistConfirmed = false);
      });
      widget.onSwipeUp!(widget.location);
    } else if (_dragY > _threshold && widget.onSwipeDown != null) {
      // Swiped down → save
      widget.onSwipeDown!(widget.location);
    }
    setState(() => _dragY = 0);
  }

  @override
  void dispose() {
    _shortlistFeedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragY / 120).clamp(-1.0, 1.0);
    final opacity = (1.0 - progress.abs() * 0.4).clamp(0.5, 1.0);
    final shortlistDragProgress = (-_dragY / _threshold).clamp(0.0, 1.0);
    final shortlistIndicatorOpacity = _showShortlistConfirmed
        ? 1.0
        : shortlistDragProgress;
    final shortlistIndicatorScale = _showShortlistConfirmed
      ? 1.18
      : 0.90 + (shortlistDragProgress * 0.22);
    final shortlistIndicatorSlideY = _showShortlistConfirmed
      ? 0.0
      : 0.20 - (shortlistDragProgress * 0.20);

    return GestureDetector(
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: AnimatedContainer(
        duration: _dragY == 0
            ? const Duration(milliseconds: 200)
            : Duration.zero,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _dragY * 0.4, 0),
        child: Opacity(
          opacity: opacity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _CarouselCard(
                location: widget.location,
                isSelected: widget.isSelected,
                bottomNavVisible: widget.bottomNavVisible,
                onLocationSelected: widget.onLocationSelected,
              ),
              // Swipe up shortlist feedback (beneath card)
              Positioned(
                bottom: -34,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 140),
                      opacity: shortlistIndicatorOpacity,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        offset: Offset(0, shortlistIndicatorSlideY),
                        child: AnimatedScale(
                          duration: Duration(
                            milliseconds:
                                _showShortlistConfirmed ? 280 : 140,
                          ),
                          curve: _showShortlistConfirmed
                              ? Curves.elasticOut
                              : Curves.easeOutCubic,
                          scale: shortlistIndicatorScale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF16A34A)
                                      .withOpacity(0.42),
                                  blurRadius: 20,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.playlist_add_check_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Shortlisted',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_dragY > 30)
                Positioned(
                  bottom: -24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 100),
                      opacity: (_dragY / _threshold).clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B894),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '↓ Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
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
}


// ─────────────────────────────────────────────────────────────
//  Individual card – image-dominant with overlaid info
// ─────────────────────────────────────────────────────────────
class _CarouselCard extends StatelessWidget {
  final LocationModel location;
  final bool isSelected;
  final bool bottomNavVisible;
  final ValueChanged<LocationModel> onLocationSelected;

  const _CarouselCard({
    required this.location,
    required this.isSelected,
    required this.bottomNavVisible,
    required this.onLocationSelected,
  });

  // ── Whether this location is "wavy" enough to get the shimmer border ──
  bool get _isWavy => (location.vibe?.wavyScore ?? 0) > 0.45;
  bool get _isBossman => (location.vibe?.bossmanScore ?? 0) > 0.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        log("Tapped card for: ${location.name} (ID: ${location.locationId})");
        onLocationSelected(location);
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          // Wavy locations get a warm coral-gold border
          border: _isWavy
              ? Border.all(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.7), width: 2)
              : isSelected
                  ? Border.all(color: colorScheme.primary, width: 2)
                  : null,
          boxShadow: [
            if (_isWavy) ...[
              BoxShadow(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.18),
                blurRadius: 14,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFFFFD93D).withValues(alpha: 0.10),
                blurRadius: 20,
                spreadRadius: -2,
                offset: const Offset(0, 6),
              ),
            ] else ...[
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: isSelected ? 0.20 : 0.10),
                blurRadius: isSelected ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. Full-bleed image ──
              _buildImage(theme),

              // ── 2. Gradient scrim for readability ──
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.65),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),

              // ── 3. Top-left: Emoji avatar + preference badge ──
              Positioned(
                top: 10,
                left: 10,
                child: Row(
                  children: [
                    // Emoji circle
                    if (location.emoji != null && location.emoji!.isNotEmpty)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withOpacity(0.6)
                              : Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          location.emoji!,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    const SizedBox(width: 6),
                    if (location.preference != null)
                      _buildPreferenceBadge(location.preference!, theme),
                  ],
                ),
              ),

              // ── 4. Top-right: status badges stack ──
              Positioned(
                top: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Open / Closed live indicator
                    if (location.openNow != null)
                      _StatusPill(
                        text: location.openNow! ? 'Open' : 'Closed',
                        color: location.openNow!
                            ? const Color(0xFF00B894)
                            : const Color(0xFFE17055),
                        icon: location.openNow!
                            ? FeatherIcons.checkCircle
                            : FeatherIcons.xCircle,
                      ),
                    if (location.openNow != null) const SizedBox(height: 4),

                    // Match score badge
                    if (location.matchScore != null &&
                        location.matchScore! > 0.1)
                      _StatusPill(
                        text: '${(location.matchScore! * 100).round()}% match',
                        color: colorScheme.primary,
                        icon: FeatherIcons.target,
                      ),
                    if (location.matchScore != null &&
                        location.matchScore! > 0.1)
                      const SizedBox(height: 4),

                    // Saved count
                    if (location.savedCount != null &&
                        location.savedCount! > 0)
                      _StatusPill(
                        text: '${location.savedCount} saves',
                        color: Colors.white.withOpacity(0.85),
                        textColor: Colors.black87,
                        icon: FeatherIcons.bookmark,
                        iconColor: colorScheme.primary,
                      ),
                  ],
                ),
              ),

              // ── 5. Bottom overlay: all the info ──
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
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.2),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Name + rating row ──
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  location.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    letterSpacing: -0.3,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (location.rating != null)
                                _RatingChip(
                                  rating: location.rating!,
                                  reviewCount: location.userRatingsTotal,
                                ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // ── One-liner summary or vicinity ──
                          if (_summaryText != null)
                            Text(
                              _summaryText!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                                height: 1.3,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (_summaryText != null) const SizedBox(height: 7),

                          // ── Tags row: price + cuisine + vibe pills ──
                          SizedBox(
                            height: 24,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              children: [
                                // Price level
                                if (location.priceLevel != null &&
                                    location.priceLevel! > 0)
                                  _InfoPill(
                                    text: '£' * location.priceLevel!,
                                    bgColor:
                                        const Color(0xFF00B894).withOpacity(0.25),
                                    textColor: const Color(0xFF55EFC4),
                                    fontWeight: FontWeight.w800,
                                  ),
                                // Cuisine
                                if (location.cuisine != null &&
                                    location.cuisine!.isNotEmpty)
                                  _InfoPill(
                                    text: location.cuisine!,
                                    bgColor: Colors.white.withOpacity(0.15),
                                    textColor: Colors.white,
                                  ),
                                // Top 2 vibe tags
                                ..._topVibeTags.map((entry) {
                                  final style = _vibeStyles[entry.key];
                                  if (style == null) return const SizedBox.shrink();
                                  return _InfoPill(
                                    text: style.label,
                                    icon: style.icon,
                                    bgColor: style.color.withOpacity(0.25),
                                    textColor:
                                        Color.lerp(style.color, Colors.white, 0.5)!,
                                  );
                                }),
                                // Feature micro-icons
                                ..._featureIcons,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── 6. Wavy shimmer overlay (top edge gleam) ──
              if (_isWavy)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 2.5,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFFF6B6B),
                          Color(0xFFFFD93D),
                          Color(0xFFFF8C42),
                          Color(0xFFFFD93D),
                          Color(0xFFFF6B6B),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── 7. Late night indicator (bottom-right) ──
              if (location.isOpenLate == true)
                Positioned(
                  top: 10,
                  left: location.emoji != null ? 100 : 60,
                  child: _StatusPill(
                    text: 'Late Night',
                    color: const Color(0xFF2D3436),
                    icon: FeatherIcons.moon,
                    iconColor: const Color(0xFFFDCB6E),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Computed helpers ──

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
      return '🍽 Try: ${location.recommendedDishes!}';
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

  List<Widget> get _featureIcons {
    final icons = <Widget>[];
    void addIf(bool? flag, IconData icon, Color color, String tooltip) {
      if (flag == true) {
        icons.add(
          Tooltip(
            message: tooltip,
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 13, color: color),
            ),
          ),
        );
      }
    }

    addIf(location.outdoorSeating, FeatherIcons.sun, const Color(0xFFFDCB6E),
        'Outdoor seating');
    addIf(location.liveMusic, FeatherIcons.music, const Color(0xFFE17055),
        'Live music');
    addIf(location.servesCocktails, FeatherIcons.droplet,
        const Color(0xFF74B9FF), 'Cocktails');
    addIf(location.servesBrunch, FeatherIcons.sunrise, const Color(0xFFFFA502),
        'Brunch');
    addIf(location.servesVegetarianFood, FeatherIcons.feather,
        const Color(0xFF00B894), 'Vegetarian');
    addIf(location.goodForGroups, FeatherIcons.users, const Color(0xFFA29BFE),
        'Good for groups');
    addIf(location.isTakeaway, FeatherIcons.package, const Color(0xFF81ECEC),
        'Takeaway');

    return icons;
  }

  // ── Preference badge ──

  Widget _buildPreferenceBadge(LocationPreference pref, ThemeData theme) {
    final (IconData icon, String label, Color bg, Color fg) = switch (pref) {
      LocationPreference.saved => (
          FeatherIcons.heart,
          'Saved',
          theme.colorScheme.primary,
          theme.colorScheme.onPrimary,
        ),
      LocationPreference.recommended => (
          FeatherIcons.award,
          'Top Pick',
          const Color(0xFFFDCB6E),
          Colors.black87,
        ),
      LocationPreference.search => (
          FeatherIcons.search,
          'Match',
          Colors.white.withOpacity(0.9),
          Colors.black87,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: bg.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Image builder ──

  Widget _buildImage(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final url = location.imageUrl ?? location.photoReference;

    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => _imagePlaceholder(colorScheme),
        errorWidget: (_, __, error) {
          log("Error loading image for ${location.name}: $error");
          return _imageError(colorScheme);
        },
      );
    }
    return _imageEmpty(colorScheme);
  }

  Widget _imagePlaceholder(ColorScheme cs) => Container(
        color: cs.surfaceContainerHighest,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(cs.primary),
          ),
        ),
      );

  Widget _imageError(ColorScheme cs) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.surfaceContainerHighest,
              cs.surfaceContainerHighest.withOpacity(0.7),
            ],
          ),
        ),
        child: Center(
          child: Icon(FeatherIcons.image,
              size: 36, color: cs.onSurfaceVariant.withOpacity(0.4)),
        ),
      );

  Widget _imageEmpty(ColorScheme cs) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primaryContainer.withOpacity(0.3),
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
//  Reusable micro-widgets
// ─────────────────────────────────────────────────────────────

/// Compact rating chip: "4.5 ★ (1.2k)"
class _RatingChip extends StatelessWidget {
  final double rating;
  final int? reviewCount;
  const _RatingChip({required this.rating, this.reviewCount});

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(FeatherIcons.star, size: 10, color: Colors.amber),
          if (reviewCount != null && reviewCount! > 0) ...[
            const SizedBox(width: 4),
            Text(
              '(${_formatCount(reviewCount!)})',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Status pill used for Open/Closed, match %, saves count
class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color? textColor;
  final IconData? icon;
  final Color? iconColor;

  const _StatusPill({
    required this.text,
    required this.color,
    this.textColor,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withOpacity(color == Colors.white.withOpacity(0.85) ? 0.85 : 0.85),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: iconColor ?? textColor ?? Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small info pill for tags row (price, cuisine, vibe tags)
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: textColor.withOpacity(0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(
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
        ],
      ),
    );
  }
}
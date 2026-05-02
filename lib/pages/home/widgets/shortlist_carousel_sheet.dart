import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/widgets/mode_toggle.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/providers/shortlist_provider.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:provider/provider.dart';

class ShortlistCarouselSheet extends StatefulWidget {
  final List<LocationModel> items;
  final HomeMode currentMode;
  final ValueChanged<HomeMode> onReturnToMode;

  const ShortlistCarouselSheet({
    super.key,
    required this.items,
    required this.currentMode,
    required this.onReturnToMode,
  });

  static Future<void> show(
    BuildContext context, {
    required HomeMode currentMode,
    required ValueChanged<HomeMode> onReturnToMode,
  }) {
    final snapshot = List<LocationModel>.from(
      context.read<ShortlistProvider>().items,
    );

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ShortlistCarouselSheet(
        items: snapshot,
        currentMode: currentMode,
        onReturnToMode: onReturnToMode,
      ),
    );
  }

  @override
  State<ShortlistCarouselSheet> createState() => _ShortlistCarouselSheetState();
}

class _ShortlistCarouselSheetState extends State<ShortlistCarouselSheet> {
  late final PageController _controller;
  late final List<LocationModel> _items;
  int _currentIndex = 0;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.94);
    _items = List<LocationModel>.of(widget.items);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _exitToMode() async {
    if (_isClosing) return;
    _isClosing = true;

    widget.onReturnToMode(widget.currentMode);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handlePageChanged(int index) {
    _currentIndex = index;
    if (index == _items.length) {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 240), _exitToMode),
      );
    }
  }

  void _removeFromShortlist(LocationModel location) {
    if (_isClosing) return;

    context.read<ShortlistProvider>().remove(location.locationId);

    setState(() {
      _items.removeWhere((item) => item.locationId == location.locationId);
      if (_currentIndex > _items.length) {
        _currentIndex = _items.length;
      }
    });

    HapticFeedback.lightImpact();

    if (_items.isEmpty) {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 220), _exitToMode),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        color: pinit.PinitColors.cream,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: pinit.PinitColors.aubergine,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: pinit.PinitColors.aubergine,
            blurRadius: 0,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: pinit.PinitColors.creamDeep,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shortlist',
                    style: AppTypography.brand(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: pinit.PinitColors.aubergine,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Swipe up to remove',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pinit.PinitColors.mute,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 206,
            child: _items.isEmpty
                ? const _EmptyState()
                : PageView.builder(
                    controller: _controller,
                    itemCount: _items.length + 1,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    onPageChanged: _handlePageChanged,
                    itemBuilder: (context, index) {
                      if (index == _items.length) {
                        return _KeepExploringCard(
                          mode: widget.currentMode,
                          onTap: _exitToMode,
                        );
                      }
                      final location = _items[index];
                      return _ShortlistCarouselCard(
                        location: location,
                        onSwipeUpRemove: () => _removeFromShortlist(location),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ShortlistCarouselCard extends StatelessWidget {
  final LocationModel location;
  final VoidCallback onSwipeUpRemove;

  const _ShortlistCarouselCard({
    super.key,
    required this.location,
    required this.onSwipeUpRemove,
  });

  bool get _isWavy => (location.vibe?.wavyScore ?? 0) > 0.45;

  Color get _borderColor =>
      _isWavy ? pinit.PinitColors.accent : pinit.PinitColors.aubergine;

  String get _summaryText {
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
    return 'In your shortlist';
  }

  List<MapEntry<String, double>> get _topVibeTags {
    if (location.vibe == null) return const [];
    return location.vibe!
        .topTags(3)
        .where((entry) => entry.value > 0.3 && entry.key != 'bossman')
        .take(2)
        .toList();
  }

  List<Widget> get _featureMicros {
    final icons = <Widget>[];

    void addIf(bool? flag, IconData icon, String tooltip) {
      if (flag == true) {
        icons.add(
          Tooltip(
            message: tooltip,
            child: Container(
              margin: const EdgeInsets.only(right: 5),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: pinit.PinitColors.creamSunk,
                shape: BoxShape.circle,
                border: Border.all(
                  color: pinit.PinitColors.creamDeep,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 11,
                color: pinit.PinitColors.aubergineSoft,
              ),
            ),
          ),
        );
      }
    }

    addIf(location.outdoorSeating, FeatherIcons.sun, 'Outdoor seating');
    addIf(location.liveMusic, FeatherIcons.music, 'Live music');
    addIf(location.servesCocktails, FeatherIcons.droplet, 'Cocktails');
    addIf(location.servesBrunch, FeatherIcons.sunrise, 'Brunch');
    addIf(location.servesVegetarianFood, FeatherIcons.feather, 'Vegetarian');
    addIf(location.goodForGroups, FeatherIcons.users, 'Good for groups');
    addIf(location.isTakeaway, FeatherIcons.package, 'Takeaway');

    return icons;
  }

  void _openLocationCard(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, _, __) => ExpandedLocationCard(
        location: location,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
      transitionBuilder: (dialogContext, animation, _, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Dismissible(
        key: ValueKey<String>('shortlist_remove_${location.locationId}'),
        direction: DismissDirection.up,
        dismissThresholds: const {DismissDirection.up: 0.35},
        background: const SizedBox.shrink(),
        secondaryBackground: _ShortlistRemoveBackground(
          borderColor: _borderColor,
        ),
        onDismissed: (_) => onSwipeUpRemove(),
        child: GestureDetector(
          onTap: () => _openLocationCard(context),
          child: Container(
            decoration: BoxDecoration(
              color: pinit.PinitColors.cream,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _borderColor,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _borderColor,
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
                  SizedBox(
                    width: 122,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _LocationImage(location: location),
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
                        if (location.emoji != null &&
                            location.emoji!.isNotEmpty)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: pinit.PinitColors.cream,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: pinit.PinitColors.aubergine,
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
                  Container(
                    width: 1.5,
                    color: _borderColor,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          color: pinit.PinitColors.creamSunk,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                FeatherIcons.bookmark,
                                size: 11,
                                color: pinit.PinitColors.mute,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'SHORTLIST',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    color: pinit.PinitColors.mute,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              if (location.rating != null) ...[
                                _CompactRating(
                                  rating: location.rating!,
                                  reviewCount: location.userRatingsTotal,
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (location.matchScore != null &&
                                  location.matchScore! > 0.1)
                                _MatchBadge(
                                  score: (location.matchScore! * 100).round(),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  location.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: pinit.PinitColors.aubergine,
                                    height: 1.15,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _summaryText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11.5,
                                    color: pinit.PinitColors.mute,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                                const Spacer(),
                                SizedBox(
                                  height: 24,
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
                                          accent: entry.key == 'wavy',
                                        );
                                      }),
                                      if (location.isOpenLate == true)
                                        const _PinitPill(
                                          label: 'Late Night',
                                          icon: FeatherIcons.moon,
                                        ),
                                      ..._featureMicros,
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
        ),
      ),
    );
  }
}

class _ShortlistRemoveBackground extends StatelessWidget {
  final Color borderColor;

  const _ShortlistRemoveBackground({
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FeatherIcons.trash2,
            size: 14,
            color: pinit.PinitColors.aubergine,
          ),
          const SizedBox(width: 8),
          Text(
            'Remove from shortlist',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: pinit.PinitColors.aubergine,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeepExploringCard extends StatelessWidget {
  final HomeMode mode;
  final VoidCallback onTap;

  const _KeepExploringCard({
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final modeLabel = switch (mode) {
      HomeMode.you => 'Pinned',
      HomeMode.explore => 'Explore',
      HomeMode.bubble => 'Bubble',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: pinit.PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: pinit.PinitColors.aubergine,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: pinit.PinitColors.aubergine,
                blurRadius: 0,
                offset: Offset(4, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Keep exploring',
                  style: AppTypography.brand(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: pinit.PinitColors.aubergine,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Back to $modeLabel mode',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: pinit.PinitColors.aubergineSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: pinit.PinitColors.creamDeep,
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'No places shortlisted yet',
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: pinit.PinitColors.aubergineSoft,
        ),
      ),
    );
  }
}

class _LocationImage extends StatelessWidget {
  final LocationModel location;

  const _LocationImage({required this.location});

  @override
  Widget build(BuildContext context) {
    final imageUrl = location.imageUrl ?? location.photoReference;
    if (imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: pinit.PinitColors.creamSunk,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  pinit.PinitColors.aubergineSoft,
                ),
              ),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: pinit.PinitColors.creamSunk,
          alignment: Alignment.center,
          child: const Icon(
            FeatherIcons.image,
            size: 28,
            color: pinit.PinitColors.aubergineSoft,
          ),
        ),
      );
    }

    return Container(
      color: pinit.PinitColors.creamSunk,
      alignment: Alignment.center,
      child: Text(
        location.emoji ?? '•',
        style: const TextStyle(fontSize: 34),
      ),
    );
  }
}

class _CompactRating extends StatelessWidget {
  final double rating;
  final int? reviewCount;

  const _CompactRating({
    required this.rating,
    this.reviewCount,
  });

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          FeatherIcons.star,
          size: 11,
          color: pinit.PinitColors.aubergine,
        ),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.dmSans(
            color: pinit.PinitColors.aubergine,
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
              color: pinit.PinitColors.mute,
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

class _MatchBadge extends StatelessWidget {
  final int score;

  const _MatchBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = pinit.PinitColors.matchIndicator(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1,
        ),
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
    late final Color backgroundColor;
    late final Color foregroundColor;
    late final Color borderColor;

    if (accent) {
      backgroundColor = pinit.PinitColors.accent;
      foregroundColor = pinit.PinitColors.cream;
      borderColor = pinit.PinitColors.accent;
    } else if (filled) {
      backgroundColor = pinit.PinitColors.aubergine;
      foregroundColor = pinit.PinitColors.cream;
      borderColor = pinit.PinitColors.aubergine;
    } else {
      backgroundColor = pinit.PinitColors.creamSunk;
      foregroundColor = pinit.PinitColors.aubergine;
      borderColor = pinit.PinitColors.creamDeep;
    }

    return Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 10,
              color: foregroundColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
              height: 1.0,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _VibeTagStyle {
  final String label;
  final IconData icon;

  const _VibeTagStyle(this.label, this.icon);
}

const Map<String, _VibeTagStyle> _vibeStyles = {
  'cafe': _VibeTagStyle('Cafe', FeatherIcons.coffee),
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
  'grocery_store': _VibeTagStyle('Shop', FeatherIcons.shoppingCart),
  'brunch': _VibeTagStyle('Brunch', FeatherIcons.sun),
  'outdoor_dining': _VibeTagStyle('Outdoor', FeatherIcons.wind),
  'wavy': _VibeTagStyle('Wavy', FeatherIcons.activity),
  'bossman': _VibeTagStyle('Bossman', FeatherIcons.shield),
};

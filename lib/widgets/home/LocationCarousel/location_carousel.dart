import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/utils/geo_types.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'dart:developer';

// ─────────────────────────────────────────────────────────────
//  Vibe tag display config: label + icon
//  Colours intentionally omitted — pinit palette is cream + aubergine.
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

class LocationCarousel extends StatelessWidget {
  final PageController pageController;
  final List<LocationModel> locations;
  final Widget? leadingCard;
  final Set<int> beenToLocationIds;
  final String? selectedMarkerId;
  final bool bottomNavVisible;
  final double? heightOverride;
  final bool showFirstItemSwipeHint;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<LocationModel> onLocationSelected;
  final void Function(LocationModel location)? onSwipeUp;
  final void Function(LocationModel location)? onSwipeDown;
  final VoidCallback? onFirstItemSwipeHintCompleted;

  const LocationCarousel({
    Key? key,
    required this.pageController,
    required this.locations,
    this.leadingCard,
    this.beenToLocationIds = const <int>{},
    required this.selectedMarkerId,
    required this.bottomNavVisible,
    this.heightOverride,
    this.showFirstItemSwipeHint = false,
    required this.onPageChanged,
    required this.onLocationSelected,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onFirstItemSwipeHintCompleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Allow the leading onboarding card to render even when there are no
    // locations yet (e.g. fresh accounts before recommendations return).
    if (locations.isEmpty && leadingCard == null) {
      return const SizedBox.shrink();
    }
    final leadingCount = leadingCard == null ? 0 : 1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuint,
      height: heightOverride ?? (bottomNavVisible ? 185.0 : 215.0),
      child: PageView.builder(
        controller: pageController,
        itemCount: locations.length + leadingCount,
        pageSnapping: true,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemBuilder: (context, index) {
          if (leadingCount == 1 && index == 0) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuint,
              margin:
                  const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
              transform: Matrix4.diagonal3Values(0.96, 0.96, 1.0),
              transformAlignment: Alignment.center,
              alignment: Alignment.center,
              child: leadingCard,
            );
          }

          final locationIndex = index - leadingCount;
          final location = locations[locationIndex];
          final isSelected = selectedMarkerId == location.locationId.toString();
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuint,
            margin: EdgeInsets.symmetric(
              horizontal: 6.0,
              vertical: isSelected ? 0 : 8.0,
            ),
            transform: isSelected
                ? Matrix4.identity()
                : Matrix4.diagonal3Values(0.96, 0.96, 1.0),
            transformAlignment: Alignment.center,
            child: _SwipeableCard(
              location: location,
              isSelected: isSelected,
              bottomNavVisible: bottomNavVisible,
              showSwipeHint: showFirstItemSwipeHint && locationIndex == 0,
              beenToLocationIds: beenToLocationIds,
              onLocationSelected: onLocationSelected,
              onSwipeUp: onSwipeUp,
              onSwipeDown: onSwipeDown,
              onSwipeHintCompleted: onFirstItemSwipeHintCompleted,
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
class _SwipeableCard extends StatefulWidget {
  final LocationModel location;
  final bool isSelected;
  final bool bottomNavVisible;
  final bool showSwipeHint;
  final Set<int> beenToLocationIds;
  final ValueChanged<LocationModel> onLocationSelected;
  final void Function(LocationModel)? onSwipeUp;
  final void Function(LocationModel)? onSwipeDown;
  final VoidCallback? onSwipeHintCompleted;

  const _SwipeableCard({
    required this.location,
    required this.isSelected,
    required this.bottomNavVisible,
    required this.showSwipeHint,
    required this.beenToLocationIds,
    required this.onLocationSelected,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onSwipeHintCompleted,
  });

  @override
  State<_SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<_SwipeableCard>
    with SingleTickerProviderStateMixin {
  double _dragY = 0;
  bool _showShortlistConfirmed = false;
  bool _swipeHintPlayed = false;
  Timer? _shortlistFeedbackTimer;
  late final AnimationController _swipeHintController;
  static const _threshold = 60.0;

  @override
  void initState() {
    super.initState();
    _swipeHintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    if (widget.showSwipeHint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playSwipeHintIfNeeded();
      });
    }
  }

  @override
  void didUpdateWidget(_SwipeableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.showSwipeHint) {
      _swipeHintPlayed = false;
      _swipeHintController.reset();
      return;
    }
    if (!oldWidget.showSwipeHint || oldWidget.location != widget.location) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playSwipeHintIfNeeded();
      });
    }
  }

  void _playSwipeHintIfNeeded() {
    if (!mounted ||
        !widget.showSwipeHint ||
        _swipeHintPlayed ||
        _swipeHintController.isAnimating) {
      return;
    }
    _swipeHintPlayed = true;
    _swipeHintController.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      widget.onSwipeHintCompleted?.call();
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    _swipeHintController.stop();
    _swipeHintController.reset();
    _swipeHintPlayed = true;
    setState(() => _dragY += d.delta.dy);
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (_dragY < -_threshold && widget.onSwipeUp != null) {
      _shortlistFeedbackTimer?.cancel();
      setState(() => _showShortlistConfirmed = true);
      _shortlistFeedbackTimer = Timer(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() => _showShortlistConfirmed = false);
      });
      widget.onSwipeUp!(widget.location);
    } else if (_dragY > _threshold && widget.onSwipeDown != null) {
      widget.onSwipeDown!(widget.location);
    }
    setState(() => _dragY = 0);
  }

  @override
  void dispose() {
    _shortlistFeedbackTimer?.cancel();
    _swipeHintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragY / 120).clamp(-1.0, 1.0);
    final opacity = (1.0 - progress.abs() * 0.4).clamp(0.5, 1.0);
    final shortlistDragProgress = (-_dragY / _threshold).clamp(0.0, 1.0);
    final shortlistIndicatorOpacity =
        _showShortlistConfirmed ? 1.0 : shortlistDragProgress;
    final shortlistIndicatorScale =
        _showShortlistConfirmed ? 1.18 : 0.90 + (shortlistDragProgress * 0.22);
    final shortlistIndicatorSlideY =
        _showShortlistConfirmed ? 0.0 : 0.20 - (shortlistDragProgress * 0.20);

    return GestureDetector(
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: AnimatedContainer(
        duration:
            _dragY == 0 ? const Duration(milliseconds: 200) : Duration.zero,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _dragY * 0.4, 0),
        child: Opacity(
          opacity: opacity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _swipeHintController,
                builder: (context, child) {
                  final progress =
                      (_swipeHintController.value / 0.34).clamp(0.0, 1.0);
                  final bounce = math.sin(progress * math.pi);
                  return Transform.translate(
                    offset: Offset(0, -10 * bounce),
                    child: Transform.scale(
                      scale: 1 + (0.018 * bounce),
                      child: child,
                    ),
                  );
                },
                child: _CarouselCard(
                  location: widget.location,
                  isSelected: widget.isSelected,
                  bottomNavVisible: widget.bottomNavVisible,
                  beenToLocationIds: widget.beenToLocationIds,
                  onLocationSelected: widget.onLocationSelected,
                ),
              ),
              if (widget.showSwipeHint && _swipeHintController.value < 1)
                AnimatedBuilder(
                  animation: _swipeHintController,
                  builder: (context, child) {
                    final value = _swipeHintController.value;
                    final swipeProgress =
                        const Interval(0.26, 0.88, curve: Curves.easeOutCubic)
                            .transform(value);
                    final opacity =
                        const Interval(0.20, 0.42, curve: Curves.easeOut)
                                .transform(value) *
                            (1 -
                                const Interval(0.82, 1.0, curve: Curves.easeIn)
                                    .transform(value));
                    return Positioned(
                      key: const ValueKey('first_carousel_swipe_hint'),
                      bottom: -42 - (26 * swipeProgress),
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.92 + (0.08 * swipeProgress),
                            child: child,
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Center(
                    child: _SwipeUpShortlistHint(),
                  ),
                ),
              // Swipe up shortlist feedback
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
                            milliseconds: _showShortlistConfirmed ? 280 : 140,
                          ),
                          curve: _showShortlistConfirmed
                              ? Curves.elasticOut
                              : Curves.easeOutCubic,
                          scale: shortlistIndicatorScale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: PinitColors.aubergine,
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
                                  Icons.playlist_add_check_rounded,
                                  size: 16,
                                  color: PinitColors.cream,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'SHORTLISTED',
                                  style: GoogleFonts.dmSans(
                                    color: PinitColors.cream,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
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
                  bottom: -28,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 100),
                        opacity: (_dragY / _threshold).clamp(0.0, 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: PinitColors.cream,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: PinitColors.aubergine,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            'SAVE',
                            style: GoogleFonts.dmSans(
                              color: PinitColors.aubergine,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
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

class _SwipeUpShortlistHint extends StatelessWidget {
  const _SwipeUpShortlistHint();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PinitColors.aubergine,
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
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 18,
              color: PinitColors.cream,
            ),
            SizedBox(width: 4),
            Icon(
              Icons.playlist_add_check_rounded,
              size: 16,
              color: PinitColors.cream,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Individual card – pinit style: cream surface, aubergine border,
//  hard offset shadow, image left / info right.
// ─────────────────────────────────────────────────────────────
class _CarouselCard extends StatelessWidget {
  final LocationModel location;
  final bool isSelected;
  final bool bottomNavVisible;
  final Set<int> beenToLocationIds;
  final ValueChanged<LocationModel> onLocationSelected;

  const _CarouselCard({
    required this.location,
    required this.isSelected,
    required this.bottomNavVisible,
    required this.beenToLocationIds,
    required this.onLocationSelected,
  });

  bool get _isWavy => (location.vibe?.wavyScore ?? 0) > 0.45;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manager = Provider.of<LocationListManager?>(context);
    final isBeenTo = beenToLocationIds.contains(location.locationId) ||
        (manager?.isLocationBeenToSync(location.locationId) ?? false);
    final cuisineLabel = location.displayCuisine;
    final walkEta = _walkEtaLabel(manager?.currentPosition);
    final Color borderColor =
        _isWavy ? PinitColors.accent : PinitColors.aubergine;
    final Color shadowColor =
        _isWavy ? PinitColors.accent : PinitColors.aubergine;

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
          color: PinitColors.cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 0,
              offset: Offset(isSelected ? 5 : 4, isSelected ? 5 : 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left: Image column (with floating overlays) ──
              SizedBox(
                width: 122,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(theme),
                    // Subtle bottom-up scrim so overlays stay legible
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
                    if (isBeenTo)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: PinitColors.warning,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: PinitColors.aubergine,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                FeatherIcons.check,
                                size: 10,
                                color: PinitColors.cream,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Been',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                  color: PinitColors.cream,
                                  height: 1,
                                ),
                              ),
                            ],
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

              // ── Vertical divider (matches the chunky border style) ──
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
                    // Top label strip (cream-sunk) — distance / preference / match
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
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (walkEta != null) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.directions_walk_rounded,
                                        size: 14,
                                        color: PinitColors.mute,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        walkEta,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 12,
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
                                        score: (location.matchScore! * 100)
                                            .round(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            // Name — full row, up to 2 lines
                            Text(
                              location.name,
                              style: GoogleFonts.dmSans(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: PinitColors.aubergine,
                                height: 1.15,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (_summaryText != null)
                              Text(
                                _summaryText!,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11.5,
                                  color: PinitColors.mute,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const Spacer(),
                            // Tags row: price + cuisine + vibe pills + features
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
                                  if (cuisineLabel != null)
                                    _PinitPill(
                                      label: cuisineLabel,
                                      cuisine: true,
                                    ),
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
    final cuisineLabel = location.displayCuisine;
    if (cuisineLabel != null) {
      return cuisineLabel.toUpperCase();
    }
    return 'NEARBY';
  }

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

  List<MapEntry<String, double>> get _topVibeTags {
    if (location.vibe == null) return [];
    return location.vibe!
        .topTags(3)
        .where((e) => e.value > 0.3 && e.key != 'bossman')
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
                color: PinitColors.creamSunk,
                shape: BoxShape.circle,
                border: Border.all(
                  color: PinitColors.creamDeep,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 11, color: PinitColors.aubergineSoft),
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

  // ── Image builder ──

  Widget _buildImage(ThemeData theme) {
    final url = location.imageUrl ?? location.photoReference;

    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => _imagePlaceholder(),
        errorWidget: (_, __, error) {
          log("Error loading image for ${location.name}: $error");
          return _imageError();
        },
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
//  Pinit-styled micro-widgets
// ─────────────────────────────────────────────────────────────

/// Compact rating used inside the top label strip — no background,
/// just a star + number so it sits next to the tracked uppercase label.
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
        const Icon(FeatherIcons.star, size: 13, color: PinitColors.aubergine),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.dmSans(
            color: PinitColors.aubergine,
            fontWeight: FontWeight.w800,
            fontSize: 12,
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ],
    );
  }
}

/// Match-score badge for the top strip.
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

/// Universal pinit pill — used for tags, status, vibes.
/// - default: cream-sunk fill, aubergine ink, cream-deep border
/// - filled : aubergine fill, cream ink (active state)
/// - accent : accent fill, cream ink (reserved for "wavy")
class _PinitPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool filled;
  final bool accent;
  final bool cuisine;

  const _PinitPill({
    required this.label,
    this.icon,
    this.filled = false,
    this.accent = false,
    this.cuisine = false,
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
    } else if (cuisine) {
      bg = const Color(0xFF494331);
      fg = PinitColors.cream;
      border = const Color(0xFF494331);
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

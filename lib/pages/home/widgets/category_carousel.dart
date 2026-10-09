import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/home/categories/category_glyph.dart';
import 'package:login/pages/home/categories/home_category.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/themes/app_typography.dart';

/// Tier-1 of the home browse flow: a single slim rail of category chips
/// (cuisines, bubbles, eat-lists, vibes, sources) docked above the nav, so the map
/// keeps the screen. Each chip carries a generated [CategoryGlyph]; tapping
/// one drills into the focused location carousel.
class CategoryCarousel extends StatefulWidget {
  final List<HomeCategory> categories;
  final bool bottomNavVisible;
  final ValueChanged<HomeCategory> onCategorySelected;

  /// When set, a "See all" chip closes the rail.
  final VoidCallback? onSeeAll;

  const CategoryCarousel({
    super.key,
    required this.categories,
    required this.bottomNavVisible,
    required this.onCategorySelected,
    this.onSeeAll,
  });

  static const double chipHeight = 52;

  @override
  State<CategoryCarousel> createState() => _CategoryCarouselState();
}

class _CategoryCarouselState extends State<CategoryCarousel>
    with SingleTickerProviderStateMixin {
  static const double _edgeInset = 20;
  static const int _maxStaggered = 7;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories;
    if (categories.isEmpty) return const SizedBox.shrink();

    final items = <Widget>[];
    for (var i = 0; i < categories.length; i++) {
      final category = categories[i];
      if (i > 0 && categories[i - 1].kind != category.kind) {
        items.add(const CategoryGroupDot());
      }
      items.add(CategoryChip(
        category: category,
        onTap: () => widget.onCategorySelected(category),
      ));
    }
    if (widget.onSeeAll != null) {
      items.add(_SeeAllChip(onTap: widget.onSeeAll!));
    }

    return SizedBox(
      height: CategoryCarousel.chipHeight + (widget.bottomNavVisible ? 22 : 30),
      child: ShaderMask(
        // Soft fade at both ends so the rail reads as scrollable without
        // chips being guillotined at the screen edge.
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Color(0x00000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
          ],
          stops: [0.0, 0.045, 0.955, 1.0],
        ).createShader(bounds),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          padding: EdgeInsets.fromLTRB(
            _edgeInset,
            6,
            _edgeInset,
            widget.bottomNavVisible ? 16 : 24,
          ),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) => _staggered(index, items[index]),
        ),
      ),
    );
  }

  /// Chips rise and fade in one after another; anything past the first
  /// screenful arrives with the last visible one.
  Widget _staggered(int index, Widget child) {
    final slot = math.min(index, _maxStaggered);
    final start = slot * 0.07;
    final curve = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, math.min(start + 0.5, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      child: child,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curve.value) * 14),
          child: child,
        ),
      ),
    );
  }
}

class CategoryChip extends StatefulWidget {
  final HomeCategory category;
  final VoidCallback onTap;

  /// Filled aubergine state, for chips used as toggles (See All filters).
  final bool selected;

  /// Replaces the kind-derived meta line when set.
  final String? meta;

  const CategoryChip({
    super.key,
    required this.category,
    required this.onTap,
    this.selected = false,
    this.meta,
  });

  @override
  State<CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<CategoryChip> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  String get _meta {
    if (widget.meta != null) return widget.meta!;
    final count = widget.category.count;
    final area = widget.category.areaLabel;
    return switch (widget.category.kind) {
      HomeCategoryKind.source when count == 0 => 'SHARE A TIKTOK',
      HomeCategoryKind.source => '$count ${count == 1 ? 'SAVE' : 'SAVES'}',
      HomeCategoryKind.cuisine when area != null =>
        '${area.toUpperCase()} · $count',
      HomeCategoryKind.cuisine => '$count ${count == 1 ? 'SPOT' : 'SPOTS'}',
      HomeCategoryKind.eatList => 'LIST · $count',
      HomeCategoryKind.vibe => 'VIBE · $count',
      HomeCategoryKind.bubble => 'BUBBLE · $count',
      HomeCategoryKind.magic => '$count ${count == 1 ? 'MATCH' : 'MATCHES'}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final isOwnList = category.kind == HomeCategoryKind.eatList;

    final avatars = category.kind == HomeCategoryKind.bubble
        ? category.avatarUrls.where((u) => u.isNotEmpty).take(2).toList()
        : const <String>[];

    return Semantics(
      button: true,
      label: category.areaLabel == null
          ? '${category.label}, ${category.count} places'
          : '${category.label} in ${category.areaLabel}, '
              '${category.count} places',
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) {
          _setPressed(false);
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: CategoryCarousel.chipHeight,
            padding: const EdgeInsets.only(left: 7, right: 18),
            decoration: BoxDecoration(
              // The user's own lists sit one step deeper in the cream family.
              color: widget.selected
                  ? PinitColors.aubergine
                  : _pressed
                      ? PinitColors.creamDeep
                      : (isOwnList ? PinitColors.creamSunk : PinitColors.cream),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: widget.selected
                    ? PinitColors.aubergine
                    : PinitColors.creamDeep,
                width: 1.5,
              ),
              boxShadow: _pressed
                  ? const [
                      BoxShadow(
                        color: Color(0x0F41133D),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x1441133D),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (avatars.isNotEmpty)
                  _AvatarPair(urls: avatars)
                else
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: _pressed ? 0.06 : 0.0),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    builder: (context, spin, _) =>
                        CategoryGlyph(category: category, size: 38, spin: spin),
                  ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 132),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.brand(
                          fontSize: 16,
                          color: widget.selected
                              ? PinitColors.cream
                              : PinitColors.aubergine,
                          height: 1.0,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _meta,
                        maxLines: 1,
                        style: GoogleFonts.dmSans(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: widget.selected
                              ? PinitColors.cream.withValues(alpha: 0.7)
                              : PinitColors.mute,
                          letterSpacing: 0.9,
                          height: 1.0,
                          fontFeatures: const [FontFeature.tabularFigures()],
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
    );
  }
}

/// Up to two overlapping member photos for a bubble chip, in place of the
/// generated glyph. Falls back to the glyph when no member has a photo.
class _AvatarPair extends StatelessWidget {
  final List<String> urls;

  const _AvatarPair({required this.urls});

  static const double _size = 30;
  static const double _overlap = 12;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size + (urls.length - 1) * (_size - _overlap),
      height: 38,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          for (var i = 0; i < urls.length; i++)
            Positioned(
              left: i * (_size - _overlap),
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PinitColors.creamDeep,
                  border: Border.all(color: PinitColors.cream, width: 2),
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(urls[i]),
                    fit: BoxFit.cover,
                    onError: (_, __) {},
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Closes the rail: the one filled (primary) pill, so the eye lands on it
/// last.
class _SeeAllChip extends StatefulWidget {
  final VoidCallback onTap;

  const _SeeAllChip({required this.onTap});

  @override
  State<_SeeAllChip> createState() => _SeeAllChipState();
}

class _SeeAllChipState extends State<_SeeAllChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'See all places',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            height: CategoryCarousel.chipHeight,
            padding: const EdgeInsets.only(left: 20, right: 7),
            decoration: BoxDecoration(
              color: PinitColors.aubergine,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SEE ALL',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: PinitColors.cream,
                    letterSpacing: 11 * 0.12,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedSlide(
                  offset: _pressed ? const Offset(0.12, 0) : Offset.zero,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: PinitColors.cream,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: PinitColors.aubergine,
                    ),
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

/// A quiet 4px dot between groups (cuisines · bubbles · lists · vibes · sources).
class CategoryGroupDot extends StatelessWidget {
  const CategoryGroupDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          color: PinitColors.mute.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

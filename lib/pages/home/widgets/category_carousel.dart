import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/home/categories/home_category.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// Tier-1 of the home browse flow: a compact, horizontally-scrolling row of
/// category tiles (Instagram, TikTok, cuisines, eat-lists, vibes). Tapping a
/// tile drills into the focused location carousel.
class CategoryCarousel extends StatelessWidget {
  final List<HomeCategory> categories;
  final bool bottomNavVisible;
  final ValueChanged<HomeCategory> onCategorySelected;

  const CategoryCarousel({
    super.key,
    required this.categories,
    required this.bottomNavVisible,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: bottomNavVisible ? 108.0 : 128.0,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => _CategoryTile(
          category: categories[index],
          onTap: () => onCategorySelected(categories[index]),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatefulWidget {
  final HomeCategory category;
  final VoidCallback onTap;

  const _CategoryTile({required this.category, required this.onTap});

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) => setState(() => _scale = 0.95);
  void _onTapUp(TapUpDetails _) {
    setState(() => _scale = 1.0);
    widget.onTap();
  }

  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final countLabel =
        '${category.count} ${category.count == 1 ? 'spot' : 'spots'}';

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: 88,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              category.emoji != null
                  ? Text(category.emoji!, style: const TextStyle(fontSize: 30))
                  : Icon(category.icon,
                      size: 28, color: PinitColors.aubergine),
              const SizedBox(height: 8),
              Text(
                category.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: PinitColors.aubergine,
                  height: 1.1,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                countLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: PinitColors.mute,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

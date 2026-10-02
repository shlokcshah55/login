import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:login/pages/home/categories/home_category.dart';
import 'package:login/pages/home/categories/home_category_builder.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/themes/app_typography.dart';

/// What sits in the middle of a [CategoryGlyph]: an icon, the category's own
/// emoji, or a generated monogram — in that order of preference.
@immutable
class CategoryMark {
  final IconData? icon;
  final String? emoji;
  final String? monogram;

  const CategoryMark._({this.icon, this.emoji, this.monogram});

  /// Picks a mark for [category] by reading its id and label. Categories are
  /// generated from live data (cuisines in the area, the user's own list
  /// names, vibe tags), so the icon is resolved from keywords rather than a
  /// fixed per-category table.
  factory CategoryMark.resolve(HomeCategory category) {
    // Bubble names are free text ("Date crew"), so don't keyword-match them.
    if (category.kind == HomeCategoryKind.bubble) {
      return const CategoryMark._(icon: Icons.groups_rounded);
    }

    final haystack = _normalise('${category.id} ${category.label}');

    if (category.kind == HomeCategoryKind.source) {
      if (category.id == HomeCategoryBuilder.sharedFindsId) {
        return const CategoryMark._(icon: FontAwesomeIcons.tiktok);
      }
      if (haystack.contains('instagram')) {
        return const CategoryMark._(icon: FeatherIcons.instagram);
      }
      if (haystack.contains('tiktok')) {
        return const CategoryMark._(icon: Icons.music_note_rounded);
      }
    }

    for (final rule in _rules) {
      if (rule.matches(haystack)) return CategoryMark._(icon: rule.icon);
    }

    // A list the user named themselves keeps its own emoji when no keyword
    // fits — it's their personality, not ours.
    final emoji = category.emoji;
    if (category.kind == HomeCategoryKind.eatList &&
        emoji != null &&
        emoji.isNotEmpty &&
        emoji != '📌') {
      return CategoryMark._(emoji: emoji);
    }

    if (category.icon != null) return CategoryMark._(icon: category.icon);

    final letter = category.label.trim().isEmpty
        ? '•'
        : category.label.trim().characters.first.toUpperCase();
    return CategoryMark._(monogram: letter);
  }

  static String _normalise(String raw) =>
      ' ${raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim()} ';

  // Ordered most-specific first. Keys match at the start of a word, so
  // plurals work but "late" skips "chocolate"; short keys (≤3 chars) must be
  // the whole word so "bar" skips "barbecue".
  static const List<_IconRule> _rules = [
    _IconRule(['sushi', 'japanese', 'seafood', 'fish', 'poke'],
        Icons.set_meal_rounded),
    _IconRule(['ramen', 'noodle', 'thai', 'vietnamese', 'pho', 'korean'],
        Icons.ramen_dining_rounded),
    _IconRule(['pizza', 'pizzeria'], Icons.local_pizza_rounded),
    _IconRule(['italian', 'pasta'], Icons.dinner_dining_rounded),
    _IconRule(
        ['burger', 'american', 'diner', 'smash'], Icons.lunch_dining_rounded),
    _IconRule(['indian', 'curry', 'biryani', 'nepalese', 'pakistani'],
        Icons.rice_bowl_rounded),
    _IconRule(['chinese', 'dim sum', 'dumpling', 'takeaway', 'takeout'],
        Icons.takeout_dining_rounded),
    _IconRule(
        ['turkish', 'kebab', 'middle eastern', 'lebanese', 'greek', 'shawarma'],
        Icons.kebab_dining_rounded),
    _IconRule(['mexican', 'taco', 'spanish', 'tapas'], Icons.tapas_rounded),
    _IconRule(['french', 'bakery', 'croissant', 'pastry', 'patisserie'],
        Icons.bakery_dining_rounded),
    _IconRule(['brunch'], Icons.brunch_dining_rounded),
    _IconRule(['breakfast', 'toast'], Icons.breakfast_dining_rounded),
    _IconRule(['dessert', 'cake', 'sweet', 'treat'], Icons.cake_rounded),
    _IconRule(['ice cream', 'gelato'], Icons.icecream_rounded),
    _IconRule(
        ['coffee', 'cafe', 'espresso', 'matcha'], Icons.local_cafe_rounded),
    _IconRule(['vegan', 'vegetarian', 'plant', 'healthy', 'salad'],
        Icons.eco_rounded),
    _IconRule(['wine'], Icons.wine_bar_rounded),
    _IconRule(['pub', 'british', 'beer', 'pint', 'sports bar'],
        Icons.sports_bar_rounded),
    _IconRule(
        ['cocktail', 'bar', 'drinks', 'speakeasy'], Icons.local_bar_rounded),
    _IconRule(['live music', 'music', 'jazz', 'gig'], Icons.graphic_eq_rounded),
    _IconRule(
        ['date', 'romantic', 'love', 'anniversary'], Icons.favorite_rounded),
    _IconRule(['late night', 'late', 'night'], Icons.bedtime_rounded),
    _IconRule(['birthday', 'party', 'celebrat'], Icons.celebration_rounded),
    _IconRule(['fine dining', 'elegant', 'bougie', 'fancy', 'luxury'],
        Icons.diamond_rounded),
    _IconRule(
        ['hidden gem', 'hole in the wall', 'gem', 'secret'], Icons.key_rounded),
    _IconRule(['trendy', 'trending', 'hot', 'hype'], Icons.whatshot_rounded),
    _IconRule(['cozy', 'cosy', 'comfort'], Icons.weekend_rounded),
    _IconRule(['quiet', 'calm', 'chill'], Icons.spa_rounded),
    _IconRule(['outdoor', 'terrace', 'garden', 'rooftop', 'patio'],
        Icons.deck_rounded),
    _IconRule(['football', 'sport', 'match'], Icons.sports_soccer_rounded),
    _IconRule(
        ['food truck', 'street food', 'market'], Icons.local_shipping_rounded),
    _IconRule(['fast food', 'quick'], Icons.fastfood_rounded),
    _IconRule(['shop', 'deli', 'grocer'], Icons.storefront_rounded),
    _IconRule(['modern', 'new'], Icons.bolt_rounded),
    _IconRule(['wavy'], Icons.waves_rounded),
    _IconRule(['friends', 'group', 'squad'], Icons.groups_rounded),
    _IconRule(['work', 'laptop', 'study'], Icons.laptop_rounded),
    _IconRule(['casual', 'everyday', 'local'], Icons.restaurant_rounded),
  ];
}

class _IconRule {
  final List<String> keys;
  final IconData icon;

  const _IconRule(this.keys, this.icon);

  bool matches(String haystack) {
    for (final key in keys) {
      final hit = key.length <= 3
          ? haystack.contains(' $key ')
          : haystack.contains(' $key');
      if (hit) return true;
    }
    return false;
  }
}

/// A small generated badge that gives every home category its own mark.
///
/// The silhouette comes from the category kind (sources are perforated
/// stamps, cuisines are rosettes, lists are tilted tags, vibes are soft
/// starbursts, bubbles are soft clusters). Petal count, depth, rotation and
/// tone are seeded from the category id, so each category always gets the
/// same unique badge and new categories get one automatically.
class CategoryGlyph extends StatelessWidget {
  final HomeCategory category;
  final double size;

  /// Extra spin in turns, driven by the parent for press feedback.
  final double spin;

  const CategoryGlyph({
    super.key,
    required this.category,
    this.size = 38,
    this.spin = 0,
  });

  @override
  Widget build(BuildContext context) {
    final seed = _stableHash('${category.kind.name}:${category.id}');
    final spec = _GlyphSpec.fromSeed(category.kind, seed);
    final mark = CategoryMark.resolve(category);
    final ink = spec.darkFill ? PinitColors.cream : PinitColors.aubergine;

    Widget centre;
    if (mark.icon != null) {
      centre = Icon(mark.icon, size: size * 0.46, color: ink);
    } else if (mark.emoji != null) {
      centre = Text(
        mark.emoji!,
        style: TextStyle(fontSize: size * 0.42, height: 1.0),
      );
    } else {
      centre = Text(
        mark.monogram!,
        style: AppTypography.brand(
          fontSize: size * 0.48,
          color: ink,
          height: 1.0,
          letterSpacing: 0,
        ),
      );
    }

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: spec.rotation + spin * 2 * math.pi,
            child: CustomPaint(
              size: Size.square(size),
              painter: _GlyphPainter(spec),
            ),
          ),
          centre,
        ],
      ),
    );
  }

  /// FNV-1a — stable across runs and platforms, unlike [String.hashCode].
  static int _stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }
}

@immutable
class _GlyphSpec {
  final HomeCategoryKind kind;
  final int lobes;
  final double depth;
  final double rotation;
  final Color fill;
  final bool darkFill;

  const _GlyphSpec({
    required this.kind,
    required this.lobes,
    required this.depth,
    required this.rotation,
    required this.fill,
    required this.darkFill,
  });

  factory _GlyphSpec.fromSeed(HomeCategoryKind kind, int seed) {
    final rng = math.Random(seed);
    // Tones stay inside the brand families: two aubergines and cream-deep.
    const tones = [
      (PinitColors.aubergine, true),
      (PinitColors.aubergineSoft, true),
      (PinitColors.creamDeep, false),
    ];
    final tone = tones[rng.nextInt(tones.length)];

    return switch (kind) {
      HomeCategoryKind.source => _GlyphSpec(
          kind: kind,
          lobes: 14 + rng.nextInt(5),
          depth: 0.07,
          rotation: rng.nextDouble() * math.pi,
          // Sources are the user's own saves — always the strongest tone.
          fill: PinitColors.aubergine,
          darkFill: true,
        ),
      HomeCategoryKind.cuisine => _GlyphSpec(
          kind: kind,
          lobes: 6 + rng.nextInt(4),
          depth: 0.10 + rng.nextDouble() * 0.06,
          rotation: rng.nextDouble() * math.pi,
          fill: tone.$1,
          darkFill: tone.$2,
        ),
      HomeCategoryKind.eatList => _GlyphSpec(
          kind: kind,
          lobes: 0,
          depth: 0,
          rotation: (rng.nextDouble() - 0.5) * 0.36,
          fill: PinitColors.creamDeep,
          darkFill: false,
        ),
      HomeCategoryKind.bubble => _GlyphSpec(
          kind: kind,
          // Few, shallow lobes: a soft cluster rather than a badge.
          lobes: 4 + rng.nextInt(2),
          depth: 0.05,
          rotation: rng.nextDouble() * math.pi,
          fill: PinitColors.aubergineSoft,
          darkFill: true,
        ),
      HomeCategoryKind.vibe => _GlyphSpec(
          kind: kind,
          lobes: 9 + rng.nextInt(5),
          depth: 0.05 + rng.nextDouble() * 0.04,
          rotation: rng.nextDouble() * math.pi,
          fill: tone.$1,
          darkFill: tone.$2,
        ),
    };
  }
}

class _GlyphPainter extends CustomPainter {
  final _GlyphSpec spec;

  const _GlyphPainter(this.spec);

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    final outline = spec.kind == HomeCategoryKind.eatList
        ? _tagPath(centre, radius)
        : _lobedPath(centre, radius);

    canvas.drawPath(outline, Paint()..color = spec.fill);

    if (!spec.darkFill) {
      canvas.drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = PinitColors.aubergine.withValues(alpha: 0.22),
      );
    }

    // Inner hairline ring — the detail that makes it read as a printed
    // badge rather than a flat blob.
    canvas.drawCircle(
      centre,
      radius * 0.66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = (spec.darkFill ? PinitColors.cream : PinitColors.aubergine)
            .withValues(alpha: spec.darkFill ? 0.22 : 0.14),
    );
  }

  /// Radius modulated by a cosine: few deep lobes → rosette, many shallow
  /// lobes → perforated stamp or starburst.
  Path _lobedPath(Offset centre, double radius) {
    const steps = 144;
    final base = radius * (1 - spec.depth);
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * 2 * math.pi;
      final r = base + radius * spec.depth * math.cos(spec.lobes * t);
      final point = centre + Offset(math.cos(t) * r, math.sin(t) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  /// A squircle luggage-tag with a punched hole, for the user's own lists.
  Path _tagPath(Offset centre, double radius) {
    final rect = Rect.fromCircle(center: centre, radius: radius * 0.9);
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius * 0.42)));
    final hole = Path()
      ..addOval(Rect.fromCircle(
        center: rect.topRight + Offset(-radius * 0.34, radius * 0.34),
        radius: radius * 0.1,
      ));
    return Path.combine(PathOperation.difference, body, hole);
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) {
    final old = oldDelegate.spec;
    return old.kind != spec.kind ||
        old.lobes != spec.lobes ||
        old.depth != spec.depth ||
        old.fill != spec.fill;
  }
}

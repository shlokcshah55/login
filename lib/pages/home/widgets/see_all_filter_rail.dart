import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/categories/home_category.dart';
import 'package:login/pages/home/categories/vibe_styles.dart';
import 'package:login/pages/home/widgets/category_carousel.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// One selectable chip in the See All rail.
class SeeAllFilterOption {
  final String id;
  final String label;
  final int count;

  const SeeAllFilterOption({
    required this.id,
    required this.label,
    required this.count,
  });
}

/// Normalised cuisine id for grouping, or null when unknown.
String? seeAllCuisineId(LocationModel location) {
  final key = location.cuisineKey?.trim().toLowerCase();
  if (key != null && key.isNotEmpty && key != 'unknown') return key;
  final label = location.displayCuisine;
  if (label == null) return null;
  return label.toLowerCase().replaceAll(' ', '_');
}

/// Human label for [seeAllCuisineId].
String? seeAllCuisineLabel(LocationModel location) =>
    LocationModel.formatCuisineLabel(location.cuisineKey) ??
    location.displayCuisine;

/// Vibe ids (keys of [vibeStyles]) a location is tagged with.
Set<String> seeAllVibeIds(LocationModel location) {
  final vibe = location.vibe;
  if (vibe == null) return const {};
  return {
    for (final entry in vibe.topTags(3))
      if (entry.value > 0.3 && vibeStyles.containsKey(entry.key)) entry.key,
  };
}

/// Cuisine chips for [pool], most common first.
List<SeeAllFilterOption> buildCuisineOptions(List<LocationModel> pool) {
  final counts = <String, int>{};
  final labels = <String, String>{};
  for (final location in pool) {
    final id = seeAllCuisineId(location);
    if (id == null) continue;
    counts[id] = (counts[id] ?? 0) + 1;
    labels.putIfAbsent(id, () => seeAllCuisineLabel(location) ?? id);
  }
  return _sorted(counts, labels);
}

/// Vibe chips for [pool], most common first.
List<SeeAllFilterOption> buildVibeOptions(List<LocationModel> pool) {
  final counts = <String, int>{};
  for (final location in pool) {
    for (final id in seeAllVibeIds(location)) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  return _sorted(counts, {
    for (final id in counts.keys) id: vibeStyles[id]!.label,
  });
}

List<SeeAllFilterOption> _sorted(
  Map<String, int> counts,
  Map<String, String> labels,
) {
  final options = [
    for (final entry in counts.entries)
      SeeAllFilterOption(
        id: entry.key,
        label: labels[entry.key] ?? entry.key,
        count: entry.value,
      ),
  ];
  options.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    return byCount != 0 ? byCount : a.label.compareTo(b.label);
  });
  return options;
}

/// Source + cuisine + vibe chips in one rail, styled like the home category
/// carousel. Sources are single-select; cuisines and vibes are multi-select.
class SeeAllFilterRail extends StatelessWidget {
  final List<SeeAllFilterOption> sources;
  final String activeSourceId;
  final List<SeeAllFilterOption> cuisines;
  final List<SeeAllFilterOption> vibes;
  final Set<String> selectedCuisines;
  final Set<String> selectedVibes;
  final ValueChanged<String> onSourceSelected;
  final ValueChanged<String> onCuisineToggled;
  final ValueChanged<String> onVibeToggled;
  final VoidCallback? onClear;

  const SeeAllFilterRail({
    super.key,
    required this.sources,
    required this.activeSourceId,
    required this.cuisines,
    required this.vibes,
    required this.selectedCuisines,
    required this.selectedVibes,
    required this.onSourceSelected,
    required this.onCuisineToggled,
    required this.onVibeToggled,
    this.onClear,
  });

  static HomeCategory _category(
    HomeCategoryKind kind,
    SeeAllFilterOption option, {
    String? idPrefix,
  }) =>
      HomeCategory(
        kind: kind,
        id: '${idPrefix ?? ''}${option.id}',
        label: option.label,
        count: option.count,
        icon: kind == HomeCategoryKind.vibe ? vibeStyles[option.id]?.icon : null,
        resolve: () async => const [],
      );

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (onClear != null) _ClearChip(onTap: onClear!),
      for (final source in sources)
        CategoryChip(
          category: _category(HomeCategoryKind.source, source),
          meta: '${source.count} ${source.count == 1 ? 'SPOT' : 'SPOTS'}',
          selected: source.id == activeSourceId,
          onTap: () => onSourceSelected(source.id),
        ),
      if (cuisines.isNotEmpty) const CategoryGroupDot(),
      for (final cuisine in cuisines)
        CategoryChip(
          category: _category(HomeCategoryKind.cuisine, cuisine),
          selected: selectedCuisines.contains(cuisine.id),
          onTap: () => onCuisineToggled(cuisine.id),
        ),
      if (vibes.isNotEmpty) const CategoryGroupDot(),
      for (final vibe in vibes)
        CategoryChip(
          category: _category(HomeCategoryKind.vibe, vibe),
          selected: selectedVibes.contains(vibe.id),
          onTap: () => onVibeToggled(vibe.id),
        ),
    ];

    return SizedBox(
      height: CategoryCarousel.chipHeight + 14,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Color(0x00000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
          ],
          stops: [0.0, 0.03, 0.97, 1.0],
        ).createShader(bounds),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) => items[index],
        ),
      ),
    );
  }
}

class _ClearChip extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Clear filters',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: CategoryCarousel.chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(
            'CLEAR',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: PinitColors.accent,
              letterSpacing: 11 * 0.12,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/categories/home_category.dart';
import 'package:login/pages/home/categories/vibe_styles.dart';
import 'package:login/supabase/helpers/collections.dart';

/// Builds the ordered list of home category tiles from data that's already
/// been fetched/warmed (saved spots, area recommendations, user vibe
/// affinity, collections). Pure given its inputs — no I/O except the eat-list
/// [resolve] closures, which defer to [loadCollectionLocations].
///
/// Tile order: Instagram, TikTok (source), then cuisines, eat-lists, vibes.
class HomeCategoryBuilder {
  // ── Tunables ──────────────────────────────────────────────────
  static const int maxCuisineTiles = 4;
  static const int maxVibeTiles = 4;

  /// A location "has" a vibe when its normalised score clears this bar.
  static const double vibePresenceThreshold = 0.35;

  /// Weight applied to spots with no match score when ranking cuisines/vibes.
  static const double matchScoreFallback = 0.5;

  /// Vibe keys we never surface as their own tile.
  static const Set<String> _excludedVibeTags = {'bossman'};

  /// Best-effort emoji per cuisine key; falls back to a plate.
  static const Map<String, String> _cuisineEmoji = {
    'italian': '🍝',
    'indian': '🍛',
    'american': '🍔',
    'turkish': '🥙',
    'pub': '🍺',
    'chinese': '🥡',
    'british': '🍽️',
    'japanese': '🍣',
    'french': '🥐',
    'middle_eastern': '🧆',
    'thai': '🍜',
    'mexican': '🌮',
    'korean': '🍲',
    'vietnamese': '🍜',
    'greek': '🥗',
    'spanish': '🥘',
    'seafood': '🦞',
    'vegan': '🥦',
    'vegetarian': '🥗',
    'dessert': '🍰',
    'bakery': '🥐',
    'coffee': '☕',
    'burger': '🍔',
    'pizza': '🍕',
    'sushi': '🍣',
  };

  const HomeCategoryBuilder._();

  static List<HomeCategory> build({
    required List<LocationModel> savedLocations,
    required List<LocationModel> areaRecommendations,
    required List<double>? vibeTagAffinity,
    required List<CollectionItem> collections,
    required Future<List<LocationModel>> Function(String collectionId)
        loadCollectionLocations,
  }) {
    final categories = <HomeCategory>[];

    // ── 1. Source tiles (Instagram, TikTok) — always first, if non-empty ──
    categories.addAll(_sourceCategories(savedLocations));

    // Pool for cuisine/vibe aggregation: area recommendations (area-aware)
    // combined with saved spots (personal), deduped by locationId.
    final pool = _dedupeById([...areaRecommendations, ...savedLocations]);

    // ── 2. Cuisine tiles ──
    categories.addAll(_cuisineCategories(pool));

    // ── 3. Eat-list tiles ──
    categories.addAll(_eatListCategories(collections, loadCollectionLocations));

    // ── 4. Vibe tiles ──
    categories.addAll(_vibeCategories(pool, vibeTagAffinity));

    return categories;
  }

  // ────────────────────────────────────────────────────────────────
  //  Source
  // ────────────────────────────────────────────────────────────────
  static List<HomeCategory> _sourceCategories(List<LocationModel> saved) {
    HomeCategory? tile(String method, String label, IconData icon) {
      final matches =
          saved.where((l) => l.savedMethod == method).toList(growable: false);
      if (matches.isEmpty) return null;
      return HomeCategory(
        kind: HomeCategoryKind.source,
        id: method,
        label: label,
        icon: icon,
        count: matches.length,
        resolve: () async => matches,
      );
    }

    return [
      tile('instagram', 'Instagram', FeatherIcons.instagram),
      tile('tiktok', 'TikTok', FeatherIcons.video),
    ].whereType<HomeCategory>().toList();
  }

  // ────────────────────────────────────────────────────────────────
  //  Cuisine
  // ────────────────────────────────────────────────────────────────
  static List<HomeCategory> _cuisineCategories(List<LocationModel> pool) {
    final weightByKey = <String, double>{};
    final labelByKey = <String, String>{};

    for (final loc in pool) {
      final key = _cuisineKey(loc);
      if (key == null) continue;
      final label = loc.displayCuisine;
      if (label == null) continue;
      weightByKey[key] =
          (weightByKey[key] ?? 0) + (loc.matchScore ?? matchScoreFallback);
      labelByKey[key] ??= label;
    }

    final ranked = weightByKey.keys.toList()
      ..sort((a, b) => weightByKey[b]!.compareTo(weightByKey[a]!));

    return ranked.take(maxCuisineTiles).map((key) {
      final matches =
          pool.where((l) => _cuisineKey(l) == key).toList(growable: false);
      return HomeCategory(
        kind: HomeCategoryKind.cuisine,
        id: key,
        label: labelByKey[key]!,
        emoji: _cuisineEmoji[key] ?? '🍽️',
        count: matches.length,
        resolve: () async => matches,
      );
    }).toList();
  }

  static String? _cuisineKey(LocationModel loc) {
    final raw = (loc.cuisinePrimary ?? loc.cuisine)?.trim().toLowerCase();
    if (raw == null || raw.isEmpty || raw == 'unknown') return null;
    return raw.replaceAll(RegExp(r'\s+'), '_');
  }

  // ────────────────────────────────────────────────────────────────
  //  Eat-lists
  // ────────────────────────────────────────────────────────────────
  static List<HomeCategory> _eatListCategories(
    List<CollectionItem> collections,
    Future<List<LocationModel>> Function(String) loadCollectionLocations,
  ) {
    return collections
        .where((c) => c.placeCount > 0)
        .map(
          (c) => HomeCategory(
            kind: HomeCategoryKind.eatList,
            id: c.collectionId,
            label: c.name,
            emoji: (c.emoji != null && c.emoji!.isNotEmpty) ? c.emoji : '📌',
            count: c.placeCount,
            resolve: () => loadCollectionLocations(c.collectionId),
          ),
        )
        .toList();
  }

  // ────────────────────────────────────────────────────────────────
  //  Vibes
  // ────────────────────────────────────────────────────────────────
  static List<HomeCategory> _vibeCategories(
    List<LocationModel> pool,
    List<double>? vibeTagAffinity,
  ) {
    final scoreByTag = <String, double>{};

    for (final loc in pool) {
      final vibe = loc.vibe;
      if (vibe == null) continue;
      for (final entry in vibe.topTags(3)) {
        if (entry.value < vibePresenceThreshold) continue;
        if (_excludedVibeTags.contains(entry.key)) continue;
        if (!vibeStyles.containsKey(entry.key)) continue;
        scoreByTag[entry.key] = (scoreByTag[entry.key] ?? 0) + entry.value;
      }
    }

    // Weight each present vibe by the user's affinity for it (neutral 1.0
    // when there's no affinity data), so personal taste re-ranks what's around.
    final weighted = scoreByTag.map(
      (tag, score) => MapEntry(tag, score * _affinity(vibeTagAffinity, tag)),
    );

    final ranked = weighted.keys.toList()
      ..sort((a, b) => weighted[b]!.compareTo(weighted[a]!));

    return ranked.take(maxVibeTiles).map((tag) {
      final matches = pool
          .where((l) => (l.vibe?.scoreFor(tag) ?? 0) >= vibePresenceThreshold)
          .toList()
        ..sort((a, b) =>
            (b.vibe!.scoreFor(tag)).compareTo(a.vibe!.scoreFor(tag)));
      final style = vibeStyles[tag]!;
      return HomeCategory(
        kind: HomeCategoryKind.vibe,
        id: tag,
        label: style.label,
        icon: style.icon,
        count: matches.length,
        resolve: () async => matches,
      );
    }).toList();
  }

  /// User affinity for [tag], normalised to ~0..1. Returns a neutral 1.0 when
  /// affinity data is absent so ranking falls back to raw area presence.
  static double _affinity(List<double>? affinity, String tag) {
    if (affinity == null || affinity.isEmpty) return 1.0;
    final idx = vibeTagOrder[tag];
    if (idx == null || idx >= affinity.length) return 1.0;
    final raw = affinity[idx];
    if (!raw.isFinite || raw <= 0) return 0.0;
    return raw <= 1.0 ? raw : (raw / 100.0).clamp(0.0, 1.0);
  }

  static List<LocationModel> _dedupeById(List<LocationModel> locations) {
    final seen = <int>{};
    final out = <LocationModel>[];
    for (final loc in locations) {
      if (seen.add(loc.locationId)) out.add(loc);
    }
    return out;
  }
}

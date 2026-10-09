import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:login/models/home_rail_candidate.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/categories/home_category.dart';
import 'package:login/pages/home/categories/vibe_styles.dart';
import 'package:login/supabase/helpers/collections.dart';

/// Builds the ordered list of home category tiles from data that's already
/// been fetched/warmed (saved spots, area recommendations, user vibe
/// affinity, collections). Pure given its inputs — no I/O except the eat-list
/// [resolve] closures, which defer to [loadCollectionLocations].
///
/// Tile order: Shared Finds (source), then cuisines, eat-lists, vibes.
///
/// With [railCandidates] from `get_home_rail` (server rail enabled), cuisine
/// tiles come from the server's area lift + taste ranking, bubble tiles are
/// added, and the order becomes Shared Finds, cuisines, bubbles, eat-lists,
/// vibes, capped at [maxTiles].
///
/// The Shared Finds tile is always present, even with no social saves yet.
class HomeCategoryBuilder {
  // ── Tunables ──────────────────────────────────────────────────
  static const int maxCuisineTiles = 4;
  static const int maxVibeTiles = 4;
  static const int maxBubbleTiles = 3;
  static const int maxTiles = 10;

  /// A location "has" a vibe when its normalised score clears this bar.
  static const double vibePresenceThreshold = 0.35;

  /// Weight applied to spots with no match score when ranking cuisines/vibes.
  static const double matchScoreFallback = 0.5;

  /// Vibe keys we never surface as their own tile.
  static const Set<String> _excludedVibeTags = {'bossman'};

  /// Id/label of the source tile collecting every TikTok + Instagram save.
  static const String sharedFindsId = 'shared_finds';
  static const String sharedFindsLabel = 'Shared Finds';

  /// `saved_method` values that count as a shared find.
  static const Set<String> _socialSavedMethods = {'tiktok', 'instagram'};

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
    'burgers': '🍔',
    'pizza': '🍕',
    'sushi': '🍣',
    'chicken': '🍗',
    'barbecue': '🍖',
    'lebanese': '🧆',
    'persian': '🍢',
    'pakistani': '🍛',
    'bangladeshi': '🍛',
    'sri_lankan': '🍛',
    'african': '🍲',
    'caribbean': '🍗',
    'brazilian': '🥩',
    'peruvian': '🐟',
    'portuguese': '🐓',
    'mediterranean': '🫒',
    'malaysian': '🍜',
    'indonesian': '🍛',
    'taiwanese': '🧋',
  };

  const HomeCategoryBuilder._();

  static List<HomeCategory> build({
    required List<LocationModel> savedLocations,
    required List<LocationModel> areaRecommendations,
    required List<double>? vibeTagAffinity,
    required List<CollectionItem> collections,
    required Future<List<LocationModel>> Function(String collectionId)
        loadCollectionLocations,
    List<HomeRailCandidate>? railCandidates,
    Future<List<LocationModel>> Function(List<int> locationIds)?
        loadLocationsByIds,
    String? areaLabel,
    Map<String, List<String>> bubbleAvatars = const {},
  }) {
    if (railCandidates != null && loadLocationsByIds != null) {
      return _buildWithServerRail(
        savedLocations: savedLocations,
        areaRecommendations: areaRecommendations,
        vibeTagAffinity: vibeTagAffinity,
        collections: collections,
        loadCollectionLocations: loadCollectionLocations,
        railCandidates: railCandidates,
        loadLocationsByIds: loadLocationsByIds,
        areaLabel: areaLabel,
        bubbleAvatars: bubbleAvatars,
      );
    }

    final categories = <HomeCategory>[];

    // ── 1. Shared Finds — always first ──
    categories.add(_sharedFindsCategory(savedLocations));

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

  static List<HomeCategory> _buildWithServerRail({
    required List<LocationModel> savedLocations,
    required List<LocationModel> areaRecommendations,
    required List<double>? vibeTagAffinity,
    required List<CollectionItem> collections,
    required Future<List<LocationModel>> Function(String) loadCollectionLocations,
    required List<HomeRailCandidate> railCandidates,
    required Future<List<LocationModel>> Function(List<int>) loadLocationsByIds,
    required String? areaLabel,
    required Map<String, List<String>> bubbleAvatars,
  }) {
    final pool = _dedupeById([...areaRecommendations, ...savedLocations]);

    // Server cuisines first (area lift + taste); client cuisines only fill
    // the remaining slots with keys the server didn't return.
    final serverCuisines = railCandidates
        .where((c) => c.isCuisine && c.locationIds.isNotEmpty)
        .take(maxCuisineTiles)
        .map((c) => HomeCategory(
              kind: HomeCategoryKind.cuisine,
              id: c.id,
              label: c.label,
              emoji: _cuisineEmoji[c.id] ?? '🍽️',
              count: c.placeCount,
              areaLabel: c.isAreaLifted ? areaLabel : null,
              resolve: () => loadLocationsByIds(c.locationIds),
            ))
        .toList();
    final serverCuisineIds = serverCuisines.map((c) => c.id).toSet();
    final clientCuisines = _cuisineCategories(pool)
        .where((c) => !serverCuisineIds.contains(c.id))
        .take(maxCuisineTiles - serverCuisines.length);

    final bubbles = railCandidates
        .where((c) => c.isBubble && c.locationIds.length >= 2)
        .take(maxBubbleTiles)
        .map((c) => HomeCategory(
              kind: HomeCategoryKind.bubble,
              id: c.id,
              label: c.label,
              icon: FeatherIcons.users,
              count: c.placeCount,
              avatarUrls: bubbleAvatars[c.id] ?? const [],
              resolve: () => loadLocationsByIds(c.locationIds),
            ));

    return [
      _sharedFindsCategory(savedLocations),
      ...serverCuisines,
      ...clientCuisines,
      ...bubbles,
      ..._eatListCategories(collections, loadCollectionLocations),
      ..._vibeCategories(pool, vibeTagAffinity),
    ].take(maxTiles).toList();
  }

  // ────────────────────────────────────────────────────────────────
  //  Source
  // ────────────────────────────────────────────────────────────────
  static HomeCategory _sharedFindsCategory(List<LocationModel> saved) {
    final matches = saved
        .where((l) => _socialSavedMethods.contains(l.savedMethod))
        .toList(growable: false);
    return HomeCategory(
      kind: HomeCategoryKind.source,
      id: sharedFindsId,
      label: sharedFindsLabel,
      icon: FontAwesomeIcons.tiktok.data,
      count: matches.length,
      resolve: () async => matches,
    );
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
      // Label from the key so 'italian' / 'Italian' rows land on one tile.
      final label = LocationModel.formatCuisineLabel(key);
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

  /// Prefers the server-normalised `cuisine_key`; falls back to the sparse
  /// legacy fields for rows fetched without it (e.g. older cached saves).
  static String? _cuisineKey(LocationModel loc) {
    final raw =
        (loc.cuisineKey ?? loc.cuisinePrimary ?? loc.cuisine)?.trim().toLowerCase();
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
    // The auto-generated Shared Finds collection is covered by the source tile.
    return collections
        .where((c) => c.placeCount > 0 && c.name != sharedFindsLabel)
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

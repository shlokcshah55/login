import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/home_rail_candidate.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/categories/home_category.dart';
import 'package:login/pages/home/categories/home_category_builder.dart';
import 'package:login/supabase/helpers/collections.dart';

LocationModel _loc(
  int id, {
  String? cuisine,
  String? cuisineKey,
  String? savedMethod,
}) {
  return LocationModel(
    locationId: id,
    name: 'Place $id',
    createdAt: DateTime.utc(2026, 9, 1),
    lat: 51.5,
    lng: -0.1,
    cuisinePrimary: cuisine,
    cuisineKey: cuisineKey,
    savedMethod: savedMethod,
  );
}

HomeRailCandidate _candidate(
  String kind,
  String id, {
  String? label,
  String reason = 'area',
  List<int> ids = const [1, 2, 3],
  int? count,
}) {
  return HomeRailCandidate(
    kind: kind,
    id: id,
    label: label ?? id,
    score: 1,
    placeCount: count ?? ids.length,
    locationIds: ids,
    reason: reason,
  );
}

CollectionItem _collection(String id, String name, int count) {
  return CollectionItem(
    collectionId: id,
    name: name,
    placeCount: count,
  );
}

List<HomeCategory> _build({
  List<LocationModel> saved = const [],
  List<LocationModel> recs = const [],
  List<CollectionItem> collections = const [],
  List<HomeRailCandidate>? rail,
  String? areaLabel,
  Map<String, List<String>> avatars = const {},
  List<List<int>>? loadedIds,
}) {
  return HomeCategoryBuilder.build(
    savedLocations: saved,
    areaRecommendations: recs,
    vibeTagAffinity: null,
    collections: collections,
    loadCollectionLocations: (_) async => const [],
    railCandidates: rail,
    loadLocationsByIds: rail == null
        ? null
        : (ids) async {
            loadedIds?.add(ids);
            return ids.map((id) => _loc(id)).toList();
          },
    areaLabel: areaLabel,
    bubbleAvatars: avatars,
  );
}

void main() {
  final saved = [
    _loc(10, cuisine: 'Italian', savedMethod: 'instagram'),
    _loc(11, cuisine: 'Thai', savedMethod: 'tiktok'),
  ];
  final collections = [_collection('c1', 'Date night', 4)];

  group('without server rail (flag off)', () {
    test('keeps the original order: sources, cuisines, eat-lists', () {
      final tiles = _build(saved: saved, collections: collections);
      expect(tiles.map((t) => t.kind).toList(), [
        HomeCategoryKind.source,
        HomeCategoryKind.source,
        HomeCategoryKind.cuisine,
        HomeCategoryKind.cuisine,
        HomeCategoryKind.eatList,
      ]);
      expect(tiles.any((t) => t.kind == HomeCategoryKind.bubble), isFalse);
    });
  });

  group('client cuisine tiles', () {
    test('prefer cuisine_key over cuisine_primary', () {
      final tiles = _build(recs: [
        // cuisine_primary disagrees; the normalised key wins.
        _loc(1, cuisine: 'Pizza', cuisineKey: 'italian'),
        _loc(2, cuisineKey: 'italian'),
      ]);
      final cuisines =
          tiles.where((t) => t.kind == HomeCategoryKind.cuisine).toList();
      expect(cuisines.map((t) => t.id), ['italian']);
      expect(cuisines.single.label, 'Italian');
      expect(cuisines.single.count, 2);
    });

    test('places with only cuisine_key now get a tile', () {
      final tiles = _build(recs: [_loc(1, cuisineKey: 'middle_eastern')]);
      final tile = tiles.singleWhere((t) => t.kind == HomeCategoryKind.cuisine);
      expect(tile.id, 'middle_eastern');
      expect(tile.label, 'Middle Eastern');
    });

    test('mixed-case legacy values land on one tile', () {
      final tiles = _build(recs: [
        _loc(1, cuisine: 'italian'),
        _loc(2, cuisine: 'Italian'),
      ]);
      final cuisines =
          tiles.where((t) => t.kind == HomeCategoryKind.cuisine).toList();
      expect(cuisines, hasLength(1));
      expect(cuisines.single.count, 2);
    });
  });

  group('LocationModel.cuisineKey', () {
    test('round-trips cuisine_key through JSON', () {
      final loc = LocationModel.fromJson({
        'location_id': 5,
        'name': 'Dishoom',
        'created_at': '2026-09-01T00:00:00Z',
        'lat': 51.5,
        'lng': -0.1,
        'cuisine_key': 'indian',
      }, null);
      expect(loc.cuisineKey, 'indian');
      expect(loc.toJson()['cuisine_key'], 'indian');
      expect(loc.copyWith(name: 'x').cuisineKey, 'indian');
    });
  });

  group('with server rail', () {
    test('orders cuisines, bubbles, eat-lists, vibes, sources', () {
      final tiles = _build(
        saved: saved,
        collections: collections,
        rail: [
          _candidate('cuisine', 'korean', label: 'Korean'),
          _candidate('bubble', 'b1', label: 'Sunday Crew'),
        ],
      );
      final kinds = tiles.map((t) => t.kind).toList();
      expect(kinds.first, HomeCategoryKind.cuisine);
      expect(kinds.indexOf(HomeCategoryKind.bubble),
          lessThan(kinds.indexOf(HomeCategoryKind.eatList)));
      expect(kinds.indexOf(HomeCategoryKind.eatList),
          lessThan(kinds.indexOf(HomeCategoryKind.source)));
      expect(tiles.first.id, 'korean');
    });

    test('server cuisine wins over the client tile with the same key', () {
      final tiles = _build(
        saved: saved,
        rail: [_candidate('cuisine', 'italian', label: 'Italian', count: 42)],
      );
      final italian =
          tiles.where((t) => t.kind == HomeCategoryKind.cuisine && t.id == 'italian');
      expect(italian, hasLength(1));
      expect(italian.single.count, 42);
      // The client-only Thai tile still fills a remaining cuisine slot.
      expect(tiles.any((t) => t.id == 'thai'), isTrue);
    });

    test('area label only on area-lifted cuisine tiles', () {
      final tiles = _build(
        areaLabel: 'Islington',
        rail: [
          _candidate('cuisine', 'korean'),
          _candidate('cuisine', 'thai', reason: 'personal'),
          _candidate('cuisine', 'japanese', reason: 'area+personal'),
        ],
      );
      String? area(String id) => tiles.firstWhere((t) => t.id == id).areaLabel;
      expect(area('korean'), 'Islington');
      expect(area('japanese'), 'Islington');
      expect(area('thai'), isNull);
    });

    test('caps cuisine tiles at maxCuisineTiles', () {
      final tiles = _build(rail: [
        for (final id in ['a', 'b', 'c', 'd', 'e', 'f'])
          _candidate('cuisine', id),
      ]);
      expect(tiles.where((t) => t.kind == HomeCategoryKind.cuisine),
          hasLength(HomeCategoryBuilder.maxCuisineTiles));
    });

    test('caps the whole rail at maxTiles', () {
      final tiles = _build(
        saved: saved,
        collections: [
          for (var i = 0; i < 12; i++) _collection('c$i', 'List $i', 2),
        ],
        rail: [_candidate('cuisine', 'korean')],
      );
      expect(tiles, hasLength(HomeCategoryBuilder.maxTiles));
    });

    test('bubble tiles carry member avatars and resolve by location ids',
        () async {
      final loaded = <List<int>>[];
      final tiles = _build(
        rail: [_candidate('bubble', 'b1', label: 'Sunday Crew', ids: [7, 8])],
        avatars: {
          'b1': ['https://img/a.jpg', 'https://img/b.jpg'],
        },
        loadedIds: loaded,
      );
      final bubble = tiles.singleWhere((t) => t.kind == HomeCategoryKind.bubble);
      expect(bubble.label, 'Sunday Crew');
      expect(bubble.avatarUrls, hasLength(2));

      final places = await bubble.resolve();
      expect(loaded, [
        [7, 8]
      ]);
      expect(places.map((p) => p.locationId), [7, 8]);
    });

    test('drops bubble candidates with fewer than 2 places', () {
      final tiles = _build(rail: [_candidate('bubble', 'b1', ids: [7])]);
      expect(tiles.any((t) => t.kind == HomeCategoryKind.bubble), isFalse);
    });
  });

  group('HomeRailCandidate.tryParse', () {
    test('parses an RPC row', () {
      final c = HomeRailCandidate.tryParse({
        'kind': 'cuisine',
        'id': 'korean',
        'label': 'Korean',
        'score': 14.6,
        'place_count': 16,
        'location_ids': [3, 1, 2],
        'reason': 'area+personal',
      })!;
      expect(c.isCuisine, isTrue);
      expect(c.isAreaLifted, isTrue);
      expect(c.locationIds, [3, 1, 2]);
      expect(HomeRailCandidate.tryParse(c.toJson())!.placeCount, 16);
    });

    test('rejects malformed rows', () {
      expect(HomeRailCandidate.tryParse({'kind': 'cuisine'}), isNull);
      expect(HomeRailCandidate.tryParse('nope'), isNull);
    });
  });
}

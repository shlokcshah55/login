import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/home/search/header_search_coordinator.dart';
import 'package:login/pages/home/search/header_search_types.dart';

void main() {
  group('HeaderSearchCoordinator intent detection', () {
    test('classifies people intent from social query language', () {
      expect(
        HeaderSearchCoordinator.detectIntent('find friends for brunch'),
        SearchIntentType.people,
      );
      expect(
        HeaderSearchCoordinator.detectIntent('@alice'),
        SearchIntentType.people,
      );
    });

    test('classifies place intent from venue query language', () {
      expect(
        HeaderSearchCoordinator.detectIntent('best pizza near me'),
        SearchIntentType.place,
      );
    });

    test('classifies natural language intent from descriptive prompts', () {
      expect(
        HeaderSearchCoordinator.detectIntent(
          'somewhere cozy for a date with good cocktails',
        ),
        SearchIntentType.naturalLanguage,
      );
    });

    test('classifies short single-word queries as place lookups', () {
      // Short queries are almost always proper-noun place lookups
      // ("Jamun", "London") rather than vibe searches.
      expect(
        HeaderSearchCoordinator.detectIntent('london'),
        SearchIntentType.place,
      );
    });
  });

  group('HeaderSearchCoordinator section ordering', () {
    test('place intent excludes the Recommended section to save magic-search calls',
        () {
      expect(
        HeaderSearchCoordinator.sectionOrderForIntent(SearchIntentType.place),
        const [
          SearchSectionType.places,
          SearchSectionType.people,
        ],
      );
    });

    test('mixed intent shows all three sections', () {
      expect(
        HeaderSearchCoordinator.sectionOrderForIntent(SearchIntentType.mixed),
        const [
          SearchSectionType.places,
          SearchSectionType.naturalLanguage,
          SearchSectionType.people,
        ],
      );
    });

    test('people intent excludes the Recommended section', () {
      expect(
        HeaderSearchCoordinator.sectionOrderForIntent(SearchIntentType.people),
        const [
          SearchSectionType.people,
          SearchSectionType.places,
        ],
      );
    });

    test('natural language intent puts Recommended first', () {
      expect(
        HeaderSearchCoordinator.sectionOrderForIntent(
          SearchIntentType.naturalLanguage,
        ),
        const [
          SearchSectionType.naturalLanguage,
          SearchSectionType.places,
          SearchSectionType.people,
        ],
      );
    });
  });

  group('HeaderSearchCoordinator stage gating', () {
    test('natural-language stage runs for naturalLanguage and mixed only', () {
      expect(
        HeaderSearchCoordinator.shouldRunNaturalLanguageStage(
          SearchIntentType.naturalLanguage,
        ),
        isTrue,
      );
      expect(
        HeaderSearchCoordinator.shouldRunNaturalLanguageStage(
          SearchIntentType.mixed,
        ),
        isTrue,
      );
      expect(
        HeaderSearchCoordinator.shouldRunNaturalLanguageStage(
          SearchIntentType.place,
        ),
        isFalse,
      );
      expect(
        HeaderSearchCoordinator.shouldRunNaturalLanguageStage(
          SearchIntentType.people,
        ),
        isFalse,
      );
    });

    test('mapbox stage runs for place and mixed only', () {
      expect(
        HeaderSearchCoordinator.shouldRunMapboxStage(SearchIntentType.place),
        isTrue,
      );
      expect(
        HeaderSearchCoordinator.shouldRunMapboxStage(SearchIntentType.mixed),
        isTrue,
      );
      expect(
        HeaderSearchCoordinator.shouldRunMapboxStage(
          SearchIntentType.naturalLanguage,
        ),
        isFalse,
      );
      expect(
        HeaderSearchCoordinator.shouldRunMapboxStage(SearchIntentType.people),
        isFalse,
      );
    });
  });

  group('HeaderSearchCoordinator improved intent detection', () {
    test('classifies sentence-shaped queries as natural language', () {
      expect(
        HeaderSearchCoordinator.detectIntent(
          'where can i take my parents this weekend',
        ),
        SearchIntentType.naturalLanguage,
      );
      expect(
        HeaderSearchCoordinator.detectIntent('show me a quiet rooftop bar'),
        SearchIntentType.naturalLanguage,
      );
    });

    test('classifies short proper-noun lookups as place intent', () {
      expect(
        HeaderSearchCoordinator.detectIntent('jamun'),
        SearchIntentType.place,
      );
      expect(
        HeaderSearchCoordinator.detectIntent('padella borough'),
        SearchIntentType.place,
      );
    });
  });

  group('HeaderSearchCoordinator place merging', () {
    test('keeps DB results first and appends Mapbox fallback second', () {
      final dbResults = [
        _location(
          id: 101,
          name: 'Dishoom Shoreditch',
          googlePlaceId: 'db-1',
        ),
        _location(
          id: 102,
          name: 'Padella',
          googlePlaceId: 'db-2',
        ),
      ];
      final mapboxResults = [
        _location(
          id: -201,
          name: 'Dishoom Shoreditch',
          googlePlaceId: 'db-1',
        ),
        _location(
          id: -202,
          name: 'Kiln Soho',
          googlePlaceId: 'mbx-2',
        ),
      ];

      final merged = HeaderSearchCoordinator.mergePlaceResults(
        databaseResults: dbResults,
        mapboxResults: mapboxResults,
      );

      expect(merged.map((location) => location.name).toList(), [
        'Dishoom Shoreditch',
        'Padella',
        'Kiln Soho',
      ]);
      expect(merged.first.locationId, 101);
      expect(merged.last.locationId, -202);
    });
  });

  group('HeaderSearchCoordinator people ranking', () {
    test('biases accepted follows before suggested users before organic text matches', () {
      final users = [
        _user(
          id: 'followed-user',
          name: 'Alex Morgan',
          username: 'alexm',
          followersCount: 3,
        ),
        _user(
          id: 'suggested-user',
          name: 'Alex Rivera',
          username: 'alexr',
          followersCount: 100,
        ),
        _user(
          id: 'organic-user',
          name: 'Alex Stone',
          username: 'stonealex',
          followersCount: 400,
        ),
      ];

      final ranked = HeaderSearchCoordinator.rankPeopleResults(
        query: 'alex',
        users: users,
        followInfluenceByUserId: const {
          'followed-user': 80,
        },
        suggestedUserIds: const {'suggested-user'},
      );

      expect(ranked.map((user) => user.supabaseId).toList(), [
        'followed-user',
        'suggested-user',
        'organic-user',
      ]);
    });
  });
}

LocationModel _location({
  required int id,
  required String name,
  required String googlePlaceId,
}) {
  return LocationModel(
    locationId: id,
    name: name,
    googlePlaceId: googlePlaceId,
    lat: 51.5074,
    lng: -0.1278,
    createdAt: DateTime(2024),
  );
}

UserModel _user({
  required String id,
  required String name,
  required String username,
  required int followersCount,
}) {
  return UserModel(
    supabaseId: id,
    name: name,
    username: username,
    email: '$username@example.com',
    followersCount: followersCount,
  );
}

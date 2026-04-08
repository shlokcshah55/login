import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/search/header_search_coordinator.dart';
import 'package:login/pages/home/search/header_search_repository.dart';
import 'package:login/pages/home/search/header_search_types.dart';
import 'package:login/utils/geo_types.dart';

void main() {
  test('progressively fills waterfall stages and ignores stale responses', () async {
    final repository = _FakeHeaderSearchRepository();
    final coordinator = HeaderSearchCoordinator(
      repository: repository,
      debounceDuration: Duration.zero,
    );

    await coordinator.open();
    coordinator.updateQuery('pizza');
    await pumpEventQueue();

    expect(coordinator.state.result.inlineCompletion, 'pizza palace');
    expect(
      coordinator.state.result.completedStages,
      contains(WaterfallStage.inlineCompletion),
    );
    expect(coordinator.state.result.sections.every((section) => section.items.isEmpty), isTrue);

    repository.quickSuggestions('pizza').complete([
      SearchSuggestionItem.recentQuery('pizza palace'),
    ]);
    await pumpEventQueue();

    expect(
      coordinator.state.result.quickSuggestions.map((item) => item.title).toList(),
      ['pizza palace'],
    );
    expect(
      coordinator.state.result.completedStages,
      contains(WaterfallStage.personalSuggestions),
    );

    coordinator.updateQuery('pizz');
    await pumpEventQueue();

    repository.sections('pizza').complete({
      SearchSectionType.places: const [
        SearchSuggestionItem(
          id: 'old-place',
          kind: SearchSuggestionKind.place,
          title: 'Old Pizza Result',
        ),
      ],
    });
    await pumpEventQueue();

    expect(coordinator.state.query, 'pizz');
    expect(
      coordinator.state.result.sections
          .expand((section) => section.items)
          .map((item) => item.title),
      isNot(contains('Old Pizza Result')),
    );

    repository.quickSuggestions('pizz').complete([
      SearchSuggestionItem.recentQuery('pizzette'),
    ]);
    repository.sections('pizz').complete({
      SearchSectionType.places: const [
        SearchSuggestionItem(
          id: 'latest-place',
          kind: SearchSuggestionKind.place,
          title: 'Latest Pizza Result',
        ),
      ],
    });
    await pumpEventQueue();

    expect(
      coordinator.state.result.quickSuggestions.map((item) => item.title).toList(),
      ['pizzette'],
    );
    expect(
      coordinator.state.result.sections
          .firstWhere((section) => section.type == SearchSectionType.places)
          .items
          .map((item) => item.title)
          .toList(),
      ['Latest Pizza Result'],
    );
    expect(
      coordinator.state.result.completedStages,
      contains(WaterfallStage.fullResults),
    );
  });

  test('mapbox live suggestions merge into Places after DB results land',
      () async {
    final repository = _FakeHeaderSearchRepository();
    final coordinator = HeaderSearchCoordinator(
      repository: repository,
      debounceDuration: Duration.zero,
    );

    await coordinator.open();
    coordinator.updateQuery('blue');
    await pumpEventQueue();

    repository.quickSuggestions('blue').complete(const []);
    repository.sections('blue').complete({
      SearchSectionType.places: const [
        SearchSuggestionItem(
          id: 'db-blue-bar',
          kind: SearchSuggestionKind.place,
          title: 'Blue Bar',
        ),
      ],
    });
    await pumpEventQueue();

    var places = coordinator.state.result.sections
        .firstWhere((section) => section.type == SearchSectionType.places)
        .items
        .map((item) => item.title)
        .toList();
    expect(places, ['Blue Bar']);
    expect(
      coordinator.state.result.completedStages,
      isNot(contains(WaterfallStage.mapboxLiveResults)),
    );

    repository.mapboxLive('blue').complete([
      const SearchSuggestionItem(
        id: 'mapbox:abc',
        kind: SearchSuggestionKind.place,
        title: 'Blue Lagoon',
        isMapboxResult: true,
        mapboxId: 'abc',
      ),
    ]);
    await pumpEventQueue();

    places = coordinator.state.result.sections
        .firstWhere((section) => section.type == SearchSectionType.places)
        .items
        .map((item) => item.title)
        .toList();
    expect(places, ['Blue Bar', 'Blue Lagoon']);
    expect(
      coordinator.state.result.completedStages,
      contains(WaterfallStage.mapboxLiveResults),
    );
    // A single session token must be reused for every /suggest call in
    // the same search session.
    expect(repository.mapboxSessionTokens, isNotEmpty);
    expect(repository.mapboxSessionTokens.toSet().length, 1);
  });

  test('mapbox stage is skipped for empty queries and people intent', () async {
    final repository = _FakeHeaderSearchRepository();
    final coordinator = HeaderSearchCoordinator(
      repository: repository,
      debounceDuration: Duration.zero,
    );

    await coordinator.open();
    expect(repository.mapboxSessionTokens, isEmpty);

    coordinator.updateQuery('@alice');
    await pumpEventQueue();
    repository.quickSuggestions('@alice').complete(const []);
    repository.sections('@alice').complete(const {});
    await pumpEventQueue();

    expect(repository.mapboxSessionTokens, isEmpty);
  });
}

class _FakeHeaderSearchRepository implements HeaderSearchRepository {
  final Map<String, Completer<List<SearchSuggestionItem>>> _quickSuggestions =
      {};
  final Map<String, Completer<Map<SearchSectionType, List<SearchSuggestionItem>>>>
      _sections = {};
  final Map<String, Completer<List<SearchSuggestionItem>>> _mapboxLive = {};
  final Map<String, Completer<List<SearchSuggestionItem>>> _naturalLanguage =
      {};
  final List<String> mapboxSessionTokens = <String>[];
  final List<String> naturalLanguageQueries = <String>[];

  Completer<List<SearchSuggestionItem>> quickSuggestions(String query) {
    return _quickSuggestions.putIfAbsent(
      query,
      Completer<List<SearchSuggestionItem>>.new,
    );
  }

  Completer<Map<SearchSectionType, List<SearchSuggestionItem>>> sections(
    String query,
  ) {
    return _sections.putIfAbsent(
      query,
      Completer<Map<SearchSectionType, List<SearchSuggestionItem>>>.new,
    );
  }

  Completer<List<SearchSuggestionItem>> mapboxLive(String query) {
    return _mapboxLive.putIfAbsent(
      query,
      Completer<List<SearchSuggestionItem>>.new,
    );
  }

  Completer<List<SearchSuggestionItem>> naturalLanguage(String query) {
    return _naturalLanguage.putIfAbsent(
      query,
      Completer<List<SearchSuggestionItem>>.new,
    );
  }

  @override
  String? buildInlineCompletion({
    required String query,
    required List<String> recentQueries,
    required List<String> personalPrompts,
  }) {
    if (query == 'pizza') {
      return 'pizza palace';
    }
    return null;
  }

  @override
  List<String> buildPersonalPrompts() => const [
        'Best match for my tastes nearby',
      ];

  @override
  Future<List<SearchSuggestionItem>> loadDatabaseMatches({
    required String query,
    required SearchIntentType intent,
  }) async {
    return const [];
  }

  @override
  Future<List<String>> loadRecentQueries() async => const [];

  @override
  Future<List<SearchSuggestionItem>> loadQuickSuggestions({
    required String query,
    required List<String> recentQueries,
    required List<String> personalPrompts,
  }) {
    return quickSuggestions(query).future;
  }

  @override
  Future<Map<SearchSectionType, List<SearchSuggestionItem>>> loadSections({
    required String query,
    required SearchIntentType intent,
  }) {
    return sections(query).future;
  }

  @override
  Future<List<SearchSuggestionItem>> loadNaturalLanguageSection({
    required String query,
    required SearchIntentType intent,
  }) {
    naturalLanguageQueries.add(query);
    return naturalLanguage(query).future;
  }

  @override
  Future<List<SearchSuggestionItem>> loadMapboxLiveSuggestions({
    required String query,
    required String sessionToken,
    LatLng? proximity,
  }) {
    mapboxSessionTokens.add(sessionToken);
    return mapboxLive(query).future;
  }

  @override
  Future<LatLng?> currentProximity() async => null;

  @override
  Future<LocationModel?> resolveMapboxSuggestion({
    required String mapboxId,
    required String sessionToken,
  }) async {
    return null;
  }

  @override
  Future<void> saveRecentQuery(String query) async {}
}

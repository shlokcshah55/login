import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/search/header_search_coordinator.dart';
import 'package:login/pages/home/search/header_search_repository.dart';
import 'package:login/pages/home/search/header_search_types.dart';
import 'package:login/utils/geo_types.dart';

void main() {
  test('normal search runs Google place search on each debounced query change',
      () async {
    final repository = _FakeHeaderSearchRepository();
    final coordinator = HeaderSearchCoordinator(
      repository: repository,
      debounceDuration: Duration.zero,
    );

    await coordinator.open();
    coordinator.updateQuery('padella');
    await pumpEventQueue();

    expect(repository.googleSearchQueries, ['padella']);
    expect(coordinator.state.result.isLoading, isTrue);

    repository.quickSuggestions('padella').complete([
      SearchSuggestionItem.recentQuery('padella borough'),
    ]);
    await pumpEventQueue();

    expect(
      coordinator.state.result.quickSuggestions.map((item) => item.title),
      ['padella borough'],
    );
    expect(repository.googleSearchQueries, ['padella']);

    repository.googlePlaces('padella').add([
      SearchSuggestionItem.place(
        _location(id: -1, name: 'Padella', googlePlaceId: 'google-padella'),
      ),
    ]);
    await pumpEventQueue();

    expect(
      coordinator.state.result.placeItems.map((item) => item.title),
      ['Padella'],
    );

    await repository.googlePlaces('padella').close();
    await pumpEventQueue();

    expect(coordinator.state.result.isLoading, isFalse);
  });

  test(
      'submit remembers query without duplicating an already-run Google search',
      () async {
    final repository = _FakeHeaderSearchRepository();
    final coordinator = HeaderSearchCoordinator(
      repository: repository,
      debounceDuration: Duration.zero,
    );

    await coordinator.open();
    coordinator.updateQuery('padella');
    await pumpEventQueue();
    repository.googlePlaces('padella').add([
      SearchSuggestionItem.place(
        _location(id: -1, name: 'Padella', googlePlaceId: 'google-padella'),
      ),
    ]);
    await repository.googlePlaces('padella').close();
    await pumpEventQueue();

    await coordinator.submitQuery();
    await pumpEventQueue();

    expect(repository.savedQueries, ['padella']);
    expect(repository.googleSearchQueries, ['padella']);
  });

  test('keystroke Google searches ignore stale streamed results', () async {
    final repository = _FakeHeaderSearchRepository();
    final coordinator = HeaderSearchCoordinator(
      repository: repository,
      debounceDuration: Duration.zero,
    );

    await coordinator.open();
    coordinator.updateQuery('pizza');
    await pumpEventQueue();

    coordinator.updateQuery('pasta');
    await pumpEventQueue();

    repository.googlePlaces('pizza').add([
      const SearchSuggestionItem(
        id: 'old-google-result',
        kind: SearchSuggestionKind.place,
        title: 'Old Pizza Result',
      ),
    ]);
    await pumpEventQueue();

    expect(coordinator.state.query, 'pasta');
    expect(
      coordinator.state.result.placeItems.map((item) => item.title),
      isNot(contains('Old Pizza Result')),
    );

    repository.googlePlaces('pasta').add([
      SearchSuggestionItem.place(
        _location(id: -2, name: 'Bancone', googlePlaceId: 'google-bancone'),
      ),
    ]);
    await pumpEventQueue();

    expect(
      coordinator.state.result.placeItems.map((item) => item.title),
      ['Bancone'],
    );
  });
}

class _FakeHeaderSearchRepository implements HeaderSearchRepository {
  final Map<String, Completer<List<SearchSuggestionItem>>> _quickSuggestions =
      {};
  final Map<String, StreamController<List<SearchSuggestionItem>>>
      _googlePlaces = {};
  final List<String> googleSearchQueries = <String>[];
  final List<String> savedQueries = <String>[];

  Completer<List<SearchSuggestionItem>> quickSuggestions(String query) {
    return _quickSuggestions.putIfAbsent(
      query,
      Completer<List<SearchSuggestionItem>>.new,
    );
  }

  StreamController<List<SearchSuggestionItem>> googlePlaces(String query) {
    return _googlePlaces.putIfAbsent(
      query,
      StreamController<List<SearchSuggestionItem>>.new,
    );
  }

  @override
  String? buildInlineCompletion({
    required String query,
    required List<String> recentQueries,
    required List<String> personalPrompts,
  }) {
    if (query == 'padella') {
      return 'padella borough';
    }
    return null;
  }

  @override
  List<String> buildPersonalPrompts() => const [
        'Best match for my tastes nearby',
      ];

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
  Stream<List<SearchSuggestionItem>> searchGooglePlaces({
    required String query,
  }) {
    googleSearchQueries.add(query);
    return googlePlaces(query).stream;
  }

  @override
  Future<LatLng?> currentProximity() async => null;

  @override
  Future<void> saveRecentQuery(String query) async {
    savedQueries.add(query);
  }
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
    preference: LocationPreference.search,
  );
}

import 'package:login/models/locations.dart';
import 'package:login/pages/home/search/header_search_recent_store.dart';
import 'package:login/pages/home/search/header_search_repository.dart';
import 'package:login/pages/home/search/header_search_types.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/supabase/helpers/location.dart';
import 'package:login/utils/geo_types.dart';

typedef HeaderSearchPersistedPlaceLookup = Future<List<LocationModel>> Function(
  List<String> googlePlaceIds,
);

class LiveHeaderSearchRepository implements HeaderSearchRepository {
  final LocationListManager _locationListManager;
  final UserDataProvider _userDataProvider;
  final HeaderSearchRecentStore _recentStore;
  final GooglePlacesService _googlePlacesService;
  final HeaderSearchPersistedPlaceLookup _persistedPlaceLookup;

  LiveHeaderSearchRepository({
    required LocationListManager locationListManager,
    required UserDataProvider userDataProvider,
    HeaderSearchRecentStore? recentStore,
    GooglePlacesService? googlePlacesService,
    HeaderSearchPersistedPlaceLookup? persistedPlaceLookup,
  })  : _locationListManager = locationListManager,
        _userDataProvider = userDataProvider,
        _recentStore = recentStore ?? HeaderSearchRecentStore(),
        _googlePlacesService = googlePlacesService ?? GooglePlacesService(),
        _persistedPlaceLookup = persistedPlaceLookup ??
            LocationHelper().getLocationsByGooglePlaceIds;

  @override
  Future<List<String>> loadRecentQueries() {
    return _recentStore.loadRecentQueries();
  }

  @override
  Future<void> saveRecentQuery(String query) async {
    await _recentStore.saveQuery(query);
  }

  @override
  List<String> buildPersonalPrompts() {
    final prompts = <String>[
      'A hidden gem near me',
      'Best match for my tastes nearby',
      'Where should I go tonight?',
      'Places my friends are loving',
    ];

    if ((_userDataProvider.supabaseUserData?.followersCount ?? 0) > 0) {
      prompts.insert(0, 'Something my circle would save');
    }

    if (_locationListManager.currentPosition != null) {
      prompts.add('Best coffee near me');
    }

    return prompts.toSet().toList();
  }

  @override
  String? buildInlineCompletion({
    required String query,
    required List<String> recentQueries,
    required List<String> personalPrompts,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final candidates = [
      ...recentQueries,
      ...personalPrompts,
      ..._locationListManager.popularLocations.map((location) => location.name),
      ..._locationListManager.hiddenGemLocations
          .map((location) => location.name),
    ];

    final normalizedQuery = trimmed.toLowerCase();
    final prefixMatches = candidates.where((candidate) {
      final normalized = candidate.toLowerCase();
      return normalized.startsWith(normalizedQuery) &&
          normalized != normalizedQuery;
    }).toList()
      ..sort((left, right) => left.length.compareTo(right.length));

    if (prefixMatches.isNotEmpty) {
      return prefixMatches.first;
    }

    final containsMatches = candidates.where((candidate) {
      final normalized = candidate.toLowerCase();
      return normalized.contains(normalizedQuery) &&
          normalized != normalizedQuery;
    }).toList();

    return containsMatches.isEmpty ? null : containsMatches.first;
  }

  @override
  Future<List<SearchSuggestionItem>> loadQuickSuggestions({
    required String query,
    required List<String> recentQueries,
    required List<String> personalPrompts,
  }) async {
    if (query.trim().isEmpty) {
      return [
        ...recentQueries.take(4).map(SearchSuggestionItem.recentQuery),
        ...personalPrompts.take(4).map(SearchSuggestionItem.personalPrompt),
      ];
    }

    final normalized = query.trim().toLowerCase();
    final filteredRecents = recentQueries
        .where((value) => value.toLowerCase().contains(normalized))
        .take(3)
        .map(SearchSuggestionItem.recentQuery);

    final filteredPrompts = personalPrompts
        .where((value) => value.toLowerCase().contains(normalized))
        .take(3)
        .map(SearchSuggestionItem.personalPrompt);

    return [...filteredRecents, ...filteredPrompts];
  }

  @override
  Stream<List<SearchSuggestionItem>> searchGooglePlaces({
    required String query,
  }) async* {
    const limit = 10;
    final proximity = _locationListManager.currentPosition;
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      yield const [];
      return;
    }

    final locations = await _googlePlacesService.searchPlaces(
      query: trimmed,
      latitude: proximity?.latitude,
      longitude: proximity?.longitude,
    );

    final googleLocations = locations.take(limit).toList(growable: false);
    if (googleLocations.isEmpty) {
      yield const [];
      return;
    }

    final placeIds = _googlePlaceIds(googleLocations);
    final persistedLocationsFuture = placeIds.isEmpty
        ? Future<List<LocationModel>>.value(const [])
        : _persistedPlaceLookup(placeIds);

    yield googleLocations.map(SearchSuggestionItem.place).toList();

    final persistedLocations = await persistedLocationsFuture;
    if (persistedLocations.isEmpty) {
      return;
    }

    final resolvedLocations = reconcileGooglePlacesWithPersistedLocations(
      googleLocations: googleLocations,
      persistedLocations: persistedLocations,
    );

    yield resolvedLocations.map(SearchSuggestionItem.place).toList();
  }

  @override
  Future<LatLng?> currentProximity() => _currentLocation();

  Future<LatLng?> _currentLocation() async {
    return _locationListManager.currentPosition ??
        await _locationListManager.getCurrentLocation();
  }
}

List<LocationModel> reconcileGooglePlacesWithPersistedLocations({
  required List<LocationModel> googleLocations,
  required List<LocationModel> persistedLocations,
}) {
  final persistedByPlaceId = <String, LocationModel>{};
  for (final location in persistedLocations) {
    final placeId = location.googlePlaceId?.trim();
    if (placeId == null || placeId.isEmpty) continue;
    persistedByPlaceId.putIfAbsent(placeId, () => location);
  }

  return [
    for (final googleLocation in googleLocations)
      _mergeSearchLocation(
        googleLocation: googleLocation,
        persistedLocation:
            persistedByPlaceId[googleLocation.googlePlaceId?.trim()],
      ),
  ];
}

LocationModel _mergeSearchLocation({
  required LocationModel googleLocation,
  required LocationModel? persistedLocation,
}) {
  if (persistedLocation == null) {
    return googleLocation;
  }

  return persistedLocation.copyWith(
    imageUrl: persistedLocation.imageUrl ?? googleLocation.imageUrl,
    photoReference:
        persistedLocation.photoReference ?? googleLocation.photoReference,
  );
}

List<String> _googlePlaceIds(List<LocationModel> locations) {
  final placeIds = <String>{};
  for (final location in locations) {
    final placeId = location.googlePlaceId?.trim();
    if (placeId != null && placeId.isNotEmpty) {
      placeIds.add(placeId);
    }
  }
  return placeIds.toList(growable: false);
}

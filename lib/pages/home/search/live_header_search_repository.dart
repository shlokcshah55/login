import 'package:login/models/locations.dart';
import 'package:login/pages/home/search/header_search_recent_store.dart';
import 'package:login/pages/home/search/header_search_repository.dart';
import 'package:login/pages/home/search/header_search_types.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/supabase/service.dart';
import 'package:login/utils/geo_types.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveHeaderSearchRepository implements HeaderSearchRepository {
  static const int _searchCacheMaxEntries = 32;
  static const Duration _searchCacheTtl = Duration(minutes: 2);

  final LocationListManager _locationListManager;
  final UserDataProvider _userDataProvider;
  final SupabaseService _supabaseService;
  final HeaderSearchRecentStore _recentStore;

  // Keyed by normalised query + rounded proximity bucket. LinkedHashMap so
  // we can evict the oldest entry when we exceed the cap.
  final Map<String, _CachedSearchResult> _searchCache =
      <String, _CachedSearchResult>{};

  LiveHeaderSearchRepository({
    required LocationListManager locationListManager,
    required UserDataProvider userDataProvider,
    required SupabaseService supabaseService,
    HeaderSearchRecentStore? recentStore,
  })  : _locationListManager = locationListManager,
        _userDataProvider = userDataProvider,
        _supabaseService = supabaseService,
        _recentStore = recentStore ?? HeaderSearchRecentStore();

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
  Stream<List<SearchSuggestionItem>> loadDatabasePlaces({
    required String query,
  }) async* {
    const limit = 10;
    final proximity = _locationListManager.currentPosition;
    final normalized = query.trim().toLowerCase();

    if (normalized.isEmpty) {
      final fallback = [
        ..._locationListManager.hiddenGemLocations,
        ..._locationListManager.popularLocations,
      ].take(limit).map(SearchSuggestionItem.place).toList();
      yield fallback;
      return;
    }

    final cacheKey = _searchCacheKey(normalized, limit, proximity);

    final cached = _searchCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      // Touch for LRU ordering.
      _searchCache.remove(cacheKey);
      _searchCache[cacheKey] = cached;
      yield cached.locations.map(SearchSuggestionItem.place).toList();
      return;
    }

    final response = await _fetchRawFromRpc(
      normalizedQuery: normalized,
      limit: limit,
      proximity: proximity,
    );

    if (response.isEmpty) {
      yield const [];
      _storeSearchResult(cacheKey, const []);
      return;
    }

    // Stream suggestions as each location's image URL resolves. Cache-hot
    // rows surface first (Stream.fromFutures emits in completion order),
    // so the list paints incrementally instead of blocking on the slowest
    // item in the batch.
    final accumulator = <LocationModel>[];
    await for (final location
        in _supabaseService.locations.streamLocationsWithImages(response)) {
      accumulator.add(location);
      yield accumulator.map(SearchSuggestionItem.place).toList(growable: false);
    }

    _storeSearchResult(cacheKey, accumulator);
  }

  @override
  Future<LatLng?> currentProximity() => _currentLocation();

  Future<List<dynamic>> _fetchRawFromRpc({
    required String normalizedQuery,
    required int limit,
    required LatLng? proximity,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'search_locations',
        params: {
          'p_query': normalizedQuery,
          'p_limit': limit,
          'p_lat': proximity?.latitude,
          'p_lng': proximity?.longitude,
        },
      );

      if (response is! List) {
        return const [];
      }
      return response;
    } catch (_) {
      return const [];
    }
  }

  String _searchCacheKey(String normalized, int limit, LatLng? proximity) {
    if (proximity == null) {
      return 'q:$normalized|l:$limit|p:none';
    }
    // Round to ~100m so nearby keystrokes still share cache entries.
    final lat = (proximity.latitude * 1000).round() / 1000;
    final lng = (proximity.longitude * 1000).round() / 1000;
    return 'q:$normalized|l:$limit|p:$lat,$lng';
  }

  void _storeSearchResult(String cacheKey, List<LocationModel> results) {
    _searchCache.remove(cacheKey);
    _searchCache[cacheKey] = _CachedSearchResult(
      locations: results,
      cachedAt: DateTime.now(),
    );
    while (_searchCache.length > _searchCacheMaxEntries) {
      _searchCache.remove(_searchCache.keys.first);
    }
  }

  Future<LatLng?> _currentLocation() async {
    return _locationListManager.currentPosition ??
        await _locationListManager.getCurrentLocation();
  }

}

class _CachedSearchResult {
  _CachedSearchResult({required this.locations, required this.cachedAt});

  final List<LocationModel> locations;
  final DateTime cachedAt;

  bool get isExpired =>
      DateTime.now().difference(cachedAt) >
      LiveHeaderSearchRepository._searchCacheTtl;
}

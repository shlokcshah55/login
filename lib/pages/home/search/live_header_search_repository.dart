import 'package:login/models/locations.dart';
import 'package:login/pages/home/search/header_search_recent_store.dart';
import 'package:login/pages/home/search/header_search_repository.dart';
import 'package:login/pages/home/search/header_search_types.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/service.dart';
import 'package:login/utils/geo_types.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveHeaderSearchRepository implements HeaderSearchRepository {
  final LocationListManager _locationListManager;
  final UserDataProvider _userDataProvider;
  final SupabaseService _supabaseService;
  final HeaderSearchRecentStore _recentStore;
  GooglePlacesService? _googlePlacesServiceField;
  GooglePlacesService get _googlePlacesService =>
      _googlePlacesServiceField ??= GooglePlacesService();

  LiveHeaderSearchRepository({
    required LocationListManager locationListManager,
    required UserDataProvider userDataProvider,
    required SupabaseService supabaseService,
    HeaderSearchRecentStore? recentStore,
    GooglePlacesService? googlePlacesService,
  })  : _locationListManager = locationListManager,
        _userDataProvider = userDataProvider,
        _supabaseService = supabaseService,
        _recentStore = recentStore ?? HeaderSearchRecentStore(),
        _googlePlacesServiceField = googlePlacesService;

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
  Future<List<SearchSuggestionItem>> loadDatabasePlaces({
    required String query,
  }) async {
    final locations =
        await _searchPlacesFromDatabase(query: query, limit: 10);
    return locations.map(SearchSuggestionItem.place).toList();
  }

  @override
  Future<List<SearchSuggestionItem>> loadGoogleAutocompleteSuggestions({
    required String query,
    LatLng? proximity,
  }) async {
    if (query.trim().isEmpty) {
      return const [];
    }

    final suggestions = await _googlePlacesService.autocompleteFoodAndDrink(
      query: query,
      origin: proximity,
      limit: 6,
    );

    return suggestions
        .map(
          (suggestion) => SearchSuggestionItem.place(
            _buildGoogleAutocompleteLocation(suggestion),
            isGoogleResult: true,
            distanceMeters: suggestion.distanceMeters,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<LatLng?> currentProximity() => _currentLocation();

  Future<List<LocationModel>> _searchPlacesFromDatabase({
    required String query,
    required int limit,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return [
        ..._locationListManager.hiddenGemLocations,
        ..._locationListManager.popularLocations,
      ].take(limit).toList();
    }

    final searchTerm = _escapeForIlike(trimmed);
    try {
      final response = await Supabase.instance.client
          .from(SupabaseConstants.tableLocations)
          .select()
          .or(
            'name.ilike.%$searchTerm%,'
            'vicinity.ilike.%$searchTerm%,'
            'cuisine.ilike.%$searchTerm%',
          )
          .limit(limit);

      final processed =
          await _supabaseService.locations.processLocationsWithImages(
        response as List,
        userVibeAffinity: _userDataProvider.vibeTagAffinity,
        userDietaryAffinity: _userDataProvider.dietaryRequirementTagAffinity,
      );
      return processed;
    } catch (_) {
      return const [];
    }
  }

  Future<LatLng?> _currentLocation() async {
    return _locationListManager.currentPosition ??
        await _locationListManager.getCurrentLocation();
  }

  LocationModel _buildGoogleAutocompleteLocation(
    GoogleAutocompleteSuggestion suggestion,
  ) {
    final name = (suggestion.mainText?.trim().isNotEmpty ?? false)
        ? suggestion.mainText!.trim()
        : suggestion.text.trim();
    final secondaryText = suggestion.secondaryText?.trim();
    final typeLabel = _displayTypeLabel(suggestion.types);

    return LocationModel(
      locationId: -suggestion.placeId.hashCode.abs(),
      name: name,
      vicinity: secondaryText?.isNotEmpty == true ? secondaryText : null,
      createdAt: DateTime.now(),
      googlePlaceId: suggestion.placeId,
      cuisine: typeLabel,
      types: suggestion.types.join(','),
      preference: LocationPreference.search,
      googleMapsUri:
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(name)}&query_place_id=${suggestion.placeId}',
    );
  }

  String? _displayTypeLabel(List<String> types) {
    if (types.isEmpty) {
      return null;
    }

    const preferredTypes = [
      'restaurant',
      'bar',
      'pub',
      'cafe',
      'night_club',
      'wine_bar',
      'sports_bar',
      'cocktail_bar',
      'bakery',
    ];

    for (final preferred in preferredTypes) {
      if (types.contains(preferred)) {
        return preferred
            .split('_')
            .map((part) => part[0].toUpperCase() + part.substring(1))
            .join(' ');
      }
    }

    final first = types.first;
    return first
        .split('_')
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _escapeForIlike(String value) {
    return value.replaceAll(',', ' ').replaceAll('%', '');
  }
}

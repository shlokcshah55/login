import 'package:login/models/locations.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/home/search/header_search_coordinator.dart';
import 'package:login/pages/home/search/header_search_recent_store.dart';
import 'package:login/pages/home/search/header_search_repository.dart';
import 'package:login/pages/home/search/header_search_types.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/services/natural_language_search_service.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/service.dart';
import 'package:login/utils/geo_types.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveHeaderSearchRepository implements HeaderSearchRepository {
  final LocationListManager _locationListManager;
  final UserDataProvider _userDataProvider;
  final SupabaseService _supabaseService;
  final HeaderSearchRecentStore _recentStore;
  final NaturalLanguageSearchService _naturalLanguageSearchService;
  // Nullable + lazy getter so a new field added during hot reload doesn't
  // null-deref on instances created before the reload.
  GooglePlacesService? _googlePlacesServiceField;
  GooglePlacesService get _googlePlacesService =>
      _googlePlacesServiceField ??= GooglePlacesService();

  List<UserModel>? _suggestedUsersCache;
  Map<String, int?>? _friendInfluenceCache;

  LiveHeaderSearchRepository({
    required LocationListManager locationListManager,
    required UserDataProvider userDataProvider,
    required SupabaseService supabaseService,
    HeaderSearchRecentStore? recentStore,
    NaturalLanguageSearchService? naturalLanguageSearchService,
    GooglePlacesService? googlePlacesService,
  })  : _locationListManager = locationListManager,
        _userDataProvider = userDataProvider,
        _supabaseService = supabaseService,
        _recentStore = recentStore ?? HeaderSearchRecentStore(),
        _naturalLanguageSearchService =
            naturalLanguageSearchService ?? NaturalLanguageSearchService(),
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
  Future<List<SearchSuggestionItem>> loadDatabaseMatches({
    required String query,
    required SearchIntentType intent,
  }) async {
    final placeFuture = _searchPlacesFromDatabase(query: query, limit: 3);
    final peopleFuture = _searchPeople(query: query, limit: 3);

    final placeResults = await placeFuture;
    final peopleResults = await peopleFuture;

    final suggestions = <SearchSuggestionItem>[
      ...placeResults.take(2).map(SearchSuggestionItem.place),
      ...peopleResults.take(2).map((user) {
        final isFollowed =
            (_friendInfluenceCache?[user.supabaseId ?? ''] ?? 0) > 0;
        return SearchSuggestionItem.person(
          user,
          isPersonalized: isFollowed,
        );
      }),
    ];

    return suggestions;
  }

  @override
  Future<Map<SearchSectionType, List<SearchSuggestionItem>>> loadSections({
    required String query,
    required SearchIntentType intent,
  }) async {
    if (query.trim().isEmpty) {
      final suggestedUsers = await _loadSuggestedUsers();
      final placeLocations = [
        ..._locationListManager.hiddenGemLocations,
        ..._locationListManager.popularLocations,
      ].take(10).toList();

      return {
        SearchSectionType.places:
            placeLocations.map(SearchSuggestionItem.place).toList(),
        SearchSectionType.people:
            suggestedUsers.map(SearchSuggestionItem.person).toList(),
      };
    }

    final placeFuture = _searchPlacesFromDatabase(query: query, limit: 10);
    final peopleFuture = _searchPeople(query: query, limit: 10);

    final placeLocations = await placeFuture;
    final people = await peopleFuture;

    return {
      SearchSectionType.places:
          placeLocations.map(SearchSuggestionItem.place).toList(),
      SearchSectionType.people: people
          .map((user) => SearchSuggestionItem.person(
                user,
                isPersonalized:
                    (_friendInfluenceCache?[user.supabaseId ?? ''] ?? 0) > 0,
              ))
          .toList(),
    };
  }

  @override
  Future<List<SearchSuggestionItem>> loadNaturalLanguageSection({
    required String query,
    required SearchIntentType intent,
  }) async {
    final results = await _searchNaturalLanguage(query: query, limit: 10);
    return results.map(SearchSuggestionItem.naturalLanguageResult).toList();
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
      // Search only the short, indexable columns. `editorial_summary` is
      // long-form text and including it in an OR with ilike causes the
      // Postgres planner to fall back to a sequential scan, which trips
      // the statement timeout (57014) on the locations table.
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
    } catch (error) {
      // Statement timeout, network blip, schema issue — degrade to empty
      // so the Google autocomplete stage can still populate the Places row.
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

  Future<List<UserModel>> _searchPeople({
    required String query,
    required int limit,
  }) async {
    try {
      final currentUserId = _supabaseService.users.currentUser?.id;
      final rawResults = query.trim().isEmpty
          ? await _loadSuggestedUsers()
          : await _supabaseService.users.searchUsers(query.trim());
      final users = rawResults
          .where((user) =>
              user.supabaseId != null && user.supabaseId != currentUserId)
          .toList();

      final influence = await _loadFriendInfluence();
      final suggestedIds = (await _loadSuggestedUsers())
          .map((user) => user.supabaseId)
          .whereType<String>()
          .toSet();

      final ranked = HeaderSearchCoordinator.rankPeopleResults(
        query: query,
        users: users,
        followInfluenceByUserId: influence,
        suggestedUserIds: suggestedIds,
      );
      return ranked.take(limit).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<LocationModel>> _searchNaturalLanguage({
    required String query,
    required int limit,
  }) async {
    final userId = _supabaseService.users.currentUser?.id;
    final currentLocation =
        _locationListManager.cameraPosition?.target ?? await _currentLocation();
    if (userId == null || currentLocation == null || query.trim().isEmpty) {
      return const [];
    }

    try {
      return await _naturalLanguageSearchService.search(
        userId: userId,
        query: query,
        currentLocation: currentLocation,
        maxResults: limit,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<List<UserModel>> _loadSuggestedUsers() async {
    if (_suggestedUsersCache != null) {
      return _suggestedUsersCache!;
    }

    final users = await _supabaseService.users.getSuggestedUsers();
    _suggestedUsersCache = users;
    return users;
  }

  Future<Map<String, int?>> _loadFriendInfluence() async {
    if (_friendInfluenceCache != null) {
      return _friendInfluenceCache!;
    }

    final influence = await _supabaseService.users.getAllFriendsInfluence();
    _friendInfluenceCache = influence;
    return influence;
  }

  String _escapeForIlike(String value) {
    return value.replaceAll(',', ' ').replaceAll('%', '');
  }
}

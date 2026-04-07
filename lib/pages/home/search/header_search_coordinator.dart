import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/home/search/header_search_repository.dart';
import 'package:login/pages/home/search/header_search_types.dart';

class HeaderSearchCoordinator extends ChangeNotifier {
  final HeaderSearchRepository _repository;
  final Duration debounceDuration;

  HeaderSearchState _state = HeaderSearchState.initial();
  Timer? _debounce;
  int _requestVersion = 0;

  HeaderSearchCoordinator({
    HeaderSearchRepository? repository,
    this.debounceDuration = const Duration(milliseconds: 180),
  }) : _repository = repository ?? const NoopHeaderSearchRepository();

  HeaderSearchState get state => _state;

  static SearchIntentType detectIntent(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return SearchIntentType.mixed;
    }

    const peopleMarkers = [
      '@',
      'friend',
      'friends',
      'people',
      'person',
      'profile',
      'follow',
      'following',
      'who ',
    ];
    if (peopleMarkers.any(normalized.contains)) {
      return SearchIntentType.people;
    }

    const naturalLanguageMarkers = [
      'somewhere',
      'something',
      'spot with',
      'place with',
      'good for',
      'perfect for',
      'vibe',
      'date',
      'cozy',
      'romantic',
      'group',
      'quiet',
      'fun',
      'cocktails',
      'brunch',
    ];
    final containsNaturalLanguageCue =
        naturalLanguageMarkers.any(normalized.contains);

    const placeMarkers = [
      'near me',
      'pizza',
      'coffee',
      'sushi',
      'restaurant',
      'bar',
      'cafe',
      'pub',
      'ramen',
      'burger',
      'lunch',
      'dinner',
      'breakfast',
    ];
    final containsPlaceCue = placeMarkers.any(normalized.contains);

    if (containsNaturalLanguageCue && !containsPlaceCue) {
      return SearchIntentType.naturalLanguage;
    }

    if (containsPlaceCue) {
      return SearchIntentType.place;
    }

    if (normalized.split(RegExp(r'\s+')).length >= 4 &&
        containsNaturalLanguageCue) {
      return SearchIntentType.naturalLanguage;
    }

    return SearchIntentType.mixed;
  }

  static List<SearchSectionType> sectionOrderForIntent(SearchIntentType intent) {
    switch (intent) {
      case SearchIntentType.place:
      case SearchIntentType.mixed:
        return const [
          SearchSectionType.places,
          SearchSectionType.naturalLanguage,
          SearchSectionType.people,
        ];
      case SearchIntentType.naturalLanguage:
        return const [
          SearchSectionType.naturalLanguage,
          SearchSectionType.places,
          SearchSectionType.people,
        ];
      case SearchIntentType.people:
        return const [
          SearchSectionType.people,
          SearchSectionType.places,
          SearchSectionType.naturalLanguage,
        ];
    }
  }

  static List<LocationModel> mergePlaceResults({
    required List<LocationModel> databaseResults,
    required List<LocationModel> mapboxFallbackResults,
  }) {
    final seenKeys = <String>{};
    final merged = <LocationModel>[];

    void appendAll(List<LocationModel> values) {
      for (final location in values) {
        final key = _locationDeduplicationKey(location);
        if (seenKeys.add(key)) {
          merged.add(location);
        }
      }
    }

    appendAll(databaseResults);
    appendAll(mapboxFallbackResults);
    return merged;
  }

  static List<UserModel> rankPeopleResults({
    required String query,
    required List<UserModel> users,
    required Map<String, int?> followInfluenceByUserId,
    required Set<String> suggestedUserIds,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final ranked = [...users];
    ranked.sort((left, right) {
      final leftScore = _peopleScore(
        user: left,
        normalizedQuery: normalizedQuery,
        followInfluenceByUserId: followInfluenceByUserId,
        suggestedUserIds: suggestedUserIds,
      );
      final rightScore = _peopleScore(
        user: right,
        normalizedQuery: normalizedQuery,
        followInfluenceByUserId: followInfluenceByUserId,
        suggestedUserIds: suggestedUserIds,
      );
      return rightScore.compareTo(leftScore);
    });
    return ranked;
  }

  Future<void> open() async {
    if (!_state.isActive) {
      _state = _state.copyWith(isActive: true);
      notifyListeners();
    }

    final requestVersion = ++_requestVersion;
    final recentQueries = await _repository.loadRecentQueries();
    if (!_isLatestRequest(requestVersion)) {
      return;
    }

    _state = _state.copyWith(recentQueries: recentQueries);
    notifyListeners();

    await _loadSearchState(
      query: '',
      requestVersion: requestVersion,
      isEmptyState: true,
    );
  }

  void close() {
    _debounce?.cancel();
    _requestVersion++;
    _state = _state.copyWith(
      isActive: false,
      isPreviewingMap: false,
      query: '',
      clearPreviewedLocation: true,
      result: HeaderSearchResultModel.initial(),
    );
    notifyListeners();
  }

  void updateQuery(String query, {Duration? debounce}) {
    _state = _state.copyWith(query: query);
    _debounce?.cancel();
    final requestVersion = ++_requestVersion;
    final effectiveDebounce = debounce ?? debounceDuration;
    _debounce = Timer(effectiveDebounce, () {
      unawaited(
        _loadSearchState(
          query: query,
          requestVersion: requestVersion,
          isEmptyState: query.trim().isEmpty,
        ),
      );
    });
    notifyListeners();
  }

  void beginPreview(LocationModel location) {
    _state = _state.copyWith(
      isPreviewingMap: true,
      previewedLocation: location,
    );
    notifyListeners();
  }

  void endPreview() {
    if (!_state.isPreviewingMap && _state.previewedLocation == null) {
      return;
    }
    _state = _state.copyWith(
      isPreviewingMap: false,
      clearPreviewedLocation: true,
    );
    notifyListeners();
  }

  Future<void> rememberQuery(String query) async {
    final recentQueries = await _repository.loadRecentQueries();
    await _repository.saveRecentQuery(query);
    final refreshed = await _repository.loadRecentQueries();
    _state = _state.copyWith(
      recentQueries: refreshed.isNotEmpty ? refreshed : recentQueries,
    );
    notifyListeners();
  }

  Future<void> _loadSearchState({
    required String query,
    required int requestVersion,
    required bool isEmptyState,
  }) async {
    final intent = isEmptyState ? SearchIntentType.mixed : detectIntent(query);
    final personalPrompts = _repository.buildPersonalPrompts();
    final inlineCompletion = isEmptyState
        ? null
        : _repository.buildInlineCompletion(
            query: query,
            recentQueries: _state.recentQueries,
            personalPrompts: personalPrompts,
          );

    _state = _state.copyWith(
      query: query,
      result: HeaderSearchResultModel(
        intent: intent,
        query: query,
        inlineCompletion: inlineCompletion,
        quickSuggestions: const [],
        databaseMatches: const [],
        sections: _emptySectionsForIntent(intent),
        completedStages: {WaterfallStage.inlineCompletion},
        isSearching: true,
      ),
    );
    notifyListeners();

    unawaited(
      _runQuickSuggestionsStage(
        query: query,
        requestVersion: requestVersion,
        personalPrompts: personalPrompts,
      ),
    );
    unawaited(
      _runDatabaseMatchesStage(
        query: query,
        requestVersion: requestVersion,
        intent: intent,
      ),
    );
    unawaited(
      _runSectionsStage(
        query: query,
        requestVersion: requestVersion,
        intent: intent,
      ),
    );
  }

  Future<void> _runQuickSuggestionsStage({
    required String query,
    required int requestVersion,
    required List<String> personalPrompts,
  }) async {
    final suggestions = await _repository.loadQuickSuggestions(
      query: query,
      recentQueries: _state.recentQueries,
      personalPrompts: personalPrompts,
    );
    if (!_isLatestRequest(requestVersion)) {
      return;
    }

    _state = _state.copyWith(
      result: _state.result.copyWith(
        quickSuggestions: suggestions,
        completedStages: {
          ..._state.result.completedStages,
          WaterfallStage.personalSuggestions,
        },
      ),
    );
    notifyListeners();
  }

  Future<void> _runDatabaseMatchesStage({
    required String query,
    required int requestVersion,
    required SearchIntentType intent,
  }) async {
    final matches = await _repository.loadDatabaseMatches(
      query: query,
      intent: intent,
    );
    if (!_isLatestRequest(requestVersion)) {
      return;
    }

    _state = _state.copyWith(
      result: _state.result.copyWith(
        databaseMatches: matches,
        completedStages: {
          ..._state.result.completedStages,
          WaterfallStage.databaseMatches,
        },
      ),
    );
    notifyListeners();
  }

  Future<void> _runSectionsStage({
    required String query,
    required int requestVersion,
    required SearchIntentType intent,
  }) async {
    try {
      final sectionsByType = await _repository.loadSections(
        query: query,
        intent: intent,
      );
      if (!_isLatestRequest(requestVersion)) {
        return;
      }

      final sections = _orderedSections(
        intent: intent,
        sectionsByType: sectionsByType,
      );

      _state = _state.copyWith(
        result: _state.result.copyWith(
          sections: sections,
          completedStages: {
            ..._state.result.completedStages,
            WaterfallStage.fullResults,
          },
          isSearching: false,
        ),
      );
      notifyListeners();

      if (_shouldLoadMapboxFallback(intent: intent, sections: sections)) {
        await _runMapboxFallbackStage(
          query: query,
          requestVersion: requestVersion,
          intent: intent,
        );
      }
    } catch (_) {
      if (!_isLatestRequest(requestVersion)) {
        return;
      }
      _state = _state.copyWith(
        result: _state.result.copyWith(
          isSearching: false,
          errorMessage: 'Search is temporarily unavailable.',
        ),
      );
      notifyListeners();
    }
  }

  Future<void> _runMapboxFallbackStage({
    required String query,
    required int requestVersion,
    required SearchIntentType intent,
  }) async {
    final fallbackItems = await _repository.loadMapboxFallback(
      query: query,
      intent: intent,
    );
    if (!_isLatestRequest(requestVersion) || fallbackItems.isEmpty) {
      return;
    }

    final sections = _state.result.sections.map((section) {
      if (section.type != SearchSectionType.places) {
        return section;
      }
      final merged = _mergeSuggestionLists(
        primary: section.items,
        secondary: fallbackItems,
      );
      return section.copyWith(items: merged);
    }).toList();

    _state = _state.copyWith(
      result: _state.result.copyWith(
        sections: sections,
        completedStages: {
          ..._state.result.completedStages,
          WaterfallStage.mapboxFallback,
        },
      ),
    );
    notifyListeners();
  }

  bool _isLatestRequest(int requestVersion) => requestVersion == _requestVersion;

  static List<HeaderSearchSectionModel> _emptySectionsForIntent(
    SearchIntentType intent,
  ) {
    return sectionOrderForIntent(intent).map((type) {
      return HeaderSearchSectionModel(
        type: type,
        title: _titleForSection(type),
        items: const [],
        isLoading: true,
      );
    }).toList();
  }

  static List<HeaderSearchSectionModel> _orderedSections({
    required SearchIntentType intent,
    required Map<SearchSectionType, List<SearchSuggestionItem>> sectionsByType,
  }) {
    return sectionOrderForIntent(intent).map((type) {
      return HeaderSearchSectionModel(
        type: type,
        title: _titleForSection(type),
        items: sectionsByType[type] ?? const [],
        isLoading: false,
      );
    }).toList();
  }

  static String _titleForSection(SearchSectionType type) {
    switch (type) {
      case SearchSectionType.places:
        return 'Places';
      case SearchSectionType.naturalLanguage:
        return 'Recommended';
      case SearchSectionType.people:
        return 'People';
    }
  }

  static bool _shouldLoadMapboxFallback({
    required SearchIntentType intent,
    required List<HeaderSearchSectionModel> sections,
  }) {
    if (intent != SearchIntentType.place && intent != SearchIntentType.mixed) {
      return false;
    }

    final placesSection = sections.firstWhere(
      (section) => section.type == SearchSectionType.places,
      orElse: () => const HeaderSearchSectionModel(
        type: SearchSectionType.places,
        title: 'Places',
      ),
    );
    return placesSection.items.length < 3;
  }

  static List<SearchSuggestionItem> _mergeSuggestionLists({
    required List<SearchSuggestionItem> primary,
    required List<SearchSuggestionItem> secondary,
  }) {
    final seen = <String>{};
    final merged = <SearchSuggestionItem>[];

    for (final item in [...primary, ...secondary]) {
      final key = item.location != null
          ? _locationDeduplicationKey(item.location!)
          : item.id;
      if (seen.add(key)) {
        merged.add(item);
      }
    }
    return merged;
  }

  static int _peopleScore({
    required UserModel user,
    required String normalizedQuery,
    required Map<String, int?> followInfluenceByUserId,
    required Set<String> suggestedUserIds,
  }) {
    final name = user.name?.toLowerCase() ?? '';
    final username = user.username?.toLowerCase() ?? '';
    final email = user.email.toLowerCase();
    final userId = user.supabaseId ?? user.email;

    var score = 0;

    if (normalizedQuery.isNotEmpty) {
      if (name == normalizedQuery || username == normalizedQuery) {
        score += 400;
      } else if (name.startsWith(normalizedQuery) ||
          username.startsWith(normalizedQuery)) {
        score += 250;
      } else if (name.contains(normalizedQuery) ||
          username.contains(normalizedQuery) ||
          email.contains(normalizedQuery)) {
        score += 150;
      }
    }

    final followInfluence = followInfluenceByUserId[userId] ?? 0;
    score += followInfluence * 20;

    if (suggestedUserIds.contains(userId)) {
      score += 500;
    }

    score += user.followersCount;
    return score;
  }

  static String _locationDeduplicationKey(LocationModel location) {
    final placeId = location.googlePlaceId?.trim();
    if (placeId != null && placeId.isNotEmpty) {
      return 'place:$placeId';
    }

    final normalizedName = location.name.trim().toLowerCase();
    final normalizedVicinity = (location.vicinity ?? '').trim().toLowerCase();
    return 'name:$normalizedName|vicinity:$normalizedVicinity';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

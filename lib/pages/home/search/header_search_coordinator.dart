import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/home/search/header_search_repository.dart';
import 'package:login/pages/home/search/header_search_types.dart';
import 'package:login/services/mapbox_search_box_service.dart';

class HeaderSearchCoordinator extends ChangeNotifier {
  static const int _minMapboxQueryLength = 2;

  /// Friendly status messages cycled into the Recommended section while
  /// the magic-search endpoint is in flight.
  static const List<String> magicLoadingMessages = [
    'Asking the magic search…',
    'Reading between the lines…',
    'Finding spots that match your vibe…',
    'Brewing recommendations…',
  ];

  final HeaderSearchRepository _repository;
  final Duration debounceDuration;

  HeaderSearchState _state = HeaderSearchState.initial();
  Timer? _debounce;
  int _requestVersion = 0;
  int _magicMessageCursor = 0;
  String? _mapboxSessionToken;

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

    final words = normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final wordCount = words.length;

    const naturalLanguageStarters = [
      'where',
      'what',
      'which',
      'how',
      'find',
      'show',
      'recommend',
      'suggest',
      'looking',
      'tell',
      'help',
      'i want',
      'i need',
      'i feel',
      'we want',
      'we need',
      'can i',
      'can we',
      'should i',
      'should we',
      'take me',
      'take us',
    ];
    final startsLikeAQuestion = naturalLanguageStarters.any(
      (starter) =>
          normalized == starter || normalized.startsWith('$starter '),
    );
    final hasQuestionMark = normalized.contains('?');

    const naturalLanguageMarkers = [
      'somewhere',
      'something',
      'spot with',
      'spot for',
      'place with',
      'place for',
      'good for',
      'perfect for',
      'best for',
      'vibe',
      'vibes',
      'cozy',
      'romantic',
      'quiet',
      'lively',
      'chill',
      'relaxed',
      'aesthetic',
      'mood',
      'date night',
      'first date',
      'hidden gem',
      'feels like',
      'tonight',
      'this weekend',
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
      'brunch',
      'tacos',
      'thai',
      'indian',
      'chinese',
      'mexican',
      'italian',
      'japanese',
      'french',
      'korean',
      'vegan',
      'vegetarian',
      'bakery',
      'dessert',
      'wine bar',
      'cocktail bar',
    ];
    final containsPlaceCue = placeMarkers.any(normalized.contains);

    if (startsLikeAQuestion || hasQuestionMark) {
      return SearchIntentType.naturalLanguage;
    }
    if (wordCount >= 6) {
      return SearchIntentType.naturalLanguage;
    }
    if (wordCount >= 4 && containsNaturalLanguageCue) {
      return SearchIntentType.naturalLanguage;
    }
    if (containsNaturalLanguageCue && !containsPlaceCue) {
      return SearchIntentType.naturalLanguage;
    }
    if (containsPlaceCue) {
      return SearchIntentType.place;
    }
    if (wordCount <= 2) {
      return SearchIntentType.place;
    }

    return SearchIntentType.mixed;
  }

  static List<SearchSectionType> sectionOrderForIntent(SearchIntentType intent) {
    switch (intent) {
      case SearchIntentType.place:
        return const [
          SearchSectionType.places,
          SearchSectionType.people,
        ];
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
        ];
    }
  }

  /// Whether the LLM-backed natural-language stage should run for [intent].
  static bool shouldRunNaturalLanguageStage(SearchIntentType intent) {
    return intent == SearchIntentType.naturalLanguage ||
        intent == SearchIntentType.mixed;
  }

  /// Whether the Mapbox `/suggest` stage should run for [intent].
  static bool shouldRunMapboxStage(SearchIntentType intent) {
    return intent == SearchIntentType.place ||
        intent == SearchIntentType.mixed;
  }

  static List<LocationModel> mergePlaceResults({
    required List<LocationModel> databaseResults,
    required List<LocationModel> mapboxResults,
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
    appendAll(mapboxResults);
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
    _mapboxSessionToken ??= MapboxSearchBoxService.newSessionToken();

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
    _mapboxSessionToken = null;
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
    unawaited(
      _runMapboxLiveStage(
        query: query,
        requestVersion: requestVersion,
        intent: intent,
      ),
    );
    unawaited(
      _runNaturalLanguageStage(
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
    List<SearchSuggestionItem> suggestions;
    try {
      suggestions = await _repository.loadQuickSuggestions(
        query: query,
        recentQueries: _state.recentQueries,
        personalPrompts: personalPrompts,
      );
    } catch (_) {
      suggestions = const [];
    }
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
    List<SearchSuggestionItem> matches;
    try {
      matches = await _repository.loadDatabaseMatches(
        query: query,
        intent: intent,
      );
    } catch (_) {
      matches = const [];
    }
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

      // Only update sections that this stage actually loaded. The
      // natural-language section is filled by _runNaturalLanguageStage in
      // parallel and must keep its current loading state until that stage
      // resolves — otherwise we'd clobber the magic-search shimmer.
      final updatedSections = _state.result.sections.map((section) {
        if (!sectionsByType.containsKey(section.type)) {
          return section;
        }
        return section.copyWith(
          items: sectionsByType[section.type] ?? const [],
          isLoading: false,
          clearLoadingMessage: true,
        );
      }).toList();

      _state = _state.copyWith(
        result: _state.result.copyWith(
          sections: updatedSections,
          completedStages: {
            ..._state.result.completedStages,
            WaterfallStage.fullResults,
          },
          isSearching: false,
        ),
      );
      notifyListeners();
    } catch (_) {
      if (!_isLatestRequest(requestVersion)) {
        return;
      }
      // Drop the loading state on every section so any results that
      // arrive afterwards (e.g. from the parallel Mapbox live stage)
      // render through the carousel instead of being hidden by the
      // shimmer placeholder.
      final clearedSections = _state.result.sections
          .map((section) => section.copyWith(isLoading: false))
          .toList();
      _state = _state.copyWith(
        result: _state.result.copyWith(
          sections: clearedSections,
          isSearching: false,
          errorMessage: 'Search is temporarily unavailable.',
        ),
      );
      notifyListeners();
    }
  }

  Future<void> _runMapboxLiveStage({
    required String query,
    required int requestVersion,
    required SearchIntentType intent,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < _minMapboxQueryLength) return;
    // Skip Mapbox for clearly conversational queries — magic search will
    // handle those — and for people-only queries.
    if (!shouldRunMapboxStage(intent)) return;

    final sessionToken =
        _mapboxSessionToken ??= MapboxSearchBoxService.newSessionToken();

    List<SearchSuggestionItem> liveItems;
    try {
      final proximity = await _repository.currentProximity();
      if (!_isLatestRequest(requestVersion)) return;
      liveItems = await _repository.loadMapboxLiveSuggestions(
        query: query,
        sessionToken: sessionToken,
        proximity: proximity,
      );
    } catch (_) {
      liveItems = const [];
    }
    if (!_isLatestRequest(requestVersion) || liveItems.isEmpty) {
      return;
    }

    // Clear isLoading on the Places section when merging — the section
    // stage may still be in flight (or may have failed), and the UI hides
    // items behind a shimmer while isLoading is true.
    final sections = _state.result.sections.map((section) {
      if (section.type != SearchSectionType.places) {
        return section;
      }
      final merged = _mergeSuggestionLists(
        primary: section.items,
        secondary: liveItems,
      );
      return section.copyWith(items: merged, isLoading: false);
    }).toList();

    _state = _state.copyWith(
      result: _state.result.copyWith(
        sections: sections,
        completedStages: {
          ..._state.result.completedStages,
          WaterfallStage.mapboxLiveResults,
        },
      ),
    );
    notifyListeners();
  }

  /// Resolves a tapped Mapbox suggestion stub to a [LocationModel] with
  /// coordinates by calling Mapbox's `/retrieve` endpoint. Rotates the
  /// session token afterwards because Mapbox sessions end on retrieve.
  Future<LocationModel?> resolveMapboxSelection(
    SearchSuggestionItem item,
  ) async {
    final mapboxId = item.mapboxId;
    if (mapboxId == null) return null;
    final sessionToken =
        _mapboxSessionToken ??= MapboxSearchBoxService.newSessionToken();

    final resolved = await _repository.resolveMapboxSuggestion(
      mapboxId: mapboxId,
      sessionToken: sessionToken,
    );

    // Mapbox sessions end after a /retrieve call — rotate so the next
    // /suggest starts a fresh session.
    _mapboxSessionToken = MapboxSearchBoxService.newSessionToken();
    return resolved;
  }

  Future<void> _runNaturalLanguageStage({
    required String query,
    required int requestVersion,
    required SearchIntentType intent,
  }) async {
    if (query.trim().isEmpty) return;
    if (!shouldRunNaturalLanguageStage(intent)) return;
    // Bail if the section isn't even rendered for this intent.
    final hasNaturalSection = _state.result.sections
        .any((section) => section.type == SearchSectionType.naturalLanguage);
    if (!hasNaturalSection) return;

    List<SearchSuggestionItem> items;
    try {
      items = await _repository.loadNaturalLanguageSection(
        query: query,
        intent: intent,
      );
    } catch (_) {
      items = const [];
    }
    if (!_isLatestRequest(requestVersion)) return;

    final updated = _state.result.sections.map((section) {
      if (section.type != SearchSectionType.naturalLanguage) return section;
      return section.copyWith(
        items: items,
        isLoading: false,
        clearLoadingMessage: true,
      );
    }).toList();

    _state = _state.copyWith(
      result: _state.result.copyWith(
        sections: updated,
        completedStages: {
          ..._state.result.completedStages,
          WaterfallStage.naturalLanguage,
        },
      ),
    );
    notifyListeners();
  }

  bool _isLatestRequest(int requestVersion) => requestVersion == _requestVersion;

  String _nextMagicLoadingMessage() {
    final message =
        magicLoadingMessages[_magicMessageCursor % magicLoadingMessages.length];
    _magicMessageCursor++;
    return message;
  }

  List<HeaderSearchSectionModel> _emptySectionsForIntent(
    SearchIntentType intent,
  ) {
    final showMagicMessage = shouldRunNaturalLanguageStage(intent);
    return sectionOrderForIntent(intent).map((type) {
      final isMagicSection = type == SearchSectionType.naturalLanguage;
      return HeaderSearchSectionModel(
        type: type,
        title: _titleForSection(type),
        items: const [],
        isLoading: true,
        loadingMessage: isMagicSection && showMagicMessage
            ? _nextMagicLoadingMessage()
            : null,
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

  static List<SearchSuggestionItem> _mergeSuggestionLists({
    required List<SearchSuggestionItem> primary,
    required List<SearchSuggestionItem> secondary,
  }) {
    final seen = <String>{};
    final merged = <SearchSuggestionItem>[];

    for (final item in [...primary, ...secondary]) {
      final key = item.location != null
          ? _locationDeduplicationKey(item.location!)
          : (item.mapboxId != null ? 'mapbox:${item.mapboxId}' : item.id);
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

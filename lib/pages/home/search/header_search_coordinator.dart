import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/search/header_search_repository.dart';
import 'package:login/pages/home/search/header_search_types.dart';

class HeaderSearchCoordinator extends ChangeNotifier {
  static const int _minGoogleAutocompleteQueryLength = 2;

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

  Future<void> open() async {
    if (!_state.isActive) {
      _state = _state.copyWith(isActive: true);
      notifyListeners();
    }

    final requestVersion = ++_requestVersion;
    final recentQueries = await _repository.loadRecentQueries();
    if (!_isLatestRequest(requestVersion)) return;

    _state = _state.copyWith(recentQueries: recentQueries);
    notifyListeners();

    await _loadSearchState(
      query: '',
      requestVersion: requestVersion,
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
    if (!_state.isPreviewingMap && _state.previewedLocation == null) return;
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
  }) async {
    final personalPrompts = _repository.buildPersonalPrompts();
    final inlineCompletion = query.trim().isEmpty
        ? null
        : _repository.buildInlineCompletion(
            query: query,
            recentQueries: _state.recentQueries,
            personalPrompts: personalPrompts,
          );

    _state = _state.copyWith(
      query: query,
      result: HeaderSearchResultModel(
        query: query,
        inlineCompletion: inlineCompletion,
        quickSuggestions: _state.result.quickSuggestions,
        placeItems: const [],
        isLoading: true,
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
      _runPlacesStage(
        query: query,
        requestVersion: requestVersion,
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
    if (!_isLatestRequest(requestVersion)) return;

    _state = _state.copyWith(
      result: _state.result.copyWith(quickSuggestions: suggestions),
    );
    notifyListeners();
  }

  /// Runs the Supabase and Google Places lookups in parallel and publishes
  /// them in a single batch — DB results first, Google results appended
  /// below — so the list renders all items at once with no jolts.
  Future<void> _runPlacesStage({
    required String query,
    required int requestVersion,
  }) async {
    final trimmed = query.trim();
    final runGoogle = trimmed.length >= _minGoogleAutocompleteQueryLength;

    final dbFuture = _safeLoadDatabasePlaces(query);
    Future<List<SearchSuggestionItem>> googleFuture;
    if (runGoogle) {
      googleFuture = _safeLoadGooglePlaces(query);
    } else {
      googleFuture = Future.value(const <SearchSuggestionItem>[]);
    }

    final results = await Future.wait([dbFuture, googleFuture]);
    if (!_isLatestRequest(requestVersion)) return;

    final merged = _mergeSuggestionLists(
      primary: results[0],
      secondary: results[1],
    );

    _state = _state.copyWith(
      result: _state.result.copyWith(
        placeItems: merged,
        isLoading: false,
        clearErrorMessage: true,
      ),
    );
    notifyListeners();
  }

  Future<List<SearchSuggestionItem>> _safeLoadDatabasePlaces(
    String query,
  ) async {
    try {
      return await _repository.loadDatabasePlaces(query: query);
    } catch (_) {
      return const [];
    }
  }

  Future<List<SearchSuggestionItem>> _safeLoadGooglePlaces(String query) async {
    try {
      final proximity = await _repository.currentProximity();
      return await _repository.loadGoogleAutocompleteSuggestions(
        query: query,
        proximity: proximity,
      );
    } catch (_) {
      return const [];
    }
  }

  bool _isLatestRequest(int requestVersion) =>
      requestVersion == _requestVersion;

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

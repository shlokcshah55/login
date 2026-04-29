import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/search/header_search_repository.dart';
import 'package:login/pages/home/search/header_search_types.dart';

class HeaderSearchCoordinator extends ChangeNotifier {
  final HeaderSearchRepository _repository;
  final Duration debounceDuration;

  HeaderSearchState _state = HeaderSearchState.initial();
  Timer? _debounce;
  int _requestVersion = 0;
  StreamSubscription<List<SearchSuggestionItem>>? _placesSubscription;
  String? _lastPlacesQuery;

  HeaderSearchCoordinator({
    HeaderSearchRepository? repository,
    this.debounceDuration = const Duration(milliseconds: 100),
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
      runPlacesStage: false,
    );
  }

  void close() {
    _debounce?.cancel();
    _placesSubscription?.cancel();
    _placesSubscription = null;
    _lastPlacesQuery = null;
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
    _placesSubscription?.cancel();
    _placesSubscription = null;
    final requestVersion = ++_requestVersion;
    final effectiveDebounce = debounce ?? debounceDuration;
    _debounce = Timer(effectiveDebounce, () {
      unawaited(
        _loadSearchState(
          query: query,
          requestVersion: requestVersion,
          runPlacesStage: query.trim().isNotEmpty,
        ),
      );
    });
    notifyListeners();
  }

  Future<void> submitQuery() async {
    final query = _state.query.trim();
    if (query.isEmpty) return;

    _debounce?.cancel();
    await rememberQuery(query);

    if (_lastPlacesQuery == query) {
      return;
    }

    final requestVersion = ++_requestVersion;
    await _loadSearchState(
      query: query,
      requestVersion: requestVersion,
      runPlacesStage: true,
    );
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
    required bool runPlacesStage,
  }) async {
    final personalPrompts = _repository.buildPersonalPrompts();
    _state = _state.copyWith(
      query: query,
      result: HeaderSearchResultModel(
        query: query,
        inlineCompletion: null,
        quickSuggestions: _state.result.quickSuggestions,
        placeItems: const [],
        isLoading: runPlacesStage,
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
    if (runPlacesStage) {
      _runPlacesStage(
        query: query,
        requestVersion: requestVersion,
      );
    }
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

  void _runPlacesStage({
    required String query,
    required int requestVersion,
  }) {
    // Cancel any prior in-flight places stream. A new query version
    // supersedes the old one — we don't want late emissions from a stale
    // search overwriting fresh results.
    _placesSubscription?.cancel();
    _lastPlacesQuery = query;
    _placesSubscription = _repository.searchGooglePlaces(query: query).listen(
      (items) {
        if (!_isLatestRequest(requestVersion)) return;

        _state = _state.copyWith(
          result: _state.result.copyWith(
            placeItems: dedupePlaceSuggestions(items),
            // Keep `isLoading` true while the stream is still emitting;
            // the final `onDone` handler flips it off. This preserves the
            // skeleton state only for the tail end of the batch.
            clearErrorMessage: true,
          ),
        );
        notifyListeners();
      },
      onError: (_) {
        if (!_isLatestRequest(requestVersion)) return;
        _state = _state.copyWith(
          result: _state.result.copyWith(
            placeItems: const [],
            isLoading: false,
          ),
        );
        notifyListeners();
      },
      onDone: () {
        if (!_isLatestRequest(requestVersion)) return;
        _state = _state.copyWith(
          result: _state.result.copyWith(isLoading: false),
        );
        notifyListeners();
      },
      cancelOnError: true,
    );
  }

  bool _isLatestRequest(int requestVersion) =>
      requestVersion == _requestVersion;

  static List<SearchSuggestionItem> dedupePlaceSuggestions(
    List<SearchSuggestionItem> items,
  ) {
    final seen = <String>{};
    final merged = <SearchSuggestionItem>[];

    for (final item in items) {
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
    _placesSubscription?.cancel();
    super.dispose();
  }
}

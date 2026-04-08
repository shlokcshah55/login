import 'package:flutter/foundation.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/users.dart';
import 'package:login/services/mapbox_search_box_service.dart';

enum SearchIntentType {
  place,
  naturalLanguage,
  people,
  mixed,
}

enum SearchSectionType {
  places,
  naturalLanguage,
  people,
}

enum WaterfallStage {
  inlineCompletion,
  personalSuggestions,
  databaseMatches,
  fullResults,
  mapboxLiveResults,
  naturalLanguage,
}

enum SearchSuggestionKind {
  recentQuery,
  personalPrompt,
  place,
  naturalLanguage,
  person,
}

@immutable
class SearchSuggestionItem {
  final String id;
  final SearchSuggestionKind kind;
  final String title;
  final String? subtitle;
  final String? queryValue;
  final LocationModel? location;
  final UserModel? user;
  final bool isPersonalized;
  final bool isMapboxResult;
  final String? mapboxId;

  const SearchSuggestionItem({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.queryValue,
    this.location,
    this.user,
    this.isPersonalized = false,
    this.isMapboxResult = false,
    this.mapboxId,
  });

  factory SearchSuggestionItem.recentQuery(String query) {
    return SearchSuggestionItem(
      id: 'recent:$query',
      kind: SearchSuggestionKind.recentQuery,
      title: query,
      queryValue: query,
    );
  }

  factory SearchSuggestionItem.personalPrompt(String prompt) {
    return SearchSuggestionItem(
      id: 'prompt:$prompt',
      kind: SearchSuggestionKind.personalPrompt,
      title: prompt,
      queryValue: prompt,
      isPersonalized: true,
    );
  }

  factory SearchSuggestionItem.place(
    LocationModel location, {
    bool isMapboxResult = false,
  }) {
    return SearchSuggestionItem(
      id: 'place:${location.locationId}',
      kind: SearchSuggestionKind.place,
      title: location.name,
      subtitle: location.vicinity ?? location.cuisine,
      queryValue: location.name,
      location: location,
      isMapboxResult: isMapboxResult,
    );
  }

  /// Stub created from a Mapbox `/suggest` response. [location] is null until
  /// the user taps the result and `/retrieve` is called to resolve coordinates.
  factory SearchSuggestionItem.mapboxSuggestion(MapboxSuggestion suggestion) {
    return SearchSuggestionItem(
      id: 'mapbox:${suggestion.mapboxId}',
      kind: SearchSuggestionKind.place,
      title: suggestion.name,
      subtitle: suggestion.placeFormatted ?? suggestion.address,
      queryValue: suggestion.name,
      isMapboxResult: true,
      mapboxId: suggestion.mapboxId,
    );
  }

  factory SearchSuggestionItem.naturalLanguageResult(
    LocationModel location, {
    String? subtitle,
  }) {
    return SearchSuggestionItem(
      id: 'natural:${location.locationId}',
      kind: SearchSuggestionKind.naturalLanguage,
      title: location.name,
      subtitle: subtitle ?? location.editorialSummary ?? location.vicinity,
      queryValue: location.name,
      location: location,
      isPersonalized: true,
    );
  }

  factory SearchSuggestionItem.person(
    UserModel user, {
    bool isPersonalized = false,
  }) {
    final username = (user.username?.isNotEmpty ?? false)
        ? '@${user.username}'
        : null;
    return SearchSuggestionItem(
      id: 'person:${user.supabaseId ?? user.email}',
      kind: SearchSuggestionKind.person,
      title: user.name ?? username ?? user.email,
      subtitle: username ?? user.email,
      queryValue: user.name ?? user.username ?? user.email,
      user: user,
      isPersonalized: isPersonalized,
    );
  }
}

@immutable
class HeaderSearchSectionModel {
  final SearchSectionType type;
  final String title;
  final List<SearchSuggestionItem> items;
  final bool isLoading;

  /// Optional message displayed alongside the loading shimmer to give the
  /// user context about what's running. Used by the natural-language stage
  /// to signal that an LLM-backed magic search is in flight.
  final String? loadingMessage;

  const HeaderSearchSectionModel({
    required this.type,
    required this.title,
    this.items = const [],
    this.isLoading = false,
    this.loadingMessage,
  });

  HeaderSearchSectionModel copyWith({
    SearchSectionType? type,
    String? title,
    List<SearchSuggestionItem>? items,
    bool? isLoading,
    String? loadingMessage,
    bool clearLoadingMessage = false,
  }) {
    return HeaderSearchSectionModel(
      type: type ?? this.type,
      title: title ?? this.title,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      loadingMessage:
          clearLoadingMessage ? null : loadingMessage ?? this.loadingMessage,
    );
  }
}

@immutable
class HeaderSearchResultModel {
  final SearchIntentType intent;
  final String query;
  final String? inlineCompletion;
  final List<SearchSuggestionItem> quickSuggestions;
  final List<SearchSuggestionItem> databaseMatches;
  final List<HeaderSearchSectionModel> sections;
  final Set<WaterfallStage> completedStages;
  final bool isSearching;
  final String? errorMessage;

  const HeaderSearchResultModel({
    this.intent = SearchIntentType.mixed,
    this.query = '',
    this.inlineCompletion,
    this.quickSuggestions = const [],
    this.databaseMatches = const [],
    this.sections = const [],
    this.completedStages = const {},
    this.isSearching = false,
    this.errorMessage,
  });

  factory HeaderSearchResultModel.initial() {
    return const HeaderSearchResultModel(
      sections: [
        HeaderSearchSectionModel(
          type: SearchSectionType.places,
          title: 'Places',
        ),
        HeaderSearchSectionModel(
          type: SearchSectionType.naturalLanguage,
          title: 'Recommended',
        ),
        HeaderSearchSectionModel(
          type: SearchSectionType.people,
          title: 'People',
        ),
      ],
    );
  }

  HeaderSearchResultModel copyWith({
    SearchIntentType? intent,
    String? query,
    String? inlineCompletion,
    bool clearInlineCompletion = false,
    List<SearchSuggestionItem>? quickSuggestions,
    List<SearchSuggestionItem>? databaseMatches,
    List<HeaderSearchSectionModel>? sections,
    Set<WaterfallStage>? completedStages,
    bool? isSearching,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return HeaderSearchResultModel(
      intent: intent ?? this.intent,
      query: query ?? this.query,
      inlineCompletion: clearInlineCompletion
          ? null
          : inlineCompletion ?? this.inlineCompletion,
      quickSuggestions: quickSuggestions ?? this.quickSuggestions,
      databaseMatches: databaseMatches ?? this.databaseMatches,
      sections: sections ?? this.sections,
      completedStages: completedStages ?? this.completedStages,
      isSearching: isSearching ?? this.isSearching,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

@immutable
class HeaderSearchState {
  final bool isActive;
  final bool isPreviewingMap;
  final String query;
  final LocationModel? previewedLocation;
  final List<String> recentQueries;
  final HeaderSearchResultModel result;

  const HeaderSearchState({
    this.isActive = false,
    this.isPreviewingMap = false,
    this.query = '',
    this.previewedLocation,
    this.recentQueries = const [],
    this.result = const HeaderSearchResultModel(),
  });

  factory HeaderSearchState.initial() {
    return HeaderSearchState(
      result: HeaderSearchResultModel.initial(),
    );
  }

  HeaderSearchState copyWith({
    bool? isActive,
    bool? isPreviewingMap,
    String? query,
    LocationModel? previewedLocation,
    bool clearPreviewedLocation = false,
    List<String>? recentQueries,
    HeaderSearchResultModel? result,
  }) {
    return HeaderSearchState(
      isActive: isActive ?? this.isActive,
      isPreviewingMap: isPreviewingMap ?? this.isPreviewingMap,
      query: query ?? this.query,
      previewedLocation: clearPreviewedLocation
          ? null
          : previewedLocation ?? this.previewedLocation,
      recentQueries: recentQueries ?? this.recentQueries,
      result: result ?? this.result,
    );
  }
}

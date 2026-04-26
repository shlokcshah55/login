import 'package:flutter/foundation.dart';
import 'package:login/models/locations.dart';

enum SearchSuggestionKind {
  recentQuery,
  personalPrompt,
  place,
}

@immutable
class SearchSuggestionItem {
  final String id;
  final SearchSuggestionKind kind;
  final String title;
  final String? subtitle;
  final String? queryValue;
  final LocationModel? location;
  final bool isPersonalized;
  final double? distanceMeters;

  const SearchSuggestionItem({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.queryValue,
    this.location,
    this.isPersonalized = false,
    this.distanceMeters,
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
    double? distanceMeters,
  }) {
    return SearchSuggestionItem(
      id: 'place:${location.locationId}',
      kind: SearchSuggestionKind.place,
      title: location.name,
      subtitle: location.vicinity ?? location.cuisine,
      queryValue: location.name,
      location: location,
      distanceMeters: distanceMeters,
    );
  }
}

@immutable
class HeaderSearchResultModel {
  final String query;
  final String? inlineCompletion;
  final List<SearchSuggestionItem> quickSuggestions;
  final List<SearchSuggestionItem> placeItems;
  final bool isLoading;
  final String? errorMessage;

  const HeaderSearchResultModel({
    this.query = '',
    this.inlineCompletion,
    this.quickSuggestions = const [],
    this.placeItems = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  factory HeaderSearchResultModel.initial() {
    return const HeaderSearchResultModel();
  }

  HeaderSearchResultModel copyWith({
    String? query,
    String? inlineCompletion,
    bool clearInlineCompletion = false,
    List<SearchSuggestionItem>? quickSuggestions,
    List<SearchSuggestionItem>? placeItems,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return HeaderSearchResultModel(
      query: query ?? this.query,
      inlineCompletion: clearInlineCompletion
          ? null
          : inlineCompletion ?? this.inlineCompletion,
      quickSuggestions: quickSuggestions ?? this.quickSuggestions,
      placeItems: placeItems ?? this.placeItems,
      isLoading: isLoading ?? this.isLoading,
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

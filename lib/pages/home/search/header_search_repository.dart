import 'package:login/pages/home/search/header_search_types.dart';

abstract class HeaderSearchRepository {
  Future<List<String>> loadRecentQueries();

  Future<void> saveRecentQuery(String query);

  List<String> buildPersonalPrompts();

  String? buildInlineCompletion({
    required String query,
    required List<String> recentQueries,
    required List<String> personalPrompts,
  });

  Future<List<SearchSuggestionItem>> loadQuickSuggestions({
    required String query,
    required List<String> recentQueries,
    required List<String> personalPrompts,
  });

  Future<List<SearchSuggestionItem>> loadDatabaseMatches({
    required String query,
    required SearchIntentType intent,
  });

  Future<Map<SearchSectionType, List<SearchSuggestionItem>>> loadSections({
    required String query,
    required SearchIntentType intent,
  });

  Future<List<SearchSuggestionItem>> loadMapboxFallback({
    required String query,
    required SearchIntentType intent,
  });
}

class NoopHeaderSearchRepository implements HeaderSearchRepository {
  const NoopHeaderSearchRepository();

  @override
  String? buildInlineCompletion({
    required String query,
    required List<String> recentQueries,
    required List<String> personalPrompts,
  }) {
    return null;
  }

  @override
  List<String> buildPersonalPrompts() => const [];

  @override
  Future<List<SearchSuggestionItem>> loadDatabaseMatches({
    required String query,
    required SearchIntentType intent,
  }) async {
    return const [];
  }

  @override
  Future<List<String>> loadRecentQueries() async => const [];

  @override
  Future<List<SearchSuggestionItem>> loadQuickSuggestions({
    required String query,
    required List<String> recentQueries,
    required List<String> personalPrompts,
  }) async {
    return const [];
  }

  @override
  Future<Map<SearchSectionType, List<SearchSuggestionItem>>> loadSections({
    required String query,
    required SearchIntentType intent,
  }) async {
    return const {};
  }

  @override
  Future<List<SearchSuggestionItem>> loadMapboxFallback({
    required String query,
    required SearchIntentType intent,
  }) async {
    return const [];
  }

  @override
  Future<void> saveRecentQuery(String query) async {}
}

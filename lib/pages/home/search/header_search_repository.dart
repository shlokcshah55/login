import 'package:login/pages/home/search/header_search_types.dart';
import 'package:login/utils/geo_types.dart';

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

  /// Streams place suggestions for [query] as each result's image URL
  /// resolves. The stream emits the *running* list (ascending in size) so
  /// the UI can replace `placeItems` on each event without reconciliation.
  /// A single terminal event is emitted even when no rows are returned.
  Stream<List<SearchSuggestionItem>> loadDatabasePlaces({
    required String query,
  });

  Future<LatLng?> currentProximity();
}

class NoopHeaderSearchRepository implements HeaderSearchRepository {
  const NoopHeaderSearchRepository();

  @override
  String? buildInlineCompletion({
    required String query,
    required List<String> recentQueries,
    required List<String> personalPrompts,
  }) =>
      null;

  @override
  List<String> buildPersonalPrompts() => const [];

  @override
  Future<List<String>> loadRecentQueries() async => const [];

  @override
  Future<List<SearchSuggestionItem>> loadQuickSuggestions({
    required String query,
    required List<String> recentQueries,
    required List<String> personalPrompts,
  }) async =>
      const [];

  @override
  Stream<List<SearchSuggestionItem>> loadDatabasePlaces({
    required String query,
  }) =>
      Stream.value(const []);

  @override
  Future<LatLng?> currentProximity() async => null;

  @override
  Future<void> saveRecentQuery(String query) async {}
}

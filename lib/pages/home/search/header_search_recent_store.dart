import 'package:shared_preferences/shared_preferences.dart';

class HeaderSearchRecentStore {
  static const String _recentSearchesKey = 'header_search_recent_queries';
  static const int _maxRecentQueries = 12;

  Future<List<String>> loadRecentQueries() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_recentSearchesKey) ?? const [];
  }

  Future<List<String>> saveQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return loadRecentQueries();
    }

    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getStringList(_recentSearchesKey) ?? <String>[];
    final next = <String>[
      trimmed,
      ...existing.where(
        (value) => value.toLowerCase() != trimmed.toLowerCase(),
      ),
    ].take(_maxRecentQueries).toList();

    await preferences.setStringList(_recentSearchesKey, next);
    return next;
  }
}

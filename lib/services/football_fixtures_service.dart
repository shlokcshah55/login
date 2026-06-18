import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:login/models/football_fixture.dart';
import 'package:login/services/recommendations_api.dart';

class FootballFixturesService {
  static const String defaultBaseUrl = RecommendationsApi.defaultBaseUrl;
  static const String fixturesPath = '/football/fixtures';

  FootballFixturesService({
    http.Client? client,
    String? endpoint,
  })  : _client = client ?? http.Client(),
        _endpoint = endpoint ?? resolveFootballFixturesEndpoint();

  final http.Client _client;
  final String _endpoint;

  Future<List<FootballFixture>> fetchActiveFixtures() async {
    final response = await _client.get(
      Uri.parse(_endpoint),
      headers: const {'Accept': 'application/json'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FootballFixturesException(
        'Fixture request failed with ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    final rawFixtures = decoded is Map<String, dynamic>
        ? decoded['fixtures'] ?? decoded['results'] ?? decoded['data']
        : decoded;

    if (rawFixtures is! List) {
      throw FootballFixturesException('Fixture response must be a list');
    }

    return rawFixtures
        .whereType<Map>()
        .map(
          (item) => FootballFixture.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }
}

String resolveFootballFixturesEndpoint({Map<String, String>? env}) {
  final source = env ?? _dotenvEnvOrEmpty();
  final explicit = source['FOOTBALL_FIXTURES_API_URL']?.trim();
  if (explicit != null && explicit.isNotEmpty) {
    return explicit.replaceFirst(RegExp(r'/+$'), '');
  }

  final recommendations = source['RECOMMENDATIONS_API_URL']?.trim();
  final magicSearch = source['MAGIC_SEARCH_API_URL']?.trim();
  final override = recommendations?.isNotEmpty == true
      ? recommendations
      : magicSearch?.isNotEmpty == true
          ? magicSearch
          : null;

  final base = override == null || override.isEmpty
      ? FootballFixturesService.defaultBaseUrl
      : _stripKnownApiPath(override);
  return '${base.replaceFirst(RegExp(r'/+$'), '')}'
      '${FootballFixturesService.fixturesPath}';
}

String _stripKnownApiPath(String value) {
  var normalized = value.replaceFirst(RegExp(r'/+$'), '');
  const magicSearchPath = '/locations/magic-search';
  if (normalized.endsWith(magicSearchPath)) {
    normalized = normalized.substring(
      0,
      normalized.length - magicSearchPath.length,
    );
  }
  return normalized;
}

Map<String, String> _dotenvEnvOrEmpty() {
  try {
    return dotenv.env;
  } catch (_) {
    return const {};
  }
}

class FootballFixturesException implements Exception {
  const FootballFixturesException(this.message);

  final String message;

  @override
  String toString() => 'FootballFixturesException: $message';
}

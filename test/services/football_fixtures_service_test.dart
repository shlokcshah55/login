import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:login/models/football_fixture.dart';
import 'package:login/services/football_fixtures_service.dart';

void main() {
  test('football fixtures endpoint defaults to recommendations API route', () {
    expect(
      resolveFootballFixturesEndpoint(env: const {}),
      '${FootballFixturesService.defaultBaseUrl}/football/fixtures',
    );
  });

  test('football fixtures endpoint prefers explicit fixture override', () {
    expect(
      resolveFootballFixturesEndpoint(
        env: const {
          'FOOTBALL_FIXTURES_API_URL': 'https://api.example.com/live-fixtures',
          'MAGIC_SEARCH_API_URL': 'http://localhost:8080',
        },
      ),
      'https://api.example.com/live-fixtures',
    );
  });

  test('football fixtures endpoint derives from magic search base URL', () {
    expect(
      resolveFootballFixturesEndpoint(
        env: const {
          'MAGIC_SEARCH_API_URL':
              'http://localhost:8080/locations/magic-search',
        },
      ),
      'http://localhost:8080/football/fixtures',
    );
  });

  test('fetchActiveFixtures parses fixture payload', () async {
    Uri? requestUri;
    final service = FootballFixturesService(
      endpoint: 'http://localhost:8080/football/fixtures',
      client: MockClient((request) async {
        requestUri = request.url;
        return http.Response(
          jsonEncode({
            'fixtures': [
              {
                'id': 'fra-sen',
                'teamA': 'France',
                'teamB': 'Senegal',
                'countryA': 'France',
                'countryB': 'Senegal',
                'flagAUrl': 'https://flags.example/fr.svg',
                'flagBUrl': 'https://flags.example/sn.svg',
                'kickoffTime': '2026-06-19T20:00:00Z',
                'competition': 'World Cup',
              }
            ],
          }),
          200,
          headers: const {'Content-Type': 'application/json'},
        );
      }),
    );

    final fixtures = await service.fetchActiveFixtures();

    expect(requestUri?.toString(), 'http://localhost:8080/football/fixtures');
    expect(fixtures, hasLength(1));
    expect(fixtures.first.id, 'fra-sen');
    expect(fixtures.first.teamA, 'France');
    expect(fixtures.first.teamB, 'Senegal');
    expect(fixtures.first.countryA, 'France');
    expect(fixtures.first.countryB, 'Senegal');
    expect(fixtures.first.kickoffTime, DateTime.parse('2026-06-19T20:00:00Z'));
  });

  test('football fixture falls back countries to team names', () {
    final fixture = FootballFixture.fromJson(const {
      'id': 'eng-usa',
      'teamA': 'England',
      'teamB': 'USA',
    });

    expect(fixture.countryAForSearch, 'England');
    expect(fixture.countryBForSearch, 'USA');
  });
}

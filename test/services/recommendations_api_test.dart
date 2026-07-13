import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:login/services/recommendations_api.dart';

void main() {
  test('recommendations api base url defaults to production', () {
    expect(
      resolveRecommendationsApiBaseUrl(env: const {}),
      RecommendationsApi.defaultBaseUrl,
    );
  });

  test('recommendations api base url can use local magic search override', () {
    expect(
      resolveRecommendationsApiBaseUrl(
        env: const {'MAGIC_SEARCH_API_URL': 'http://localhost:8080'},
      ),
      'http://localhost:8080',
    );
  });

  test('recommendations api base url prefers recommendations override', () {
    expect(
      resolveRecommendationsApiBaseUrl(
        env: const {
          'RECOMMENDATIONS_API_URL': 'http://localhost:8090/',
          'MAGIC_SEARCH_API_URL': 'http://localhost:8080',
        },
      ),
      'http://localhost:8090',
    );
  });

  test('empty recommendations override falls back to magic search override',
      () {
    expect(
      resolveRecommendationsApiBaseUrl(
        env: const {
          'RECOMMENDATIONS_API_URL': ' ',
          'MAGIC_SEARCH_API_URL': 'http://localhost:8080',
        },
      ),
      'http://localhost:8080',
    );
  });

  test('recommendations api strips magic search route from override', () {
    expect(
      resolveRecommendationsApiBaseUrl(
        env: const {
          'MAGIC_SEARCH_API_URL':
              'http://localhost:8080/locations/magic-search',
        },
      ),
      'http://localhost:8080',
    );
  });

  test('add location sends full enrichment flags', () async {
    late Map<String, dynamic> payload;
    late Uri requestUri;
    final api = RecommendationsApi(
      baseUrl: 'http://localhost:8080',
      client: MockClient((request) async {
        requestUri = request.url;
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'success': true, 'location_id': 42}),
          200,
          headers: const {'Content-Type': 'application/json'},
        );
      }),
    );

    final locationId = await api.addLocationByGooglePlaceId(
      googlePlaceId: ' google-place-id ',
      source: 'magic-search-open',
      classifyPhoto: true,
      generateEmoji: true,
      processSynchronously: true,
    );

    expect(locationId, 42);
    expect(requestUri.toString(), 'http://localhost:8080/locations/add');
    expect(payload, {
      'google_place_id': 'google-place-id',
      'classify_photo': true,
      'generate_emoji': true,
      'process_synchronously': true,
      'source': 'magic-search-open',
    });
  });

  test('process location posts canonical processing request', () async {
    late Map<String, dynamic> payload;
    late Uri requestUri;
    final api = RecommendationsApi(
      baseUrl: 'http://localhost:8080',
      client: MockClient((request) async {
        requestUri = request.url;
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'queued': true,
            'location_id': 42,
            'request_id': 'request-42',
          }),
          202,
          headers: const {'Content-Type': 'application/json'},
        );
      }),
    );

    await api.processLocation(
      locationId: 42,
      googlePlaceId: ' place-42 ',
      source: 'expanded-card-open',
    );

    expect(requestUri.toString(), 'http://localhost:8080/locations/process');
    expect(payload, {
      'location_id': 42,
      'google_place_id': 'place-42',
      'source': 'expanded-card-open',
    });
  });
}

// Integration tests for Magic Search (natural-language location search).
//
// `NaturalLanguageSearchService.search` sends a prompt + location to the
// recommendations backend's `/locations/magic-search` endpoint. If the
// backend returns zero matches the service short-circuits; otherwise it
// hydrates the returned `location_id`s from the `locations` table in
// Supabase. We test the parts we can run hermetically — request shape,
// empty-result handling, and error paths. The Supabase-hydration branch
// requires an initialised `Supabase.instance.client` and is flagged as a
// follow-up with `skip:`.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:login/services/natural_language_search_service.dart';
import 'package:login/utils/geo_types.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NaturalLanguageSearchService — request shape', () {
    test('POSTs prompt + coords + limits to the configured endpoint',
        () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'recommendations': []}),
          200,
        );
      });

      final service = NaturalLanguageSearchService(
        client: client,
        endpoint: 'https://example.test/magic-search',
      );

      final results = await service.search(
        userId: 'user-1',
        query: '  romantic rooftop with a view  ',
        currentLocation: const LatLng(51.5074, -0.1278),
        radiusKm: 1.5,
        maxResults: 7,
        includeTasteBreakdown: true,
      );

      expect(results, isEmpty);
      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(captured!.url.toString(), 'https://example.test/magic-search');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['user_id'], 'user-1');
      expect(body['latitude'], 51.5074);
      expect(body['longitude'], -0.1278);
      expect(
        body['prompt'],
        'romantic rooftop with a view',
        reason: 'prompt must be trimmed before sending',
      );
      expect(body['radius_km'], 1.5);
      expect(body['max_results'], 7);
      expect(body['include_taste_breakdown'], isTrue);
    });

    test('returns an empty list when backend yields no recommendations',
        () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'recommendations': []}),
            200,
          ));
      final service = NaturalLanguageSearchService(
        client: client,
        endpoint: 'https://example.test/magic-search',
      );

      final results = await service.search(
        userId: 'u',
        query: 'anything',
        currentLocation: const LatLng(0, 0),
      );
      expect(results, isEmpty);
    });

    test('returns an empty list when the response is malformed', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({}), // no `recommendations` key at all
            200,
          ));
      final service = NaturalLanguageSearchService(
        client: client,
        endpoint: 'https://example.test/magic-search',
      );

      final results = await service.search(
        userId: 'u',
        query: 'tacos',
        currentLocation: const LatLng(40.7, -74.0),
      );
      expect(results, isEmpty);
    });

    test('drops recommendations that are missing a location_id', () async {
      // The service is expected to silently skip entries without a
      // `location_id` and — since the remaining id list is empty — return
      // `[]` without touching Supabase.
      final client = MockClient((_) async => http.Response(
            jsonEncode({
              'recommendations': [
                {'name': 'No id here'},
                {'location_id': null, 'name': 'Null id'},
              ],
            }),
            200,
          ));
      final service = NaturalLanguageSearchService(
        client: client,
        endpoint: 'https://example.test/magic-search',
      );

      final results = await service.search(
        userId: 'u',
        query: 'cozy',
        currentLocation: const LatLng(0, 0),
      );
      expect(results, isEmpty);
    });
  });

  group('NaturalLanguageSearchService — error propagation', () {
    test('throws on non-2xx status codes', () async {
      final client = MockClient((_) async => http.Response(
            'rate limited',
            429,
          ));
      final service = NaturalLanguageSearchService(
        client: client,
        endpoint: 'https://example.test/magic-search',
      );

      await expectLater(
        service.search(
          userId: 'u',
          query: 'q',
          currentLocation: const LatLng(0, 0),
        ),
        throwsA(
          predicate<Object>(
            (e) => e.toString().contains('429'),
            'exception message contains status code',
          ),
        ),
      );
    });

    test('5xx is not retried — bubbles up immediately', () async {
      var attempts = 0;
      final client = MockClient((_) async {
        attempts++;
        return http.Response('boom', 500);
      });
      final service = NaturalLanguageSearchService(
        client: client,
        endpoint: 'https://example.test/magic-search',
      );

      await expectLater(
        service.search(
          userId: 'u',
          query: 'q',
          currentLocation: const LatLng(0, 0),
        ),
        throwsA(isA<Exception>()),
      );
      expect(attempts, 1,
          reason: 'magic-search does not implement its own retry loop');
    });
  });

  group('NaturalLanguageSearchService — hydration path', () {
    test('hydrates matched ids via Supabase and preserves server order',
        () async {
      // TODO(refactor): requires `Supabase.instance.client` to be
      // initialised with a test fake, or for the service to accept an
      // injected `PostgrestClient`. Leaving documented until one of those
      // lands.
    }, skip: 'Needs injectable PostgrestClient / Supabase test harness');
  });

  group('LatLng value semantics', () {
    test('preserves latitude and longitude verbatim', () {
      const p = LatLng(12.5, -77.2);
      expect(p.latitude, 12.5);
      expect(p.longitude, -77.2);
    });
  });
}

// Integration tests for the Recommendations feature.
//
// RecommendationsApi talks to the PinIt recommendations Cloud Run backend.
// By injecting a `MockClient` from `package:http/testing.dart` we can
// assert the exact request shape, response parsing, retry behaviour, and
// error propagation without hitting the network.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:login/models/proximal_models.dart';
import 'package:login/services/recommendations_api.dart';

import '_helpers/test_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('RecommendationsApi.fetchProximal', () {
    test('POSTs to the proximal endpoint with a JSON body', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode(fakeProximalResponseJson()),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = RecommendationsApi(client: client);
      await api.fetchProximal(
        userId: 'user-1',
        latitude: 51.5074,
        longitude: -0.1278,
        radiusKm: 2.0,
      );

      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(
        captured!.url.toString(),
        endsWith('/recommendations/proximal'),
      );
      expect(
        captured!.headers['content-type'],
        contains('application/json'),
      );

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['user_id'], 'user-1');
      expect(body['latitude'], 51.5074);
      expect(body['longitude'], -0.1278);
      expect((body['radius_km'] as num).toDouble(), 2.0);
      expect(body.containsKey('quality_weight'), isTrue);
      expect(body.containsKey('vibe_weight'), isTrue);
      expect(body.containsKey('dietary_weight'), isTrue);
      expect(body.containsKey('social_weight'), isTrue);
      expect(body.containsKey('collaborative_weight'), isTrue);
    });

    test('parses a canonical response into a ProximalResponse', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode(fakeProximalResponseJson(resultCount: 3)),
            200,
          ));
      final api = RecommendationsApi(client: client);

      final result = await api.fetchProximal(
        userId: 'user-1',
        latitude: 51.0,
        longitude: -0.1,
        radiusKm: 2.0,
      );

      expect(result, isA<ProximalResponse>());
      expect(result.userId, 'user-1');
      expect(result.recommendations, hasLength(3));
      expect(result.recommendations.first.name, 'Recommended Spot 1');
      expect(result.recommendations.first.tasteBreakdown, hasLength(1));
      expect(result.recommendations.first.tasteBreakdown.first.tag, 'cozy');
      expect(result.totalResults, 3);
    });

    test('throws RecommendationsApiException on non-2xx after retries',
        () async {
      var attempts = 0;
      final client = MockClient((_) async {
        attempts++;
        return http.Response('upstream died', 503);
      });
      final api = RecommendationsApi(client: client);

      await expectLater(
        api.fetchProximal(
          userId: 'u',
          latitude: 0,
          longitude: 0,
          radiusKm: 1,
        ),
        throwsA(isA<RecommendationsApiException>()),
      );
      expect(attempts, greaterThan(1),
          reason: '5xx should trigger the retry loop');
    });

    test('does NOT retry on 4xx client errors', () async {
      var attempts = 0;
      final client = MockClient((_) async {
        attempts++;
        return http.Response('bad request', 400);
      });
      final api = RecommendationsApi(client: client);

      await expectLater(
        api.fetchProximal(
          userId: 'u',
          latitude: 0,
          longitude: 0,
          radiusKm: 1,
        ),
        throwsA(isA<RecommendationsApiException>()),
      );
      expect(attempts, 1);
    });

    test('clamps maxResults into [1, defaultMaxResults]', () async {
      Map<String, dynamic>? body;
      final client = MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(fakeProximalResponseJson()), 200);
      });
      final api = RecommendationsApi(client: client);

      await api.fetchProximal(
        userId: 'u',
        latitude: 0,
        longitude: 0,
        radiusKm: 1,
        maxResults: 9999, // well above default cap
      );
      expect(body!['max_results'], RecommendationsApi.defaultMaxResults);

      await api.fetchProximal(
        userId: 'u',
        latitude: 0,
        longitude: 0,
        radiusKm: 1,
        maxResults: 0, // below floor
      );
      expect(body!['max_results'], 1);
    });

    test('merges `cuisines` shortcut into explicit filters', () async {
      Map<String, dynamic>? body;
      final client = MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(fakeProximalResponseJson()), 200);
      });
      final api = RecommendationsApi(client: client);

      await api.fetchProximal(
        userId: 'u',
        latitude: 0,
        longitude: 0,
        radiusKm: 1,
        cuisines: const ['italian', 'thai'],
        filters: const {'price_max': 3},
      );

      final filters = body!['filters'] as Map<String, dynamic>;
      expect(filters['cuisine'], ['italian', 'thai']);
      expect(filters['price_max'], 3);
    });
  });

  group('RecommendationsApi.fetchProximalBubble', () {
    test('POSTs to the bubble endpoint with user_ids + bubble_id', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode(fakeProximalResponseJson(userId: 'bubble-42')),
          200,
        );
      });
      final api = RecommendationsApi(client: client);

      await api.fetchProximalBubble(
        userIds: const ['u1', 'u2', 'u3'],
        bubbleId: 'bubble-42',
        latitude: 51.5,
        longitude: -0.1,
      );

      expect(captured!.url.toString(), endsWith('/recommendations/bubble'));
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['user_ids'], ['u1', 'u2', 'u3']);
      expect(body['bubble_id'], 'bubble-42');
      expect(body['latitude'], 51.5);
      expect(body['longitude'], -0.1);
    });

    test('omits bubble_id when null or empty', () async {
      Map<String, dynamic>? body;
      final client = MockClient((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(fakeProximalResponseJson()), 200);
      });
      final api = RecommendationsApi(client: client);

      await api.fetchProximalBubble(
        userIds: const ['u1'],
        latitude: 0,
        longitude: 0,
      );
      expect(body!.containsKey('bubble_id'), isFalse);

      await api.fetchProximalBubble(
        userIds: const ['u1'],
        bubbleId: '',
        latitude: 0,
        longitude: 0,
      );
      expect(body!.containsKey('bubble_id'), isFalse);
    });
  });

  group('RecommendationsApi.addLocationByGooglePlaceId', () {
    test('returns null when the place id is blank', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });
      final api = RecommendationsApi(client: client);

      final result = await api.addLocationByGooglePlaceId(googlePlaceId: '   ');
      expect(result, isNull);
      expect(called, isFalse,
          reason: 'blank id must short-circuit without a network call');
    });

    test('returns the location_id from the backend response', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'location_id': 4242}),
            200,
          ));
      final api = RecommendationsApi(client: client);

      final result =
          await api.addLocationByGooglePlaceId(googlePlaceId: 'ChIJxyz');
      expect(result, 4242);
    });

    test('accepts numeric location_id encoded as double', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'location_id': 77.0}),
            200,
          ));
      final api = RecommendationsApi(client: client);

      final result =
          await api.addLocationByGooglePlaceId(googlePlaceId: 'abc');
      expect(result, 77);
    });
  });

  group('ProximalResponse.fromJson — defensive parsing', () {
    test('handles missing optional fields', () {
      final response = ProximalResponse.fromJson({
        'recommendations': [
          {'location_id': 1, 'name': 'Bare'},
        ],
      });
      expect(response.userId, '');
      expect(response.radiusKm, 0);
      expect(response.recommendations.single.name, 'Bare');
      expect(response.recommendations.single.rating, isNull);
    });

    test('defaults totalResults to recommendations.length', () {
      final response = ProximalResponse.fromJson({
        'recommendations': [
          {'location_id': 1, 'name': 'A'},
          {'location_id': 2, 'name': 'B'},
        ],
      });
      expect(response.totalResults, 2);
    });
  });
}

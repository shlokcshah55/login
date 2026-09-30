import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:login/services/area_name_service.dart';

Map<String, dynamic> _feature(String type, String name) => {
      'properties': {'feature_type': type, 'name': name},
    };

void main() {
  group('parseAreaName', () {
    test('prefers a neighbourhood over a locality', () {
      final body = {
        'features': [
          _feature('locality', 'Islington'),
          _feature('neighborhood', 'Angel'),
        ],
      };
      expect(AreaNameService.parseAreaName(body), 'Angel');
    });

    test('falls back to the locality', () {
      final body = {
        'features': [_feature('locality', 'East Ham')],
      };
      expect(AreaNameService.parseAreaName(body), 'East Ham');
    });

    test('returns null for empty or malformed bodies', () {
      expect(AreaNameService.parseAreaName({'features': []}), isNull);
      expect(AreaNameService.parseAreaName('nope'), isNull);
    });
  });

  group('lookup', () {
    test('requests neighbourhood/locality and caches per ~110 m cell',
        () async {
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        return http.Response(
          jsonEncode({
            'features': [_feature('neighborhood', 'Soho')],
          }),
          200,
        );
      });
      final service = AreaNameService(client: client, accessToken: 'tok');

      expect(await service.lookup(51.51361, -0.13652), 'Soho');
      // Same 3-dp cell (51.514, -0.137): served from cache.
      expect(await service.lookup(51.51372, -0.13658), 'Soho');
      expect(service.cached(51.5136, -0.1365), 'Soho');

      expect(requests, hasLength(1));
      expect(requests.single.path, '/search/geocode/v6/reverse');
      expect(requests.single.queryParameters['types'], 'neighborhood,locality');
    });

    test('shares one in-flight request per cell', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'features': [_feature('locality', 'Brixton')],
          }),
          200,
        );
      });
      final service = AreaNameService(client: client, accessToken: 'tok');
      final results = await Future.wait([
        service.lookup(51.4613, -0.1156),
        service.lookup(51.4613, -0.1156),
      ]);
      expect(results, ['Brixton', 'Brixton']);
      expect(calls, 1);
    });

    test('returns null without a token or on HTTP errors', () async {
      final failing = MockClient((_) async => http.Response('nope', 500));
      expect(
        await AreaNameService(client: failing, accessToken: '').lookup(1, 1),
        isNull,
      );
      expect(
        await AreaNameService(client: failing, accessToken: 'tok')
            .lookup(1, 1),
        isNull,
      );
    });
  });
}

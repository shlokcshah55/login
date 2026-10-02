import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/recommendations_api.dart';
import 'package:login/supabase/helpers/location.dart';
import 'package:login/utils/photo_urls.dart';

const _cdn = 'https://img.example.com';
const _api = 'https://api.example.com';

LocationModel _location({
  int id = 7,
  bool? imageStored = true,
  bool? imageUnavailable,
  int? extras,
  int? photoCount,
}) {
  return LocationModel(
    locationId: id,
    name: 'Venue',
    createdAt: DateTime.utc(2025, 1, 1),
    imageStored: imageStored,
    imageUnavailable: imageUnavailable,
    extraPhotosStored: extras,
    photos: photoCount == null
        ? null
        : [
            for (var i = 0; i < photoCount; i++)
              {'name': 'places/p/photos/$i'},
          ],
  );
}

String _hero(int id, int n) => '$_cdn/l/$id/${n}_hero.webp';

void main() {
  late List<http.Request> requests;
  late http.Response Function(http.Request) respond;

  setUp(() {
    PhotoUrls.configure(_cdn);
    requests = [];
    respond = (_) => http.Response(jsonEncode({'photos': []}), 200);
    LocationHelper.resetGalleryRequestsForTesting(
      api: RecommendationsApi(
        baseUrl: _api,
        client: MockClient((request) async {
          requests.add(request);
          return respond(request);
        }),
      ),
    );
  });

  tearDown(() {
    PhotoUrls.configure(null);
    LocationHelper.resetGalleryRequestsForTesting();
  });

  group('cdnRowImageUrl', () {
    test('stored rows get the card variant', () {
      expect(
        LocationHelper.cdnRowImageUrl({'location_id': 7, 'image_stored': true}),
        '$_cdn/l/7/0_card.webp',
      );
    });

    test('rows without a stored photo get a placeholder, not a 404 url', () {
      expect(
        LocationHelper.cdnRowImageUrl({
          'location_id': 7,
          'image_stored': false,
          'google_place_id': 'abc',
        }),
        isNull,
      );
      expect(
        LocationHelper.cdnRowImageUrl({
          'location_id': 7,
          'image_unavailable': true,
        }),
        isNull,
      );
    });
  });

  group('fetchCdnGallery', () {
    test('a fully stored gallery is served from the CDN with no server call',
        () async {
      final partials = <List<String>>[];
      final urls = await LocationHelper.fetchCdnGallery(
        _location(extras: 2, photoCount: 3),
        maxPhotos: 10,
        onPartial: partials.add,
      );
      expect(urls, [_hero(7, 0), _hero(7, 1), _hero(7, 2)]);
      expect(partials, [urls]);
      expect(requests, isEmpty);
    });

    test('emits stored photos first, then appends the server tail', () async {
      respond = (_) => http.Response(
            jsonEncode({
              'photos': [
                _hero(7, 0),
                'https://lh3.googleusercontent.com/a',
                'https://lh3.googleusercontent.com/b',
              ],
            }),
            200,
          );
      final partials = <List<String>>[];
      final urls = await LocationHelper.fetchCdnGallery(
        _location(extras: 0, photoCount: 3),
        maxPhotos: 10,
        onPartial: partials.add,
      );

      expect(requests.single.url.toString(), '$_api/locations/7/photos');
      expect(jsonDecode(requests.single.body), {'max_photos': 10});
      expect(partials.first, [_hero(7, 0)]);
      expect(urls, [
        _hero(7, 0),
        'https://lh3.googleusercontent.com/a',
        'https://lh3.googleusercontent.com/b',
      ]);
      expect(partials.last, urls);
    });

    test('asks the server once per location per session', () async {
      final location = _location(extras: 0, photoCount: 5);
      await LocationHelper.fetchCdnGallery(location, maxPhotos: 10);
      await LocationHelper.fetchCdnGallery(location, maxPhotos: 10);
      expect(requests, hasLength(1));
    });

    test('a failed request keeps stored photos and retries on next open',
        () async {
      respond = (_) => http.Response('boom', 500);
      final location = _location(extras: 0, photoCount: 5);
      final first =
          await LocationHelper.fetchCdnGallery(location, maxPhotos: 10);
      expect(first, [_hero(7, 0)]);

      respond = (_) => http.Response(
            jsonEncode({
              'photos': [_hero(7, 0), _hero(7, 1)],
            }),
            200,
          );
      final second =
          await LocationHelper.fetchCdnGallery(location, maxPhotos: 10);
      expect(second, [_hero(7, 0), _hero(7, 1)]);
      expect(requests, hasLength(2));
    });

    test('a place with no stored photo still gets its gallery from the server',
        () async {
      respond = (_) => http.Response(
            jsonEncode({
              'photos': ['https://lh3.googleusercontent.com/a'],
            }),
            200,
          );
      final urls = await LocationHelper.fetchCdnGallery(
        _location(imageStored: false),
        maxPhotos: 10,
      );
      expect(urls, ['https://lh3.googleusercontent.com/a']);
    });

    test('places marked image_unavailable make no request', () async {
      final urls = await LocationHelper.fetchCdnGallery(
        _location(imageStored: false, imageUnavailable: true),
        maxPhotos: 10,
      );
      expect(urls, isEmpty);
      expect(requests, isEmpty);
    });
  });
}

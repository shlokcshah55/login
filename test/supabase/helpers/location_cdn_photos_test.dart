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
      respond = (_) => http.Response(
            jsonEncode({
              'photos': [_hero(7, 0), 'https://lh3.googleusercontent.com/a'],
            }),
            200,
          );
      final location = _location(extras: 0, photoCount: 5);
      await LocationHelper.fetchCdnGallery(location, maxPhotos: 10);
      await LocationHelper.fetchCdnGallery(location, maxPhotos: 10);
      expect(requests, hasLength(1));
    });

    test('asks again on the next open when the server had nothing new',
        () async {
      final location = _location(imageStored: false, photoCount: null);
      expect(await LocationHelper.fetchCdnGallery(location, maxPhotos: 10),
          isEmpty);
      respond = (_) => http.Response(
            jsonEncode({
              'photos': ['https://lh3.googleusercontent.com/a'],
            }),
            200,
          );
      expect(await LocationHelper.fetchCdnGallery(location, maxPhotos: 10),
          ['https://lh3.googleusercontent.com/a']);
      expect(requests, hasLength(2));
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

  group('mergeFreshPhotoState', () {
    test('a photo stored since caching replaces the placeholder', () {
      final cached = _location(imageStored: false);
      final merged = LocationHelper.mergeFreshPhotoState(cached, {
        'location_id': 7,
        'image_stored': true,
        'extra_photos_stored': 2,
      });
      expect(merged.imageStored, isTrue);
      expect(merged.extraPhotosStored, 2);
      expect(merged.imageUrl, '$_cdn/l/7/0_card.webp');
    });

    test('a stored photo replaces a cached Google link', () {
      final cached = _location(imageStored: false)
          .copyWith(imageUrl: 'https://lh3.googleusercontent.com/a');
      final merged = LocationHelper.mergeFreshPhotoState(
          cached, {'location_id': 7, 'image_stored': true});
      expect(merged.imageUrl, '$_cdn/l/7/0_card.webp');
    });

    test('an unchanged row returns the cached model itself', () {
      final cached =
          _location(extras: 1).copyWith(imageUrl: '$_cdn/l/7/0_card.webp');
      final merged = LocationHelper.mergeFreshPhotoState(cached, {
        'location_id': 7,
        'image_stored': true,
        'extra_photos_stored': 1,
      });
      expect(identical(merged, cached), isTrue);
    });
  });

  group('withEnsuredPhotos', () {
    test('fills places without a photo and skips the rest', () async {
      respond = (_) => http.Response(
            jsonEncode({
              'photos': {'2': 'https://lh3.googleusercontent.com/b'},
            }),
            200,
          );
      final locations = [
        _location(id: 1).copyWith(imageUrl: '$_cdn/l/1/0_card.webp'),
        _location(id: 2, imageStored: false),
        _location(id: 3, imageStored: false, imageUnavailable: true),
        _location(id: 4, imageStored: false),
      ];
      final out = await LocationHelper.withEnsuredPhotos(locations);

      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/locations/photos/ensure');
      expect(jsonDecode(requests.single.body), {
        'location_ids': [2, 4],
      });
      expect(out.map((l) => l.imageUrl), [
        '$_cdn/l/1/0_card.webp',
        'https://lh3.googleusercontent.com/b',
        null,
        null,
      ]);
      expect(identical(out[0], locations[0]), isTrue);
    });

    test('does not ask about the same place again right away', () async {
      final locations = [_location(id: 2, imageStored: false)];
      await LocationHelper.withEnsuredPhotos(locations);
      await LocationHelper.withEnsuredPhotos(locations);
      expect(requests, hasLength(1));
    });

    test('splits large lists into batches', () async {
      final locations = [
        for (var i = 1; i <= 45; i++) _location(id: i, imageStored: false),
      ];
      await LocationHelper.withEnsuredPhotos(locations);
      expect(requests, hasLength(2));
    });

    test('a failed request leaves the list unchanged', () async {
      respond = (_) => http.Response('boom', 500);
      final locations = [_location(id: 2, imageStored: false)];
      final out = await LocationHelper.withEnsuredPhotos(locations);
      expect(identical(out.single, locations.single), isTrue);
    });
  });
}

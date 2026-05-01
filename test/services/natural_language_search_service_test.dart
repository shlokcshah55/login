import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/natural_language_search_service.dart';

void main() {
  test('magic search endpoint defaults to production Cloud Run URL', () {
    expect(
      resolveMagicSearchEndpoint(env: const {}),
      NaturalLanguageSearchService.defaultEndpoint,
    );
  });

  test('magic search endpoint can be overridden with env var', () {
    expect(
      resolveMagicSearchEndpoint(
        env: const {
          'MAGIC_SEARCH_API_URL': 'http://localhost:8080',
        },
      ),
      'http://localhost:8080/locations/magic-search',
    );
  });

  test('magic search endpoint accepts full local route override', () {
    expect(
      resolveMagicSearchEndpoint(
        env: const {
          'MAGIC_SEARCH_API_URL':
              'http://127.0.0.1:8080/locations/magic-search',
        },
      ),
      'http://127.0.0.1:8080/locations/magic-search',
    );
  });

  test(
      'magic search recommendations parse unknown places as temporary locations',
      () {
    final locations = magicSearchRecommendationsToLocationModels([
      {
        'location_id': -123,
        'google_place_id': 'google-new',
        'is_known_location': false,
        'name': 'New Google Place',
        'vicinity': 'New Street',
        'lat': 51.51,
        'lng': -0.14,
        'rating': 4.8,
        'user_ratings_total': 500,
        'price_level': 2,
        'types': 'restaurant,bar',
        'open_now': true,
      },
    ]);

    expect(locations, hasLength(1));
    expect(locations.first.locationId, -123);
    expect(locations.first.googlePlaceId, 'google-new');
    expect(locations.first.name, 'New Google Place');
    expect(locations.first.vicinity, 'New Street');
    expect(locations.first.lat, 51.51);
    expect(locations.first.lng, -0.14);
    expect(locations.first.rating, 4.8);
    expect(locations.first.userRatingsTotal, 500);
    expect(locations.first.priceLevel, 2);
    expect(locations.first.openNow, true);
  });

  test('magic search ids only include persisted positive location ids', () {
    final ids = persistedMagicSearchLocationIds([
      {'location_id': 4001},
      {'location_id': -123},
      {'location_id': null},
    ]);

    expect(ids, [4001]);
  });
}

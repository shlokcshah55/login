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
        'photo_reference': 'places/google-new/photos/photo-1',
      },
    ], env: const {
      'GOOGLE_PLACE_API_KEY': 'test-key'
    });

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
    expect(locations.first.photoReference, 'places/google-new/photos/photo-1');
    expect(
      locations.first.imageUrl,
      'https://places.googleapis.com/v1/places/google-new/photos/photo-1/media?maxHeightPx=2000&maxWidthPx=2000&key=test-key',
    );
  });

  test(
      'magic search recommendations propagate website/editorial/maps/vibe fields',
      () {
    final locations = magicSearchRecommendationsToLocationModels([
      {
        'location_id': -456,
        'google_place_id': 'google-rich',
        'name': 'Rich Place',
        'lat': 51.5,
        'lng': -0.1,
        'website': 'https://example.com',
        'google_maps_uri': 'https://maps.google.com/?cid=42',
        'editorial_summary': 'Cosy neighbourhood Italian.',
        'review_summary': 'Loved by locals.',
        'international_phone_number': '+44 20 7946 0958',
        'business_status': 'OPERATIONAL',
        'formatted_address': '1 Example Street, London',
        'opening_hours_text': const ['Monday: 9 AM – 11 PM', 'Tuesday: 9 AM – 11 PM'],
        'good_for_children': true,
        'good_for_groups': true,
        'good_for_watching_sports': false,
        'live_music': false,
        'outdoor_seating': true,
        'serves_beer': true,
        'serves_breakfast': false,
        'serves_brunch': true,
        'serves_cocktails': true,
        'serves_coffee': true,
        'serves_dessert': true,
        'serves_dinner': true,
        'serves_lunch': true,
        'serves_vegetarian_food': true,
        'serves_wine': true,
      },
    ]);

    expect(locations, hasLength(1));
    final loc = locations.first;
    expect(loc.website, 'https://example.com');
    expect(loc.googleMapsUri, 'https://maps.google.com/?cid=42');
    expect(loc.editorialSummary, 'Cosy neighbourhood Italian.');
    expect(loc.reviewSummary, 'Loved by locals.');
    expect(loc.internationalPhoneNumber, '+44 20 7946 0958');
    expect(loc.businessStatus, 'OPERATIONAL');
    expect(loc.vicinity, '1 Example Street, London');
    expect(
      loc.openingHoursText,
      ['Monday: 9 AM – 11 PM', 'Tuesday: 9 AM – 11 PM'],
    );
    expect(loc.goodForChildren, true);
    expect(loc.outdoorSeating, true);
    expect(loc.servesCocktails, true);
    expect(loc.servesBreakfast, false);
    expect(loc.liveMusic, false);
  });

  test('magic search photo url is null without a client google api key', () {
    expect(
      magicSearchPhotoUrl(
        'places/google-new/photos/photo-1',
        env: const {},
      ),
      isNull,
    );
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

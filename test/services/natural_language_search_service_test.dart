import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/natural_language_search_service.dart';

void main() {
  test('magic search endpoint defaults to local magic search URL', () {
    expect(
      resolveMagicSearchEndpoint(env: const {}),
      'http://localhost:8080/locations/magic-search',
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
        'opening_hours_text': const [
          'Monday: 9 AM – 11 PM',
          'Tuesday: 9 AM – 11 PM'
        ],
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

  test('magic search grouped recommendations preserve headers and friend saves',
      () {
    final locations = magicSearchRecommendationsToLocationModels([
      {
        'header': 'Friends would pick these',
        'recommendations': [
          {
            'location_id': -701,
            'google_place_id': 'google-social',
            'name': 'Social Cafe',
            'lat': 51.5,
            'lng': -0.1,
            'friend_saves': const [
              {
                'friend_id': 'friend-1',
                'friend_name': 'Maya Patel',
                'friend_username': 'maya',
                'friend_profile_image_url': 'https://example.com/maya.jpg',
                'action_type': 'save',
                'timestamp': '2026-06-08T12:00:00Z',
              },
            ],
          },
        ],
      },
      {
        'title': 'Worth the walk',
        'results': [
          {
            'location_id': -702,
            'google_place_id': 'google-walk',
            'name': 'Walkable Bistro',
            'lat': 51.51,
            'lng': -0.11,
          },
        ],
      },
    ]);

    expect(locations.map((location) => location.name), [
      'Social Cafe',
      'Walkable Bistro',
    ]);
    expect(locations.first.magicSearchSectionTitle, 'Friends would pick these');
    expect(locations.last.magicSearchSectionTitle, 'Worth the walk');
    expect(locations.first.friendSaves, hasLength(1));
    expect(locations.first.friendSaves.single.friendName, 'Maya Patel');
  });

  test('magic search recommendations preserve rich ranking and source metadata',
      () {
    final locations = magicSearchRecommendationsToLocationModels([
      {
        'location_id': -171192625659736,
        'google_place_id': 'google-rich-ranking',
        'is_known_location': false,
        'name': '4R Nepalese Bites',
        'vicinity': '2nd Floor, Whaley Wharf, Unit: M208, London',
        'distance_km': 5.691553287099971,
        'final_score': 0.6263161830878778,
        'rank': 1,
        'image_stored': false,
        'image_unavailable': true,
        'extra_photos_stored': 3,
        'source': const ['Google'],
        'source_metadata': const [
          {'provider': 'places'}
        ],
        'match_reasons': const [
          'Open now',
          'Hidden gem signal',
          'Highly rated on Google',
        ],
        'intent_matches': const {
          'availability': 1.0,
          'google_quality': 0.880761649472333,
        },
        'confidence': 0.5471055190071206,
      },
    ]);

    final loc = locations.single;
    expect(loc.distanceKm, 5.691553287099971);
    expect(loc.matchScore, 0.6263161830878778);
    expect(loc.magicSearchRank, 1);
    expect(loc.imageStored, false);
    expect(loc.imageUnavailable, true);
    expect(loc.extraPhotosStored, 3);
    expect(loc.magicSearchSources, ['Google']);
    expect(loc.magicSearchSourceMetadata, [
      {'provider': 'places'}
    ]);
    expect(loc.magicSearchMatchReasons, [
      'Open now',
      'Hidden gem signal',
      'Highly rated on Google',
    ]);
    expect(loc.magicSearchIntentMatches, {
      'availability': 1.0,
      'google_quality': 0.880761649472333,
    });
    expect(loc.magicSearchConfidence, 0.5471055190071206);
  });

  test('hydrated Supabase magic search locations merge fresh Google fields',
      () {
    final hydrated = LocationModel(
      locationId: 42,
      name: 'Stored Cafe',
      createdAt: DateTime(2026, 1, 1),
      imageUrl: 'https://storage.example/stored.jpg',
      cuisine: 'Cafe',
    );
    final magicSearch = magicSearchRecommendationsToLocationModels([
      {
        'location_id': 42,
        'google_place_id': 'google-known',
        'name': 'Google Cafe',
        'vicinity': '29 Corsham St, London',
        'rating': 4.8,
        'user_ratings_total': 118,
        'photo_reference': 'places/google-known/photos/photo-1',
        'website': 'https://example.com',
        'review_summary': 'Fresh momos and coffee.',
        'open_now': true,
        'final_score': 0.72,
        'rank': 2,
        'match_reasons': const ['Open now'],
      },
    ]).single;

    final merged = mergeMagicSearchLocationResult(
      hydrated: hydrated,
      magicSearch: magicSearch,
    );

    expect(merged.locationId, 42);
    expect(merged.name, 'Stored Cafe');
    expect(merged.imageUrl, 'https://storage.example/stored.jpg');
    expect(merged.googlePlaceId, 'google-known');
    expect(merged.vicinity, '29 Corsham St, London');
    expect(merged.rating, 4.8);
    expect(merged.userRatingsTotal, 118);
    expect(merged.photoReference, 'places/google-known/photos/photo-1');
    expect(merged.website, 'https://example.com');
    expect(merged.reviewSummary, 'Fresh momos and coffee.');
    expect(merged.openNow, true);
    expect(merged.matchScore, 0.72);
    expect(merged.magicSearchRank, 2);
    expect(merged.magicSearchMatchReasons, ['Open now']);
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

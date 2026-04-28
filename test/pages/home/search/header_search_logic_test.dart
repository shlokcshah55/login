import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/search/header_search_coordinator.dart';
import 'package:login/pages/home/search/header_search_location_hydrator.dart';
import 'package:login/pages/home/search/header_search_readiness.dart';
import 'package:login/pages/home/search/header_search_types.dart';

void main() {
  group('HeaderSearchCoordinator place deduplication', () {
    test('keeps the first Google result for the same place id', () {
      final merged = HeaderSearchCoordinator.dedupePlaceSuggestions([
        SearchSuggestionItem.place(
          _location(
            id: -1,
            name: 'Padella',
            googlePlaceId: 'google-padella',
          ),
        ),
        SearchSuggestionItem.place(
          _location(
            id: -2,
            name: 'Padella Borough',
            googlePlaceId: 'google-padella',
          ),
        ),
        SearchSuggestionItem.place(
          _location(
            id: -3,
            name: 'Bancone',
            googlePlaceId: 'google-bancone',
          ),
        ),
      ]);

      expect(merged.map((item) => item.title), ['Padella', 'Bancone']);
      expect(merged.first.location?.locationId, -1);
    });

    test('falls back to normalized name and vicinity without a place id', () {
      final merged = HeaderSearchCoordinator.dedupePlaceSuggestions([
        SearchSuggestionItem.place(
          _location(id: -1, name: 'Kiln', vicinity: 'Soho'),
        ),
        SearchSuggestionItem.place(
          _location(id: -2, name: ' kiln ', vicinity: ' soho '),
        ),
      ]);

      expect(merged.map((item) => item.location?.locationId), [-1]);
    });
  });

  group('Header search detail readiness', () {
    test('allows transient Google places to open expanded details', () {
      final transientGooglePlace = _location(
        id: -1,
        name: 'Padella',
        googlePlaceId: 'google-padella',
      );
      final persistedPlace = _location(id: 42, name: 'Kiln');

      expect(canOpenHeaderSearchDetails(transientGooglePlace), isTrue);
      expect(canOpenHeaderSearchDetails(persistedPlace), isTrue);
      expect(canOpenHeaderSearchDetails(null), isFalse);
    });
  });

  group('Header search location hydration', () {
    test('loads persisted Supabase location before Google details', () async {
      var googleCalls = 0;
      final transientGooglePlace = _location(
        id: -1,
        name: 'Padella',
        googlePlaceId: 'google-padella',
      );
      final persistedPlace = _location(
        id: 42,
        name: 'Padella DB',
        googlePlaceId: 'google-padella',
      );

      final hydrated = await hydrateHeaderSearchLocation(
        transientGooglePlace,
        locationsByGoogleIds: (placeIds) async {
          expect(placeIds, ['google-padella']);
          return [persistedPlace];
        },
        googleDetailsLoader: (_) async {
          googleCalls++;
          return null;
        },
      );

      expect(hydrated, same(persistedPlace));
      expect(googleCalls, 0);
    });

    test('falls back to Google details when Supabase has no matching place',
        () async {
      var googleCalls = 0;
      final transientGooglePlace = _location(
        id: -1,
        name: 'Padella',
        googlePlaceId: 'google-padella',
      );
      final googleDetails = _location(
        id: -1,
        name: 'Padella Google Details',
        googlePlaceId: 'google-padella',
      );

      final hydrated = await hydrateHeaderSearchLocation(
        transientGooglePlace,
        locationsByGoogleIds: (_) async => const [],
        googleDetailsLoader: (_) async {
          googleCalls++;
          return googleDetails;
        },
      );

      expect(hydrated, same(googleDetails));
      expect(googleCalls, 1);
    });
  });
}

LocationModel _location({
  required int id,
  required String name,
  String? googlePlaceId,
  String? vicinity,
}) {
  return LocationModel(
    locationId: id,
    name: name,
    googlePlaceId: googlePlaceId,
    vicinity: vicinity,
    lat: 51.5074,
    lng: -0.1278,
    createdAt: DateTime(2024),
    preference: LocationPreference.search,
  );
}

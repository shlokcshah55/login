import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/proximal_models.dart';
import 'package:login/pages/home/search/live_header_search_repository.dart';
import 'package:login/services/google_place_service.dart';

void main() {
  test('maps autocomplete place predictions to transient search locations', () {
    final locations = autocompleteSuggestionsToSearchLocations([
      const GoogleAutocompleteSuggestion(
        placeId: 'google-padella',
        text: 'Padella, Borough Market, London',
        mainText: 'Padella',
        secondaryText: 'Borough Market, London',
        types: ['restaurant', 'point_of_interest'],
        distanceMeters: 120,
      ),
    ]);

    expect(locations, hasLength(1));
    expect(locations.first.locationId, lessThan(0));
    expect(locations.first.name, 'Padella');
    expect(locations.first.vicinity, 'Borough Market, London');
    expect(locations.first.googlePlaceId, 'google-padella');
    expect(locations.first.types, 'restaurant,point_of_interest');
    expect(locations.first.imageUrl, isNull);
    expect(locations.first.photoReference, isNull);
    expect(locations.first.preference, LocationPreference.search);
  });

  test(
    'replaces transient Google results with matching Supabase locations',
    () {
      final resolved = reconcileGooglePlacesWithPersistedLocations(
        googleLocations: [
          _location(
            id: -1,
            name: 'Padella',
            googlePlaceId: 'google-padella',
            imageUrl: 'https://maps.googleapis.com/padella.jpg',
          ),
          _location(
            id: -2,
            name: 'Bancone',
            googlePlaceId: 'google-bancone',
          ),
        ],
        persistedLocations: [
          _location(
            id: 42,
            name: 'Padella DB',
            googlePlaceId: 'google-padella',
          ),
        ],
      );

      expect(resolved.map((location) => location.locationId), [42, -2]);
      expect(resolved.map((location) => location.name), [
        'Padella DB',
        'Bancone',
      ]);
      expect(
          resolved.first.imageUrl, 'https://maps.googleapis.com/padella.jpg');
    },
  );

  test('adds local match scores to Supabase search hits from existing vectors',
      () {
    final enriched = enrichPersistedSearchLocationsForUser(
      [
        _location(
          id: 42,
          name: 'Padella DB',
          googlePlaceId: 'google-padella',
          vibeVector: const [1, 0],
          dietaryRequirementVector: const [1, 0],
          friendSaves: const [
            FriendSave(
              friendId: 'friend-1',
              friendName: 'Maya',
              actionType: 'save',
              timestamp: '2026-04-29T10:00:00Z',
            ),
          ],
        ),
        _location(
          id: 43,
          name: 'No vectors',
          googlePlaceId: 'google-no-vectors',
        ),
      ],
      userVibeAffinity: const [1, 0],
      userDietaryAffinity: const [1, 0],
    );

    expect(enriched.first.matchScore, closeTo(1, 0.001));
    expect(enriched.first.friendSaves.single.friendName, 'Maya');
    expect(enriched.last.matchScore, isNull);
  });

  test('attaches friend saves to Supabase search hits by location id', () {
    final enriched = attachFriendSavesToSearchLocations(
      [
        _location(
          id: 42,
          name: 'Padella DB',
          googlePlaceId: 'google-padella',
        ),
        _location(
          id: -7,
          name: 'Autocomplete only',
          googlePlaceId: 'google-new',
        ),
      ],
      {
        42: const [
          FriendSave(
            friendId: 'friend-1',
            friendName: 'Maya',
            actionType: 'save',
            timestamp: '2026-04-29T10:00:00Z',
          ),
        ],
      },
    );

    expect(enriched.first.friendSaves.single.friendName, 'Maya');
    expect(enriched.last.friendSaves, isEmpty);
  });
}

LocationModel _location({
  required int id,
  required String name,
  required String googlePlaceId,
  String? imageUrl,
  List<double>? vibeVector,
  List<int>? dietaryRequirementVector,
  List<FriendSave> friendSaves = const [],
}) {
  return LocationModel(
    locationId: id,
    name: name,
    googlePlaceId: googlePlaceId,
    lat: 51.5074,
    lng: -0.1278,
    imageUrl: imageUrl,
    vibeVector: vibeVector,
    dietaryRequirementVector: dietaryRequirementVector,
    friendSaves: friendSaves,
    createdAt: DateTime(2024),
    preference: LocationPreference.search,
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/search/live_header_search_repository.dart';

void main() {
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
}

LocationModel _location({
  required int id,
  required String name,
  required String googlePlaceId,
  String? imageUrl,
}) {
  return LocationModel(
    locationId: id,
    name: name,
    googlePlaceId: googlePlaceId,
    lat: 51.5074,
    lng: -0.1278,
    imageUrl: imageUrl,
    createdAt: DateTime(2024),
    preference: LocationPreference.search,
  );
}

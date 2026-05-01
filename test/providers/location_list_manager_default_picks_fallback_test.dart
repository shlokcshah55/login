import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/utils/geo_types.dart';
import 'package:mocktail/mocktail.dart';

class _MockGooglePlacesService extends Mock implements GooglePlacesService {}

void main() {
  setUpAll(() {
    dotenv.testLoad(
      fileInput: 'GOOGLE_PLACE_API_KEY=test\nAPI_SECRET_KEY=test\n',
    );
  });

  test('defaults to Picks when fewer than 10 saved locations exist', () {
    final manager = LocationListManager(_MockGooglePlacesService());

    final shouldUsePicks = manager.shouldDefaultPinsToRecommendations(
      userPosition: const LatLng(51.5000, -0.1200),
      savedLocations: List.generate(
        9,
        (index) => _location(
          index,
          51.5000,
          -0.1200 + index * 0.001,
        ),
      ),
    );

    expect(shouldUsePicks, isTrue);
  });

  test('defaults to Picks when fewer than 5 saved locations are within 4km',
      () {
    final manager = LocationListManager(_MockGooglePlacesService());

    final shouldUsePicks = manager.shouldDefaultPinsToRecommendations(
      userPosition: const LatLng(51.5000, -0.1200),
      savedLocations: [
        ...List.generate(
          4,
          (index) => _location(
            index,
            51.5000,
            -0.1200 + index * 0.001,
          ),
        ),
        ...List.generate(
          6,
          (index) => _location(
            100 + index,
            51.9000,
            -0.1200,
          ),
        ),
      ],
    );

    expect(shouldUsePicks, isTrue);
  });

  test('keeps saved pins when total and nearby saved thresholds are met', () {
    final manager = LocationListManager(_MockGooglePlacesService());

    final shouldUsePicks = manager.shouldDefaultPinsToRecommendations(
      userPosition: const LatLng(51.5000, -0.1200),
      savedLocations: [
        ...List.generate(
          5,
          (index) => _location(
            index,
            51.5000,
            -0.1200 + index * 0.001,
          ),
        ),
        ...List.generate(
          5,
          (index) => _location(
            100 + index,
            51.9000,
            -0.1200,
          ),
        ),
      ],
    );

    expect(shouldUsePicks, isFalse);
  });

  test('saved locations without coordinates do not count as nearby', () {
    final manager = LocationListManager(_MockGooglePlacesService());

    final shouldUsePicks = manager.shouldDefaultPinsToRecommendations(
      userPosition: const LatLng(51.5000, -0.1200),
      savedLocations: [
        ...List.generate(
          5,
          (index) => LocationModel(
            locationId: index,
            name: 'Missing coordinates $index',
            createdAt: DateTime(2026, 5, 1),
          ),
        ),
        ...List.generate(
          5,
          (index) => _location(
            100 + index,
            51.9000,
            -0.1200,
          ),
        ),
      ],
    );

    expect(shouldUsePicks, isTrue);
  });
}

LocationModel _location(int id, double lat, double lng) {
  return LocationModel(
    locationId: id,
    name: 'Location $id',
    lat: lat,
    lng: lng,
    createdAt: DateTime(2026, 5, 1),
  );
}

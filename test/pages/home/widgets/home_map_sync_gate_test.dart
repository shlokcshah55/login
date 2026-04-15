import 'package:flutter_test/flutter_test.dart';
import 'package:login/pages/home/widgets/home_map_sync_gate.dart';
import 'package:login/providers/location_list_provider.dart';

void main() {
  test('saved map pins wait for saved locations to finish loading', () {
    expect(
      shouldSyncGeoJsonPins(
        useGeoJsonLayers: true,
        isMapLoaded: true,
        currentListType: LocationListType.saved,
        hasLoadedSavedLocations: false,
      ),
      isFalse,
    );

    expect(
      shouldSyncGeoJsonPins(
        useGeoJsonLayers: true,
        isMapLoaded: true,
        currentListType: LocationListType.saved,
        hasLoadedSavedLocations: true,
      ),
      isTrue,
    );
  });

  test('non-saved lists only need the map to be ready', () {
    expect(
      shouldSyncGeoJsonPins(
        useGeoJsonLayers: true,
        isMapLoaded: false,
        currentListType: LocationListType.recommended,
        hasLoadedSavedLocations: false,
      ),
      isFalse,
    );

    expect(
      shouldSyncGeoJsonPins(
        useGeoJsonLayers: true,
        isMapLoaded: true,
        currentListType: LocationListType.recommended,
        hasLoadedSavedLocations: false,
      ),
      isTrue,
    );
  });
}

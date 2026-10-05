import 'package:flutter_test/flutter_test.dart';
import 'package:login/pages/home/widgets/home_map_sync_gate.dart';
import 'package:login/providers/location_list_provider.dart';

void main() {
  test('saved map pins wait for saved locations to finish loading', () {
    expect(
      shouldSyncGeoJsonPins(
        useGeoJsonLayers: true,
        currentListType: LocationListType.saved,
        hasLoadedSavedLocations: false,
      ),
      isFalse,
    );

    expect(
      shouldSyncGeoJsonPins(
        useGeoJsonLayers: true,
        currentListType: LocationListType.saved,
        hasLoadedSavedLocations: true,
      ),
      isTrue,
    );
  });

  test('non-saved lists sync without waiting for saved locations', () {
    expect(
      shouldSyncGeoJsonPins(
        useGeoJsonLayers: true,
        currentListType: LocationListType.recommended,
        hasLoadedSavedLocations: false,
      ),
      isTrue,
    );
  });

  test('legacy annotation mode never syncs GeoJSON pins', () {
    expect(
      shouldSyncGeoJsonPins(
        useGeoJsonLayers: false,
        currentListType: LocationListType.recommended,
        hasLoadedSavedLocations: true,
      ),
      isFalse,
    );
  });
}

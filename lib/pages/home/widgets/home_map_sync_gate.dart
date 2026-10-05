import 'package:login/providers/location_list_provider.dart';

/// Whether the current list is ready to be pushed to the GeoJSON map.
///
/// Map readiness isn't checked here: [MapStateProvider.requestPins] holds the
/// request until the style has loaded.
bool shouldSyncGeoJsonPins({
  required bool useGeoJsonLayers,
  required LocationListType currentListType,
  required bool hasLoadedSavedLocations,
}) {
  if (!useGeoJsonLayers) {
    return false;
  }

  if (currentListType == LocationListType.saved && !hasLoadedSavedLocations) {
    return false;
  }

  return true;
}

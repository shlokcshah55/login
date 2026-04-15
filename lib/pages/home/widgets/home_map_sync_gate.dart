import 'package:login/providers/location_list_provider.dart';

bool shouldSyncGeoJsonPins({
  required bool useGeoJsonLayers,
  required bool isMapLoaded,
  required LocationListType currentListType,
  required bool hasLoadedSavedLocations,
}) {
  if (!useGeoJsonLayers || !isMapLoaded) {
    return false;
  }

  if (currentListType == LocationListType.saved && !hasLoadedSavedLocations) {
    return false;
  }

  return true;
}

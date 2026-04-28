import 'package:login/models/locations.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/supabase/helpers/location.dart';

typedef HeaderSearchGoogleDetailsLoader = Future<LocationModel?> Function(
  LocationModel location,
);

typedef HeaderSearchLocationsByIdsLoader = Future<List<LocationModel>> Function(
  List<int> locationIds,
);

typedef HeaderSearchLocationsByGoogleIdsLoader = Future<List<LocationModel>>
    Function(
  List<String> googlePlaceIds,
);

Future<LocationModel?> hydrateHeaderSearchLocation(
  LocationModel location, {
  HeaderSearchLocationsByIdsLoader? locationsByIds,
  HeaderSearchLocationsByGoogleIdsLoader? locationsByGoogleIds,
  HeaderSearchGoogleDetailsLoader? googleDetailsLoader,
}) async {
  LocationHelper? helper;
  LocationHelper locationHelper() => helper ??= LocationHelper();
  final loadGoogleDetails =
      googleDetailsLoader ?? GooglePlacesService().fetchPlaceDetails;

  if (location.locationId > 0) {
    final loadByIds = locationsByIds ?? locationHelper().getLocationsByIds;
    final persisted = await loadByIds([location.locationId]);
    if (persisted.isNotEmpty) {
      return persisted.first;
    }
    return location;
  }

  final googlePlaceId = location.googlePlaceId?.trim();
  if (googlePlaceId == null || googlePlaceId.isEmpty) {
    return location;
  }

  final loadByGoogleIds =
      locationsByGoogleIds ?? locationHelper().getLocationsByGooglePlaceIds;
  final persisted = await loadByGoogleIds([googlePlaceId]);
  if (persisted.isNotEmpty) {
    return persisted.first;
  }

  return loadGoogleDetails(location);
}

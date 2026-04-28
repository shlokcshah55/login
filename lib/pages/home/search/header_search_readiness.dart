import 'package:login/models/locations.dart';

bool canOpenHeaderSearchDetails(LocationModel? location) {
  if (location == null) return false;
  if (location.locationId > 0) return true;

  final googlePlaceId = location.googlePlaceId?.trim();
  return googlePlaceId != null && googlePlaceId.isNotEmpty;
}

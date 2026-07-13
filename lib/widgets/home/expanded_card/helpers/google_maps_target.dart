/// Resolves the most precise Google Maps destination available for a place.
///
/// Google-provided canonical links win. A Place ID link is preferred over a
/// coordinate search because it opens the actual business listing, including
/// its reviews and live details.
Uri? resolveGoogleMapsTarget({
  required String name,
  String? googleMapsUri,
  String? googlePlaceId,
  double? lat,
  double? lng,
}) {
  final canonical = googleMapsUri?.trim();
  if (canonical != null && canonical.isNotEmpty) {
    final parsed = Uri.tryParse(canonical);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }
  }

  final placeId = googlePlaceId?.trim();
  if (placeId != null && placeId.isNotEmpty) {
    final query = name.trim().isEmpty ? placeId : name.trim();
    return Uri.https(
      'www.google.com',
      '/maps/search/',
      {
        'api': '1',
        'query': query,
        'query_place_id': placeId,
      },
    );
  }

  if (lat != null && lng != null) {
    return Uri.https(
      'www.google.com',
      '/maps/search/',
      {
        'api': '1',
        'query': '$lat,$lng',
      },
    );
  }
  return null;
}

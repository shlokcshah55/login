import 'package:flutter_test/flutter_test.dart';
import 'package:login/widgets/home/expanded_card/helpers/google_maps_target.dart';

void main() {
  test('canonical Google Maps URI wins', () {
    final target = resolveGoogleMapsTarget(
      googleMapsUri: 'https://maps.google.com/?cid=42',
      name: 'Noodle Yard',
      googlePlaceId: 'place-42',
      lat: 51.5,
      lng: -0.1,
    );

    expect(target.toString(), 'https://maps.google.com/?cid=42');
  });

  test('Place ID fallback targets the named Google place', () {
    final target = resolveGoogleMapsTarget(
      name: 'Noodle Yard & Bar',
      googlePlaceId: 'place-42',
      lat: 51.5,
      lng: -0.1,
    );

    expect(target?.host, 'www.google.com');
    expect(target?.path, '/maps/search/');
    expect(target?.queryParameters, {
      'api': '1',
      'query': 'Noodle Yard & Bar',
      'query_place_id': 'place-42',
    });
  });

  test('coordinates are used only when no Place ID is available', () {
    final target = resolveGoogleMapsTarget(
      name: 'Noodle Yard',
      lat: 51.5,
      lng: -0.1,
    );

    expect(target?.queryParameters, {
      'api': '1',
      'query': '51.5,-0.1',
    });
  });

  test('returns null when there is no usable destination', () {
    expect(resolveGoogleMapsTarget(name: 'Noodle Yard'), isNull);
  });
}

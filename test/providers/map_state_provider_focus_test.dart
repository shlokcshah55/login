import 'package:flutter_test/flutter_test.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/utils/geo_types.dart';

void main() {
  group('MapStateProvider.pointsToFrame', () {
    const soho = LatLng(51.5136, -0.1365);
    const shoreditch = LatLng(51.5265, -0.0798); // ~4 km from Soho
    const newYork = LatLng(40.7128, -74.0060);
    const tokyo = LatLng(35.6762, 139.6503);

    test('drops far-away saves so the frame stays local', () {
      final framed = MapStateProvider.pointsToFrame(
        [newYork, soho, tokyo, shoreditch],
        anchor: const LatLng(51.51, -0.13),
      );
      expect(framed, [soho, shoreditch]);
    });

    test('seeds on the first point without an anchor', () {
      final framed =
          MapStateProvider.pointsToFrame([newYork, soho, shoreditch]);
      expect(framed, [newYork]);
    });

    test('keeps a single point as is', () {
      expect(MapStateProvider.pointsToFrame([tokyo]), [tokyo]);
    });
  });
}

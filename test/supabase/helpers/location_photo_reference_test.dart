import 'package:flutter_test/flutter_test.dart';
import 'package:login/supabase/helpers/location.dart';

void main() {
  group('LocationHelper.photoResourceNameFor', () {
    test('uses Places v1 photo name when present', () {
      expect(
        LocationHelper.photoResourceNameFor({
          'name': 'places/place-id/photos/photo-id',
          'photo_reference': 'legacy-reference',
        }),
        'places/place-id/photos/photo-id',
      );
    });

    test('falls back to legacy Places photo_reference', () {
      expect(
        LocationHelper.photoResourceNameFor({
          'photo_reference': 'legacy-reference',
        }),
        'legacy-reference',
      );
    });

    test('returns null for blank or missing references', () {
      expect(LocationHelper.photoResourceNameFor({'name': '   '}), isNull);
      expect(LocationHelper.photoResourceNameFor({'width': 1200}), isNull);
    });
  });

  group('LocationHelper.photoMediaUriFor', () {
    test('builds a Places v1 media URI for resource names', () {
      final uri = LocationHelper.photoMediaUriFor(
        'places/place-id/photos/photo-id',
        apiKey: 'api-key',
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'places.googleapis.com');
      expect(uri.path, '/v1/places/place-id/photos/photo-id/media');
      expect(uri.queryParameters['maxHeightPx'], '2000');
      expect(uri.queryParameters['maxWidthPx'], '2000');
      expect(uri.queryParameters['key'], 'api-key');
    });

    test('builds a legacy Place Photo URI for photo_reference values', () {
      final uri = LocationHelper.photoMediaUriFor(
        'legacy-reference',
        apiKey: 'api-key',
      );

      expect(uri.scheme, 'https');
      expect(uri.host, 'maps.googleapis.com');
      expect(uri.path, '/maps/api/place/photo');
      expect(uri.queryParameters['maxheight'], '1600');
      expect(uri.queryParameters['maxwidth'], '1600');
      expect(uri.queryParameters['photoreference'], 'legacy-reference');
      expect(uri.queryParameters['key'], 'api-key');
    });
  });
}

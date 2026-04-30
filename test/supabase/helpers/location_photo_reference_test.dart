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

    test('does not use legacy Places photo_reference values', () {
      expect(
        LocationHelper.photoResourceNameFor({
          'photo_reference': 'legacy-reference',
        }),
        isNull,
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

    test('rejects non-v1 photo references', () {
      expect(
        () => LocationHelper.photoMediaUriFor(
          'legacy-reference',
          apiKey: 'api-key',
        ),
        throwsArgumentError,
      );
    });
  });

  group('LocationHelper canonical photo metadata', () {
    test('detects canonical high resolution metadata', () {
      expect(
        LocationHelper.hasCanonicalPhotoMetadata([
          {
            'name': 'places/place-id/photos/photo-id',
            'pinit_media_max_width': 2000,
          },
        ]),
        isTrue,
      );
    });

    test('detects old format and unmarked v1 metadata as stale', () {
      expect(
        LocationHelper.hasCanonicalPhotoMetadata([
          {'photo_reference': 'legacy-reference'},
        ]),
        isFalse,
      );
      expect(
        LocationHelper.hasCanonicalPhotoMetadata([
          {'name': 'places/place-id/photos/photo-id'},
        ]),
        isFalse,
      );
    });

    test('annotates v1 photos with current media width', () {
      expect(
        LocationHelper.annotateCanonicalPhotos([
          {'name': 'places/place-id/photos/photo-id', 'widthPx': 900},
        ]),
        [
          {
            'name': 'places/place-id/photos/photo-id',
            'widthPx': 900,
            'pinit_media_max_width': 2000,
          },
        ],
      );
    });
  });

  group('LocationHelper photo refresh decisions', () {
    test('refetches Places metadata when photos are missing or legacy only',
        () {
      expect(LocationHelper.needsPlacePhotoRefresh(null), isTrue);
      expect(LocationHelper.needsPlacePhotoRefresh(const []), isTrue);
      expect(
        LocationHelper.needsPlacePhotoRefresh([
          {'photo_reference': 'legacy-reference'},
        ]),
        isTrue,
      );
    });

    test('keeps unmarked v1 metadata but refreshes stored image bytes', () {
      final photos = [
        {'name': 'places/place-id/photos/photo-id'},
      ];

      expect(LocationHelper.needsPlacePhotoRefresh(photos), isFalse);
      expect(LocationHelper.needsStoredPhotoRefresh(photos), isTrue);
    });

    test('does not refresh metadata or storage for canonical photos', () {
      final photos = [
        {
          'name': 'places/place-id/photos/photo-id',
          'pinit_media_max_width': 2000,
        },
      ];

      expect(LocationHelper.needsPlacePhotoRefresh(photos), isFalse);
      expect(LocationHelper.needsStoredPhotoRefresh(photos), isFalse);
    });

    test('does not refetch after a canonical no-photos check', () {
      final photos = LocationHelper.canonicalNoPhotosCheckedMetadata();

      expect(LocationHelper.hasCanonicalNoPhotosCheck(photos), isTrue);
      expect(LocationHelper.needsPlacePhotoRefresh(photos), isFalse);
      expect(LocationHelper.needsStoredPhotoRefresh(photos), isFalse);
      expect(LocationHelper.photoResourceNameFor(photos.single), isNull);
    });
  });
}

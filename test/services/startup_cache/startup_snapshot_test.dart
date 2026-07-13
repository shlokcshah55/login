import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/users.dart';
import 'package:login/models/video_extras.dart';
import 'package:login/services/startup_cache/startup_snapshot.dart';

void main() {
  test('round trip preserves startup fields and saved metadata', () {
    final snapshot = StartupSnapshot(
      schemaVersion: StartupSnapshot.currentSchemaVersion,
      userId: 'user-1',
      writtenAt: DateTime.utc(2026, 7, 13, 10),
      acceptedConsentVersion: 'v1',
      profile: UserModel(
        supabaseId: 'user-1',
        email: 'pinit@example.com',
        name: 'Pinit User',
        wizardCompleted: true,
        verified: true,
      ),
      savedLocations: <LocationModel>[
        LocationModel(
          locationId: 42,
          name: 'Cafe Cache',
          createdAt: DateTime.utc(2026, 7, 1),
          lat: 51.5,
          lng: -0.1,
          imageUrl: 'https://images.example/42.jpg',
          matchScore: 0.87,
          savedFrom: 'https://tiktok.example/video',
          savedMethod: 'tiktok',
          savedAt: DateTime.utc(2026, 7, 12),
          videoExtras: const VideoExtras(
            personalNotes: 'Order the bun',
            specialOffers: <SpecialOffer>[
              SpecialOffer(
                offer: 'Two for one',
                code: 'CACHE',
                validUntil: '2026-08-01',
              ),
            ],
          ),
        ),
      ],
    );

    final decoded = StartupSnapshot.fromJson(snapshot.toJson());

    expect(decoded.userId, 'user-1');
    expect(decoded.writtenAt, DateTime.utc(2026, 7, 13, 10));
    expect(decoded.profile?.wizardCompleted, isTrue);
    expect(decoded.profile?.verified, isTrue);
    expect(decoded.acceptedConsentVersion, 'v1');
    expect(
      decoded.savedLocations.single.imageUrl,
      'https://images.example/42.jpg',
    );
    expect(decoded.savedLocations.single.matchScore, 0.87);
    expect(decoded.savedLocations.single.savedMethod, 'tiktok');
    expect(
      decoded.savedLocations.single.videoExtras?.personalNotes,
      'Order the bun',
    );
    expect(
      decoded.savedLocations.single.videoExtras?.specialOffers?.single.code,
      'CACHE',
    );
  });

  test('unsupported schema throws a specific format exception', () {
    expect(
      () => StartupSnapshot.fromJson(<String, dynamic>{
        'schema_version': 999,
        'user_id': 'user-1',
        'written_at': '2026-07-13T10:00:00.000Z',
        'saved_locations': <dynamic>[],
      }),
      throwsA(isA<StartupSnapshotUnsupportedSchemaException>()),
    );
  });

  test('invalid profile and location sections do not discard valid data', () {
    final snapshot = StartupSnapshot.fromJson(<String, dynamic>{
      'schema_version': StartupSnapshot.currentSchemaVersion,
      'user_id': 'user-1',
      'written_at': '2026-07-13T10:00:00.000Z',
      'profile': <String, dynamic>{'invalid': true},
      'saved_locations': <dynamic>[
        <String, dynamic>{'invalid': true},
        <String, dynamic>{
          'location_id': 9,
          'name': 'Still Valid',
          'created_at': '2026-07-01T00:00:00.000Z',
        },
      ],
    });

    expect(snapshot.profile, isNull);
    expect(snapshot.savedLocations.map((location) => location.locationId),
        <int>[9]);
  });
}

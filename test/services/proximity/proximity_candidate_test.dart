import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/proximity/proximity_candidate.dart';

void main() {
  LocationModel loc({String? savedMethod, double? lat = 1, double? lng = 2}) =>
      LocationModel(
        locationId: 7,
        name: 'Nobu',
        lat: lat,
        lng: lng,
        createdAt: DateTime.utc(2025, 1, 1),
        savedMethod: savedMethod,
      );

  test('insight parses the RPC row and trims blanks', () {
    final i = ProximityInsight.fromJson({
      'saved_method': 'tiktok',
      'creator_handle': ' foodie ',
      'top_dish': '',
      'vibe': 'elegant',
      'confidence_tier': 'HIGH',
      'confirmed_by_user': true,
      'been_to': false,
    });
    expect(i.savedMethod, 'tiktok');
    expect(i.creatorHandle, 'foodie');
    expect(i.topDish, isNull);
    expect(i.vibe, 'elegant');
    expect(i.confidenceTier, 'high');
    expect(i.confirmedByUser, isTrue);
    expect(i.beenTo, isFalse);
  });

  test('source comes from the location, falling back to the insight', () {
    expect(
      ProximityCandidate.fromLocation(loc(savedMethod: 'instagram'))!.source,
      ProximitySource.instagram,
    );
    expect(
      ProximityCandidate.fromLocation(
        loc(),
        insight: const ProximityInsight(savedMethod: 'tiktok'),
      )!
          .source,
      ProximitySource.tiktok,
    );
    expect(
      ProximityCandidate.fromLocation(loc())!.source,
      ProximitySource.inApp,
    );
  });

  test('places without coordinates cannot be candidates', () {
    expect(ProximityCandidate.fromLocation(loc(lat: null)), isNull);
  });
}

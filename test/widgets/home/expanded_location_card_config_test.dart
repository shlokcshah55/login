import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/location_processing_trigger.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:login/widgets/home/expanded_card/social_review_context.dart';

void main() {
  test('resolves shared video urls on open by default', () {
    final card = ExpandedLocationCard(
      location: LocationModel(
        locationId: 42,
        name: 'Noodle Yard',
        createdAt: DateTime.utc(2026, 5, 29),
      ),
      onClose: _noop,
    );

    expect(card.resolveSharedVideoUrlOnOpen, isTrue);
    expect(card.socialReviewContext, isNull);
  });

  test('accepts optional social review context', () {
    const context = SocialReviewContext(
      platform: 'tiktok',
      placeName: 'Noodle Yard',
      confidenceScore: 0.91,
    );
    final card = ExpandedLocationCard(
      location: LocationModel(
        locationId: 42,
        name: 'Noodle Yard',
        createdAt: DateTime.utc(2026, 5, 29),
      ),
      onClose: _noop,
      socialReviewContext: context,
    );

    expect(card.socialReviewContext, same(context));
  });

  test('accepts an injectable location processing trigger', () {
    final trigger = LocationProcessingTrigger(
      loadRow: (_) async => null,
      requestProcessing: ({required locationId, googlePlaceId}) async {},
    );
    final card = ExpandedLocationCard(
      location: LocationModel(
        locationId: 42,
        name: 'Noodle Yard',
        createdAt: DateTime.utc(2026, 5, 29),
      ),
      onClose: _noop,
      locationProcessingTrigger: trigger,
    );

    expect(card.locationProcessingTrigger, same(trigger));
  });
}

void _noop() {}

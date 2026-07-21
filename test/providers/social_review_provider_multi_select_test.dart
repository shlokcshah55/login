import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/social_review_models.dart';
import 'package:login/providers/social_review_provider.dart';

class _RecordingBatchProvider extends SocialReviewProvider {
  _RecordingBatchProvider(SocialPostReviewItem item)
      : super(
          reviewLoader: () async => [item],
          locationBatchLoader: (_) async => const [],
          reviewStatusUpdater: (_, __) async {},
        );

  final List<String> savedIds = [];
  final List<String> discardedIds = [];

  @override
  Future<bool> savePlace(
    SocialPostReviewItem item,
    SocialPostPlace place,
  ) async {
    savedIds.add(place.id);
    return true;
  }

  @override
  Future<bool> discardPlace(
    SocialPostReviewItem item,
    SocialPostPlace place,
  ) async {
    discardedIds.add(place.id);
    return true;
  }
}

void main() {
  test('batch confirmation saves every selected row including same names',
      () async {
    final now = DateTime.now().toUtc();
    const sameNameA = SocialPostPlace(
      id: 'same-a',
      name: 'Noodle Yard',
      locationId: 41,
    );
    const sameNameB = SocialPostPlace(
      id: 'same-b',
      name: 'Noodle Yard',
      locationId: 42,
    );
    const other = SocialPostPlace(
      id: 'other',
      name: 'Other Place',
      locationId: 43,
    );
    final review = SocialPostReviewItem(
      reviewId: 'review-1',
      postId: 'post-1',
      sharedUrl: 'https://www.tiktok.com/@food/video/1',
      reviewStatus: 'pending',
      canonicalUrl: 'https://www.tiktok.com/@food/video/1',
      platform: 'tiktok',
      postStatus: 'processed',
      postUpdatedAt: now,
      sharedAt: now,
      places: const [sameNameA, sameNameB, other],
    );
    final provider = _RecordingBatchProvider(review);
    await provider.refresh();

    final ok = await provider.confirmPlaces(
      review,
      selectedPlaces: const [sameNameA, sameNameB],
    );

    expect(ok, isTrue);
    expect(provider.savedIds, ['same-a', 'same-b']);
    expect(provider.discardedIds, ['other']);
    expect(provider.itemByPostId('post-1')?.reviewStatus, 'reviewed');
  });
}

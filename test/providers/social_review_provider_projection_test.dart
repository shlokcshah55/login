import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/social_review_models.dart';
import 'package:login/providers/social_review_provider.dart';

void main() {
  test('refresh hydrates unique location ids in one batch', () async {
    final review = SocialPostReviewItem(
      reviewId: 'review-1',
      postId: 'post-1',
      sharedUrl: 'https://www.tiktok.com/video/1',
      reviewStatus: 'pending',
      canonicalUrl: 'https://www.tiktok.com/video/1',
      platform: 'tiktok',
      postStatus: 'processed',
      sharedAt: DateTime.utc(2026, 7, 11),
      places: const [
        SocialPostPlace(id: 'place-1', name: 'Noodle Yard', locationId: 42),
        SocialPostPlace(id: 'place-2', name: 'Noodle Yard', locationId: 42),
      ],
      placeActions: const {
        'place-1': SocialPlaceAction.saved,
        'place-2': SocialPlaceAction.saved,
      },
    );
    final requestedBatches = <List<int>>[];
    final provider = SocialReviewProvider(
      reviewLoader: () async => [review],
      locationBatchLoader: (ids) async {
        requestedBatches.add(ids);
        return [
          LocationModel(
            locationId: 42,
            name: 'Noodle Yard',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ];
      },
    );

    await provider.refresh();

    expect(requestedBatches, [
      [42],
    ]);
    expect(provider.placeItems, hasLength(2));
    expect(provider.placeItems.every((item) => item.location != null), isTrue);
  });

  test('reviewed history is visible but does not increase pending count',
      () async {
    final reviewed = SocialPostReviewItem(
      reviewId: 'reviewed-1',
      postId: 'post-1',
      sharedUrl: 'https://www.tiktok.com/video/1',
      reviewStatus: 'reviewed',
      canonicalUrl: 'https://www.tiktok.com/video/1',
      platform: 'tiktok',
      postStatus: 'processed',
      sharedAt: DateTime.utc(2026, 7, 11),
      places: const [
        SocialPostPlace(id: 'place-1', name: 'Noodle Yard', locationId: 42),
      ],
      placeActions: const {'place-1': SocialPlaceAction.saved},
    );
    final provider = SocialReviewProvider(
      reviewLoader: () async => [reviewed],
      locationBatchLoader: (_) async => const [],
    );

    await provider.refresh();

    expect(provider.placeItems, hasLength(1));
    expect(provider.pendingCount, 0);
  });

  test('successful pending shares do not count as needing checking', () async {
    final successful = SocialPostReviewItem(
      reviewId: 'pending-success',
      postId: 'post-success',
      sharedUrl: 'https://www.tiktok.com/video/success',
      reviewStatus: 'pending',
      canonicalUrl: 'https://www.tiktok.com/video/success',
      platform: 'tiktok',
      postStatus: 'processed',
      sharedAt: DateTime.utc(2026, 7, 11),
      places: const [
        SocialPostPlace(
          id: 'saved-place',
          name: 'Noodle Yard',
          locationId: 42,
          confidenceTier: 'high',
        ),
      ],
      placeActions: const {'saved-place': SocialPlaceAction.saved},
    );
    final provider = SocialReviewProvider(
      reviewLoader: () async => [successful],
      locationBatchLoader: (_) async => const [],
    );

    await provider.refresh();

    expect(provider.pendingCount, 1);
    expect(provider.needsCheckingCount, 0);
  });

  test('low-confidence pending shares count as needing checking', () async {
    final uncertain = SocialPostReviewItem(
      reviewId: 'pending-uncertain',
      postId: 'post-uncertain',
      sharedUrl: 'https://www.tiktok.com/video/uncertain',
      reviewStatus: 'pending',
      canonicalUrl: 'https://www.tiktok.com/video/uncertain',
      platform: 'tiktok',
      postStatus: 'processed',
      sharedAt: DateTime.utc(2026, 7, 11),
      places: const [
        SocialPostPlace(
          id: 'possible-place',
          name: 'Possible Cafe',
          confidenceTier: 'low',
        ),
      ],
    );
    final provider = SocialReviewProvider(
      reviewLoader: () async => [uncertain],
      locationBatchLoader: (_) async => const [],
    );

    await provider.refresh();

    expect(provider.needsCheckingCount, 1);
  });
}

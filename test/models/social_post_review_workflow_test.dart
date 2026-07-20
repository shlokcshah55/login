import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/social_review_models.dart';

void main() {
  const highPlace = SocialPostPlace(
    id: 'high',
    name: 'Noodle Yard',
    locationId: 42,
    confidenceScore: 0.93,
    confidenceTier: 'high',
  );
  const mediumPlace = SocialPostPlace(
    id: 'medium',
    name: 'Maybe Noodles',
    locationId: 43,
    confidenceScore: 0.64,
    confidenceTier: 'medium',
  );

  SocialPostReviewItem item({
    String reviewStatus = 'pending',
    String postStatus = 'processed',
    List<SocialPostPlace> places = const [],
    Map<String, SocialPlaceAction> actions = const {},
    Set<String> confirmed = const {},
    DateTime? updatedAt,
  }) {
    return SocialPostReviewItem(
      reviewId: 'review-1',
      postId: 'post-1',
      sharedUrl: 'https://www.tiktok.com/@food/video/1',
      reviewStatus: reviewStatus,
      canonicalUrl: 'https://www.tiktok.com/@food/video/1',
      platform: 'tiktok',
      creatorHandle: 'food',
      title: 'Noodles in Soho',
      caption: 'The chilli noodles are worth ordering',
      thumbnailUrl: 'https://images.example/noodles.jpg',
      postStatus: postStatus,
      evidenceFlags: const {'caption': true, 'thumbnail_ocr': true},
      processingError: postStatus == 'failed' ? 'internal detail' : null,
      postUpdatedAt: updatedAt ?? DateTime.utc(2026, 7, 20, 12),
      processedAt:
          postStatus == 'processed' ? DateTime.utc(2026, 7, 20, 12) : null,
      sharedAt: DateTime.utc(2026, 7, 20, 11),
      places: places,
      placeActions: actions,
      userConfirmedPlaceIds: confirmed,
    );
  }

  test('exposes ranked vibe and offer insights from candidate context', () {
    const place = SocialPostPlace(
      id: 'place-context',
      name: 'Monkey & Me Thai Cuisine',
      extractedContext: {
        'source': 'thumbnail_ocr',
        'reasoning': 'Name and neighbourhood appeared on screen.',
        'sentiment': 'positive',
        'vibe_signals': {'takeout_friendly': .8, 'casual': .9},
        'special_offers': [
          {'offer': 'Affordable lunch for £12'},
        ],
      },
    );

    expect(place.vibeSignalNames, ['casual', 'takeout friendly']);
    expect(place.specialOfferLabels, ['Affordable lunch for £12']);
    expect(place.reasoning, 'Name and neighbourhood appeared on screen.');
    expect(place.sentiment, 'positive');
    expect(place.sourceLabel, 'Thumbnail OCR');
  });

  test('parses all persisted post context fields', () {
    final parsed = SocialPostReviewItem.fromJson({
      'id': 'review-1',
      'social_post_id': 'post-1',
      'shared_url': 'https://www.instagram.com/reel/abc',
      'status': 'pending',
      'created_at': '2026-07-20T11:00:00Z',
      'social_posts': {
        'canonical_url': 'https://www.instagram.com/reel/abc',
        'platform': 'instagram',
        'creator_handle': 'creator',
        'title': 'A hidden terrace',
        'caption': 'Save this terrace for summer',
        'thumbnail_url': 'https://images.example/terrace.jpg',
        'status': 'processed',
        'vibes': {'outdoor_dining': 0.9},
        'sentiment': 'positive',
        'evidence_flags': {'caption': true},
        'error': null,
        'updated_at': '2026-07-20T11:04:00Z',
        'processed_at': '2026-07-20T11:04:00Z',
        'social_post_places': [],
      },
    });

    expect(parsed.caption, 'Save this terrace for summer');
    expect(parsed.thumbnailUrl, 'https://images.example/terrace.jpg');
    expect(parsed.evidenceFlags, {'caption': true});
    expect(parsed.postUpdatedAt, DateTime.utc(2026, 7, 20, 11, 4));
    expect(parsed.processedAt, DateTime.utc(2026, 7, 20, 11, 4));
  });

  test('distinguishes active and stale processing', () {
    final now = DateTime.utc(2026, 7, 20, 12, 20);

    expect(
      item(
        postStatus: 'processing',
        updatedAt: DateTime.utc(2026, 7, 20, 12, 10),
      ).workflowStateAt(now),
      SocialPostWorkflowState.processing,
    );
    expect(
      item(
        postStatus: 'processing',
        updatedAt: DateTime.utc(2026, 7, 20, 10),
      ).workflowStateAt(now),
      SocialPostWorkflowState.failed,
    );
  });

  test('failed and dismissed states take precedence', () {
    final now = DateTime.utc(2026, 7, 20, 12, 20);

    expect(
      item(postStatus: 'failed').workflowStateAt(now),
      SocialPostWorkflowState.failed,
    );
    expect(
      item(
        reviewStatus: 'dismissed',
        postStatus: 'failed',
      ).workflowStateAt(now),
      SocialPostWorkflowState.dismissed,
    );
  });

  test('medium processor save still needs explicit confirmation', () {
    final review = item(
      places: const [mediumPlace],
      actions: const {'medium': SocialPlaceAction.saved},
    );

    expect(
      review.workflowStateAt(DateTime.utc(2026, 7, 20, 12, 20)),
      SocialPostWorkflowState.needsChecking,
    );
    expect(review.pendingReviewPlaces, [mediumPlace]);
  });

  test('user-confirmed medium place resolves the post', () {
    final review = item(
      places: const [mediumPlace],
      actions: const {'medium': SocialPlaceAction.saved},
      confirmed: const {'medium'},
    );

    expect(
      review.workflowStateAt(DateTime.utc(2026, 7, 20, 12, 20)),
      SocialPostWorkflowState.resolved,
    );
    expect(review.pendingReviewPlaces, isEmpty);
  });

  test('high processor save is resolved without extra review', () {
    final review = item(
      places: const [highPlace],
      actions: const {'high': SocialPlaceAction.saved},
    );

    expect(
      review.workflowStateAt(DateTime.utc(2026, 7, 20, 12, 20)),
      SocialPostWorkflowState.resolved,
    );
  });

  test('processed post without a confident place needs checking', () {
    expect(
      item().workflowStateAt(DateTime.utc(2026, 7, 20, 12, 20)),
      SocialPostWorkflowState.needsChecking,
    );
  });
}

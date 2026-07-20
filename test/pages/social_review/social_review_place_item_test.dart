import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/social_review_models.dart';
import 'package:login/pages/social_review/social_review_place_item.dart';

void main() {
  SocialPostReviewItem review({
    String status = 'pending',
    String postStatus = 'processed',
    String? creator = 'pinitfood',
    String? title = 'Best noodles in Soho',
    List<SocialPostPlace> places = const [],
    Map<String, SocialPlaceAction> actions = const {},
    Map<String, int> savedIds = const {},
  }) {
    return SocialPostReviewItem(
      reviewId: 'review-1',
      postId: 'post-1',
      sharedUrl: 'https://www.tiktok.com/@pinitfood/video/1',
      reviewStatus: status,
      canonicalUrl: 'https://www.tiktok.com/@pinitfood/video/1',
      platform: 'tiktok',
      creatorHandle: creator,
      title: title,
      postStatus: postStatus,
      sharedAt: DateTime.utc(2026, 7, 11),
      places: places,
      placeActions: actions,
      savedLocationIds: savedIds,
    );
  }

  const savedPlace = SocialPostPlace(
    id: 'place-1',
    name: 'Noodle Yard',
    address: '12 Greek Street, Soho',
    locationId: 42,
    confidenceScore: 0.92,
    confidenceTier: 'high',
    extractedContext: {
      'key_dishes': [
        {'name': 'Chilli noodles'},
      ],
    },
  );

  test('flattens places and marks saved high-confidence matches', () {
    final rows = SocialReviewPlaceItem.fromReviews([
      review(
        places: const [savedPlace],
        actions: const {'place-1': SocialPlaceAction.saved},
        savedIds: const {'place-1': 42},
      ),
    ]);

    expect(rows, hasLength(1));
    expect(rows.single.resolvedLocationId, 42);
    expect(rows.single.recentlySaved, isTrue);
    expect(rows.single.needsChecking, isFalse);
    expect(rows.single.statusLabel, 'Saved');
  });

  test('marks low-confidence unresolved matches as needing checking', () {
    const place = SocialPostPlace(
      id: 'place-2',
      name: 'Possible Cafe',
      candidateArea: 'Shoreditch',
      confidenceScore: 0.48,
      confidenceTier: 'low',
    );

    final row = SocialReviewPlaceItem.fromReviews([
      review(places: const [place]),
    ]).single;

    expect(row.needsChecking, isTrue);
    expect(row.recentlySaved, isFalse);
    expect(row.statusLabel, 'Check match');
  });

  test('creates one fallback row for a failed post without places', () {
    final row = SocialReviewPlaceItem.fromReviews([
      review(postStatus: 'failed'),
    ]).single;

    expect(row.place, isNull);
    expect(row.needsChecking, isTrue);
    expect(row.statusLabel, 'Find restaurant');
  });

  test('matches restaurant, address, creator, title, and dish searches', () {
    final row = SocialReviewPlaceItem.fromReviews([
      review(
        places: const [savedPlace],
        actions: const {'place-1': SocialPlaceAction.saved},
      ),
    ]).single.copyWith(
          location: LocationModel(
            locationId: 42,
            name: 'Noodle Yard',
            cuisine: 'Chinese',
            vicinity: 'Soho, London',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );

    expect(row.matchesQuery('noodle'), isTrue);
    expect(row.matchesQuery('chinese'), isTrue);
    expect(row.matchesQuery('greek street'), isTrue);
    expect(row.matchesQuery('pinitfood'), isTrue);
    expect(row.matchesQuery('best noodles'), isTrue);
    expect(row.matchesQuery('chilli noodles'), isTrue);
    expect(row.matchesQuery('pizza'), isFalse);
  });

  test('filters attention, saved, and all rows', () {
    const uncertain = SocialPostPlace(
      id: 'place-2',
      name: 'Possible Cafe',
      confidenceTier: 'low',
    );
    final rows = SocialReviewPlaceItem.fromReviews([
      review(
        places: const [savedPlace, uncertain],
        actions: const {'place-1': SocialPlaceAction.saved},
      ),
    ]);

    expect(
      visibleSocialReviewPlaces(
        rows,
        filter: SocialReviewInboxFilter.needsChecking,
        query: '',
      ).map((row) => row.id),
      ['place-2'],
    );
    expect(
      visibleSocialReviewPlaces(
        rows,
        filter: SocialReviewInboxFilter.recentlySaved,
        query: '',
      ).map((row) => row.id),
      ['place-1'],
    );
    expect(
      visibleSocialReviewPlaces(
        rows,
        filter: SocialReviewInboxFilter.all,
        query: 'possible',
      ).map((row) => row.id),
      ['place-2'],
    );
  });

  test('post projection keeps one row with candidate and location context', () {
    final post = SocialReviewPostItem(
      review: review(
        places: const [
          savedPlace,
          SocialPostPlace(
            id: 'place-2',
            name: 'Second Noodle Bar',
            locationId: 43,
            confidenceTier: 'high',
          ),
        ],
        actions: const {
          'place-1': SocialPlaceAction.saved,
          'place-2': SocialPlaceAction.saved,
        },
      ),
      locationsById: {
        42: LocationModel(
          locationId: 42,
          name: 'Noodle Yard',
          cuisine: 'Chinese',
          vicinity: 'Soho, London',
          priceLevel: 2,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      },
    );

    expect(post.id, 'review-1');
    expect(post.review.places, hasLength(2));
    expect(post.bestCandidate?.name, 'Noodle Yard');
    expect(post.insightChips, containsAll(['Chinese', 'Chilli noodles', '££']));
  });

  test('post search includes caption, creator, candidates, dishes and cuisine',
      () {
    final source = SocialPostReviewItem(
      reviewId: 'review-search',
      postId: 'post-search',
      sharedUrl: 'https://www.tiktok.com/video/search',
      reviewStatus: 'pending',
      canonicalUrl: 'https://www.tiktok.com/video/search',
      platform: 'tiktok',
      creatorHandle: 'pinitfood',
      title: 'Best noodles in Soho',
      caption: 'A cosy late-night bowl',
      postStatus: 'processed',
      sharedAt: DateTime.utc(2026, 7, 20),
      places: const [savedPlace],
      placeActions: const {'place-1': SocialPlaceAction.saved},
    );
    final post = SocialReviewPostItem(
      review: source,
      locationsById: {
        42: LocationModel(
          locationId: 42,
          name: 'Noodle Yard',
          cuisine: 'Chinese',
          vicinity: 'Soho, London',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      },
    );

    for (final query in [
      'pinitfood',
      'cosy',
      'Noodle Yard',
      'Greek Street',
      'Chilli noodles',
      'Chinese',
    ]) {
      expect(post.matchesQuery(query), isTrue, reason: query);
    }
    expect(post.matchesQuery('pizza'), isFalse);
  });

  test('post filters keep actionable, processing, resolved and all histories',
      () {
    final now = DateTime.now().toUtc();
    SocialPostReviewItem withId(
      String id, {
      required String reviewStatus,
      required String postStatus,
      List<SocialPostPlace> places = const [],
      Map<String, SocialPlaceAction> actions = const {},
      Set<String> confirmed = const {},
    }) {
      return SocialPostReviewItem(
        reviewId: id,
        postId: 'post-$id',
        sharedUrl: 'https://www.tiktok.com/video/$id',
        reviewStatus: reviewStatus,
        canonicalUrl: 'https://www.tiktok.com/video/$id',
        platform: 'tiktok',
        postStatus: postStatus,
        postUpdatedAt: now,
        sharedAt: now,
        places: places,
        placeActions: actions,
        userConfirmedPlaceIds: confirmed,
      );
    }

    final posts = [
      SocialReviewPostItem(
        review: withId(
          'checking',
          reviewStatus: 'pending',
          postStatus: 'processed',
        ),
      ),
      SocialReviewPostItem(
        review: withId(
          'processing',
          reviewStatus: 'pending',
          postStatus: 'processing',
        ),
      ),
      SocialReviewPostItem(
        review: withId(
          'saved',
          reviewStatus: 'reviewed',
          postStatus: 'processed',
          places: const [savedPlace],
          actions: const {'place-1': SocialPlaceAction.saved},
        ),
      ),
      SocialReviewPostItem(
        review: withId(
          'dismissed',
          reviewStatus: 'dismissed',
          postStatus: 'failed',
        ),
      ),
    ];

    expect(
      visibleSocialReviewPosts(
        posts,
        filter: SocialReviewInboxFilter.needsChecking,
        query: '',
      ).map((post) => post.id),
      ['checking'],
    );
    expect(
      visibleSocialReviewPosts(
        posts,
        filter: SocialReviewInboxFilter.processing,
        query: '',
      ).map((post) => post.id),
      ['processing'],
    );
    expect(
      visibleSocialReviewPosts(
        posts,
        filter: SocialReviewInboxFilter.recentlySaved,
        query: '',
      ).map((post) => post.id),
      ['saved'],
    );
    expect(
      visibleSocialReviewPosts(
        posts,
        filter: SocialReviewInboxFilter.all,
        query: '',
      ),
      hasLength(4),
    );
  });
}

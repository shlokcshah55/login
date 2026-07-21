import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/social_review_models.dart';
import 'package:login/pages/social_review/social_post_review_page.dart';
import 'package:login/providers/social_review_provider.dart';
import 'package:provider/provider.dart';

class _RecordingProvider extends SocialReviewProvider {
  _RecordingProvider(List<SocialPostReviewItem> items)
      : super(
          reviewLoader: () async => items,
          locationBatchLoader: (_) async => const [],
        );

  String? confirmedCandidateId;
  List<String> confirmedCandidateIds = [];
  LocationModel? correctedPlace;
  bool dismissed = false;

  @override
  Future<bool> confirmPlace(
    SocialPostReviewItem item,
    SocialPostPlace place,
  ) async {
    confirmedCandidateId = place.id;
    return true;
  }

  @override
  Future<bool> confirmPlaces(
    SocialPostReviewItem item, {
    required List<SocialPostPlace> selectedPlaces,
    LocationModel? additionalPlace,
  }) async {
    confirmedCandidateIds = selectedPlaces.map((place) => place.id).toList();
    correctedPlace = additionalPlace;
    return true;
  }

  @override
  Future<bool> correctPlace(
    SocialPostReviewItem item,
    SocialPostPlace place,
    LocationModel correctedPlace,
  ) async {
    confirmedCandidateId = place.id;
    this.correctedPlace = correctedPlace;
    return true;
  }

  @override
  Future<void> dismissPost(SocialPostReviewItem item) async {
    dismissed = true;
  }
}

void main() {
  SocialPostReviewItem review({String postStatus = 'processed'}) {
    final now = DateTime.now().toUtc();
    return SocialPostReviewItem(
      reviewId: 'review-1',
      postId: 'post-1',
      sharedUrl: 'https://www.tiktok.com/@foodwithmaya/video/1',
      reviewStatus: 'pending',
      canonicalUrl: 'https://www.tiktok.com/@foodwithmaya/video/1',
      platform: 'tiktok',
      creatorHandle: 'foodwithmaya',
      title: 'The Soho noodle spot to know',
      caption: 'Maya loved the hand-pulled chilli noodles and cosy late vibe.',
      postStatus: postStatus,
      vibes: const {'cosy': .91, 'late_night': .84},
      sentiment: 'positive',
      evidenceFlags: const {'caption': true, 'ocr': true},
      postUpdatedAt: now,
      sharedAt: now,
      places: postStatus == 'processing'
          ? const []
          : const [
              SocialPostPlace(
                id: 'candidate-1',
                name: 'Noodle Yard',
                candidateName: 'Noodle Yard',
                candidateArea: 'Soho',
                address: '12 Greek Street, London',
                locationId: 42,
                confidenceTier: 'medium',
                confidenceScore: .72,
                extractedContext: {
                  'creator_notes': 'Order the chilli oil on the side.',
                  'reasoning': 'Name and Soho location were both mentioned.',
                  'vibe_signals': {'casual': .9},
                  'special_offers': [
                    {'offer': 'Lunch menu for £12'},
                  ],
                  'key_dishes': [
                    {'name': 'Chilli noodles'},
                  ],
                },
              ),
              SocialPostPlace(
                id: 'candidate-2',
                name: 'Xi’an Corner',
                candidateArea: 'Chinatown',
                address: '8 Gerrard Street, London',
                confidenceTier: 'low',
                confidenceScore: .41,
              ),
            ],
      placeActions: postStatus == 'processing'
          ? const {}
          : const {'candidate-1': SocialPlaceAction.saved},
      savedLocationIds:
          postStatus == 'processing' ? const {} : const {'candidate-1': 42},
    );
  }

  testWidgets('shows post context, insights, ranked candidates and search',
      (tester) async {
    final provider = _RecordingProvider([review()]);
    await provider.refresh();

    await tester.pumpWidget(
      ChangeNotifierProvider<SocialReviewProvider>.value(
        value: provider,
        child: MaterialApp(
          home: SocialPostReviewPage(
            postId: 'post-1',
            onOpenOriginal: (_) async {},
            placeSearcher: (_) async => const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Review shared post'), findsOneWidget);
    expect(find.text('@foodwithmaya'), findsOneWidget);
    expect(
      find.text(
        'Maya loved the hand-pulled chilli noodles and cosy late vibe.',
      ),
      findsOneWidget,
    );
    expect(find.text('Open original'), findsOneWidget);
    expect(find.text('What Pinit found'), findsOneWidget);
    expect(find.text('Chilli noodles'), findsWidgets);
    expect(find.text('Casual'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Suggested restaurants'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Lunch menu for £12'), findsWidgets);
    expect(find.text('Noodle Yard'), findsOneWidget);
    expect(find.text('72% match'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Xi’an Corner'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Xi’an Corner'), findsOneWidget);
    expect(find.text('41% match'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Search restaurants, cafés or bars'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.widgetWithText(TextField, 'Search restaurants, cafés or bars'),
      findsOneWidget,
    );
    expect(find.text('Confirm restaurant'), findsOneWidget);
    expect(find.text('Dismiss post'), findsOneWidget);
  });

  testWidgets('keeps multiple ranked candidates selected and confirms both',
      (tester) async {
    final provider = _RecordingProvider([review()]);
    await provider.refresh();

    await tester.pumpWidget(
      ChangeNotifierProvider<SocialReviewProvider>.value(
        value: provider,
        child: MaterialApp(
          home: SocialPostReviewPage(
            postId: 'post-1',
            onOpenOriginal: (_) async {},
            placeSearcher: (_) async => const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Xi’an Corner'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Xi’an Corner'));
    await tester.pump();

    expect(find.text('Confirm 2 restaurants'), findsOneWidget);

    await tester.tap(find.text('Confirm 2 restaurants'));
    await tester.pump();

    expect(provider.confirmedCandidateIds, ['candidate-1', 'candidate-2']);
  });

  testWidgets('processing state keeps context without review actions',
      (tester) async {
    final provider = _RecordingProvider([review(postStatus: 'processing')]);
    await provider.refresh();

    await tester.pumpWidget(
      ChangeNotifierProvider<SocialReviewProvider>.value(
        value: provider,
        child: MaterialApp(
          home: SocialPostReviewPage(
            postId: 'post-1',
            onOpenOriginal: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Still processing'), findsOneWidget);
    expect(
      find.text('Pinit is analysing the post for restaurant details.'),
      findsOneWidget,
    );
    expect(find.text('Confirm restaurant'), findsNothing);
    expect(find.text('Dismiss post'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/social_review_models.dart';
import 'package:login/pages/social_review/social_post_places_sheet.dart';
import 'package:login/providers/social_review_provider.dart';
import 'package:login/widgets/home/location_list_card.dart';
import 'package:provider/provider.dart';

class _RecordingProvider extends SocialReviewProvider {
  _RecordingProvider(List<SocialPostReviewItem> items)
      : super(
          reviewLoader: () async => items,
          locationBatchLoader: (ids) async => [
            for (final id in ids)
              LocationModel(
                locationId: id,
                name: id == 42 ? 'Noodle Yard' : 'Dumpling Bar',
                createdAt: DateTime(2026, 1, 1),
                matchScore: id == 42 ? .87 : .64,
              ),
          ],
        );

  final List<String> discarded = [];
  final List<String> saved = [];
  LocationModel? added;

  @override
  Future<bool> discardPlace(
    SocialPostReviewItem item,
    SocialPostPlace place,
  ) async {
    discarded.add(place.id);
    return true;
  }

  @override
  Future<bool> savePlace(
    SocialPostReviewItem item,
    SocialPostPlace place,
  ) async {
    saved.add(place.id);
    return true;
  }

  @override
  Future<bool> addManualPlace(
    SocialPostReviewItem item,
    LocationModel pickedPlace,
  ) async {
    added = pickedPlace;
    return true;
  }
}

SocialPostReviewItem _review() {
  final now = DateTime.now().toUtc();
  return SocialPostReviewItem(
    reviewId: 'review-1',
    postId: 'post-1',
    sharedUrl: 'https://www.tiktok.com/@foodwithmaya/video/1',
    reviewStatus: 'pending',
    canonicalUrl: 'https://www.tiktok.com/@foodwithmaya/video/1',
    platform: 'tiktok',
    creatorHandle: 'foodwithmaya',
    caption: 'Three Soho noodle spots you need to try',
    postStatus: 'processed',
    postUpdatedAt: now,
    sharedAt: now,
    places: const [
      SocialPostPlace(
        id: 'p1',
        name: 'Noodle Yard',
        locationId: 42,
        confidenceTier: 'high',
        confidenceScore: .92,
      ),
      SocialPostPlace(
        id: 'p2',
        name: 'Dumpling Bar',
        locationId: 43,
        confidenceTier: 'high',
        confidenceScore: .81,
      ),
      SocialPostPlace(
        id: 'p3',
        name: 'Xi’an Corner',
        candidateArea: 'Chinatown',
        confidenceTier: 'low',
        confidenceScore: .41,
      ),
    ],
    placeActions: const {
      'p1': SocialPlaceAction.saved,
      'p2': SocialPlaceAction.saved,
    },
    savedLocationIds: const {'p1': 42, 'p2': 43},
  );
}

void main() {
  late _RecordingProvider provider;
  late int hintSeenCalls;
  SocialPostReviewItem? opened;

  setUp(() async {
    provider = _RecordingProvider([_review()]);
    await provider.refresh();
    hintSeenCalls = 0;
    opened = null;
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    bool showHint = false,
    List<LocationModel> searchResults = const [],
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<SocialReviewProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SocialPostPlacesSheet(
                postId: 'post-1',
                onOpenOriginal: (item) async => opened = item,
                placeSearcher: (_) async => searchResults,
                shouldShowSwipeHint: () async => showHint,
                markSwipeHintSeen: () async => hintSeenCalls++,
                undoWindow: const Duration(milliseconds: 300),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('header links to the post with creator and caption',
      (tester) async {
    await pumpSheet(tester);

    expect(find.text('TIKTOK · @foodwithmaya'), findsOneWidget);
    expect(find.text('Three Soho noodle spots you need to try'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('social-post-link')));
    expect(opened?.postId, 'post-1');
  });

  testWidgets('lists places as restaurant cards with match scores',
      (tester) async {
    await pumpSheet(tester);

    expect(find.text('3 places from this TikTok'), findsOneWidget);
    expect(find.byType(LocationListCard), findsNWidgets(2));
    expect(find.text('87% MATCH'), findsOneWidget);
    expect(find.text('64% MATCH'), findsOneWidget);
    expect(find.text('Xi’an Corner'), findsOneWidget);
    expect(find.text('NOT SAVED'), findsOneWidget);
  });

  testWidgets('swiping a card left removes it after the undo window',
      (tester) async {
    await pumpSheet(tester);

    await tester.drag(
      find.byKey(const ValueKey('social-place:p2')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dumpling Bar'), findsNothing);
    expect(find.text('Removed Dumpling Bar'), findsOneWidget);
    expect(provider.discarded, isEmpty);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(provider.discarded, ['p2']);
    expect(find.text('Removed Dumpling Bar'), findsNothing);
  });

  testWidgets('undo restores a swiped card without discarding it',
      (tester) async {
    await pumpSheet(tester);

    await tester.drag(
      find.byKey(const ValueKey('social-place:p2')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('UNDO'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Dumpling Bar'), findsOneWidget);
    expect(provider.discarded, isEmpty);
  });

  testWidgets('tick saves a place that was not auto-saved', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.byKey(const ValueKey('social-place-save')));
    await tester.pump();
    expect(provider.saved, ['p3']);
  });

  testWidgets('first open plays the swipe hint revealing the bin once',
      (tester) async {
    await pumpSheet(tester, showHint: true);
    expect(find.byKey(const ValueKey('social-place-bin')), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('social-place-bin')), findsOneWidget);
    expect(hintSeenCalls, 1);

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('social-place-bin')), findsNothing);
  });

  testWidgets('no hint once it has been seen', (tester) async {
    await pumpSheet(tester);
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.byKey(const ValueKey('social-place-bin')), findsNothing);
    expect(hintSeenCalls, 0);
  });

  testWidgets('adds a restaurant from search', (tester) async {
    final picked = LocationModel(
      locationId: -1,
      name: 'Bao Soho',
      googlePlaceId: 'g-bao',
      createdAt: DateTime(2026, 1, 1),
    );
    await pumpSheet(tester, searchResults: [picked]);

    await tester.tap(find.text('ADD A RESTAURANT'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'bao');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(find.text('Bao Soho'));
    await tester.pump();

    expect(provider.added?.googlePlaceId, 'g-bao');
  });
}

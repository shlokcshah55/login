import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/social_review_models.dart';
import 'package:login/pages/social_review/social_review_inbox_page.dart';
import 'package:login/pages/social_review/social_review_place_item.dart';
import 'package:login/providers/social_review_provider.dart';
import 'package:login/widgets/home/location_list_card.dart';
import 'package:provider/provider.dart';

void main() {
  Future<SocialReviewProvider> providerWithPlaces() async {
    final review = SocialPostReviewItem(
      reviewId: 'review-1',
      postId: 'post-1',
      sharedUrl: 'https://www.tiktok.com/@food/video/1',
      reviewStatus: 'pending',
      canonicalUrl: 'https://www.tiktok.com/@food/video/1',
      platform: 'tiktok',
      creatorHandle: 'food',
      title: 'Soho noodles',
      postStatus: 'processed',
      sharedAt: DateTime.utc(2026, 7, 11),
      places: const [
        SocialPostPlace(
          id: 'saved-place',
          name: 'Noodle Yard',
          address: 'Soho, London',
          locationId: 42,
          confidenceTier: 'high',
          confidenceScore: 0.93,
        ),
        SocialPostPlace(
          id: 'uncertain-place',
          name: 'Possible Cafe',
          candidateArea: 'Shoreditch',
          confidenceTier: 'low',
          confidenceScore: 0.44,
        ),
      ],
      placeActions: const {'saved-place': SocialPlaceAction.saved},
      savedLocationIds: const {'saved-place': 42},
    );
    final provider = SocialReviewProvider(
      reviewLoader: () async => [review],
      locationBatchLoader: (_) async => [
        LocationModel(
          locationId: 42,
          name: 'Noodle Yard',
          cuisine: 'Chinese',
          vicinity: 'Soho, London',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    );
    await provider.refresh();
    return provider;
  }

  testWidgets('defaults to attention, filters saved rows, and searches places',
      (tester) async {
    final provider = await providerWithPlaces();
    SocialReviewPlaceItem? opened;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: SocialReviewInboxPage(onOpenItem: (item) => opened = item),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shared saves'), findsOneWidget);
    expect(
        find.widgetWithText(TextField, 'Search restaurants'), findsOneWidget);
    expect(find.text('Needs checking'), findsOneWidget);
    expect(find.text('Recently saved'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Possible Cafe'), findsOneWidget);
    expect(find.text('Noodle Yard'), findsNothing);

    await tester.tap(find.text('Recently saved'));
    await tester.pumpAndSettle();

    expect(find.byType(LocationListCard), findsOneWidget);
    expect(find.text('Noodle Yard'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search restaurants'),
      'pizza',
    );
    await tester.pump();
    expect(find.text('No matching restaurants'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search restaurants'),
      'noodle',
    );
    await tester.pump();
    await tester.tap(find.byType(LocationListCard));

    expect(opened?.id, 'saved-place');
  });

  testWidgets('explicit initial filter overrides attention-first default',
      (tester) async {
    final provider = await providerWithPlaces();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: SocialReviewInboxPage(
            initialFilter: SocialReviewInboxFilter.recentlySaved,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Noodle Yard'), findsOneWidget);
    expect(find.text('Possible Cafe'), findsNothing);
  });
}

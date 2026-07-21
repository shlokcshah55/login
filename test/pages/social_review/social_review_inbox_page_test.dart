import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/social_review_models.dart';
import 'package:login/pages/social_review/social_review_inbox_page.dart';
import 'package:login/pages/social_review/social_review_place_item.dart';
import 'package:login/providers/social_review_provider.dart';
import 'package:provider/provider.dart';

void main() {
  Future<SocialReviewProvider> providerWithPosts() async {
    final now = DateTime.now().toUtc();
    final reviews = [
      SocialPostReviewItem(
        reviewId: 'review-check',
        postId: 'post-check',
        sharedUrl: 'https://www.tiktok.com/@food/video/1',
        reviewStatus: 'pending',
        canonicalUrl: 'https://www.tiktok.com/@food/video/1',
        platform: 'tiktok',
        creatorHandle: 'foodwithmaya',
        title: 'Late-night noodles in Soho',
        caption: 'The chilli noodles were worth crossing London for.',
        postStatus: 'processed',
        vibes: const {'cosy': 0.92, 'late_night': 0.8},
        postUpdatedAt: now,
        sharedAt: now,
        places: const [
          SocialPostPlace(
            id: 'possible-place',
            name: 'Noodle Yard',
            candidateName: 'Noodle Yard',
            candidateArea: 'Soho',
            address: '12 Greek Street, London',
            locationId: 42,
            confidenceTier: 'medium',
            confidenceScore: 0.72,
            extractedContext: {
              'key_dishes': [
                {'name': 'Chilli noodles'},
              ],
            },
          ),
        ],
        placeActions: const {'possible-place': SocialPlaceAction.saved},
        savedLocationIds: const {'possible-place': 42},
      ),
      SocialPostReviewItem(
        reviewId: 'review-processing',
        postId: 'post-processing',
        sharedUrl: 'https://www.instagram.com/reel/processing',
        reviewStatus: 'pending',
        canonicalUrl: 'https://www.instagram.com/reel/processing',
        platform: 'instagram',
        creatorHandle: 'eastlondoneats',
        title: 'A new East London opening',
        postStatus: 'processing',
        postUpdatedAt: now,
        sharedAt: now,
      ),
      SocialPostReviewItem(
        reviewId: 'review-resolved',
        postId: 'post-resolved',
        sharedUrl: 'https://www.instagram.com/reel/resolved',
        reviewStatus: 'reviewed',
        canonicalUrl: 'https://www.instagram.com/reel/resolved',
        platform: 'instagram',
        creatorHandle: 'brunchclub',
        title: 'Sunday brunch at Lila',
        postStatus: 'processed',
        postUpdatedAt: now,
        sharedAt: now,
        places: const [
          SocialPostPlace(
            id: 'saved-place',
            name: 'Lila',
            locationId: 43,
            confidenceTier: 'high',
            confidenceScore: 0.96,
          ),
        ],
        placeActions: const {'saved-place': SocialPlaceAction.saved},
        savedLocationIds: const {'saved-place': 43},
        userConfirmedPlaceIds: const {'saved-place'},
      ),
    ];

    final provider = SocialReviewProvider(
      reviewLoader: () async => reviews,
      locationBatchLoader: (_) async => [
        LocationModel(
          locationId: 42,
          name: 'Noodle Yard',
          cuisine: 'Chinese',
          vicinity: 'Soho, London',
          priceLevel: 2,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
        LocationModel(
          locationId: 43,
          name: 'Lila',
          cuisine: 'Cafe',
          vicinity: 'Hackney, London',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    );
    await provider.refresh();
    return provider;
  }

  testWidgets('renders one contextual card per shared post', (tester) async {
    final provider = await providerWithPosts();
    SocialPostReviewItem? opened;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: SocialReviewInboxPage(onOpenPost: (item) => opened = item),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shared saves'), findsOneWidget);
    expect(find.text('Needs checking'), findsWidgets);
    expect(find.text('Processing'), findsOneWidget);
    expect(find.text('Recently saved'), findsOneWidget);
    expect(find.text('@foodwithmaya'), findsOneWidget);
    expect(
      find.text('The chilli noodles were worth crossing London for.'),
      findsOneWidget,
    );
    expect(find.text('Noodle Yard'), findsOneWidget);
    expect(find.text('72% match'), findsOneWidget);
    expect(find.text('Chinese'), findsOneWidget);
    expect(find.text('Chilli noodles'), findsOneWidget);
    expect(find.text('££'), findsOneWidget);
    expect(find.text('Restaurant not identified'), findsNothing);

    await tester.tap(find.text('Review match'));
    expect(opened?.postId, 'post-check');
  });

  testWidgets('uses DM Sans for inbox copy while retaining the Rova heading',
      (tester) async {
    final provider = await providerWithPosts();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: SocialReviewInboxPage()),
      ),
    );
    await tester.pumpAndSettle();

    final heading = tester.widget<Text>(find.text('Shared saves'));
    expect(heading.style?.fontFamily, 'Rova');

    for (final label in [
      'See what Pinit found and finish anything uncertain.',
      'Needs checking',
      '@foodwithmaya',
      'The chilli noodles were worth crossing London for.',
      'Noodle Yard',
      '72% match',
      'Chinese',
    ]) {
      final matches = tester.widgetList<Text>(find.text(label));
      expect(matches, isNotEmpty, reason: 'Expected to find "$label"');
      for (final text in matches) {
        expect(
          text.style?.fontFamily,
          anyOf('DM Sans', startsWith('DMSans_')),
          reason: 'Expected "$label" to use DM Sans',
        );
      }
    }

    final search = tester.widget<TextField>(find.byType(TextField));
    expect(search.style?.fontFamily, anyOf('DM Sans', startsWith('DMSans_')));
    expect(
      search.decoration?.hintStyle?.fontFamily,
      anyOf('DM Sans', startsWith('DMSans_')),
    );

    final reviewButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Review match'),
    );
    expect(
      reviewButton.style?.textStyle?.resolve({})?.fontFamily,
      anyOf('DM Sans', startsWith('DMSans_')),
    );
  });

  testWidgets('filters processing and resolved posts, then searches context',
      (tester) async {
    final provider = await providerWithPosts();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: SocialReviewInboxPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Processing'));
    await tester.pumpAndSettle();
    expect(find.text('@eastlondoneats'), findsOneWidget);
    expect(find.text('A new East London opening'), findsOneWidget);

    await tester.tap(find.text('Recently saved'));
    await tester.pumpAndSettle();
    expect(find.text('@brunchclub'), findsOneWidget);
    expect(find.text('Sunday brunch at Lila'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search posts, creators or places'),
      'chilli',
    );
    await tester.pump();
    expect(find.text('@foodwithmaya'), findsOneWidget);
    expect(find.text('@eastlondoneats'), findsNothing);
  });

  testWidgets('explicit filter still overrides the attention-first default',
      (tester) async {
    final provider = await providerWithPosts();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: SocialReviewInboxPage(
            initialFilter: SocialReviewInboxFilter.processing,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('@eastlondoneats'), findsOneWidget);
    expect(find.text('@foodwithmaya'), findsNothing);
  });
}

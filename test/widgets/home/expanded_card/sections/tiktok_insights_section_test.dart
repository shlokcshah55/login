import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/video_insights.dart';
import 'package:login/widgets/home/expanded_card/sections/tiktok_insights_section.dart';

void main() {
  Widget buildSubject(VideoInsight insight) {
    return MaterialApp(
      home: Scaffold(
        body: TikTokInsightsSection(insight: insight),
      ),
    );
  }

  testWidgets('uses Reel wording for Instagram video insights', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        const VideoInsight(
          id: 'insight-1',
          sourceVideoUrl: 'https://www.instagram.com/reel/abc123/',
          locationId: 42,
          creatorNotes: 'Worth saving for later.',
        ),
      ),
    );

    expect(find.text('FROM THIS REEL'), findsOneWidget);
    expect(find.text('FROM THIS TIKTOK'), findsNothing);
  });

  testWidgets('keeps TikTok wording for TikTok video insights', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        const VideoInsight(
          id: 'insight-2',
          sourceVideoUrl: 'https://www.tiktok.com/@chef/video/123',
          locationId: 42,
          creatorNotes: 'Worth saving for later.',
        ),
      ),
    );

    expect(find.text('FROM THIS TIKTOK'), findsOneWidget);
  });

  testWidgets('uses generic wording when the social platform is unknown',
      (tester) async {
    await tester.pumpWidget(
      buildSubject(
        const VideoInsight(
          id: 'insight-3',
          sourceVideoUrl: 'https://example.com/video/123',
          locationId: 42,
          creatorNotes: 'Worth saving for later.',
        ),
      ),
    );

    expect(find.text('FROM THIS SOCIAL VIDEO'), findsOneWidget);
    expect(find.text('FROM THIS TIKTOK'), findsNothing);
  });

  testWidgets('tapping a dish card opens the full dish notes', (tester) async {
    const description =
        'A crisp-edged masala dosa with coconut chutney, tomato chutney, '
        'sambar, and a longer creator note that should be readable in full.';

    await tester.pumpWidget(
      buildSubject(
        const VideoInsight(
          id: 'insight-4',
          sourceVideoUrl: 'https://www.tiktok.com/@chef/video/123',
          locationId: 42,
          keyDishes: [
            DishHighlight(
              name: 'Masala dosa',
              description: description,
              price: '£9',
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Masala dosa'));
    await tester.pumpAndSettle();

    expect(find.text('Dish notes'), findsOneWidget);
    expect(find.text('Masala dosa'), findsNWidgets(2));
    expect(find.text(description), findsNWidgets(2));
  });

  testWidgets('long dish notes scroll inside the dish card', (tester) async {
    final description = List.filled(
      12,
      'Crispy chilli noodles with garlic oil, herbs, pickles, and extra sauce.',
    ).join(' ');

    await tester.pumpWidget(
      buildSubject(
        VideoInsight(
          id: 'insight-5',
          sourceVideoUrl: 'https://www.tiktok.com/@chef/video/456',
          locationId: 42,
          keyDishes: [
            DishHighlight(
              name: 'Chilli noodles',
              description: description,
              price: '£12',
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text(description),
      ),
      findsOneWidget,
    );

    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -40),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/widgets/home/expanded_card/sections/social_match_section.dart';
import 'package:login/widgets/home/expanded_card/social_review_context.dart';

void main() {
  Widget subject(SocialReviewContext context) {
    return MaterialApp(
      home: Scaffold(body: SocialMatchSection(context: context)),
    );
  }

  testWidgets('shows numeric TikTok confidence and strong label',
      (tester) async {
    await tester.pumpWidget(
      subject(
        const SocialReviewContext(
          platform: 'tiktok',
          placeName: 'Dishoom Shoreditch',
          confidenceScore: 0.92,
          confidenceTier: 'high',
        ),
      ),
    );

    expect(find.text('TikTok match'), findsOneWidget);
    expect(find.text('92% · Strong match'), findsOneWidget);
    expect(
      find.text('We matched this post to Dishoom Shoreditch.'),
      findsOneWidget,
    );
  });

  testWidgets('uses Reel wording and omits percentage for tier-only matches',
      (tester) async {
    await tester.pumpWidget(
      subject(
        const SocialReviewContext(
          platform: 'instagram',
          placeName: 'Cafe East',
          confidenceTier: 'low',
        ),
      ),
    );

    expect(find.text('Reel match'), findsOneWidget);
    expect(find.text('Needs checking'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('only renders supplied review actions', (tester) async {
    await tester.pumpWidget(
      subject(
        SocialReviewContext(
          platform: 'tiktok',
          placeName: 'Cafe East',
          confidenceTier: 'medium',
          onCorrect: () {},
          onRemove: () {},
        ),
      ),
    );

    expect(find.text('Correct restaurant'), findsOneWidget);
    expect(find.text('Remove from saves'), findsOneWidget);
    expect(find.text('Confirm match'), findsNothing);
  });
}

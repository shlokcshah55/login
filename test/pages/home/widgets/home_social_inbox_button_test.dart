import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/pages/home/widgets/home_social_inbox_button.dart';

void main() {
  testWidgets('shows the outstanding count and invokes its callback',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeSocialInboxButton(
            count: 3,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('home_social_inbox_button')), findsOneWidget);
    expect(find.byIcon(FeatherIcons.inbox), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Open shared saves inbox, 3 need checking'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('home_social_inbox_button')));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('hides the count badge when nothing needs checking',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeSocialInboxButton(count: 0, onTap: () {}),
        ),
      ),
    );

    expect(find.text('0'), findsNothing);
    expect(
      find.bySemanticsLabel('Open shared saves inbox'),
      findsOneWidget,
    );
  });
}

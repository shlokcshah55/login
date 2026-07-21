import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/pages/home/widgets/home_social_inbox_button.dart';
import 'package:login/pages/home/widgets/mode_toggle.dart';

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

  testWidgets('home mode row exposes a neutral trailing action',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: HomeChipRow(
              currentMode: HomeMode.you,
              onModeChanged: (_) {},
              collections: const [],
              isLoadingCollections: false,
              onCollectionMenuOpened: () {},
              onCollectionSelected: (_) {},
              trailingAction: const Text('Inbox action'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Inbox action'), findsOneWidget);
  });
}

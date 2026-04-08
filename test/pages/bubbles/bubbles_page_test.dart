import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/bubble.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/bubbles/bubbles_page_view.dart';
import 'package:login/pages/bubbles/bubbles_search_state.dart';
import 'package:login/themes/pinit_theme.dart';

void main() {
  test('builds bubbles-first mixed search sections', () {
    final sections = buildBubblesSearchSections(
      query: 'br',
      bubbles: [
        Bubble(
          id: 'bubble-1',
          name: 'Brunch Crew',
          lastMessage: 'See you there',
          lastMessageTime: '2m',
          memberCount: 6,
          memberAvatars: const [],
          groupAvatar: '',
        ),
      ],
      people: [
        UserModel(
          email: 'brian@example.com',
          username: 'brian',
          name: 'Brian',
        ),
      ],
    );

    expect(sections.first.type, BubblesSearchSectionType.bubbles);
    expect(sections.first.items.single.title, 'Brunch Crew');
    expect(sections.last.type, BubblesSearchSectionType.people);
  });

  testWidgets('shows the bubble feed before search is active', (tester) async {
    await tester.pumpWidget(
      _BubblesHarness(
        searchPeople: (_) async => const [],
      ),
    );

    expect(find.text('Bubbles'), findsOneWidget);
    expect(find.text('Weekend Brunch'), findsOneWidget);
    expect(find.byKey(const Key('bubbles_people_section')), findsNothing);
  });

  testWidgets('shows the compact flat bubbles header', (tester) async {
    await tester.pumpWidget(
      _BubblesHarness(
        searchPeople: (_) async => const [],
      ),
    );

    final header = tester.widget<Container>(
      find.byKey(const Key('bubbles_compact_header')),
    );

    final decoration = header.decoration as BoxDecoration;

    expect(decoration.gradient, isNull);
    expect(decoration.borderRadius, BorderRadius.circular(18));
    expect(
      find.text('Your people, plans, and shared pins in one playful inbox.'),
      findsNothing,
    );
  });

  testWidgets('clearing or superseding search hides stale people results', (
    tester,
  ) async {
    final supersededSearch = Completer<List<UserModel>>();
    final clearedSearch = Completer<List<UserModel>>();
    final requests = <String>[];

    await tester.pumpWidget(
      _BubblesHarness(
        searchPeople: (query) {
          requests.add(query);
          switch (query) {
            case 'ava':
              return supersededSearch.future;
            case 'mara':
              return clearedSearch.future;
            case 'alex':
              return Future.value([
                UserModel(
                  email: 'alex@example.com',
                  username: 'alex',
                  name: 'Alex Stone',
                ),
              ]);
            default:
              return Future.value(const []);
          }
        },
      ),
    );

    await tester.enterText(
      find.byKey(const Key('bubbles_universal_search_field')),
      'ava',
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('bubbles_universal_search_field')),
      'alex',
    );
    await tester.pumpAndSettle();

    supersededSearch.complete([
      UserModel(
        email: 'ava@example.com',
        username: 'ava',
        name: 'Ava Stone',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Ava Stone'), findsNothing);
    expect(find.text('Alex Stone'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('bubbles_universal_search_field')),
      'mara',
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();

    clearedSearch.complete([
      UserModel(
        email: 'mara@example.com',
        username: 'mara',
        name: 'Mara Stone',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Mara Stone'), findsNothing);
    expect(find.byKey(const Key('bubbles_people_section')), findsNothing);
    expect(requests, ['ava', 'alex', 'mara']);
  });

  testWidgets('search shell stays compact with 18px radius and padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      _BubblesHarness(
        searchPeople: (_) async => const [],
      ),
    );

    final searchShell = tester.widget<Container>(
      find.byKey(const Key('bubbles_search_shell')),
    );

    final decoration = searchShell.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(18));

    final textField = tester.widget<TextField>(
      find.byKey(const Key('bubbles_universal_search_field')),
    );
    expect(
      textField.decoration?.contentPadding,
      const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    );
  });

  testWidgets('typing into search shows bubbles and people sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      _BubblesHarness(
        searchPeople: (_) async => [
          UserModel(
            email: 'ava@example.com',
            username: 'ava',
            name: 'Ava Stone',
          ),
        ],
      ),
    );

    await tester.enterText(
      find.byKey(const Key('bubbles_universal_search_field')),
      'br',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bubbles_bubbles_section')), findsOneWidget);
    expect(find.byKey(const Key('bubbles_people_section')), findsOneWidget);
    expect(find.text('Weekend Brunch'), findsOneWidget);
    expect(find.text('ava'), findsOneWidget);
  });

  testWidgets('tapping a bubble row opens the preview callback',
      (tester) async {
    await tester.pumpWidget(
      _BubblesHarness(
        searchPeople: (_) async => const [],
      ),
    );

    await tester.tap(find.byKey(const Key('bubble_tile_surface_bubble-1')));
    await tester.pump();

    final state =
        tester.state<_BubblesHarnessState>(find.byType(_BubblesHarness));
    expect(state.openedBubbleId, 'bubble-1');
  });

  testWidgets('bubble tile surface is denser and uses the new surface key', (
    tester,
  ) async {
    await tester.pumpWidget(
      _BubblesHarness(
        searchPeople: (_) async => const [],
      ),
    );

    final surface = find.byKey(const Key('bubble_tile_surface_bubble-1'));
    expect(surface, findsOneWidget);

    final tile = tester.widget<Container>(surface);
    final decoration = tile.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(18));
    expect(tester.getSize(surface).height, lessThan(150));

    final avatarShell =
        find.byKey(const Key('bubble_tile_avatar_shell_bubble-1'));
    expect(avatarShell, findsOneWidget);
    expect(tester.getSize(avatarShell), const Size(56, 56));

    final avatarContainer = tester.widget<Container>(avatarShell);
    final avatarDecoration = avatarContainer.decoration as BoxDecoration;
    expect(avatarDecoration.borderRadius, BorderRadius.circular(16));

    final metadataChip =
        find.byKey(const Key('bubble_tile_metadata_chip_members_bubble-1'));
    expect(metadataChip, findsOneWidget);

    final chipContainer = tester.widget<Container>(metadataChip);
    final chipDecoration = chipContainer.decoration as BoxDecoration;
    expect(chipDecoration.borderRadius, BorderRadius.circular(16));
  });
}

class _BubblesHarness extends StatefulWidget {
  const _BubblesHarness({
    required this.searchPeople,
  });

  final Future<List<UserModel>> Function(String query) searchPeople;

  @override
  State<_BubblesHarness> createState() => _BubblesHarnessState();
}

class _BubblesHarnessState extends State<_BubblesHarness> {
  String? openedBubbleId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: PinitTheme.light(),
      home: BubblesPageView(
        bubbles: [
          Bubble(
            id: 'bubble-1',
            name: 'Weekend Brunch',
            lastMessage: 'Let\'s lock the cafe',
            lastMessageTime: '2m',
            memberCount: 6,
            memberAvatars: const [],
            groupAvatar: '',
            unreadCount: 3,
          ),
        ],
        isLoading: false,
        errorText: null,
        searchDebounce: Duration.zero,
        onRefresh: () async {},
        onCreateBubble: () {},
        onSearchPeople: widget.searchPeople,
        onBubbleTap: (bubble) {
          setState(() {
            openedBubbleId = bubble.id;
          });
        },
        onPersonTap: (_) {},
      ),
    );
  }
}

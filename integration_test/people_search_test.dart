// Integration tests for the People Search feature.
//
// Two surfaces are exercised:
//  1. `buildBubblesSearchSections` — pure function that produces the search
//     sections shown on the bubbles page. Covers query normalization,
//     bubble-field matching, people fallthrough, and loading/error states.
//  2. `UserListPage` — the profile page used for followers / following /
//     suggestions. Its `loader` is an injected async callback, which is
//     trivial to fake without touching Supabase.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:login/models/users.dart';
import 'package:login/pages/bubbles/bubbles_search_state.dart';
import 'package:login/pages/profile/user_list_page.dart';
import 'package:login/supabase/service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '_helpers/test_fixtures.dart';

class _MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('buildBubblesSearchSections', () {
    test('returns all bubbles and all people when query is empty', () {
      final sections = buildBubblesSearchSections(
        query: '',
        bubbles: [
          buildBubble(id: 'b1', name: 'Pizza Night'),
          buildBubble(id: 'b2', name: 'Ramen Run'),
        ],
        people: [
          buildUser(email: 'alex@example.com', username: 'alex'),
          buildUser(email: 'sam@example.com', username: 'sam'),
        ],
      );

      expect(sections, hasLength(2));
      expect(sections.first.type, BubblesSearchSectionType.bubbles);
      expect(sections.first.items, hasLength(2));
      expect(sections.last.type, BubblesSearchSectionType.people);
      expect(sections.last.items, hasLength(2));
    });

    test('query filters bubbles by name, description, and last message', () {
      final sections = buildBubblesSearchSections(
        query: 'pizza',
        bubbles: [
          buildBubble(id: 'b1', name: 'Pizza Night', description: ''),
          buildBubble(id: 'b2', name: 'Taco Tuesday', description: 'pizza too'),
          buildBubble(
            id: 'b3',
            name: 'Ramen Run',
            description: 'noodles',
            lastMessage: 'bringing pizza',
          ),
          buildBubble(id: 'b4', name: 'Sushi', description: 'rolls'),
        ],
        people: const [],
      );

      final bubblesSection =
          sections.firstWhere((s) => s.type == BubblesSearchSectionType.bubbles);
      expect(bubblesSection.items.map((i) => i.id), ['b1', 'b2', 'b3']);
    });

    test('query is case-insensitive and trimmed', () {
      final sections = buildBubblesSearchSections(
        query: '  PIZZA  ',
        bubbles: [buildBubble(id: 'b1', name: 'pizza night')],
        people: const [],
      );
      final bubblesSection =
          sections.firstWhere((s) => s.type == BubblesSearchSectionType.bubbles);
      expect(bubblesSection.items, hasLength(1));
    });

    test('bubble subtitle falls back to member count when no last message', () {
      final sections = buildBubblesSearchSections(
        query: '',
        bubbles: [
          buildBubble(id: 'b1', lastMessage: '', memberCount: 5),
        ],
        people: const [],
      );
      final item = sections.first.items.single;
      expect(item.subtitle, contains('5'));
      expect(item.subtitle.toLowerCase(), contains('member'));
    });

    test('unread badge is set only when unreadCount > 0', () {
      final sections = buildBubblesSearchSections(
        query: '',
        bubbles: [
          buildBubble(id: 'b1', unreadCount: 0),
          buildBubble(id: 'b2', unreadCount: 3),
        ],
        people: const [],
      );
      final items = sections.first.items;
      expect(items[0].badgeText, isNull);
      expect(items[1].badgeText, contains('3'));
    });

    test('people items use username → name → email for title fallback', () {
      final sections = buildBubblesSearchSections(
        query: '',
        bubbles: const [],
        people: [
          buildUser(username: 'alex99', name: 'Alex', email: 'a@x.com'),
          buildUser(username: null, name: 'Bea', email: 'b@x.com'),
          buildUser(username: null, name: null, email: 'c@x.com'),
        ],
      );
      final items =
          sections.firstWhere((s) => s.type == BubblesSearchSectionType.people).items;
      expect(items[0].title, 'alex99');
      expect(items[1].title, 'Bea');
      expect(items[2].title, 'c@x.com');
    });

    test('loading and error states are forwarded to the people section', () {
      final sections = buildBubblesSearchSections(
        query: '',
        bubbles: const [],
        people: const [],
        isPeopleLoading: true,
        peopleErrorText: 'network down',
      );
      final peopleSection =
          sections.firstWhere((s) => s.type == BubblesSearchSectionType.people);
      expect(peopleSection.isLoading, isTrue);
      expect(peopleSection.errorText, 'network down');
    });
  });

  group('UserListPage widget', () {
    late _MockSupabaseService service;

    setUp(() {
      service = _MockSupabaseService();
    });

    Widget wrap(Widget child) {
      return MaterialApp(
        home: Provider<SupabaseService>.value(value: service, child: child),
      );
    }

    testWidgets('shows a spinner while the loader is pending',
        (tester) async {
      final completer = Completer<List<UserModel>>();

      await tester.pumpWidget(
        wrap(
          UserListPage(
            title: 'Followers',
            loader: (_) => completer.future,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);

      completer.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('renders the empty state when loader yields []',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          UserListPage(
            title: 'Followers',
            loader: (_) async => const <UserModel>[],
            emptyMessage: 'No followers yet',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No followers yet'), findsOneWidget);
    });

    testWidgets('renders one UserCard per returned user', (tester) async {
      // supabaseId intentionally null — UserCard's follow-status lookup
      // early-returns for null ids, so we don't need to stub SupabaseService.
      final users = [
        buildUser(supabaseId: null, email: 'a@example.com', name: 'Alice'),
        buildUser(supabaseId: null, email: 'b@example.com', name: 'Bob'),
        buildUser(supabaseId: null, email: 'c@example.com', name: 'Carol'),
      ];

      await tester.pumpWidget(
        wrap(
          UserListPage(
            title: 'Suggestions',
            loader: (_) async => users,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Carol'), findsOneWidget);
    });

    testWidgets('loader receives the SupabaseService injected via Provider',
        (tester) async {
      SupabaseService? captured;
      await tester.pumpWidget(
        wrap(
          UserListPage(
            title: 'Following',
            loader: (s) async {
              captured = s;
              return const <UserModel>[];
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(captured, same(service));
    });
  });
}


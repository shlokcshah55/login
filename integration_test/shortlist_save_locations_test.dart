// Integration tests for saving locations (the Shortlist feature).
//
// ShortlistProvider is the in-memory "plan this now" list — distinct from
// long-term "Saved" bookmarks persisted in Supabase. These tests cover the
// provider's public contract and a minimal widget binding via Provider.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:login/providers/shortlist_provider.dart';
import 'package:provider/provider.dart';

import '_helpers/test_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ShortlistProvider — state transitions', () {
    late ShortlistProvider provider;
    late int notifyCount;

    setUp(() {
      provider = ShortlistProvider();
      notifyCount = 0;
      provider.addListener(() => notifyCount++);
    });

    test('starts empty', () {
      expect(provider.isEmpty, isTrue);
      expect(provider.isNotEmpty, isFalse);
      expect(provider.count, 0);
      expect(provider.items, isEmpty);
    });

    test('add() appends and notifies listeners', () {
      provider.add(buildLocation(locationId: 1, name: 'Luigi\'s'));

      expect(provider.count, 1);
      expect(provider.isNotEmpty, isTrue);
      expect(provider.contains(1), isTrue);
      expect(notifyCount, 1);
    });

    test('add() is idempotent — re-adding the same id does NOT notify', () {
      final loc = buildLocation(locationId: 42);
      provider.add(loc);
      provider.add(loc); // second add should be a no-op

      expect(provider.count, 1);
      expect(notifyCount, 1, reason: 'duplicate add must not notify');
    });

    test('remove() deletes and notifies', () {
      provider.add(buildLocation(locationId: 1));
      provider.add(buildLocation(locationId: 2));
      notifyCount = 0;

      provider.remove(1);

      expect(provider.count, 1);
      expect(provider.contains(1), isFalse);
      expect(provider.contains(2), isTrue);
      expect(notifyCount, 1);
    });

    test('remove() of an absent id is a safe no-op', () {
      provider.add(buildLocation(locationId: 5));
      notifyCount = 0;

      provider.remove(999);

      expect(provider.count, 1);
      // removeWhere on an empty match still "succeeds" so this may or may not
      // notify depending on implementation — the important invariant is state.
      expect(provider.contains(5), isTrue);
    });

    test('toggle() adds when absent, removes when present', () {
      final loc = buildLocation(locationId: 7);

      provider.toggle(loc);
      expect(provider.contains(7), isTrue);
      expect(provider.count, 1);

      provider.toggle(loc);
      expect(provider.contains(7), isFalse);
      expect(provider.count, 0);
    });

    test('clear() empties the list and notifies exactly once', () {
      provider.add(buildLocation(locationId: 1));
      provider.add(buildLocation(locationId: 2));
      provider.add(buildLocation(locationId: 3));
      notifyCount = 0;

      provider.clear();

      expect(provider.isEmpty, isTrue);
      expect(notifyCount, 1);
    });

    test('clear() on an empty list does NOT notify', () {
      provider.clear();
      expect(notifyCount, 0);
    });

    test('items getter returns an unmodifiable view', () {
      provider.add(buildLocation(locationId: 1));
      expect(
        () => provider.items.add(buildLocation(locationId: 2)),
        throwsUnsupportedError,
      );
    });
  });

  group('ShortlistProvider — widget integration', () {
    testWidgets('a Consumer rebuilds when items change', (tester) async {
      final provider = ShortlistProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ShortlistProvider>.value(
            value: provider,
            child: Scaffold(
              body: Consumer<ShortlistProvider>(
                builder: (context, p, _) => Center(
                  child: Text('count:${p.count}'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('count:0'), findsOneWidget);

      provider.add(buildLocation(locationId: 10));
      await tester.pump();
      expect(find.text('count:1'), findsOneWidget);

      provider.toggle(buildLocation(locationId: 11));
      await tester.pump();
      expect(find.text('count:2'), findsOneWidget);

      provider.clear();
      await tester.pump();
      expect(find.text('count:0'), findsOneWidget);
    });
  });
}

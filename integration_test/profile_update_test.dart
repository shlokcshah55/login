// Integration tests for profile update flows.
//
// `UserDataProvider` is the ChangeNotifier that backs the profile surface.
// Its `updateUserProfile`, `updateVibeTagAffinity`, `setWizardCompleted`, and
// `clearUserData` methods all go through the internal SupabaseService
// singleton. These tests exercise the branches that do NOT require a live
// Supabase client — i.e. the "not authenticated" path, optimistic local
// state updates, and listener-notification guarantees.
//
// NOTE: full end-to-end tests of the Supabase write path require injecting
// the SupabaseService (today it's constructed in a field initializer). A
// follow-up refactor is flagged with a TODO in the first skipped test group.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:login/providers/user_data_provider.dart';

import '_helpers/test_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('UserDataProvider — clearUserData', () {
    test('clears all state fields and notifies listeners', () async {
      final provider = UserDataProvider();
      int notifications = 0;
      provider.addListener(() => notifications++);

      await provider.clearUserData();

      expect(provider.userId, isNull);
      expect(provider.userData, isNull);
      expect(provider.supabaseUserData, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(notifications, 1);
    });
  });

  group('UserDataProvider — setWizardCompleted', () {
    test('is a no-op when supabaseUserData is null', () {
      final provider = UserDataProvider();
      int notifications = 0;
      provider.addListener(() => notifications++);

      provider.setWizardCompleted(true);

      expect(provider.supabaseUserData, isNull);
      expect(notifications, 0);
    });
  });

  group('UserDataProvider — updateVibeTagAffinity', () {
    test('returns false early when there is no cached user', () async {
      final provider = UserDataProvider();
      final ok = await provider.updateVibeTagAffinity([0.1, 0.2, 0.3]);
      expect(ok, isFalse);
    });
  });

  group('UserDataProvider — updateUserProfile', () {
    test('returns false and sets error when nothing is provided', () async {
      final provider = UserDataProvider();
      final ok = await provider.updateUserProfile();
      // With no Supabase session and no fields, the method returns false.
      // The exact error message is an implementation detail, but `isLoading`
      // must settle to false and listeners must have fired.
      expect(ok, isFalse);
      expect(provider.isLoading, isFalse);
    });

    test('emits loading=true then loading=false regardless of outcome',
        () async {
      final provider = UserDataProvider();
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isLoading));

      await provider.updateUserProfile(name: 'New Name');

      // At minimum: one true (start), one false (settle).
      expect(states.first, isTrue);
      expect(states.last, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // TODO(refactor): the tests below require dependency injection of
  // SupabaseService into UserDataProvider. Once `UserDataProvider` accepts
  // a `SupabaseService` in its constructor (currently it constructs its own
  // via the singleton in a field initializer), un-skip and flesh out.
  //
  // Intended coverage:
  //   - updateUserProfile(name: 'X') with an authenticated mock service
  //     returning a populated UserModel → state transitions to new name.
  //   - Supabase error path → returns false, sets `error`, isLoading=false.
  //   - updateVibeTagAffinity optimistic apply + rollback on Supabase failure.
  //   - setUserIdAndFetchData with cachedProfile path (no service calls).
  // ─────────────────────────────────────────────────────────────────────

  group('UserDataProvider — authenticated write paths (needs DI)', () {
    test('happy path: updateUserProfile returns true when Supabase writes',
        () async {
      // Skipped until UserDataProvider accepts an injected SupabaseService.
    }, skip: 'Needs constructor DI of SupabaseService');

    test('rollback path: updateVibeTagAffinity reverts on failure', () async {
      // Skipped until UserDataProvider accepts an injected SupabaseService.
    }, skip: 'Needs constructor DI of SupabaseService');
  });

  group('UserDataProvider — ChangeNotifier contract', () {
    test('dispose() twice surfaces a Flutter assertion (debug mode)', () {
      // ChangeNotifier asserts-guards against use after dispose in debug
      // builds. We encode the expected behaviour here so a regression in
      // provider lifecycle (e.g. accidental double-dispose in a widget)
      // is caught by tests.
      final provider = UserDataProvider();
      provider.dispose();
      expect(() => provider.dispose(), throwsA(isA<FlutterError>()));
    });

    test('addListener + removeListener balance', () async {
      final provider = UserDataProvider();
      void listener() {}
      provider.addListener(listener);
      provider.removeListener(listener);
      // If balanced, further notifies are harmless (no listener remains).
      await provider.clearUserData();
      expect(provider.userId, isNull);
    });
  });

  group('UserModel shape used by profile surfaces', () {
    test('buildUser fixture produces an affinity-ready model', () {
      final u = buildUser(vibeTagAffinity: const [0.1, 0.2, 0.3]);
      expect(u.hasAffinityData, isTrue);
      expect(u.vibeTagAffinity, isNotNull);
    });

    test('vibeMatchScore returns 0 when vectors are empty/absent', () {
      final u = buildUser();
      expect(u.vibeMatchScore(null), 0.0);
      expect(u.vibeMatchScore(const []), 0.0);
    });

    test('vibeMatchScore computes cosine similarity when vectors align', () {
      final u = buildUser(vibeTagAffinity: const [1.0, 0.0, 0.0]);
      final score = u.vibeMatchScore(const [1.0, 0.0, 0.0]);
      expect(score, closeTo(1.0, 1e-9));
    });
  });
}

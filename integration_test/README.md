# Integration Test Suite

End-to-end style tests for PinIt's core flows. Runs on a real device or
simulator via Flutter's `integration_test` package, with `mocktail` + the
`package:http/testing` `MockClient` standing in for the network.

## Covered features

| File                                   | What it exercises |
| -------------------------------------- | ----------------- |
| `shortlist_save_locations_test.dart`   | `ShortlistProvider` add/remove/toggle/clear + notification semantics; Provider-backed widget rebuild. |
| `people_search_test.dart`              | `buildBubblesSearchSections` (query normalization, field matching, fallbacks); `UserListPage` widget with an injected loader. |
| `profile_update_test.dart`             | `UserDataProvider` state transitions (clearUserData, setWizardCompleted, updateVibeTagAffinity guard path, updateUserProfile loading/error). |
| `recommendations_test.dart`            | `RecommendationsApi.fetchProximal`, `fetchProximalBubble`, `addLocationByGooglePlaceId`; request shape, retry behaviour on 5xx, defensive `ProximalResponse.fromJson`. |
| `bubble_messaging_test.dart`           | `MessagingHelper.sendMessage` contract (text, location-pin, replies, error propagation) plus adjacent read/mark-read ops. |
| `magic_search_test.dart`               | `NaturalLanguageSearchService.search` request shape, empty/malformed responses, error propagation. |
| `_helpers/test_fixtures.dart`          | Factory helpers: `buildLocation`, `buildUser`, `buildBubble`, `fakeProximalResponseJson`. |

## Running

Prerequisite: a running simulator/emulator or a connected device.

```bash
# all integration tests
flutter test integration_test/

# a single file
flutter test integration_test/recommendations_test.dart

# on a specific device
flutter test integration_test/ -d iPhone
```

For pure-Dart / headless CI runs of the non-widget tests you can also use:

```bash
flutter test test/
```

…but the widget tests in `people_search_test.dart` and
`shortlist_save_locations_test.dart` require the Flutter binding and
should run through `integration_test`.

## Adding new tests

1. Drop a new `*_test.dart` file under `integration_test/`.
2. Start with:

   ```dart
   import 'package:flutter_test/flutter_test.dart';
   import 'package:integration_test/integration_test.dart';

   void main() {
     IntegrationTestWidgetsFlutterBinding.ensureInitialized();
     // …
   }
   ```

3. Prefer injecting `http.Client` (via `MockClient`) or `SupabaseService`
   / helper classes (via `mocktail` mocks) over touching real services.
4. Reuse `_helpers/test_fixtures.dart` — keep domain object construction
   out of the test bodies.

## Deferred coverage (needs DI refactors)

A few flows could not be driven hermetically because the production
classes construct their Supabase dependencies internally. These tests
are present but marked with `skip:` — un-skip once the refactors below
land:

- **`UserDataProvider`** — accept `SupabaseService` as a constructor
  argument instead of calling `SupabaseService()` in a field
  initialiser. Enables full `updateUserProfile` / `updateVibeTagAffinity`
  happy-path + rollback tests.
- **`NaturalLanguageSearchService`** hydration path — accept an
  injectable `PostgrestClient` (or route the `locations` query through
  `LocationHelper` on the injected `SupabaseService`). Enables testing
  end-to-end id-→-`LocationModel` hydration.
- **`MessagingHelper`** — accept a `SupabaseClient` in its constructor
  instead of pulling from `SupabaseClientManager()`. Enables exercising
  the real `send_message` RPC wiring (today we test the caller contract
  via a mocktail mock).

## Dependencies

Added to `pubspec.yaml → dev_dependencies`:

```yaml
integration_test:
  sdk: flutter
mocktail: ^1.0.4
```

`package:http/testing.dart` (for `MockClient`) is already transitively
available via the `http` dependency — no extra install required.

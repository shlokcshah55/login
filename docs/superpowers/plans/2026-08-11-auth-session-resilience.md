# Auth Session Resilience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop logging users out on transient network failures. Only a definitive, server-confirmed auth failure may end a session.

**Architecture:** Introduce a pure `classifyAuthFailure` function that splits auth errors into `transient` and `fatal`, and a tri-state `SessionValidity` (`valid` / `invalid` / `unknown`) to replace the current `bool validateSession()`. `SupabaseService` is rewired so that only `fatal` / `invalid` reach `signOut()`; `unknown` keeps the session and defers to the SDK's own auto-refresh retry loop. Every sign-out gains a named reason emitted to analytics so the remaining logout causes are observable in production.

**Tech Stack:** Flutter, Provider, supabase_flutter 2.9.0 (gotrue 2.12.0), mocktail, flutter_test

---

## Root cause (verified against gotrue 2.12.0 source)

`SupabaseService._setupAuthListener`'s `onError` handler (`lib/supabase/service.dart:487`) calls `signOut()` on any stream error. Reading the SDK:

- `_callRefreshToken` (`gotrue_client.dart:1259`) — on a **fatal** refresh failure the SDK itself calls `_removeSession()` and emits `AuthChangeEvent.signedOut`. Fatal failures **never** reach the error stream.
- Only `AuthRetryableFetchException` is forwarded via `notifyException` → `_onAuthStateChangeController.addError`.

**Consequence: the app's `onError` handler fires only for transient network errors, and it signs the user out every time.**

The cold-start path makes this routine: `recoverSession` (`gotrue_client.dart:988`) force-refreshes an expired stored session at launch — the normal case after an hour — and app launch is exactly when connectivity is least reliable. Offline launch → retryable exception → stream error → logout, with a valid refresh token discarded.

Secondary contributors:

1. `AuthHelper.validateSession` (`lib/supabase/helpers/auth.dart:514`) collapses every exception to `false`, and all three callers read `false` as "sign out".
2. `AuthChangeEvent.initialSession` is unhandled and falls into `default:` (`service.dart:469`), triggering a redundant network round-trip on every cold start.
3. `session.expiresAt!` is force-unwrapped with no clock-skew leeway (`auth.dart:485`); a fast device clock makes a valid session look expired.
4. `signOut(scope: SignOutScope.local)` wipes the refresh token, so a misfire is unrecoverable even once connectivity returns.

**Explicitly out of scope:** in-process refresh-token rotation races. The SDK single-flights refreshes via `_refreshTokenCompleter`, so concurrent in-app refreshes are already deduplicated. Cross-process rotation (share extension, multi-device) is addressed only by the server-side config change in Task 7.

---

### Task 1: Classify auth failures

**Files:**
- Create: `lib/supabase/helpers/auth_failure.dart`
- Create: `test/supabase/helpers/auth_failure_test.dart`

- [ ] **Step 1: Write the failing classifier test**

Create `test/supabase/helpers/auth_failure_test.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:login/supabase/helpers/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('classifyAuthFailure', () {
    test('treats SDK retryable fetch failures as transient', () {
      expect(
        classifyAuthFailure(AuthRetryableFetchException()),
        AuthFailureKind.transient,
      );
    });

    test('treats raw network failures as transient', () {
      for (final error in <Object>[
        const SocketException('no route to host'),
        TimeoutException('timed out'),
        http.ClientException('connection closed'),
        const HttpException('bad response'),
      ]) {
        expect(classifyAuthFailure(error), AuthFailureKind.transient,
            reason: '$error should not end a session');
      }
    });

    test('treats rate limits and server errors as transient', () {
      for (final status in <String>['429', '500', '502', '503']) {
        expect(
          classifyAuthFailure(AuthApiException('busy', statusCode: status)),
          AuthFailureKind.transient,
          reason: 'status $status should not end a session',
        );
      }
    });

    test('treats revoked-session error codes as fatal', () {
      for (final code in <String>[
        'bad_jwt',
        'session_not_found',
        'refresh_token_not_found',
        'refresh_token_already_used',
        'user_not_found',
        'user_banned',
      ]) {
        expect(
          classifyAuthFailure(
            AuthApiException('nope', statusCode: '401', code: code),
          ),
          AuthFailureKind.fatal,
          reason: 'code $code should end the session',
        );
      }
    });

    test('treats reused refresh tokens as fatal even without a code', () {
      expect(
        classifyAuthFailure(
          AuthApiException('Invalid Refresh Token: Already Used',
              statusCode: '400'),
        ),
        AuthFailureKind.fatal,
      );
    });

    test('treats a missing session as fatal', () {
      expect(
        classifyAuthFailure(AuthSessionMissingException()),
        AuthFailureKind.fatal,
      );
    });

    test('defaults unrecognised errors to transient', () {
      expect(classifyAuthFailure(Exception('who knows')),
          AuthFailureKind.transient);
      expect(classifyAuthFailure(const AuthException('no status')),
          AuthFailureKind.transient);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/supabase/helpers/auth_failure_test.dart`

Expected: FAIL because `auth_failure.dart`, `AuthFailureKind`, and `classifyAuthFailure` do not exist.

- [ ] **Step 3: Implement the classifier**

Create `lib/supabase/helpers/auth_failure.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether an auth error is worth retrying or definitively ends the session.
enum AuthFailureKind { transient, fatal }

/// Outcome of checking whether the stored session can still be used.
///
/// [unknown] means "we could not reach the server" — the session must be kept
/// and retried, never discarded.
enum SessionValidity { valid, invalid, unknown }

/// Error codes where the server has told us the session is genuinely gone.
const Set<String> _fatalAuthCodes = <String>{
  'bad_jwt',
  'session_not_found',
  'refresh_token_not_found',
  'refresh_token_already_used',
  'user_not_found',
  'user_banned',
};

/// Classifies an auth error.
///
/// Biased towards [AuthFailureKind.transient]: an unrecognised error must never
/// cost a user their session. gotrue already removes the session itself for
/// fatal refresh failures, so anything arriving on the auth error stream is
/// transient by construction.
AuthFailureKind classifyAuthFailure(Object error) {
  if (error is AuthRetryableFetchException) {
    return AuthFailureKind.transient;
  }

  if (error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException ||
      error is HttpException) {
    return AuthFailureKind.transient;
  }

  if (error is AuthException) {
    final status = int.tryParse(error.statusCode ?? '');
    if (status == 429 || (status != null && status >= 500)) {
      return AuthFailureKind.transient;
    }

    final code = error.code?.toLowerCase();
    if (code != null && _fatalAuthCodes.contains(code)) {
      return AuthFailureKind.fatal;
    }

    final message = error.message.toLowerCase();
    if (message.contains('invalid refresh token') ||
        message.contains('already used') ||
        message.contains('refresh token not found') ||
        message.contains('auth session missing')) {
      return AuthFailureKind.fatal;
    }

    if (status == 400 || status == 401 || status == 403) {
      return AuthFailureKind.fatal;
    }

    return AuthFailureKind.transient;
  }

  return AuthFailureKind.transient;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/supabase/helpers/auth_failure_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit the classifier**

```bash
git add lib/supabase/helpers/auth_failure.dart test/supabase/helpers/auth_failure_test.dart
git commit -m "feat: classify auth failures as transient or fatal"
```

---

### Task 2: Attribute every sign-out

Ships the diagnostic layer before the behavioural change, so the fix can be confirmed against real logout reasons rather than inferred.

**Files:**
- Modify: `lib/supabase/service.dart`
- Modify: `lib/pages/profile/profile_page.dart`
- Modify: `lib/pages/reset_password_page.dart`
- Create: `test/supabase/auth_signout_reason_test.dart`

- [ ] **Step 1: Write the failing reason test**

`SupabaseService` is a singleton bound to a live Supabase client, so test the reason emission through `AnalyticsService`'s existing test seam rather than through the service. Create `test/supabase/auth_signout_reason_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:login/services/analytics_service.dart';
import 'package:login/supabase/auth_signout_reason.dart';

void main() {
  late List<Map<String, dynamic>> dispatched;

  setUp(() {
    dispatched = <Map<String, dynamic>>[];
    AnalyticsService().resetForTest();
    AnalyticsService().setEventDispatcherForTest((params) async {
      dispatched.add(params);
    });
  });

  tearDown(() {
    AnalyticsService().setEventDispatcherForTest(null);
    AnalyticsService().resetForTest();
  });

  test('exposes a stable reason for every sign-out path', () {
    expect(AuthSignOutReason.values.map((r) => r.name).toSet(), <String>{
      'userInitiated',
      'startupSessionInvalid',
      'authEventSessionInvalid',
      'authStreamFatalError',
      'passwordRecoveryCompleted',
      'accountDeleted',
    });
  });

  test('reason wire names are snake_case and unique', () {
    final wireNames = AuthSignOutReason.values.map((r) => r.wireName).toList();
    expect(wireNames.toSet().length, wireNames.length);
    for (final name in wireNames) {
      expect(name, matches(RegExp(r'^[a-z0-9_]+$')));
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/supabase/auth_signout_reason_test.dart`

Expected: FAIL because `lib/supabase/auth_signout_reason.dart` does not exist.

- [ ] **Step 3: Add the reason enum**

Create `lib/supabase/auth_signout_reason.dart`:

```dart
/// Why a session ended. Emitted with every sign-out so production logouts can
/// be attributed to a specific code path.
enum AuthSignOutReason {
  userInitiated('user_initiated'),
  startupSessionInvalid('startup_session_invalid'),
  authEventSessionInvalid('auth_event_session_invalid'),
  authStreamFatalError('auth_stream_fatal_error'),
  passwordRecoveryCompleted('password_recovery_completed'),
  accountDeleted('account_deleted');

  const AuthSignOutReason(this.wireName);

  final String wireName;
}
```

- [ ] **Step 4: Thread the reason through `SupabaseService.signOut`**

In `lib/supabase/service.dart`, import `auth_signout_reason.dart` and `analytics_service.dart`, then change the signature at line 221:

```dart
Future<void> signOut({
  AuthSignOutReason reason = AuthSignOutReason.userInitiated,
}) async {
  _setLoading(true);
  try {
    AnalyticsService().track(
      eventName: 'auth_session_ended',
      eventCategory: 'auth',
      properties: <String, dynamic>{'reason': reason.wireName},
    );
    // ... existing body unchanged ...
```

Pass the matching reason at each internal call site:

- `service.dart:141` (startup validation) → `AuthSignOutReason.startupSessionInvalid`. Note this line currently calls `_authService.signOut()` directly, bypassing cache clearing and analytics; route it through `signOut(reason: ...)` instead.
- `service.dart:360` (`validateAndRefreshSession`) → `AuthSignOutReason.authEventSessionInvalid`
- `service.dart:479` (default event branch) → `AuthSignOutReason.authEventSessionInvalid`
- `service.dart:495` (`onError`) → `AuthSignOutReason.authStreamFatalError`
- `deleteMyAccount` → `AuthSignOutReason.accountDeleted`

Leave `profile_page.dart:263` on the default. Update `reset_password_page.dart:60` to pass `AuthSignOutReason.passwordRecoveryCompleted`.

- [ ] **Step 5: Verify**

```bash
flutter test test/supabase/auth_signout_reason_test.dart
flutter analyze lib/supabase/service.dart lib/supabase/auth_signout_reason.dart lib/pages/profile/profile_page.dart lib/pages/reset_password_page.dart
```

Expected: test passes; analysis reports no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/supabase/auth_signout_reason.dart lib/supabase/service.dart lib/pages/profile/profile_page.dart lib/pages/reset_password_page.dart test/supabase/auth_signout_reason_test.dart
git commit -m "feat: attribute every auth sign-out with a reason"
```

---

### Task 3: Stop signing out on transient auth-stream errors

The single highest-impact change. Do not merge Tasks 4–6 without this one.

**Files:**
- Modify: `lib/supabase/service.dart`
- Create: `test/supabase/auth_stream_error_policy_test.dart`

- [ ] **Step 1: Write the failing policy test**

Create `test/supabase/auth_stream_error_policy_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:login/supabase/auth_stream_error_policy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('shouldEndSessionForAuthStreamError', () {
    test('keeps the session for transient refresh failures', () {
      expect(
        shouldEndSessionForAuthStreamError(AuthRetryableFetchException()),
        isFalse,
      );
      expect(
        shouldEndSessionForAuthStreamError(
          const SocketException('offline'),
        ),
        isFalse,
      );
      expect(
        shouldEndSessionForAuthStreamError(
          AuthApiException('rate limited', statusCode: '429'),
        ),
        isFalse,
      );
    });

    test('ends the session only for definitive auth failures', () {
      expect(
        shouldEndSessionForAuthStreamError(
          AuthApiException('gone', statusCode: '401', code: 'bad_jwt'),
        ),
        isTrue,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/supabase/auth_stream_error_policy_test.dart`

Expected: FAIL because `auth_stream_error_policy.dart` does not exist.

- [ ] **Step 3: Implement the policy**

Create `lib/supabase/auth_stream_error_policy.dart`:

```dart
import 'package:login/supabase/helpers/auth_failure.dart';

/// Whether an error delivered on `onAuthStateChange`'s error channel should end
/// the session.
///
/// gotrue removes the session and emits `AuthChangeEvent.signedOut` itself for
/// fatal refresh failures, so in practice only transient errors arrive here.
/// The fatal branch exists as a safety net, not as the expected path.
bool shouldEndSessionForAuthStreamError(Object error) =>
    classifyAuthFailure(error) == AuthFailureKind.fatal;
```

- [ ] **Step 4: Rewire the `onError` handler**

Replace `lib/supabase/service.dart:487-496` with:

```dart
onError: (Object error, StackTrace stackTrace) {
  if (!shouldEndSessionForAuthStreamError(error)) {
    // Transient: the SDK keeps retrying with backoff and will emit
    // tokenRefreshed on success. Discarding the session here would throw
    // away a still-valid refresh token.
    if (kDebugMode) {
      print('SupabaseService: transient auth error, keeping session: $error');
    }
    AnalyticsService().recordError(
      key: 'auth_refresh_transient',
      properties: <String, dynamic>{'error': error.runtimeType.toString()},
    );
    return;
  }

  if (kDebugMode) {
    print('SupabaseService: fatal auth error, ending session: $error');
  }
  _hasValidSession = false;
  signOut(reason: AuthSignOutReason.authStreamFatalError);
},
```

- [ ] **Step 5: Verify**

```bash
flutter test test/supabase/auth_stream_error_policy_test.dart
flutter analyze lib/supabase/auth_stream_error_policy.dart lib/supabase/service.dart
```

Expected: test passes; analysis reports no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/supabase/auth_stream_error_policy.dart lib/supabase/service.dart test/supabase/auth_stream_error_policy_test.dart
git commit -m "fix: keep session alive on transient auth stream errors"
```

---

### Task 4: Replace `validateSession` with a tri-state check

**Files:**
- Modify: `lib/supabase/helpers/auth.dart`
- Modify: `test/supabase/helpers/auth_test.dart`

- [ ] **Step 1: Write the failing `checkSession` tests**

Append to `test/supabase/helpers/auth_test.dart` (reuse the existing `_MockSupabaseClient` / `_MockGoTrueClient` fixtures).

`Session.expiresAt` is **not** a constructor parameter — it is a `late` field derived by decoding the `exp` claim out of `accessToken` (`gotrue-2.12.0/lib/src/types/session.dart:60`). The fixture must therefore mint an access token carrying the desired expiry. `Jwt.parseJwt` only base64-decodes the payload and re-pads it, so an unsigned three-segment token is sufficient — no signing key is needed.

Add `import 'dart:convert';` to the test file, then:

```dart
group('checkSession', () {
  String _segment(Map<String, dynamic> claims) =>
      base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');

  /// Builds an unsigned JWT whose `exp` claim sits [delta] from now.
  String _accessTokenExpiringIn(Duration delta) {
    final header = _segment({'alg': 'HS256', 'typ': 'JWT'});
    final payload = _segment({
      'sub': 'user-123',
      'exp': DateTime.now().add(delta).millisecondsSinceEpoch ~/ 1000,
    });
    return '$header.$payload.test-signature';
  }

  Session sessionExpiringIn(Duration delta) => Session(
        accessToken: _accessTokenExpiringIn(delta),
        tokenType: 'bearer',
        expiresIn: delta.inSeconds,
        refreshToken: 'test-refresh-token',
        user: const User(
          id: 'user-123',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-05-06T00:00:00.000Z',
        ),
      );

  test('returns invalid when no session exists', () async {
    when(() => authClient.currentSession).thenReturn(null);
    final helper = AuthHelper(client: client, appleAuthService: appleAuthService);

    expect(await helper.checkSession(), SessionValidity.invalid);
  });

  test('returns valid without a network call when comfortably unexpired',
      () async {
    when(() => authClient.currentSession)
        .thenReturn(sessionExpiringIn(const Duration(minutes: 30)));
    final helper = AuthHelper(client: client, appleAuthService: appleAuthService);

    expect(await helper.checkSession(), SessionValidity.valid);
    verifyNever(() => authClient.refreshSession());
  });

  test('refreshes inside the expiry leeway window', () async {
    when(() => authClient.currentSession)
        .thenReturn(sessionExpiringIn(const Duration(seconds: 20)));
    when(() => authClient.refreshSession()).thenAnswer(
      (_) async => AuthResponse(session: sessionExpiringIn(const Duration(hours: 1))),
    );
    final helper = AuthHelper(client: client, appleAuthService: appleAuthService);

    expect(await helper.checkSession(), SessionValidity.valid);
    verify(() => authClient.refreshSession()).called(1);
  });

  test('returns unknown when refresh fails transiently', () async {
    when(() => authClient.currentSession)
        .thenReturn(sessionExpiringIn(const Duration(seconds: -10)));
    when(() => authClient.refreshSession())
        .thenThrow(AuthRetryableFetchException());
    final helper = AuthHelper(client: client, appleAuthService: appleAuthService);

    expect(await helper.checkSession(), SessionValidity.unknown);
  });

  test('returns invalid when the refresh token is definitively rejected',
      () async {
    when(() => authClient.currentSession)
        .thenReturn(sessionExpiringIn(const Duration(seconds: -10)));
    when(() => authClient.refreshSession()).thenThrow(
      AuthApiException('Invalid Refresh Token: Already Used',
          statusCode: '400'),
    );
    final helper = AuthHelper(client: client, appleAuthService: appleAuthService);

    expect(await helper.checkSession(), SessionValidity.invalid);
  });

  test('single-flights concurrent checks', () async {
    when(() => authClient.currentSession)
        .thenReturn(sessionExpiringIn(const Duration(seconds: -10)));
    when(() => authClient.refreshSession()).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return AuthResponse(session: sessionExpiringIn(const Duration(hours: 1)));
    });
    final helper = AuthHelper(client: client, appleAuthService: appleAuthService);

    await Future.wait<SessionValidity>([
      helper.checkSession(),
      helper.checkSession(),
      helper.checkSession(),
    ]);

    verify(() => authClient.refreshSession()).called(1);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/supabase/helpers/auth_test.dart`

Expected: FAIL because `AuthHelper.checkSession` does not exist.

- [ ] **Step 3: Implement `checkSession` and delete `validateSession`**

In `lib/supabase/helpers/auth.dart`, import `auth_failure.dart`, add the field and constant to `AuthHelper`, and replace `validateSession` (lines 470-520) entirely:

```dart
/// Refresh this far ahead of expiry so a slightly fast device clock never
/// makes a live session look dead.
static const Duration sessionExpiryLeeway = Duration(seconds: 60);

Future<SessionValidity>? _inFlightSessionCheck;

/// Checks whether the stored session is usable, refreshing if needed.
///
/// Returns [SessionValidity.unknown] when the server could not be reached —
/// callers must keep the session and retry, never sign out.
Future<SessionValidity> checkSession() {
  return _inFlightSessionCheck ??= _checkSession().whenComplete(() {
    _inFlightSessionCheck = null;
  });
}

Future<SessionValidity> _checkSession() async {
  final session = _client.auth.currentSession;
  if (session == null) {
    return SessionValidity.invalid;
  }

  final expiresAtSeconds = session.expiresAt;
  if (expiresAtSeconds == null) {
    // No expiry recorded: trust the SDK's own refresh scheduling.
    return SessionValidity.valid;
  }

  final expiresAt =
      DateTime.fromMillisecondsSinceEpoch(expiresAtSeconds * 1000);
  if (DateTime.now().isBefore(expiresAt.subtract(sessionExpiryLeeway))) {
    return SessionValidity.valid;
  }

  try {
    final response = await _client.auth.refreshSession();
    // A null session here is an incomplete response, not a rejection.
    return response.session == null
        ? SessionValidity.unknown
        : SessionValidity.valid;
  } catch (e) {
    return classifyAuthFailure(e) == AuthFailureKind.fatal
        ? SessionValidity.invalid
        : SessionValidity.unknown;
  }
}
```

Deleting `validateSession` rather than deprecating it is deliberate: leaving a `bool` API in place preserves the trap this plan exists to remove. The compiler will point at the three call sites, which Task 5 fixes.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/supabase/helpers/auth_test.dart`

Expected: the new group passes. `flutter analyze lib/supabase/service.dart` will now report three errors on the removed `validateSession` — that is expected and resolved in Task 5.

- [ ] **Step 5: Commit**

```bash
git add lib/supabase/helpers/auth.dart test/supabase/helpers/auth_test.dart
git commit -m "feat: add tri-state session check with clock skew leeway"
```

---

### Task 5: Rewire `SupabaseService` onto the tri-state check

**Files:**
- Modify: `lib/supabase/service.dart`

- [ ] **Step 1: Handle `initialSession` explicitly**

Add a case to the switch in `_setupAuthListener`, before `default:`, so a restored session no longer triggers a network round-trip during launch:

```dart
case AuthChangeEvent.initialSession:
  // The SDK has already restored and, where necessary, refreshed this
  // session. Trust it and let auto-refresh own the token lifecycle.
  _hasValidSession = state.session != null;
  notifyListeners();
  break;
```

- [ ] **Step 2: Make the `default:` branch tolerate unreachability**

Replace the body of `default:` (`service.dart:469-484`):

```dart
default:
  if (_authService.isAuthenticated && !_isHandlingSignedIn) {
    final validity = await _authService.checkSession();
    if (validity == SessionValidity.invalid) {
      if (kDebugMode) {
        print('SupabaseService: session definitively invalid, signing out');
      }
      await signOut(reason: AuthSignOutReason.authEventSessionInvalid);
    } else {
      // valid or unknown: keep the session. An unreachable server is not
      // grounds for ending it.
      _hasValidSession = true;
      notifyListeners();
    }
  }
```

- [ ] **Step 3: Make startup non-destructive**

Replace `service.dart:126-144`:

```dart
if (_authService.isAuthenticated && !_hasValidSession) {
  final validity = await _authService.checkSession();

  if (validity == SessionValidity.invalid) {
    if (kDebugMode) {
      print('SupabaseService: restored session is invalid, signing out');
    }
    await signOut(reason: AuthSignOutReason.startupSessionInvalid);
    _hasValidSession = false;
  } else {
    // Optimistic on `unknown`: proceed into the app. Requests may 401 while
    // offline, but the SDK retries refresh in the background and the user
    // keeps their session.
    _hasValidSession = true;
  }
}
```

- [ ] **Step 4: Update `validateAndRefreshSession`**

Replace its body (`service.dart:353-366`) with the same three-way branch, returning `true` for `valid` and `unknown` and `false` only for `invalid`, signing out only on `invalid` with `AuthSignOutReason.authEventSessionInvalid`.

- [ ] **Step 5: Verify**

```bash
dart format lib/supabase/service.dart lib/supabase/helpers/auth.dart
flutter analyze lib/supabase
rg -n "validateSession" lib
```

Expected: analysis reports no issues; the search returns no matches.

- [ ] **Step 6: Run the auth regression suite**

```bash
flutter test test/supabase test/pages/auth_handler_test.dart test/bootstrap
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/supabase/service.dart
git commit -m "fix: only end sessions on definitive auth failures"
```

---

### Task 6: Collapse the redundant auth listener

**Files:**
- Modify: `lib/supabase/supabase_client.dart`

- [ ] **Step 1: Remove the debug-only listener**

Delete the `Supabase.instance.client.auth.onAuthStateChange.listen(...)` block at `lib/supabase/supabase_client.dart:37-59`. It only prints in debug builds, and its unawaited subscription is never cancelled. `SupabaseService` (session policy) and `MyApp` (analytics and app-group sync) remain as the two intentional subscribers.

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/supabase/supabase_client.dart
flutter test test/supabase test/bootstrap
```

Expected: analysis reports no issues; tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/supabase/supabase_client.dart
git commit -m "refactor: drop redundant auth state listener"
```

---

### Task 7: Widen the server-side refresh window and verify on-device

The preceding tasks stop the client discarding good sessions. This task reduces how often the server rejects a legitimate refresh in the first place — relevant for users with the share extension or multiple devices, where rotation races cross process boundaries and the SDK's in-process single-flight cannot help.

**Files:**
- Modify: `supabase/config.toml`

- [ ] **Step 1: Widen the reuse interval locally**

In `supabase/config.toml:161`, change `refresh_token_reuse_interval = 10` to `refresh_token_reuse_interval = 30`, keeping `enable_refresh_token_rotation = true`.

- [ ] **Step 2: Apply the same change to the hosted project**

`config.toml` governs local dev only. Apply the matching value in the Supabase Dashboard → Authentication → Sessions for the production project. **This is a manual step and must be done by a project owner — flag it for the user rather than attempting it.**

- [ ] **Step 3: Manual verification matrix**

Build a debug build and confirm each case. All six must end with the user still signed in:

| Scenario | Expected |
| --- | --- |
| Cold start in airplane mode with a stored session | App opens signed in; no logout |
| Cold start after >1h idle, connection drops mid-launch | App opens signed in; refresh retries in background |
| Backgrounded >1h, resumed offline, then back online | Stays signed in; `tokenRefreshed` fires on reconnect |
| Airplane mode toggled repeatedly while app is foregrounded | Stays signed in |
| Password changed on another device | Signs out with reason `auth_stream_fatal_error` or a `signedOut` event |
| Explicit sign-out from profile | Signs out with reason `user_initiated` |

- [ ] **Step 4: Commit**

```bash
git add supabase/config.toml
git commit -m "chore: widen refresh token reuse interval"
```

---

## Verification after rollout

Query `app_analytics_events` for `auth_session_ended` grouped by `properties->>'reason'`.

- Before: expect a meaningful share of `auth_stream_fatal_error` and `startup_session_invalid`.
- After: near-total `user_initiated`. Any residual `auth_stream_fatal_error` is now a genuinely revoked session, since the transient path can no longer reach it.

Treat a sustained non-`user_initiated` rate as the signal that a cause remains unfound, and re-open the investigation with the reason breakdown as the starting point.

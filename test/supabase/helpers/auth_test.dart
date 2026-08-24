import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:login/services/apple_auth_service.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/helpers/auth.dart';
import 'package:login/supabase/helpers/auth_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockAppleAuthService extends Mock implements AppleAuthService {}

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient authClient;
  late _MockAppleAuthService appleAuthService;
  late Session session;

  setUp(() {
    client = _MockSupabaseClient();
    authClient = _MockGoTrueClient();
    appleAuthService = _MockAppleAuthService();
    session = Session(
      accessToken: 'test-access-token',
      tokenType: 'bearer',
      user: const User(
        id: 'user-123',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        email: 'test@example.com',
        createdAt: '2026-05-06T00:00:00.000Z',
      ),
    );

    when(() => client.auth).thenReturn(authClient);
    when(() => authClient.currentSession).thenReturn(session);

    dotenv.testLoad(
      fileInput: '''
SUPABASE_URL=https://supabase.test
SUPABASE_ANON_KEY=test-anon-key
''',
    );
  });

  test('resolveMutualFriendIds keeps only users present in both directions',
      () {
    final mutualIds = resolveMutualFriendIds(
      followingRows: const [
        {
          SupabaseConstants.columnFolloweeId: 'mutual-user',
        },
        {
          SupabaseConstants.columnFolloweeId: 'outbound-only-user',
        },
      ],
      followerRows: const [
        {
          SupabaseConstants.columnFollowerId: 'mutual-user',
        },
        {
          SupabaseConstants.columnFollowerId: 'inbound-only-user',
        },
      ],
    );

    expect(mutualIds, {'mutual-user'});
  });

  test(
      'resolveOAuthDisplayName prefers pending Apple full name over metadata and email fallback',
      () {
    final resolvedName = resolveOAuthDisplayName(
      pendingDisplayName: 'Taylor Swift',
      userMetadata: const {
        'name': 'metadata name',
        'full_name': 'metadata full name',
      },
      email: 'taylor.swift@example.com',
    );

    expect(resolvedName, 'Taylor Swift');
  });

  test('resolveOAuthDisplayName falls back to auth metadata before email', () {
    final resolvedName = resolveOAuthDisplayName(
      userMetadata: const {
        'full_name': 'Ada Lovelace',
      },
      email: 'ada@example.com',
    );

    expect(resolvedName, 'Ada Lovelace');
  });

  test('resolveOAuthDisplayName derives a readable fallback from email', () {
    final resolvedName = resolveOAuthDisplayName(
      userMetadata: const {},
      email: 'first.last+foodie@example.com',
    );

    expect(resolvedName, 'first last foodie');
  });

  test(
      'deleteMyAccount only succeeds after the RPC confirms auth deletion, then clears the local session',
      () async {
    final events = <String>[];

    when(() => authClient.currentSession).thenAnswer((_) {
      events.add('currentSession');
      return session;
    });
    when(() => authClient.signOut(scope: SignOutScope.local))
        .thenAnswer((_) async {
      events.add('signOut');
    });

    final helper = AuthHelper(
      client: client,
      appleAuthService: appleAuthService,
      httpPost: (url, {headers, body, encoding}) async {
        events.add('rpc');
        expect(
          url.toString(),
          'https://supabase.test/rest/v1/rpc/delete_my_account',
        );
        expect(headers, {
          'apikey': 'test-anon-key',
          'Authorization': 'Bearer test-access-token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        });
        expect(body, '{}');
        return http.Response(
          '{"success":true,"auth_deleted":true}',
          200,
        );
      },
    );

    await helper.deleteMyAccount();

    expect(events, ['currentSession', 'rpc', 'signOut']);
    verify(() => authClient.signOut(scope: SignOutScope.local)).called(1);
  });

  test('deleteMyAccount throws when auth deletion was not confirmed', () async {
    when(() => authClient.signOut(scope: SignOutScope.local))
        .thenAnswer((_) async {});

    final helper = AuthHelper(
      client: client,
      appleAuthService: appleAuthService,
      httpPost: (url, {headers, body, encoding}) async {
        return http.Response(
          '{"success":true,"auth_deleted":false}',
          200,
        );
      },
    );

    await expectLater(
      helper.deleteMyAccount(),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('auth account'),
        ),
      ),
    );
    verifyNever(() => authClient.signOut(scope: SignOutScope.local));
  });

  group('checkSession', () {
    String segment(Map<String, dynamic> claims) =>
        base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');

    /// Builds an unsigned JWT whose `exp` claim sits [delta] from now.
    ///
    /// `Session.expiresAt` is derived by decoding this token, so the expiry has
    /// to be carried in the access token rather than passed to the
    /// constructor.
    String accessTokenExpiringIn(Duration delta) {
      final header = segment({'alg': 'HS256', 'typ': 'JWT'});
      final payload = segment({
        'sub': 'user-123',
        'exp': DateTime.now().add(delta).millisecondsSinceEpoch ~/ 1000,
      });
      return '$header.$payload.test-signature';
    }

    Session sessionExpiringIn(Duration delta) => Session(
          accessToken: accessTokenExpiringIn(delta),
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
      final helper =
          AuthHelper(client: client, appleAuthService: appleAuthService);

      expect(await helper.checkSession(), SessionValidity.invalid);
    });

    test('returns valid without a network call when comfortably unexpired',
        () async {
      when(() => authClient.currentSession)
          .thenReturn(sessionExpiringIn(const Duration(minutes: 30)));
      final helper =
          AuthHelper(client: client, appleAuthService: appleAuthService);

      expect(await helper.checkSession(), SessionValidity.valid);
      verifyNever(() => authClient.refreshSession());
    });

    test('refreshes inside the expiry leeway window', () async {
      when(() => authClient.currentSession)
          .thenReturn(sessionExpiringIn(const Duration(seconds: 20)));
      when(() => authClient.refreshSession()).thenAnswer(
        (_) async =>
            AuthResponse(session: sessionExpiringIn(const Duration(hours: 1))),
      );
      final helper =
          AuthHelper(client: client, appleAuthService: appleAuthService);

      expect(await helper.checkSession(), SessionValidity.valid);
      verify(() => authClient.refreshSession()).called(1);
    });

    test('returns unknown when refresh fails transiently', () async {
      when(() => authClient.currentSession)
          .thenReturn(sessionExpiringIn(const Duration(seconds: -10)));
      when(() => authClient.refreshSession())
          .thenThrow(AuthRetryableFetchException());
      final helper =
          AuthHelper(client: client, appleAuthService: appleAuthService);

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
      final helper =
          AuthHelper(client: client, appleAuthService: appleAuthService);

      expect(await helper.checkSession(), SessionValidity.invalid);
    });

    test('single-flights concurrent checks', () async {
      when(() => authClient.currentSession)
          .thenReturn(sessionExpiringIn(const Duration(seconds: -10)));
      when(() => authClient.refreshSession()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return AuthResponse(
            session: sessionExpiringIn(const Duration(hours: 1)));
      });
      final helper =
          AuthHelper(client: client, appleAuthService: appleAuthService);

      await Future.wait<SessionValidity>([
        helper.checkSession(),
        helper.checkSession(),
        helper.checkSession(),
      ]);

      verify(() => authClient.refreshSession()).called(1);
    });
  });
}

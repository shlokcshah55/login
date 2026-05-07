import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:login/services/apple_auth_service.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/helpers/auth.dart';
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
}

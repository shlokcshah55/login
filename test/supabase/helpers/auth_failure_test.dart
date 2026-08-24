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

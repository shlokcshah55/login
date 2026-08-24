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
        shouldEndSessionForAuthStreamError(const SocketException('offline')),
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

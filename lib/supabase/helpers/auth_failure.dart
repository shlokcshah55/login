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

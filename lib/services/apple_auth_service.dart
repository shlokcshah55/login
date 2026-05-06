import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as apple;
import 'package:supabase_flutter/supabase_flutter.dart';

class AppleSignInProfileHint {
  AppleSignInProfileHint._();

  static String? _pendingDisplayName;

  static void stageDisplayName(String? name) {
    final trimmed = name?.trim();
    _pendingDisplayName =
        trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? takeDisplayName() {
    final pending = _pendingDisplayName;
    _pendingDisplayName = null;
    return pending;
  }

  static void clear() {
    _pendingDisplayName = null;
  }
}

class AppleSignInCancelledException implements Exception {
  const AppleSignInCancelledException();
}

class AppleSignInNetworkException implements Exception {
  const AppleSignInNetworkException([
    this.message = 'Network error during Apple sign in. Please try again.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class AppleAuthService {
  AppleAuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<AuthResponse> signInWithApple() async {
    try {
      final rawNonce = _client.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await apple.SignInWithApple.getAppleIDCredential(
        scopes: const [
          apple.AppleIDAuthorizationScopes.email,
          apple.AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException('No ID token from Apple.');
      }

      final givenName = credential.givenName?.trim();
      final familyName = credential.familyName?.trim();
      final fullName = [givenName, familyName]
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .join(' ');
      AppleSignInProfileHint.stageDisplayName(fullName);

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (fullName.isNotEmpty) {
        await _client.auth.updateUser(
          UserAttributes(data: {
            'full_name': fullName,
            'name': fullName,
          }),
        );
      }

      return response;
    } on apple.SignInWithAppleAuthorizationException catch (error) {
      AppleSignInProfileHint.clear();
      if (error.code == apple.AuthorizationErrorCode.canceled) {
        throw const AppleSignInCancelledException();
      }

      final message = error.message.toLowerCase();
      if (message.contains('network') || message.contains('internet')) {
        throw AppleSignInNetworkException(error.message);
      }

      throw AuthException(error.message);
    } on SocketException {
      AppleSignInProfileHint.clear();
      throw const AppleSignInNetworkException();
    } on TimeoutException {
      AppleSignInProfileHint.clear();
      throw const AppleSignInNetworkException(
        'Apple sign in timed out. Please try again.',
      );
    } catch (_) {
      AppleSignInProfileHint.clear();
      rethrow;
    }
  }
}

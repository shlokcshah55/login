import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();
}

class GoogleSignInNetworkException implements Exception {
  const GoogleSignInNetworkException([
    this.message = 'Network error during Google sign in. Please try again.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Native Google sign-in: the Google SDK shows its sheet over the app and
/// hands back an ID token, which is exchanged with Supabase. No browser hop
/// and no deep-link callback.
///
/// The iOS client ID (`GIDClientID`) and web client ID (`GIDServerClientID`)
/// are read from Info.plist. The web client ID must be listed first in the
/// Supabase Google provider's "Client IDs", followed by the iOS one.
class GoogleAuthService {
  GoogleAuthService({SupabaseClient? client, GoogleSignIn? googleSignIn})
      : _client = client ?? Supabase.instance.client,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final SupabaseClient _client;
  final GoogleSignIn _googleSignIn;

  // GoogleSignIn.initialize may only be called once per process, and the nonce
  // is fixed at that point, so the raw nonce lives for the app session.
  Future<String>? _rawNonce;

  Future<String> _ensureInitialized() {
    return _rawNonce ??= () async {
      final rawNonce = _client.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
      try {
        await _googleSignIn.initialize(nonce: hashedNonce);
      } catch (_) {
        _rawNonce = null;
        rethrow;
      }
      return rawNonce;
    }();
  }

  Future<AuthResponse> signInWithGoogle() async {
    try {
      final rawNonce = await _ensureInitialized();
      final account = await _googleSignIn.authenticate();

      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthException('No ID token from Google.');
      }

      return await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        nonce: rawNonce,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleSignInCancelledException();
      }

      final description = error.description ?? error.code.name;
      final lower = description.toLowerCase();
      if (lower.contains('network') || lower.contains('internet')) {
        throw GoogleSignInNetworkException(description);
      }

      throw AuthException(description);
    } on SocketException {
      throw const GoogleSignInNetworkException();
    } on TimeoutException {
      throw const GoogleSignInNetworkException(
        'Google sign in timed out. Please try again.',
      );
    }
  }
}

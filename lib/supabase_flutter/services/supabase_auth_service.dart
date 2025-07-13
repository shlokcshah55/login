import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_client.dart';
import '../models/user_model.dart';

/// Service for handling Supabase authentication operations
class SupabaseAuthService {
  final SupabaseClient _client = SupabaseClientManager().client;

  /// Sign up a new user with email and password
  Future<UserModel> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: name != null ? {'name': name} : null,
      );

      if (response.user == null) {
        throw Exception('Failed to sign up. User is null.');
      }

      final user = response.user!;

      // Create a user record in your users table (if needed)
      await _client.from('users').insert({
        'supabase_id': user.id,
        'email': email,
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      });

      return UserModel(
        supabaseId: user.id,
        email: email,
        name: name,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error signing up: $e');
      }
      rethrow;
    }
  }

  /// Sign in a user with email and password
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Failed to sign in. User is null.');
      }

      final user = response.user!;

      // Get user details from your users table (if you have one)
      final userDetails = await _client
          .from('users')
          .select()
          .eq('supabase_id', user.id)
          .single();

      return UserModel.fromJson(userDetails);
    } catch (e) {
      if (kDebugMode) {
        print('Error signing in: $e');
      }
      rethrow;
    }
  }

  // /// Sign in with third-party providers (Google, Apple, etc.)
  // Future<void> signInWithProvider(Provider provider) async {
  //   try {
  //     await _client.auth.signInWithOAuth(
  //       provider,
  //       redirectTo: 'io.supabase.app://login-callback/', // Set up your URL scheme
  //     );
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Error signing in with provider: $e');
  //     }
  //     rethrow;
  //   }
  // }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      if (kDebugMode) {
        print('Error signing out: $e');
      }
      rethrow;
    }
  }

  /// Get the current authenticated user
  User? get currentUser => _client.auth.currentUser;

  /// Reset password for a user
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting password: $e');
      }
      rethrow;
    }
  }

  /// Update user password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error updating password: $e');
      }
      rethrow;
    }
  }

  /// Get currently authenticated user's session
  Future<Session?> getSession() async {
    try {
      return _client.auth.currentSession;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting session: $e');
      }
      return null;
    }
  }

  /// Check if a user is currently authenticated
  bool get isAuthenticated => currentUser != null;

  /// Stream of auth state changes
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
}

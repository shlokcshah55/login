import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// Sign in with Google using Supabase OAuth
  /// Returns true if OAuth flow was successfully initiated
  /// Auth state changes will be handled automatically by listeners
  Future<bool> signInWithGoogle() async {
    try {
      if (kDebugMode) {
        print('Initiating Google OAuth flow...');
      }

      // Use Supabase's built-in OAuth flow
      // This opens browser/webview and handles the OAuth dance
      // The client ID and secret are configured in Supabase Dashboard
      final result = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.srishlok.pinit://login-callback/',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      if (!result) {
        throw Exception('Failed to initiate Google sign in');
      }

      if (kDebugMode) {
        print('Google OAuth flow initiated successfully');
      }

      // Return true to indicate flow started
      // The actual authentication happens via deep link callback
      // Auth state changes will be detected by SupabaseProvider's listener
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error initiating Google sign in: $e');
      }
      return false;
    }
  }

  /// Ensure user record exists in database for OAuth users
  /// Called automatically when auth state changes to signed in
  Future<void> ensureUserRecordExists() async {
    try {
      final user = currentUser;
      if (user == null) return;

      // Check if user exists in your users table
      final existingUser = await _client
          .from('users')
          .select()
          .eq('supabase_id', user.id)
          .maybeSingle();

      // If user doesn't exist, create a new record
      if (existingUser == null) {
        if (kDebugMode) {
          print('Creating database record for new OAuth user: ${user.email}');
        }

        await _client.from('users').insert({
          'supabase_id': user.id,
          'email': user.email,
          'name': user.userMetadata?['name'] ?? user.userMetadata?['full_name'],
          'created_at': DateTime.now().toIso8601String(),
        });

        if (kDebugMode) {
          print('User record created successfully');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error ensuring user record exists: $e');
      }
      // Don't rethrow - this is a background operation
    }
  }

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

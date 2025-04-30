import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../services/supabase_auth_service.dart';

/// Repository for user-related operations
class UserRepository {
  final SupabaseAuthService _authService = SupabaseAuthService();

  /// Sign up a new user
  Future<UserModel> signUp(String email, String password,
      {String? name}) async {
    try {
      return await _authService.signUp(
        email: email,
        password: password,
        name: name,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error in UserRepository.signUp: $e');
      }
      rethrow;
    }
  }

  /// Sign in a user
  Future<UserModel> signIn(String email, String password) async {
    try {
      return await _authService.signIn(
        email: email,
        password: password,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error in UserRepository.signIn: $e');
      }
      rethrow;
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      if (kDebugMode) {
        print('Error in UserRepository.signOut: $e');
      }
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
    } catch (e) {
      if (kDebugMode) {
        print('Error in UserRepository.resetPassword: $e');
      }
      rethrow;
    }
  }

  /// Update user password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _authService.updatePassword(newPassword);
    } catch (e) {
      if (kDebugMode) {
        print('Error in UserRepository.updatePassword: $e');
      }
      rethrow;
    }
  }

  // /// Sign in with third-party provider
  // Future<void> signInWithProvider(Provider provider) async {
  //   try {
  //     await _authService.signInWithProvider(provider);
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Error in UserRepository.signInWithProvider: $e');
  //     }
  //     rethrow;
  //   }
  // }

  /// Get the current user
  User? get currentUser => _authService.currentUser;

  /// Check if a user is authenticated
  bool get isAuthenticated => _authService.isAuthenticated;

  /// Get auth state changes stream
  Stream<AuthState> get onAuthStateChange => _authService.onAuthStateChange;
}

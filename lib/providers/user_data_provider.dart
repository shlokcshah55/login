import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:login/supabase_flutter/models/user_model.dart';
import 'package:login/supabase_flutter/repositories/user_repository.dart';
import 'package:login/supabase_flutter/supabase_client.dart';

class UserDataProvider with ChangeNotifier {
  // Keep Firebase service for backward compatibility during migration

  // Add Supabase repository
  final UserRepository _userRepository = UserRepository();

  UserDataProvider();

  String? _userId;
  Map<String, dynamic>? _userData;
  UserModel? _supabaseUserData;
  bool _isLoading = false;
  String? _error;

  // Getters
  String? get userId => _userId;
  Map<String, dynamic>? get userData => _userData;
  UserModel? get supabaseUserData => _supabaseUserData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn =>
      (_userId != null && _userData != null) || _userRepository.isAuthenticated;

  /// Sets the user ID (typically after login) and fetches user data.
  Future<void> setUserIdAndFetchData(String userId) async {
    _userId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners(); // Notify UI that loading has started

    try {
      // Try to fetch from Supabase first
      if (_userRepository.isAuthenticated) {
        final UserModel? userModel = await _userRepository.getUserProfile();
        if (userModel != null) {
          _supabaseUserData = userModel;
          log("UserDataProvider: Fetched Supabase data for user");

          // Also build a compatible map for backward compatibility
          _userData = {
            'name': userModel.name,
            'email': userModel.email,
            'uid': userModel.supabaseId,
            'profile_image_url': userModel.profileImageUrl,
            'bio': userModel.bio,
          };

          // Success with Supabase, exit early
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

    } catch (e) {
      log('UserDataProvider: Error fetching user data: $e');
      _error = 'Failed to fetch user data.';
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify UI that loading is complete (success or error)
    }
  }

  /// Clears user data (typically on logout).
  Future<void> clearUserData() async {
    _userId = null;
    _userData = null;
    _supabaseUserData = null;
    _isLoading = false;
    _error = null;
    // No need to call signOut here, let the auth handler do that.
    // This provider just clears its own state.
    log("UserDataProvider: Cleared user data.");
    notifyListeners();
  }

  /// Updates user profile data in Supabase
  Future<bool> updateUserProfile(
      {String? name, String? email, String? profileImageUrl, String? bio}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Prepare update data
      final Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (email != null) updateData['email'] = email;
      if (profileImageUrl != null)
        updateData['profile_image_url'] = profileImageUrl;
      if (bio != null) updateData['bio'] = bio;

      if (updateData.isEmpty) {
        log('UserDataProvider: Nothing to update');
        return false;
      }

      // Update in Supabase
      if (_userRepository.isAuthenticated) {
        final updatedUser = await _userRepository.updateUserProfile(updateData);
        if (updatedUser != null) {
          _supabaseUserData = updatedUser;

          // Also update the compatible map for backward compatibility
          if (_userData != null) {
            if (name != null) _userData!['name'] = name;
            if (email != null) _userData!['email'] = email;
            if (profileImageUrl != null)
              _userData!['profile_image_url'] = profileImageUrl;
            if (bio != null) _userData!['bio'] = bio;
          }

          log("UserDataProvider: Updated user profile in Supabase");
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      // If we reach here, either Supabase update failed or user not in Supabase
      // Note: For a complete implementation, you'd update Firebase here too during transition
      _error = 'Failed to update profile.';
      return false;
    } catch (e) {
      log('UserDataProvider: Error updating user profile: $e');
      _error = 'Failed to update profile: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

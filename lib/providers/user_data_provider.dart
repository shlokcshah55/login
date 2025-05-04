import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:login/services/firebase_service.dart';
import 'package:login/supabase_flutter/models/user_model.dart';
import 'package:login/supabase_flutter/repositories/user_repository.dart';
import 'package:login/supabase_flutter/supabase_client.dart';

class UserDataProvider with ChangeNotifier {
  // Keep Firebase service for backward compatibility during migration
  final FirebaseService _firebaseService;
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  
  // Add Supabase repository
  final UserRepository _userRepository = UserRepository();

  UserDataProvider(this._firebaseService);

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
  bool get isLoggedIn => (_userId != null && _userData != null) || 
                        _userRepository.isAuthenticated;

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
          };
          
          // Success with Supabase, exit early
          _isLoading = false;
          notifyListeners();
          return;
        }
      }
      
      // Fall back to Firebase if Supabase data not available
      final Map<String, dynamic>? maybeUserData = await _firebaseService.getUser(userId);
      if (maybeUserData != null) {
        _userData = maybeUserData;
        log("UserDataProvider: Fetched Firebase data for user $userId");
      } else {
        log('UserDataProvider: No user data found for ID: $userId');
        _error = 'No user data found.';
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
  Future<bool> updateUserProfile({String? name, String? email, String? profileImageUrl}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Prepare update data
      final Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (email != null) updateData['email'] = email;
      if (profileImageUrl != null) updateData['profile_image_url'] = profileImageUrl;
      
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
            if (profileImageUrl != null) _userData!['profile_image_url'] = profileImageUrl;
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

  // Example of how to update user data if needed (e.g., profile update)
  // Future<void> updateUserName(String newName) async {
  //   if (_userId == null) return;
  //   _isLoading = true;
  //   notifyListeners();
  //   try {
  //     // Assume firebaseService has an updateUser method
  //     await _firebaseService.updateUser(_userId!, {'name': newName});
  //     _userData?['name'] = newName; // Update local state optimistically or after confirmation
  //     _error = null;
  //   } catch (e) {
  //     _error = "Failed to update name.";
  //     log("Error updating user name: $e");
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }
}

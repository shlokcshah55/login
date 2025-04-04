import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:login/services/firebase_service.dart';

class UserDataProvider with ChangeNotifier {
  final FirebaseService _firebaseService;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance; // For sign out

  UserDataProvider(this._firebaseService);

  String? _userId;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  String? _error;

  // Getters
  String? get userId => _userId;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _userId != null && _userData != null;

  /// Sets the user ID (typically after login) and fetches user data.
  Future<void> setUserIdAndFetchData(String userId) async {
    _userId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners(); // Notify UI that loading has started

    try {
      final Map<String, dynamic>? maybeUserData = await _firebaseService.getUser(userId);
      if (maybeUserData != null) {
        _userData = maybeUserData;
        log("UserDataProvider: Fetched data for user $userId: $_userData");
      } else {
        log('UserDataProvider: No user data found for ID: $userId');
        _error = 'No user data found.';
        // Optionally sign out if data is expected but missing
        // await clearUserData();
      }
    } catch (e) {
      log('UserDataProvider: Error fetching user data: $e');
      _error = 'Failed to fetch user data.';
      // Optionally sign out on critical error
      // await clearUserData();
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify UI that loading is complete (success or error)
    }
  }

  /// Clears user data (typically on logout).
  Future<void> clearUserData() async {
    _userId = null;
    _userData = null;
    _isLoading = false;
    _error = null;
    // No need to call signOut here, let the auth handler do that.
    // This provider just clears its own state.
    log("UserDataProvider: Cleared user data.");
    notifyListeners();
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

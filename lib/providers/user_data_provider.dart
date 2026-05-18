import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:login/models/users.dart';
import 'package:login/providers/referral_rewards_provider.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/service.dart';

class UserDataProvider with ChangeNotifier {
  // Add Supabase repository
  final SupabaseService _supabaseProvider = SupabaseService();

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
      (_userId != null && _userData != null) ||
      _supabaseProvider.users.isAuthenticated;

  /// User's vibe-tag affinity vector (null until profile is loaded).
  List<double>? get vibeTagAffinity => _supabaseUserData?.vibeTagAffinity;

  /// User's dietary-requirement affinity vector.
  List<int>? get dietaryRequirementTagAffinity =>
      _supabaseUserData?.dietaryRequirementTagAffinity;

  /// Whether the user has any affinity data populated.
  bool get hasAffinityData => _supabaseUserData?.hasAffinityData ?? false;

  /// Sets the user ID (typically after login) and fetches user data.
  /// If [cachedProfile] is provided, uses it instead of fetching from DB.
  Future<void> setUserIdAndFetchData(String userId,
      {UserModel? cachedProfile}) async {
    _userId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners(); // Notify UI that loading has started

    try {
      // Use cached profile if available (from signIn response)
      if (cachedProfile != null) {
        _supabaseUserData = cachedProfile;
        log("UserDataProvider: Using cached profile data");

        _userData = {
          'name': cachedProfile.name,
          'email': cachedProfile.email,
          'uid': cachedProfile.supabaseId,
          'profile_image_url': cachedProfile.profileImageUrl,
          'bio': cachedProfile.bio,
          SupabaseConstants.columnReferralCode: cachedProfile.referralCode,
        };

        _isLoading = false;
        notifyListeners();
        return;
      }

      // Try to fetch from Supabase
      if (_supabaseProvider.users.isAuthenticated) {
        print(
            "UserDataProvider: Fetching profile for userId: $userId, currentUser: ${_supabaseProvider.users.currentUser?.id}");
        final UserModel? userModel =
            await _supabaseProvider.users.getUserProfile();
        print(
            "UserDataProvider: getUserProfile returned: ${userModel != null ? 'UserModel(${userModel.email})' : 'null'}");
        if (userModel != null) {
          _supabaseUserData = userModel;
          print("UserDataProvider: Fetched Supabase data for user");

          // Also build a compatible map for backward compatibility
          _userData = {
            'name': userModel.name,
            'email': userModel.email,
            'uid': userModel.supabaseId,
            'profile_image_url': userModel.profileImageUrl,
            'bio': userModel.bio,
            SupabaseConstants.columnReferralCode: userModel.referralCode,
          };

          // Success with Supabase, exit early
          _isLoading = false;
          notifyListeners();
          return;
        } else {
          // getUserProfile returned null - user record may not exist
          log('UserDataProvider: getUserProfile returned null - user record may not exist');
          _error = 'User profile not found. Please complete setup.';
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
      {String? name,
      String? email,
      String? profileImageUrl,
      String? bio}) async {
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
      if (_supabaseProvider.users.isAuthenticated) {
        final updatedUser =
            await _supabaseProvider.users.updateUserProfile(updateData);
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

  /// Optimistically replaces the user's vibe-tag affinity vector and persists
  /// to Supabase. Reverts on failure.
  Future<bool> updateVibeTagAffinity(List<double> newAffinity) async {
    final current = _supabaseUserData;
    if (current == null || current.supabaseId == null) return false;

    final previous = current.vibeTagAffinity;
    _supabaseUserData = current.copyWith(vibeTagAffinity: newAffinity);
    notifyListeners();

    final ok = await _supabaseProvider.users
        .updateVibeTagAffinity(current.supabaseId!, newAffinity);

    if (!ok) {
      _supabaseUserData = current.copyWith(vibeTagAffinity: previous);
      notifyListeners();
    }
    return ok;
  }

  Future<bool> applyReferralCode(String code) async {
    final trimmedCode = code.trim();
    log(
      'UserDataProvider: Applying referral code="$trimmedCode" length=${trimmedCode.length}',
    );
    if (_supabaseUserData == null || trimmedCode.isEmpty) {
      log(
        'UserDataProvider: Referral apply aborted. hasUser=${_supabaseUserData != null}, isCodeEmpty=${trimmedCode.isEmpty}',
      );
      return false;
    }

    try {
      await _supabaseProvider.rewards.applyReferralCode(
        trimmedCode,
        acceptIfWizardComplete: true,
      );
      log('UserDataProvider: Referral code applied successfully.');
      return true;
    } catch (e, stackTrace) {
      log(
        'UserDataProvider: Error applying referral code: $e',
        stackTrace: stackTrace,
      );
      _error = invalidReferralCodeMessage;
      notifyListeners();
      return false;
    }
  }

  /// Updates the local cached wizard completion flag immediately after the
  /// onboarding RPC succeeds so the UI does not render stale onboarding state.
  void setWizardCompleted(bool value) {
    final current = _supabaseUserData;
    if (current == null || current.wizardCompleted == value) return;

    _supabaseUserData = current.copyWith(wizardCompleted: value);
    notifyListeners();
  }
}

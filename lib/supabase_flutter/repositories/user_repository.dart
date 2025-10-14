import 'package:flutter/foundation.dart';
import 'package:login/supabase_flutter/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../services/supabase_auth_service.dart';
import '../supabase_client.dart';

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

  /// Sign in with Google
  /// Returns true if OAuth flow was successfully initiated
  Future<bool> signInWithGoogle() async {
    try {
      return await _authService.signInWithGoogle();
    } catch (e) {
      if (kDebugMode) {
        print('Error in UserRepository.signInWithGoogle: $e');
      }
      return false;
    }
  }

  /// Ensure user record exists in database (for OAuth users)
  Future<void> ensureUserRecordExists() async {
    try {
      await _authService.ensureUserRecordExists();
    } catch (e) {
      if (kDebugMode) {
        print('Error in UserRepository.ensureUserRecordExists: $e');
      }
    }
  }

  /// Get the current user
  User? get currentUser => _authService.currentUser;

  /// Check if a user is authenticated
  bool get isAuthenticated => _authService.isAuthenticated;

  /// Get auth state changes stream
  Stream<AuthState> get onAuthStateChange => _authService.onAuthStateChange;

  /// Get user profile data
  Future<UserModel?> getUserProfile() async {
    final user = _authService.currentUser;
    if (user == null) return null;
    return await getUserProfileById(user.id);
  }

  Future<UserModel?> getUserProfileById(String userId) async {
    try {
      final Map<String, dynamic> userCreds = await SupabaseClientManager()
          .client
          .from(SupabaseConstants.tableUsers)
          .select()
          .eq(SupabaseConstants.columnSupabaseId, userId)
          .single();

      final followingDetails = await SupabaseClientManager()
          .client
          .from(SupabaseConstants.tableUserFriends)
          .select()
          .eq(SupabaseConstants.columnFolloweeId, userId)
          .eq(SupabaseConstants.columnStatus,
              SupabaseConstants.relationshipStatusAccepted);

      final followersDetails = await SupabaseClientManager()
          .client
          .from(SupabaseConstants.tableUserFriends)
          .select()
          .eq(SupabaseConstants.columnFollowerId, userId)
          .eq(SupabaseConstants.columnStatus,
              SupabaseConstants.relationshipStatusAccepted);

      userCreds['followers_count'] = followersDetails.length;
      userCreds['following_count'] = followingDetails.length;

      return UserModel.fromJson(userCreds);
    } catch (e) {
      if (kDebugMode) {
        print('Error in UserRepository.getUserProfileById: $e');
      }
      return null;
    }
  }

  /// Update user profile data
  Future<UserModel?> updateUserProfile(Map<String, dynamic> userData) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return null;

      final response = await SupabaseClientManager()
          .client
          .from('users')
          .update(userData)
          .eq('supabase_id', user.id)
          .select()
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error in UserRepository.updateUserProfile: $e');
      }
      return null;
    }
  }

  Future<List<UserModel>> getSuggestedUsers() async {
    //TODO: Implement logic to fetch suggested users based on user interests or other criteria
    try {
      final user = _authService.currentUser;
      if (user == null) return [];

      final response = await SupabaseClientManager()
          .client
          .from('users')
          .select()
          .neq('supabase_id', user.id)
          .limit(10);

      final futures = (response as List)
          .map((e) => getUserProfileById(e["supabase_id"] as String))
          .toList();

      final users = await Future.wait(futures);
      return users.whereType<UserModel>().toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error in UserRepository.getSuggestedUsers: $e');
      }
      return [];
    }
  }

  Future<void> followUser(String followingId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }
      final followeeId = user.id;

      // Prevent self-follow
      if (followeeId == followingId) {
        print("User cannot follow themselves.");
        return;
      }

      await SupabaseClientManager().client.from('user_friends').insert({
        'following_id': followingId, // Current user is the follower
        'followee_id': followeeId, // User being followed
        'status': 'requested', // Initial status
        // 'created_at' is handled by Supabase (default now())
      });
      print("Follow request sent to $followeeId from $followingId");
    } catch (e) {
      if (kDebugMode) {
        print('Error in UserRepository.followUser: $e');
      }
      rethrow; // Rethrow to allow UI to handle error
    }
  }

  Future<void> unfollowUser(String followingId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }
      final followeeId = user.id;

      await SupabaseClientManager()
          .client
          .from('user_friends')
          .delete()
          .eq('following_id', followingId)
          .eq('followee_id', followeeId);
      print("Unfollowed user $followingId from $followeeId");
    } catch (e) {
      if (kDebugMode) {
        print('Error in UserRepository.unfollowUser: $e');
      }
      rethrow; // Rethrow to allow UI to handle error
    }
  }

  // Optional: Check current follow status if needed elsewhere
  Future<String?> getFollowStatus(String followeeId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return null;
      final followerId = user.id;

      final response = await SupabaseClientManager()
          .client
          .from('user_friends')
          .select('status')
          .eq('follower_id', followerId)
          .eq('followee_id', followeeId)
          .maybeSingle(); // Use maybeSingle to handle no record found

      if (response != null && response.isNotEmpty) {
        return response['status'] as String?;
      }
      return null; // No existing relationship
    } catch (e) {
      if (kDebugMode) {
        print('Error in UserRepository.getFollowStatus: $e');
      }
      return null;
    }
  }

  /// Get list of friends (accepted relationships)
  Future<List<UserModel>> getFriends() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return [];

      // Get users where current user is the follower
      final following = await SupabaseClientManager()
          .client
          .from(SupabaseConstants.tableUserFriends)
          .select('followee_id')
          .eq(SupabaseConstants.columnFollowerId, user.id)
          .eq(SupabaseConstants.columnStatus,
              SupabaseConstants.relationshipStatusAccepted);

      // Get users where current user is the followee
      final followers = await SupabaseClientManager()
          .client
          .from(SupabaseConstants.tableUserFriends)
          .select('follower_id')
          .eq(SupabaseConstants.columnFolloweeId, user.id)
          .eq(SupabaseConstants.columnStatus,
              SupabaseConstants.relationshipStatusAccepted);

      // Combine and deduplicate user IDs
      final Set<String> friendIds = {};
      for (var f in following) {
        friendIds.add(f['followee_id'] as String);
      }
      for (var f in followers) {
        friendIds.add(f['follower_id'] as String);
      }

      if (friendIds.isEmpty) return [];

      // Fetch user details
      final usersData = await SupabaseClientManager()
          .client
          .from(SupabaseConstants.tableUsers)
          .select()
          .inFilter(SupabaseConstants.columnSupabaseId, friendIds.toList());

      return usersData.map((user) => UserModel.fromJson(user)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error in UserRepository.getFriends: $e');
      }
      return [];
    }
  }

  /// Search users by name or email
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];

      final usersData = await SupabaseClientManager()
          .client
          .from(SupabaseConstants.tableUsers)
          .select()
          .or('${SupabaseConstants.name}.ilike.%$query%,${SupabaseConstants.columnEmail}.ilike.%$query%')
          .limit(20);

      return usersData.map((user) => UserModel.fromJson(user)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error in UserRepository.searchUsers: $e');
      }
      return [];
    }
  }
}

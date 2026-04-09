import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:googleapis/mybusinessbusinessinformation/v1.dart';
import 'package:login/models/locations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_client.dart';
import '../../models/users.dart';
import '../constants.dart';

/// Service for handling Supabase authentication operations
class AuthHelper {
  final SupabaseClient _client = SupabaseClientManager().client;
  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;


 

  /// Resend the signup confirmation OTP to the given email
  Future<void> resendSignUpOtp(String email) async {
    try {
      await _client.auth.resend(type: OtpType.signup, email: email);
      if (kDebugMode) {
        print('Signup OTP resent to $email');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error resending signup OTP: $e');
      }
      rethrow;
    }
  }

  /// Verify the signup confirmation OTP code
  /// Returns true if verification succeeds (user is now confirmed and signed in)
  Future<bool> verifyEmailOtp(String email, String token) async {
    try {
      final response = await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
      if (kDebugMode) {
        print('Signup OTP verified for $email');
      }
      return response.user != null;
    } catch (e) {
      if (kDebugMode) {
        print('Error verifying signup OTP: $e');
      }
      return false;
    }
  }

  /// Sign up a new user with email and password
  Future<UserModel> signUp({
    required String email,
    required String password,
    String? name,
    String? username
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

      await _client.rpc('create_user_profile', params: {
        'p_supabase_id': user.id,
        'p_email': email,
        'p_name': name ?? '',
        'p_username': username ?? '',
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
          .from(SupabaseConstants.tableUsers)
          .select()
          .eq(SupabaseConstants.columnSupabaseId, user.id)
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
        redirectTo: 'com.example.srishlok.pinit://login-callback/',
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
  /// Returns true if a new user record was created, false if it already existed
  Future<bool> ensureUserRecordExists() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      // Check if user exists in your users table
      final existingUser = await _client
          .from(SupabaseConstants.tableUsers)
          .select()
          .eq(SupabaseConstants.columnSupabaseId, user.id)
          .maybeSingle();

      // If user doesn't exist, create a new record
      if (existingUser == null) {
        if (kDebugMode) {
          print('Creating database record for new OAuth user: ${user.email}');
        }

        final name = user.userMetadata?['name'] ?? user.userMetadata?['full_name'] ?? '';
        final username = await _generateUniqueUsername(name);

        await _client.rpc('ensure_user_record_exists', params: {
          'p_supabase_id': user.id,
          'p_email': user.email,
          'p_name': name,
          'p_username': username,
        });

        if (kDebugMode) {
          print('User record created successfully with username: $username');
        }
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error ensuring user record exists: $e');
      }
      // Don't rethrow - this is a background operation
      return false;
    }
  }

  /// Generate a unique username from the user's display name
  /// e.g. "John Smith" → "johnsmith4821"
  Future<String> _generateUniqueUsername(String name) async {
    final random = Random();
    // Clean the name: lowercase, remove non-alphanumeric, remove spaces
    final base = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final prefix = base.isNotEmpty ? base : 'user';

    // Try up to 10 times to find a unique username
    for (int i = 0; i < 10; i++) {
      final suffix = random.nextInt(9000) + 1000; // 4-digit number 1000-9999
      final candidate = '$prefix$suffix';
      if (!await usernameExists(candidate)) {
        return candidate;
      }
    }

    // Fallback: use timestamp for guaranteed uniqueness
    return '$prefix${DateTime.now().millisecondsSinceEpoch % 100000}';
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

  /// Validates the current session and attempts to refresh if needed
  /// Returns true if session is valid, false otherwise
  Future<bool> validateSession() async {
    try {
      final session = await getSession();

      if (session == null) {
        if (kDebugMode) {
          print('AuthHelper.validateSession: No session exists');
        }
        return false;
      }

      // Check if token is expired
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
      final now = DateTime.now();

      if (expiresAt.isBefore(now)) {
        if (kDebugMode) {
          print('AuthHelper.validateSession: Session expired, attempting refresh');
        }

        // Try to refresh the session
        final response = await _client.auth.refreshSession();

        if (response.session == null) {
          if (kDebugMode) {
            print('AuthHelper.validateSession: Token refresh failed');
          }
          return false;
        }

        if (kDebugMode) {
          print('AuthHelper.validateSession: Token refreshed successfully');
        }
        return true;
      }

      if (kDebugMode) {
        print('AuthHelper.validateSession: Session is valid');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('AuthHelper.validateSession: Validation failed with error: $e');
      }
      return false;
    }
  }

  /// Get user profile data for the current user
  Future<UserModel?> getUserProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return await getUserProfileById(user.id);
  }

  /// Get user profile by user ID with follower/following counts
  Future<UserModel?> getUserProfileById(String userId) async {
    try {
      final Map<String, dynamic> userCreds = await _client
          .from(SupabaseConstants.tableUsers)
          .select()
          .eq(SupabaseConstants.columnSupabaseId, userId)
          .single();

      final followingDetails = await _client
          .from(SupabaseConstants.tableUserFriends)
          .select()
          .eq(SupabaseConstants.columnFolloweeId, userId)
          .eq(SupabaseConstants.columnStatus,
              SupabaseConstants.relationshipStatusAccepted);

      final followersDetails = await _client
          .from(SupabaseConstants.tableUserFriends)
          .select()
          .eq(SupabaseConstants.columnFollowerId, userId)
          .eq(SupabaseConstants.columnStatus,
              SupabaseConstants.relationshipStatusAccepted);

      userCreds['followers_count'] = followersDetails.length;
      userCreds['following_count'] = followingDetails.length;

      return UserModel.fromJson(userCreds);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error getting user profile by ID: $e');
        print('Stack trace: $stackTrace');
      }
      return null;
    }
  }

  /// Update user profile data
  Future<UserModel?> updateUserProfile(Map<String, dynamic> userData) async {
    try {
      final user = currentUser;
      if (user == null) return null;

      // Add user_id to params and call RPC
      final params = {
        'p_user_id': user.id,
        if (userData.containsKey(SupabaseConstants.name))
          'p_name': userData[SupabaseConstants.name],
        if (userData.containsKey(SupabaseConstants.columnUsername))
          'p_username': userData[SupabaseConstants.columnUsername],
        if (userData.containsKey(SupabaseConstants.columnBio))
          'p_bio': userData[SupabaseConstants.columnBio],
        if (userData.containsKey(SupabaseConstants.columnProfileImageUrl))
          'p_profile_image_url': userData[SupabaseConstants.columnProfileImageUrl],
      };

      final response = await _client.rpc('update_user_profile', params: params);

      if (response == null || (response as List).isEmpty) return null;
      return UserModel.fromJson((response).first);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating user profile: $e');
      }
      return null;
    }
  }

  /// Get suggested users (returns random users excluding current user)
  /// TODO: Implement logic to fetch suggested users based on user interests or other criteria
  Future<List<UserModel>> getSuggestedUsers() async {
    try {
      final user = currentUser;
      if (user == null) return [];

      final response = await _client
          .from(SupabaseConstants.tableUsers)
          .select()
          .neq(SupabaseConstants.columnSupabaseId, user.id)
          .limit(10);

      final futures = (response as List)
          .map((e) => getUserProfileById(e[SupabaseConstants.columnSupabaseId] as String))
          .toList();

      final users = await Future.wait(futures);
      return users.whereType<UserModel>().toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting suggested users: $e');
      }
      return [];
    }
  }

  /// Follow a user
  Future<void> followUser(String followingId) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }
      final followeeId = user.id;

      // Prevent self-follow
      if (followeeId == followingId) {
        if (kDebugMode) {
          print("User cannot follow themselves.");
        }
        return;
      }

      await _client.rpc('create_friendship', params: {
      'p_follower_id': followingId,
      'p_followee_id': followeeId,
      'p_status': SupabaseConstants.relationshipStatusPending,
      });

      if (kDebugMode) {
        print("Follow request sent to $followeeId from $followingId");
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error following user: $e');
      }
      rethrow;
    }
  }

  /// Unfollow a user
  Future<void> unfollowUser(String followingId) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }
      final followeeId = user.id;

      await _client.rpc('unfollow_user', params: {
        'p_follower_id': followingId,
        'p_followee_id': followeeId,
      });

      if (kDebugMode) {
        print("Unfollowed user $followingId from $followeeId");
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unfollowing user: $e');
      }
      rethrow;
    }
  }

  /// Check current follow status between current user and another user
  Future<String?> getFollowStatus(String followeeId) async {
    try {
      final user = currentUser;
      if (user == null) return null;
      final followerId = user.id;

      final response = await _client
          .from(SupabaseConstants.tableUserFriends)
          .select(SupabaseConstants.columnStatus)
          .eq(SupabaseConstants.columnFollowerId, followerId)
          .eq(SupabaseConstants.columnFolloweeId, followeeId)
          .maybeSingle();

      if (response != null && response.isNotEmpty) {
        return response[SupabaseConstants.columnStatus] as String?;
      }
      return null; // No existing relationship
    } catch (e) {
      if (kDebugMode) {
        print('Error getting follow status: $e');
      }
      return null;
    }
  }

  /// Get list of friends (accepted relationships)
  Future<List<UserModel>> getFriends() async {
    try {
      final user = currentUser;
      if (user == null) return [];

      // Get users where current user is the follower
      final following = await _client
          .from(SupabaseConstants.tableUserFriends)
          .select(SupabaseConstants.columnFolloweeId)
          .eq(SupabaseConstants.columnFollowerId, user.id)
          .eq(SupabaseConstants.columnStatus,
              SupabaseConstants.relationshipStatusAccepted);

      // Get users where current user is the followee
      final followers = await _client
          .from(SupabaseConstants.tableUserFriends)
          .select(SupabaseConstants.columnFollowerId)
          .eq(SupabaseConstants.columnFolloweeId, user.id)
          .eq(SupabaseConstants.columnStatus,
              SupabaseConstants.relationshipStatusAccepted);

      // Combine and deduplicate user IDs
      final Set<String> friendIds = {};
      for (var f in following) {
        friendIds.add(f[SupabaseConstants.columnFolloweeId] as String);
      }
      for (var f in followers) {
        friendIds.add(f[SupabaseConstants.columnFollowerId] as String);
      }

      if (friendIds.isEmpty) return [];

      // Fetch user details
      final usersData = await _client
          .from(SupabaseConstants.tableUsers)
          .select()
          .inFilter(SupabaseConstants.columnSupabaseId, friendIds.toList());

      return usersData.map((user) => UserModel.fromJson(user)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting friends: $e');
      }
      return [];
    }
  }

  /// Search users by name or email
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];

      final usersData = await _client
          .from(SupabaseConstants.tableUsers)
          .select()
          .or('${SupabaseConstants.name}.ilike.%$query%,${SupabaseConstants.columnEmail}.ilike.%$query%')
          .limit(20);

      return usersData.map((user) => UserModel.fromJson(user)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error searching users: $e');
      }
      return [];
    }
  }

  /// Get all dietary requirement tags for the current user
  /// Returns a list of maps containing tag information
  Future<List<Map<String, dynamic>>> getDietaryRequirementTags() async {
    try {
      final user = currentUser;
      if (user == null) return [];

      final response = await _client
          .from(SupabaseConstants.tableUserTags)
          .select('''
            ${SupabaseConstants.columnId},
            ${SupabaseConstants.tableTags}!inner(
              ${SupabaseConstants.columnTagId},
              ${SupabaseConstants.columnText},
              ${SupabaseConstants.columnPromptDescription},
              ${SupabaseConstants.columnTagType}
            )
          ''')
          .eq(SupabaseConstants.columnUserId, user.id)
          .eq('${SupabaseConstants.tableTags}.${SupabaseConstants.columnTagType}', 'dietary_requirement');

      if ((response as List).isEmpty) {
        return [];
      }

      return (response as List).map((item) {
        final tag = item[SupabaseConstants.tableTags] as Map<String, dynamic>;
        return {
          'id': item[SupabaseConstants.columnId],
          'tag_id': tag[SupabaseConstants.columnTagId],
          'text': tag[SupabaseConstants.columnText],
          'prompt_description': tag[SupabaseConstants.columnPromptDescription],
          'tag_type': tag[SupabaseConstants.columnTagType],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting dietary requirement tags: $e');
      }
      return [];
    }
  }

  /// Get all preference tags for the current user
  /// Returns a list of maps containing tag information
  Future<List<Map<String, dynamic>>> getPreferenceTags() async {
    try {
      final user = currentUser;
      if (user == null) return [];

      final response = await _client
          .from(SupabaseConstants.tableUserTags)
          .select('''
            ${SupabaseConstants.columnId},
            ${SupabaseConstants.tableTags}!inner(
              ${SupabaseConstants.columnTagId},
              ${SupabaseConstants.columnText},
              ${SupabaseConstants.columnPromptDescription},
              ${SupabaseConstants.columnTagType}
            )
          ''')
          .eq(SupabaseConstants.columnUserId, user.id)
          .eq('${SupabaseConstants.tableTags}.${SupabaseConstants.columnTagType}', 'preference');

      if ((response as List).isEmpty) {
        return [];
      }

      return (response as List).map((item) {
        final tag = item[SupabaseConstants.tableTags] as Map<String, dynamic>;
        return {
          'id': item[SupabaseConstants.columnId],
          'tag_id': tag[SupabaseConstants.columnTagId],
          'text': tag[SupabaseConstants.columnText],
          'prompt_description': tag[SupabaseConstants.columnPromptDescription],
          'tag_type': tag[SupabaseConstants.columnTagType],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting preference tags: $e');
      }
      return [];
    }
  }

  /// Get the influence value of a specific followee on the current user
  /// Takes the followee ID and returns their influence value on the current user
  Future<int?> getFolloweeInfluence(String followeeId) async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final response = await _client
          .from(SupabaseConstants.tableUserFriends)
          .select(SupabaseConstants.columnInfluence)
          .eq(SupabaseConstants.columnFollowerId, user.id)
          .eq(SupabaseConstants.columnFolloweeId, followeeId)
          .eq(SupabaseConstants.columnStatus, SupabaseConstants.relationshipStatusAccepted)
          .maybeSingle();

      if (response == null) return null;

      return response[SupabaseConstants.columnInfluence] as int?;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting followee influence: $e');
      }
      return null;
    }
  }

  /// Get all friends (followees) and their influence values on the current user
  /// Returns a map of followee_id -> influence
  Future<Map<String, int?>> getAllFriendsInfluence() async {
    try {
      final user = currentUser;
      if (user == null) return {};

      final response = await _client
          .from(SupabaseConstants.tableUserFriends)
          .select('''
            ${SupabaseConstants.columnFolloweeId},
            ${SupabaseConstants.columnInfluence}
          ''')
          .eq(SupabaseConstants.columnFollowerId, user.id)
          .eq(SupabaseConstants.columnStatus, SupabaseConstants.relationshipStatusAccepted);

      if ((response as List).isEmpty) {
        return {};
      }

      final Map<String, int?> influenceMap = {};
      for (var item in response as List) {
        final followeeId = item[SupabaseConstants.columnFolloweeId] as String;
        final influence = item[SupabaseConstants.columnInfluence] as int?;
        influenceMap[followeeId] = influence;
      }

      return influenceMap;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all friends influence: $e');
      }
      return {};
    }
  }

  /// Add multiple tags for a user (used for signup wizard)
  /// Batch inserts tags into user_tags table
  Future<void> addUserTags(String userId, List<String> tagIds) async {
    try {
      if (tagIds.isEmpty) return;

      await _client.rpc('add_user_tags_batch', params: {
        'p_user_id': userId,
        'p_tag_ids': tagIds,
      });

      if (kDebugMode) {
        print('Added ${tagIds.length} tags for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding user tags: $e');
      }
      rethrow;
    }
  }

  /// Complete wizard onboarding for a user
  /// Updates user profile with spice tolerance and marks wizard as completed
  Future<void> AddSpiceTolerance(String userId, int spiceTolerance) async {
    try {
      await _client.rpc('complete_signup_wizard', params: {
        'p_user_id': userId,
        'p_spice_tolerance': spiceTolerance,
      });

      if (kDebugMode) {
        print('Added spice for $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error completing wizard onboarding: $e');
      }
      rethrow;
    }
  }

  Future<void> completeSignupWizard(String userId) async {
    try {
      await _client.rpc('complete_signup_wizard', params: {
        'p_user_id': userId,
      });

      if (kDebugMode) {
        print('Wizard completed for $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating spice tolerance: $e');
      }
      rethrow;
    }
  }

  Future<bool> isWizardCompleted(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableUsers)
          .select(SupabaseConstants.columnWizardCompleted)
          .eq(SupabaseConstants.columnSupabaseId, userId)
          .single();

      return response[SupabaseConstants.columnWizardCompleted] as bool? ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking wizard completion: $e');
      }
      return false;
    }
  }

  Future<bool> emailExists(String email) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableUsers)
          .select()
          .eq(SupabaseConstants.columnEmail, email)
          .maybeSingle();

      return response != null;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking if email exists: $e');
      }
      return false;
    }
  }

  Future<bool> usernameExists(String username) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableUsers)
          .select()
          .eq(SupabaseConstants.columnUsername, username)
          .maybeSingle();

      return response != null;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking if username exists: $e');
      }
      return false;
    }
  }

  /// Replaces the user's full vibe-tag affinity vector with [affinity].
  /// Writes directly to the users row (no RPC needed).
  Future<bool> updateVibeTagAffinity(
      String userId, List<int> affinity) async {
    try {
      await _client
          .from(SupabaseConstants.tableUsers)
          .update({SupabaseConstants.columnVibeTagAffinity: affinity})
          .eq(SupabaseConstants.columnSupabaseId, userId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating vibe tag affinity: $e');
      }
      return false;
    }
  }

  Future<String> uploadImage(File file, String filePath, String userId) async {
    try {
    final user = _client.auth.currentUser;
    print(user);
    if (user == null) {
      if (kDebugMode) print('Upload failed: No authenticated user found.');
      throw Exception('You must be logged in to upload a profile picture.');
    }
      // Upload file to Supabase storage
      final response = await _client.storage
          .from(SupabaseConstants.supabaseStorageBucketProfileImages)
          .upload(filePath, file);

      print(response);
      // Get public URL for the uploaded file
      final publicUrl = _client.storage
          .from(SupabaseConstants.supabaseStorageBucketProfileImages)
          .getPublicUrl(filePath);


      await _client.rpc('update_user_profile', params: {
        'p_user_id': userId,
        'p_profile_image_url': publicUrl,
      });

    
      if (kDebugMode) {
        print('Image uploaded successfully: $publicUrl');
      }

      return publicUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading image: $e');
      }
      rethrow;
    }
  }

}

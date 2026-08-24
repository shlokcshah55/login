import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:login/services/apple_auth_service.dart';
import 'package:login/services/push_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_client.dart';
import '../../models/users.dart';
import '../constants.dart';
import 'auth_failure.dart';

typedef HttpPost = Future<http.Response> Function(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
});

@visibleForTesting
Set<String> resolveMutualFriendIds({
  required List<Map<String, dynamic>> followingRows,
  required List<Map<String, dynamic>> followerRows,
}) {
  final followingIds = <String>{};
  final followerIds = <String>{};

  for (final row in followingRows) {
    final followeeId = row[SupabaseConstants.columnFolloweeId];
    if (followeeId is String && followeeId.isNotEmpty) {
      followingIds.add(followeeId);
    }
  }

  for (final row in followerRows) {
    final followerId = row[SupabaseConstants.columnFollowerId];
    if (followerId is String && followerId.isNotEmpty) {
      followerIds.add(followerId);
    }
  }

  return followingIds.intersection(followerIds);
}

@visibleForTesting
String deriveDisplayNameFromEmail(String? email) {
  if (email == null || email.trim().isEmpty) {
    return '';
  }

  final emailLocal = email.split('@').first;
  return emailLocal
      .replaceAll(RegExp(r'[._+\-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

@visibleForTesting
String resolveOAuthDisplayName({
  String? pendingDisplayName,
  Map<String, dynamic>? userMetadata,
  String? email,
}) {
  final trimmedPending = pendingDisplayName?.trim();
  if (trimmedPending != null && trimmedPending.isNotEmpty) {
    return trimmedPending;
  }

  final metadataName = (userMetadata?['name'] as String?)?.trim();
  if (metadataName != null && metadataName.isNotEmpty) {
    return metadataName;
  }

  final metadataFullName = (userMetadata?['full_name'] as String?)?.trim();
  if (metadataFullName != null && metadataFullName.isNotEmpty) {
    return metadataFullName;
  }

  return deriveDisplayNameFromEmail(email);
}

@visibleForTesting
bool didDeleteAccountResponseConfirmAuthDeletion(
  Map<String, dynamic> result,
) {
  return result['success'] == true && result['auth_deleted'] == true;
}

/// Service for handling Supabase authentication operations
class AuthHelper {
  AuthHelper({
    SupabaseClient? client,
    AppleAuthService? appleAuthService,
    HttpPost? httpPost,
  })  : _client = client ?? SupabaseClientManager().client,
        _appleAuthService = appleAuthService ?? AppleAuthService(),
        _httpPost = httpPost ?? http.post;

  final SupabaseClient _client;
  final AppleAuthService _appleAuthService;
  final HttpPost _httpPost;
  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Sign up a new user with email and password
  Future<UserModel> signUp(
      {required String email,
      required String password,
      String? name,
      String? username}) async {
    try {
      print('📝 [SIGNUP] Starting signup');

      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: name != null ? {'name': name} : null,
      );

      print('✅ [SIGNUP] Signup response received. User: ${response.user?.id}');

      if (response.user == null) {
        throw Exception('Failed to sign up. User is null.');
      }

      final user = response.user!;
      print('✅ [SIGNUP] User created successfully: ${user.id}');

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

  Future<bool> signInWithApple() async {
    try {
      await _appleAuthService.signInWithApple();
      return true;
    } on AppleSignInCancelledException {
      rethrow;
    } on AppleSignInNetworkException {
      rethrow;
    } on AuthException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Error signing in with Apple: $e');
      }
      throw AuthException('Apple sign in failed: $e');
    }
  }

  /// Ensure user record exists in database for OAuth users
  /// Called automatically when auth state changes to signed in
  /// Returns true if a new user record was created, false if it already existed
  Future<bool> ensureUserRecordExists() async {
    try {
      final user = currentUser;
      if (user == null) return false;
      final pendingDisplayName = AppleSignInProfileHint.takeDisplayName();

      // Check if user exists in your users table
      final existingUser = await _client
          .from(SupabaseConstants.tableUsers)
          .select()
          .eq(SupabaseConstants.columnSupabaseId, user.id)
          .maybeSingle();
      print(
          'Checked for existing user record for ${user.email}, found: $existingUser');

      final fallbackName = deriveDisplayNameFromEmail(user.email);

      // If user doesn't exist, create a new record
      if (existingUser == null) {
        if (kDebugMode) {
          print('Creating database record for new OAuth user: ${user.id}');
        }

        final name = resolveOAuthDisplayName(
          pendingDisplayName: pendingDisplayName,
          userMetadata: user.userMetadata,
          email: user.email,
        );
        final username = await _generateUniqueUsername(name, email: user.email);

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

      if (pendingDisplayName != null) {
        final currentName =
            (existingUser[SupabaseConstants.columnName] as String?)?.trim() ??
                '';
        final shouldRepairName =
            currentName.isEmpty || currentName == fallbackName;

        if (shouldRepairName) {
          await _client.rpc('update_user_profile', params: {
            'p_user_id': user.id,
            'p_name': pendingDisplayName,
          });
        }
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

  /// Generate a unique username from the user's display name or email local part.
  /// e.g. "John Smith" → "johnsmith4821"
  Future<String> _generateUniqueUsername(String name, {String? email}) async {
    final random = Random();
    // Clean the name: lowercase, remove non-alphanumeric, remove spaces
    String base = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (base.isEmpty && email != null) {
      base = email
          .split('@')
          .first
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
    }
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
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    try {
      await _client.auth.signOut(scope: scope);
    } catch (e) {
      if (kDebugMode) {
        print('Error signing out: $e');
      }
      rethrow;
    }
  }

  /// Permanently delete the current authenticated account.
  ///
  /// The RPC must confirm both the profile row and the underlying auth user
  /// were deleted before we clear the local session.
  Future<void> deleteMyAccount() async {
    try {
      final session = _client.auth.currentSession;
      if (session == null) {
        throw Exception('User not authenticated');
      }

      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
      if (supabaseUrl == null || supabaseAnonKey == null) {
        throw Exception('Supabase configuration missing');
      }

      final response = await _httpPost(
        Uri.parse('$supabaseUrl/rest/v1/rpc/delete_my_account'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: '{}',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = response.body.trim();
        if (body.isNotEmpty) {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            throw Exception(
              decoded['error'] ??
                  decoded['message'] ??
                  'Failed to delete account',
            );
          }
        }
        throw Exception('Failed to delete account');
      }

      final responseBody = response.body.trim();
      if (responseBody.isEmpty) {
        throw Exception('Failed to delete account');
      }

      final result = Map<String, dynamic>.from(
        jsonDecode(responseBody) as Map,
      );
      if (!didDeleteAccountResponseConfirmAuthDeletion(result)) {
        throw Exception(
          result['error'] as String? ??
              'Account deletion did not remove the auth account',
        );
      }

      try {
        await _client.auth.signOut(scope: SignOutScope.local);
      } catch (e) {
        if (kDebugMode) {
          print('Error clearing local session after account deletion: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting account: $e');
      }
      rethrow;
    }
  }

  /// Get the current authenticated user

  /// Reset password for a user
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'com.srishlok.pinit://login-callback/',
      );
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

  /// Refresh this far ahead of expiry so a slightly fast device clock never
  /// makes a live session look dead.
  static const Duration sessionExpiryLeeway = Duration(seconds: 60);

  Future<SessionValidity>? _inFlightSessionCheck;

  /// Checks whether the stored session is usable, refreshing if needed.
  ///
  /// Returns [SessionValidity.unknown] when the server could not be reached —
  /// callers must keep the session and retry, never sign out.
  Future<SessionValidity> checkSession() {
    return _inFlightSessionCheck ??= _checkSession().whenComplete(() {
      _inFlightSessionCheck = null;
    });
  }

  Future<SessionValidity> _checkSession() async {
    final session = _client.auth.currentSession;
    if (session == null) {
      if (kDebugMode) {
        print('AuthHelper.checkSession: No session exists');
      }
      return SessionValidity.invalid;
    }

    final expiresAtSeconds = session.expiresAt;
    if (expiresAtSeconds == null) {
      // No expiry recorded: trust the SDK's own refresh scheduling.
      return SessionValidity.valid;
    }

    final expiresAt =
        DateTime.fromMillisecondsSinceEpoch(expiresAtSeconds * 1000);
    if (DateTime.now().isBefore(expiresAt.subtract(sessionExpiryLeeway))) {
      return SessionValidity.valid;
    }

    try {
      final response = await _client.auth.refreshSession();
      // A null session here is an incomplete response, not a rejection.
      return response.session == null
          ? SessionValidity.unknown
          : SessionValidity.valid;
    } catch (e) {
      final kind = classifyAuthFailure(e);
      if (kDebugMode) {
        print('AuthHelper.checkSession: Refresh failed ($kind): $e');
      }
      return kind == AuthFailureKind.fatal
          ? SessionValidity.invalid
          : SessionValidity.unknown;
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

      // followee_id = userId → someone follows this user → followers
      final followersRows = await _client
          .from(SupabaseConstants.tableUserFriends)
          .select()
          .eq(SupabaseConstants.columnFolloweeId, userId)
          .eq(SupabaseConstants.columnStatus,
              SupabaseConstants.relationshipStatusAccepted);

      // follower_id = userId → this user follows someone → following
      final followingRows = await _client
          .from(SupabaseConstants.tableUserFriends)
          .select()
          .eq(SupabaseConstants.columnFollowerId, userId)
          .eq(SupabaseConstants.columnStatus,
              SupabaseConstants.relationshipStatusAccepted);

      userCreds['followers_count'] = followersRows.length;
      userCreds['following_count'] = followingRows.length;

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
          'p_profile_image_url':
              userData[SupabaseConstants.columnProfileImageUrl],
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

  /// Returns users ranked by centered cosine similarity of vibe_tag_affinity.
  /// Users already in any friendship relation are excluded.
  Future<List<UserModel>> getSuggestedUsers() async {
    try {
      final user = currentUser;
      if (user == null) return [];

      final response = await _client.rpc('get_suggested_users', params: {
        'p_supabase_id': user.id,
        'p_limit': 10,
      });

      return (response as List)
          .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
          .toList();
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
      final followerId = user.id;

      // Prevent self-follow
      if (followerId == followingId) {
        if (kDebugMode) {
          print("User cannot follow themselves.");
        }
        return;
      }

      await _client.rpc('create_friendship', params: {
        'p_follower_id': followerId,
        'p_followee_id': followingId,
        'p_status': SupabaseConstants.relationshipStatusRequested,
      });

      if (kDebugMode) {
        print("Follow request sent from $followerId to $followingId");
      }

      // Best-effort: push + persist via Cloud Function. Don't fail the follow if push fails.
      unawaited(PushNotificationService().sendFollowRequestNotification(
        recipientUserId: followingId,
        requesterUserId: followerId,
      ));
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
      final followerId = user.id;

      await _client.rpc('unfollow_user', params: {
        'p_follower_id': followerId,
        'p_followee_id': followingId,
      });

      if (kDebugMode) {
        print("User $followerId unfollowed $followingId");
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

  /// Accept an incoming follow request
  Future<void> acceptFollowRequest(String requesterId) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _client.rpc('accept_friendship', params: {
        'request_from_id': requesterId,
        'user_id': user.id,
      });

      unawaited(PushNotificationService().sendFollowAcceptedNotification(
        recipientUserId: requesterId,
        accepterUserId: user.id,
      ));
    } catch (e) {
      if (kDebugMode) {
        print('Error accepting follow request: $e');
      }
      rethrow;
    }
  }

  /// Reject an incoming follow request
  Future<void> rejectFollowRequest(String requesterId) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _client.rpc('reject_friendship', params: {
        'request_from_id': requesterId,
        'user_id': user.id,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error rejecting follow request: $e');
      }
      rethrow;
    }
  }

  /// Block another user
  Future<void> blockUser(String targetId) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _client.rpc('block_user', params: {
        'p_blocker_id': user.id,
        'p_blocked_id': targetId,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error blocking user: $e');
      }
      rethrow;
    }
  }

  /// Unblock a previously blocked user
  Future<void> unblockUser(String targetId) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _client.rpc('unblock_user', params: {
        'p_blocker_id': user.id,
        'p_blocked_id': targetId,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error unblocking user: $e');
      }
      rethrow;
    }
  }

  /// Get incoming follow requests for the current user
  Future<List<UserModel>> getIncomingFollowRequests() async {
    try {
      final user = currentUser;
      if (user == null) return [];

      final response = await _client
          .rpc('get_incoming_follow_requests', params: {'p_user_id': user.id});

      return (response as List)
          .map((row) => UserModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching incoming follow requests: $e');
      }
      return [];
    }
  }

  /// Get the followers of a given user (defaults to current user)
  Future<List<UserModel>> getFollowers({String? userId}) async {
    try {
      final targetId = userId ?? currentUser?.id;
      if (targetId == null) return [];

      final response =
          await _client.rpc('get_followers', params: {'p_user_id': targetId});

      return (response as List)
          .map((row) => UserModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching followers: $e');
      }
      rethrow;
    }
  }

  /// Get the users that a given user is following (defaults to current user)
  Future<List<UserModel>> getFollowingList({String? userId}) async {
    try {
      final targetId = userId ?? currentUser?.id;
      if (targetId == null) return [];

      final response =
          await _client.rpc('get_following', params: {'p_user_id': targetId});

      return (response as List)
          .map((row) => UserModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching following list: $e');
      }
      rethrow;
    }
  }

  /// Get the users that the current user has blocked
  Future<List<UserModel>> getBlockedUsers() async {
    try {
      final user = currentUser;
      if (user == null) return [];

      final response = await _client
          .rpc('get_blocked_users', params: {'p_user_id': user.id});

      return (response as List)
          .map((row) => UserModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching blocked users: $e');
      }
      return [];
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

      final friendIds = resolveMutualFriendIds(
        followingRows: List<Map<String, dynamic>>.from(following),
        followerRows: List<Map<String, dynamic>>.from(followers),
      );

      if (friendIds.isEmpty) return [];

      // Fetch full profiles with counts
      final futures = friendIds.map((id) => getUserProfileById(id)).toList();
      final users = await Future.wait(futures);
      return users.whereType<UserModel>().toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting friends: $e');
      }
      return [];
    }
  }

  /// Search users by name or email (uses server-side RPC that includes
  /// followers_count / following_count).
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];

      final response = await _client.rpc('search_users', params: {
        'p_query': query,
        'p_limit': 20,
      });

      return (response as List)
          .map((row) => UserModel.fromJson(row as Map<String, dynamic>))
          .toList();
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
          .eq('${SupabaseConstants.tableTags}.${SupabaseConstants.columnTagType}',
              'dietary_requirement');

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
          .eq('${SupabaseConstants.tableTags}.${SupabaseConstants.columnTagType}',
              'preference');

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
          .eq(SupabaseConstants.columnStatus,
              SupabaseConstants.relationshipStatusAccepted)
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
          .eq(SupabaseConstants.columnStatus,
              SupabaseConstants.relationshipStatusAccepted);

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

  /// Complete wizard onboarding: marks wizard_completed = true, sets
  /// spice tolerance, and seeds dietary tag affinities — all atomically
  /// in a single RPC call.
  Future<void> finalizeSignupWizard(
    String userId, {
    required int spiceTolerance,
    required List<String> dietaryTagIds,
  }) async {
    try {
      await _client.rpc('complete_signup_wizard', params: {
        'p_user_id': userId,
        'p_spice_tolerance': spiceTolerance,
        'p_dietary_tag_ids': dietaryTagIds,
      });

      if (kDebugMode) {
        print('Finalized wizard for $userId '
            '(spice=$spiceTolerance, dietary=${dietaryTagIds.length})');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error finalizing wizard: $e');
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

      return response[SupabaseConstants.columnWizardCompleted] as bool? ??
          false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking wizard completion: $e');
      }
      return false;
    }
  }

  Future<bool> hasAcceptedLegalConsent(String userId) async {
    return await getLegalConsentStatus(userId) ?? false;
  }

  /// Returns null when the server could not be reached or the response could
  /// not be decoded, so cached consent is not mistaken for a server rejection.
  Future<bool?> getLegalConsentStatus(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableUsers)
          .select(SupabaseConstants.columnLegalConsentAcceptedAt)
          .eq(SupabaseConstants.columnSupabaseId, userId)
          .single();

      return response[SupabaseConstants.columnLegalConsentAcceptedAt] != null;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking legal consent: $e');
      }
      return null;
    }
  }

  Future<void> acceptLegalConsent(String userId) async {
    try {
      await _client.from(SupabaseConstants.tableUsers).update({
        SupabaseConstants.columnLegalConsentAcceptedAt:
            DateTime.now().toUtc().toIso8601String(),
      }).eq(SupabaseConstants.columnSupabaseId, userId);
    } catch (e) {
      if (kDebugMode) {
        print('Error accepting legal consent: $e');
      }
      rethrow;
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
      String userId, List<double> affinity) async {
    try {
      await _client
          .from(SupabaseConstants.tableUsers)
          .update({SupabaseConstants.columnVibeTagAffinity: affinity}).eq(
              SupabaseConstants.columnSupabaseId, userId);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error updating vibe tag affinity: $e');
      }
      return false;
    }
  }

  Future<bool> applyReferralCode(String code) async {
    final user = currentUser;
    final trimmedCode = code.trim();
    if (user == null || trimmedCode.isEmpty) return false;

    try {
      await _client.from(SupabaseConstants.tableUsers).update({
        SupabaseConstants.columnReferralCode: trimmedCode,
      }).eq(SupabaseConstants.columnSupabaseId, user.id);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error applying referral code: $e');
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

      final contentType = _profileImageContentType(filePath);

      // Overwrite the user's current profile image at a stable storage path.
      await _client.storage
          .from(SupabaseConstants.supabaseStorageBucketProfileImages)
          .upload(
            filePath,
            file,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
            ),
          );

      // Append a version query param so Flutter doesn't keep showing a cached
      // older avatar when the storage path stays the same across uploads.
      final storageUrl = _client.storage
          .from(SupabaseConstants.supabaseStorageBucketProfileImages)
          .getPublicUrl(filePath);
      final publicUrl =
          '$storageUrl?v=${DateTime.now().millisecondsSinceEpoch}';

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

  String _profileImageContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}

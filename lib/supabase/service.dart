import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:login/models/users.dart';
import 'package:login/services/apple_auth_service.dart';
import 'package:login/supabase/helpers/auth.dart';
import 'package:login/supabase/helpers/collections.dart';
import 'package:login/supabase/helpers/location.dart';
import 'package:login/supabase/helpers/notes_import.dart';
import 'package:login/supabase/helpers/location_reviews.dart';
import 'package:login/supabase/helpers/rewards.dart';
import 'package:login/supabase/helpers/tags.dart';
import 'package:login/services/referral_prompt_service.dart';
import 'package:login/services/fcm_service.dart';
import 'package:login/services/analytics_service.dart';
import 'package:login/supabase/auth_signout_reason.dart';
import 'package:login/supabase/auth_stream_error_policy.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/bubbles.dart';
import 'helpers/messaging.dart';
import 'helpers/notifications.dart';
import 'supabase_client.dart';

/// Provider class for Supabase services
class SupabaseService extends ChangeNotifier {
  // Lazy-initialized helpers (created after Supabase is initialized)
  late final AuthHelper _authService;
  late final LocationHelper _locationService;
  late final BubbleHelper _bubbleService;
  late final TagsHelper _tagsService;
  late final LocationReviewsHelper _reviewsService;
  late final NotificationsHelper _notificationsService;
  late final MessagingHelper _messagingService;
  late final CollectionsHelper _collectionsService;
  late final NotesImportHelper _notesImportService;
  late final RewardsHelper _rewardsService;

  bool _isLoading = false;
  bool _isInitializing = true;
  String? _error;
  StreamSubscription? _authSubscription;
  bool _hasValidSession = false;
  bool _isValidatingSession = false;
  bool _pendingOAuthWizardRouting = false;
  // Guards against concurrent auth events (e.g. userUpdated / tokenRefreshed)
  // notifying listeners before the signedIn handler has finished creating the
  // user record, which would cause ProfilePage to fetch a non-existent row.
  bool _isHandlingSignedIn = false;

  // Completer for waiting on initial auth state (replaces 500ms delay)
  Completer<void>? _authStateCompleter;
  bool _hasReceivedInitialAuthState = false;

  // Cached profile from sign-in to avoid double fetch
  UserModel? _cachedUserProfile;

  // Signals that the app received a password recovery deep link and should
  // show the reset password screen. Cleared by the UI after handling.
  final ValueNotifier<bool> passwordRecoveryRequested =
      ValueNotifier<bool>(false);

  // Getters for repositories
  AuthHelper get users => _authService;
  LocationHelper get locations => _locationService;
  BubbleHelper get bubbles => _bubbleService;
  TagsHelper get tags => _tagsService;
  LocationReviewsHelper get reviews => _reviewsService;
  NotificationsHelper get notifications => _notificationsService;
  MessagingHelper get messaging => _messagingService;
  CollectionsHelper get collections => _collectionsService;
  NotesImportHelper get notesImport => _notesImportService;
  RewardsHelper get rewards => _rewardsService;

  // Status getters
  bool get isLoading => _isLoading || _isInitializing;
  String? get error => _error;
  bool get isAuthenticated => _authService.isAuthenticated;
  bool get hasValidSession => _hasValidSession;
  bool get isValidatingSession => _isValidatingSession;
  bool get pendingOAuthWizardRouting => _pendingOAuthWizardRouting;

  // Cached profile getter - use this to avoid re-fetching after login
  UserModel? get cachedUserProfile => _cachedUserProfile;
  void clearCachedUserProfile() => _cachedUserProfile = null;
  void clearPendingOAuthWizardRouting() => _pendingOAuthWizardRouting = false;

  // Create single instance of this provider
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal() {
    // Auth listener will be set up after initialization
  }

  // Initialize Supabase
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await SupabaseClientManager.initialize();

      // Create helpers AFTER Supabase is initialized
      _authService = AuthHelper();
      _locationService = LocationHelper();
      _reviewsService = LocationReviewsHelper();
      _bubbleService = BubbleHelper();
      _tagsService = TagsHelper();
      _notificationsService = NotificationsHelper();
      _messagingService = MessagingHelper();
      _collectionsService = CollectionsHelper();
      _notesImportService = NotesImportHelper();
      _rewardsService = RewardsHelper();

      // Initialize completer before setting up listener
      _authStateCompleter = Completer<void>();

      // Set up auth state listener now that helpers are created
      _setupAuthListener();

      _setError(null);

      // Wait for auth state to be ready (no more 500ms delay!)
      await ensureAuthStateReady();

      // Auth listener handles ensureUserRecordExists on signedIn event
      // Just validate if we have a session already
      if (_authService.isAuthenticated && !_hasValidSession) {
        if (kDebugMode) {
          print('SupabaseService: Found existing session, validating...');
        }

        final isValid = await _authService.validateSession();
        print('isValid: $isValid');

        if (isValid) {
          // Note: ensureUserRecordExists is called only in auth listener
          _hasValidSession = true;
        } else {
          if (kDebugMode) {
            print('SupabaseService: Restored session is invalid, signing out');
          }
          await signOut(reason: AuthSignOutReason.startupSessionInvalid);
          _hasValidSession = false;
        }
      }
    } catch (e) {
      _setError('Failed to initialize Supabase: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Ensure auth state is ready before routing decisions
  Future<void> ensureAuthStateReady() async {
    // If we already received initial auth state, no need to wait
    if (_hasReceivedInitialAuthState) {
      _isInitializing = false;
      notifyListeners();
      return;
    }

    // Wait for auth state stream to emit initial state (with timeout)
    // This replaces the old 500ms hard-coded delay
    if (_authStateCompleter != null && !_authStateCompleter!.isCompleted) {
      try {
        await _authStateCompleter!.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            if (kDebugMode) {
              print(
                  'SupabaseService: Auth state wait timed out, proceeding anyway');
            }
          },
        );
      } catch (e) {
        if (kDebugMode) {
          print('SupabaseService: Error waiting for auth state: $e');
        }
      }
    }

    _isInitializing = false;
    notifyListeners();
  }

  // Authentication methods
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    try {
      // Cache the profile to avoid double-fetch later
      _cachedUserProfile =
          await _authService.signIn(email: email, password: password);
      _setError(null);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Sign in failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<String> signUp(String email, String password,
      {String? name, String? username}) async {
    _setLoading(true);
    try {
      UserModel user = await _authService.signUp(
          email: email, password: password, name: name, username: username);
      await _markReferralPromptPending(user.supabaseId);
      _setError(null);
      notifyListeners();
      return user.supabaseId ?? '';
    } catch (e) {
      _setError('Sign up failed: $e');
      return '';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut({
    AuthSignOutReason reason = AuthSignOutReason.userInitiated,
  }) async {
    _setLoading(true);
    try {
      AnalyticsService().track(
        eventName: 'auth_session_ended',
        eventCategory: 'auth',
        properties: <String, dynamic>{'reason': reason.wireName},
      );

      // Clear the FCM token BEFORE tearing down the session. The
      // `update_fcm_token` RPC runs under the current user's RLS context, so
      // it has to happen while we're still authenticated. If we defer this
      // to the signedOut event listener, `currentUser` is already null and
      // the clear silently becomes a no-op — leaving the device receiving
      // push notifications for the logged-out account.
      await FCMService().clearFCMToken();
      FCMService().cleanupOnLogout();

      // Clear all caches before signing out
      _clearAllCaches();

      await _authService.signOut();
      _setError(null);
      notifyListeners();
    } catch (e) {
      _setError('Sign out failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteMyAccount() async {
    _setLoading(true);
    try {
      await FCMService().clearFCMToken();
      await _authService.deleteMyAccount();
      // The RPC path signs out inside AuthHelper, so record the reason here
      // rather than routing account deletion through signOut().
      AnalyticsService().track(
        eventName: 'auth_session_ended',
        eventCategory: 'auth',
        properties: <String, dynamic>{
          'reason': AuthSignOutReason.accountDeleted.wireName,
        },
      );
      _setError(null);
    } catch (e) {
      if (_authService.isAuthenticated) {
        try {
          await FCMService().refreshAndSaveToken();
        } catch (restoreError) {
          if (kDebugMode) {
            print(
              'SupabaseService: Error restoring FCM token after failed delete: $restoreError',
            );
          }
        }
      }
      _setError('Delete account failed: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Clear all cached data (call on logout or user switch)
  void _clearAllCaches() {
    // Clear cached user profile
    _cachedUserProfile = null;

    // Clear location cache
    _locationService.clearCache();

    // Reset session state
    _hasValidSession = false;
    _pendingOAuthWizardRouting = false;

    if (kDebugMode) {
      print('SupabaseService: Cleared all caches');
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _pendingOAuthWizardRouting = true;
    try {
      final success = await _authService.signInWithGoogle();
      if (success) {
        _setError(null);
        // Note: Don't navigate here - let auth state listener handle it
        // The OAuth flow happens asynchronously via browser
      } else {
        _pendingOAuthWizardRouting = false;
        _setError('Failed to initiate Google sign in');
      }
      return success;
    } catch (e) {
      _pendingOAuthWizardRouting = false;
      _setError('Google sign in failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithApple() async {
    _setLoading(true);
    _pendingOAuthWizardRouting = true;
    try {
      final success = await _authService.signInWithApple();
      _setError(null);
      return success;
    } on AppleSignInCancelledException {
      _pendingOAuthWizardRouting = false;
      _setError(null);
      rethrow;
    } on AppleSignInNetworkException catch (e) {
      _pendingOAuthWizardRouting = false;
      _setError(e.message);
      rethrow;
    } on AuthException catch (e) {
      _pendingOAuthWizardRouting = false;
      _setError(e.message);
      rethrow;
    } catch (e) {
      _pendingOAuthWizardRouting = false;
      _setError('Apple sign in failed: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<UserModel>> searchUsers(String query) async {
    return await _authService.searchUsers(query);
  }

  /// Validate current session and sign out if invalid
  Future<bool> validateAndRefreshSession() async {
    if (!_authService.isAuthenticated) {
      _hasValidSession = false;
      return false;
    }

    _isValidatingSession = true;
    notifyListeners();

    try {
      final isValid = await _authService.validateSession();

      if (!isValid) {
        if (kDebugMode) {
          print('SupabaseService: Session validation failed, signing out user');
        }
        await signOut(reason: AuthSignOutReason.authEventSessionInvalid);
        _hasValidSession = false;
        return false;
      }

      _hasValidSession = true;
      return true;
    } finally {
      _isValidatingSession = false;
      notifyListeners();
    }
  }

  // Set up auth state listener with comprehensive error handling
  void _setupAuthListener() {
    _authSubscription = _authService.onAuthStateChange.listen(
      (state) async {
        if (kDebugMode) {
          print('SupabaseService: Auth state changed: ${state.event}');
        }

        // Signal that we've received initial auth state (completes the Completer)
        if (!_hasReceivedInitialAuthState) {
          _hasReceivedInitialAuthState = true;
          if (_authStateCompleter != null &&
              !_authStateCompleter!.isCompleted) {
            _authStateCompleter!.complete();
          }
        }

        // Handle different auth events
        switch (state.event) {
          case AuthChangeEvent.signedIn:
            // Block concurrent events from notifying until we've finished
            // creating the user record and caching the profile.
            _isHandlingSignedIn = true;
            try {
              // User just signed in - this is the ONLY place we call ensureUserRecordExists
              final isNewUser = await _authService.ensureUserRecordExists();
              print('Is user new: $isNewUser');

              // For new OAuth users, initialize vibe tags and assign a default profile picture
              if (isNewUser && _authService.currentUser != null) {
                final userId = _authService.currentUser!.id;
                _pendingOAuthWizardRouting = true;
                await _markReferralPromptPending(userId);
                await _tagsService.initializeVibeTagsForUser(userId);
                await _uploadDefaultProfilePicture(userId);
                if (kDebugMode) {
                  print(
                      'SupabaseService: Initialized vibe tags and profile picture for new OAuth user');
                }
              }

              // Cache profile now so AuthHandler can use it without a race
              _cachedUserProfile = await _authService.getUserProfile();
              print(
                  'Cached user profile after sign in: ${_cachedUserProfile?.name}');
              // Save FCM token to new user account
              _hasValidSession = true;

              await FCMService().refreshAndSaveToken();

              // Reinitialize notifications (load from DB and setup Realtime)
              await FCMService().reinitializeAfterLogin();
            } finally {
              _isHandlingSignedIn = false;
            }

            notifyListeners();
            break;

          case AuthChangeEvent.signedOut:
            // User signed out - clear all caches
            _clearAllCaches();

            // Clear FCM token from backend to prevent notifications to logged-out user
            await FCMService().clearFCMToken();

            // Cleanup notifications
            FCMService().cleanupOnLogout();

            _hasValidSession = false;
            notifyListeners();
            break;

          case AuthChangeEvent.tokenRefreshed:
            // Token was successfully refreshed
            if (kDebugMode) {
              print('SupabaseService: Token refreshed successfully');
            }
            _hasValidSession = true;
            if (!_isHandlingSignedIn) notifyListeners();
            break;

          case AuthChangeEvent.userUpdated:
            // User data updated
            if (!_isHandlingSignedIn) notifyListeners();
            break;

          case AuthChangeEvent.passwordRecovery:
            // User tapped the reset-password email link. Supabase grants a
            // short-lived recovery session; surface a flag so the UI can
            // push the reset-password screen.
            _hasValidSession = true;
            passwordRecoveryRequested.value = true;
            notifyListeners();
            break;

          default:
            // For other events, validate the session — but skip if the
            // signedIn handler is still running to avoid a premature notify.
            if (_authService.isAuthenticated && !_isHandlingSignedIn) {
              final isValid = await _authService.validateSession();
              if (!isValid) {
                if (kDebugMode) {
                  print(
                      'SupabaseService: Session validation failed after auth event, signing out');
                }
                await signOut(
                    reason: AuthSignOutReason.authEventSessionInvalid);
              } else {
                _hasValidSession = true;
                notifyListeners();
              }
            }
        }
      },
      onError: (Object error) {
        if (!shouldEndSessionForAuthStreamError(error)) {
          // Transient: the SDK keeps retrying with backoff and will emit
          // tokenRefreshed on success. Discarding the session here would throw
          // away a still-valid refresh token.
          if (kDebugMode) {
            print(
                'SupabaseService: Transient auth error, keeping session: $error');
          }
          AnalyticsService().recordError(
            key: 'auth_refresh_transient',
            properties: <String, dynamic>{
              'error': error.runtimeType.toString(),
            },
          );
          return;
        }

        if (kDebugMode) {
          print('SupabaseService: Fatal auth error, ending session: $error');
        }
        _hasValidSession = false;
        signOut(reason: AuthSignOutReason.authStreamFatalError);
      },
    );
  }

  Future<void> _markReferralPromptPending(String? userId) async {
    try {
      await ReferralPromptService().markPendingForUser(userId);
    } catch (e) {
      if (kDebugMode) {
        print('SupabaseService: Error marking referral prompt pending: $e');
      }
    }
  }

  /// Upload a random default food icon as the profile picture for a new user
  Future<void> _uploadDefaultProfilePicture(String userId) async {
    try {
      final iconFiles = [
        'lib/assets/pin_emojis/burgerIcon.jpg',
        'lib/assets/pin_emojis/curryIcon.jpg',
        'lib/assets/pin_emojis/donutIcon.jpg',
        'lib/assets/pin_emojis/phoIcon.jpg',
        'lib/assets/pin_emojis/pizzaIcon.jpg',
        'lib/assets/pin_emojis/steakIcon.jpg',
        'lib/assets/pin_emojis/sushiIcon.jpg',
        'lib/assets/pin_emojis/tacoIcon.jpg',
        'lib/assets/pin_emojis/thaiIcon.jpg',
      ];

      final random = Random();
      final selectedIcon = iconFiles[random.nextInt(iconFiles.length)];

      final byteData = await rootBundle.load(selectedIcon);
      final bytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final fileName = selectedIcon.split('/').last;
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);

      final fileExt = fileName.split('.').last;
      final filePath = '$userId/$userId.$fileExt';

      await _authService.uploadImage(tempFile, filePath, userId);

      if (kDebugMode) {
        print(
            'SupabaseService: Default profile picture uploaded for user $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('SupabaseService: Error uploading default profile picture: $e');
      }
      // Don't rethrow - this is a background operation
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // Cancel auth subscription to prevent memory leaks
    _authSubscription?.cancel();
    super.dispose();
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:login/models/users.dart';
import 'package:login/supabase/helpers/auth.dart';
import 'package:login/supabase/helpers/location.dart';
import 'package:login/supabase/helpers/location_reviews.dart';
import 'package:login/supabase/helpers/tags.dart';
import 'package:login/services/fcm_service.dart';
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

  bool _isLoading = false;
  bool _isInitializing = true;
  String? _error;
  StreamSubscription? _authSubscription;
  bool _hasValidSession = false;
  bool _isValidatingSession = false;

  // Getters for repositories
  AuthHelper get users => _authService;
  LocationHelper get locations => _locationService;
  BubbleHelper get bubbles => _bubbleService;
  TagsHelper get tags => _tagsService;
  LocationReviewsHelper get reviews => _reviewsService;
  NotificationsHelper get notifications => _notificationsService;
  MessagingHelper get messaging => _messagingService;

  // Status getters
  bool get isLoading => _isLoading || _isInitializing;
  String? get error => _error;
  bool get isAuthenticated => _authService.isAuthenticated;
  bool get hasValidSession => _hasValidSession;
  bool get isValidatingSession => _isValidatingSession;

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

      // Set up auth state listener now that helpers are created
      _setupAuthListener();

      _setError(null);
      await ensureAuthStateReady();

      // If user is already authenticated (restored session), validate it
      if (_authService.isAuthenticated) {
        if (kDebugMode) {
          print('SupabaseService: Found existing session, validating...');
        }

        final isValid = await _authService.validateSession();

        if (isValid) {
          await _authService.ensureUserRecordExists();
          _hasValidSession = true;
        } else {
          if (kDebugMode) {
            print('SupabaseService: Restored session is invalid, signing out');
          }
          await _authService.signOut();
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
    // Wait for auth state stream to emit initial state
    // Increased from 100ms to 500ms to handle slower devices/networks
    await Future.delayed(Duration(milliseconds: 500));
    _isInitializing = false;
    notifyListeners();
  }
  
  // Authentication methods
  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    try {
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

  Future<String> signUp(String email, String password, {String? name, String? username}) async {
    _setLoading(true);
    try {
      UserModel user = await _authService.signUp(email: email, password: password, name: name, username: username);
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
  
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _setError(null);
      notifyListeners();
    } catch (e) {
      _setError('Sign out failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    try {
      final success = await _authService.signInWithGoogle();
      if (success) {
        _setError(null);
        // Note: Don't navigate here - let auth state listener handle it
        // The OAuth flow happens asynchronously via browser
      } else {
        _setError('Failed to initiate Google sign in');
      }
      return success;
    } catch (e) {
      _setError('Google sign in failed: $e');
      return false;
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
        await signOut();
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

        // Handle different auth events
        switch (state.event) {
          case AuthChangeEvent.signedIn:
            // User just signed in
            await _authService.ensureUserRecordExists();
            _hasValidSession = true;

            // Save FCM token to new user account
            await FCMService().refreshAndSaveToken();

            // Reinitialize notifications (load from DB and setup Realtime)
            await FCMService().reinitializeAfterLogin();

            notifyListeners();
            break;

          case AuthChangeEvent.signedOut:
            // User signed out
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
            notifyListeners();
            break;

          case AuthChangeEvent.userUpdated:
            // User data updated
            notifyListeners();
            break;

          default:
            // For other events, validate the session
            if (_authService.isAuthenticated) {
              final isValid = await _authService.validateSession();
              if (!isValid) {
                if (kDebugMode) {
                  print('SupabaseService: Session validation failed after auth event, signing out');
                }
                await signOut();
              } else {
                _hasValidSession = true;
                notifyListeners();
              }
            }
        }
      },
      onError: (error) {
        // Handle auth stream errors (e.g., token refresh failures)
        if (kDebugMode) {
          print('SupabaseService: Auth state error: $error');
        }

        // If we get an error in the auth stream, sign out the user
        _hasValidSession = false;
        signOut();
      },
    );
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:googleapis/compute/v1.dart';
import 'package:login/models/users.dart';
import 'package:login/supabase/helpers/auth.dart';
import 'package:login/supabase/helpers/location.dart';
import 'package:login/supabase/helpers/tags.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers/bubbles.dart';
import 'supabase_client.dart';

/// Provider class for Supabase services
class SupabaseService extends ChangeNotifier {
  final AuthHelper _authService = AuthHelper();
  final LocationHelper _locationService = LocationHelper();
  final BubbleHelper _bubbleService = BubbleHelper();
  final TagsHelper _tagsService = TagsHelper();

  bool _isLoading = false;
  String? _error;
  StreamSubscription? _authSubscription;

  // Getters for repositories
  AuthHelper get users => _authService;
  LocationHelper get locations => _locationService;
  BubbleHelper get bubbles => _bubbleService;
  TagsHelper get tags => _tagsService;

  // Status getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _authService.isAuthenticated;

  // Create single instance of this provider
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal() {
    // Set up auth state listener to automatically notify listeners
    _setupAuthListener();
  }
  
  // Initialize Supabase
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await SupabaseClientManager.initialize();
      _setError(null);
    } catch (e) {
      _setError('Failed to initialize Supabase: $e');
    } finally {
      _setLoading(false);
    }
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
  
  Future<String> signUp(String email, String password, {String? name}) async {
    _setLoading(true);
    try {
      UserModel user = await _authService.signUp(email: email, password: password, name: name);
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
  
  // Set up auth state listener
  void _setupAuthListener() {
    _authSubscription = _authService.onAuthStateChange.listen((state) async {
      // Notify all listeners when auth state changes
      notifyListeners();

      // If user just signed in, ensure their database record exists
      // This is especially important for OAuth users
      if (state.event == AuthChangeEvent.signedIn) {
        await _authService.ensureUserRecordExists();
      }
    });
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
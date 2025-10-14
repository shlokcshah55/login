import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repositories/user_repository.dart';
import 'repositories/location_repository.dart';
import 'repositories/video_repository.dart';
import 'supabase_client.dart';

/// Provider class for Supabase services
class SupabaseProvider extends ChangeNotifier {
  final UserRepository _userRepository = UserRepository();
  final LocationRepository _locationRepository = LocationRepository();
  final VideoRepository _videoRepository = VideoRepository();

  bool _isLoading = false;
  String? _error;
  StreamSubscription? _authSubscription;

  // Getters for repositories
  UserRepository get userRepository => _userRepository;
  LocationRepository get locationRepository => _locationRepository;
  VideoRepository get videoRepository => _videoRepository;

  // Status getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _userRepository.isAuthenticated;

  // Create single instance of this provider
  static final SupabaseProvider _instance = SupabaseProvider._internal();
  factory SupabaseProvider() => _instance;
  SupabaseProvider._internal() {
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
      await _userRepository.signIn(email, password);
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
  
  Future<bool> signUp(String email, String password, {String? name}) async {
    _setLoading(true);
    try {
      await _userRepository.signUp(email, password, name: name);
      _setError(null);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Sign up failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _userRepository.signOut();
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
      final success = await _userRepository.signInWithGoogle();
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
    _authSubscription = _userRepository.onAuthStateChange.listen((state) async {
      // Notify all listeners when auth state changes
      notifyListeners();

      // If user just signed in, ensure their database record exists
      // This is especially important for OAuth users
      if (state.event == AuthChangeEvent.signedIn) {
        await _userRepository.ensureUserRecordExists();
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
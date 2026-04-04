import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:login/utils/geo_types.dart';

/// Centralized location service that handles all location-related functionality.
/// This is the single source of truth for location permissions and tracking.
class LocationService with ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // DEBUG: Set to non-null to override GPS with a fixed location
  static const LatLng? _debugOverrideLocation = null;

  // State
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;
  bool _permissionGranted = false;
  bool _locationServiceEnabled = false;
  String? _error;
  bool _initialized = false;

  // Getters
  LatLng? get currentPosition => _debugOverrideLocation ?? _currentPosition;
  bool get isTracking => _isTracking;
  bool get permissionGranted => _permissionGranted;
  bool get locationServiceEnabled => _locationServiceEnabled;
  String? get error => _error;
  bool get initialized => _initialized;
  
  void _log(String message) {
    print('[LocationService] $message');
  }

  /// Initialize the location service. Should be called once at app startup.
  Future<void> initialize() async {
    if (_initialized) {
      _log('Already initialized');
      return;
    }

    _log('Initializing...');
    
    // Check if location services are enabled
    _locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    _log('Location services enabled: $_locationServiceEnabled');

    // Check current permission status using Geolocator (more reliable on iOS)
    final geoPermission = await Geolocator.checkPermission();
    _log('Geolocator permission status: $geoPermission');
    
    _permissionGranted = geoPermission == LocationPermission.whileInUse || 
                         geoPermission == LocationPermission.always;
    _log('Permission granted: $_permissionGranted');

    _initialized = true;
    notifyListeners();
  }

  /// Check and request location permission.
  /// Returns true if permission is granted.
  Future<bool> checkAndRequestPermission() async {
    _log('checkAndRequestPermission called');
    _error = null;

    // First check if location services are enabled
    _locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_locationServiceEnabled) {
      _error = 'Location services are disabled. Please enable GPS.';
      _permissionGranted = false;
      _log('Location services disabled');
      notifyListeners();
      return false;
    }

    // Check current permission status using Geolocator (more reliable on iOS)
    LocationPermission permission = await Geolocator.checkPermission();
    _log('Current Geolocator permission status: $permission');

    // If already granted, we're done
    if (permission == LocationPermission.whileInUse || 
        permission == LocationPermission.always) {
      _permissionGranted = true;
      _error = null;
      _log('Permission already granted');
      notifyListeners();
      return true;
    }

    // If permanently denied, can't request again
    if (permission == LocationPermission.deniedForever) {
      _permissionGranted = false;
      _error = 'Location permission permanently denied. Please enable in Settings.';
      _log('Permission permanently denied');
      notifyListeners();
      return false;
    }

    // Request permission using Geolocator
    _log('Requesting permission...');
    permission = await Geolocator.requestPermission();
    _log('Permission request result: $permission');

    _permissionGranted = permission == LocationPermission.whileInUse || 
                         permission == LocationPermission.always;
    
    if (!_permissionGranted) {
      if (permission == LocationPermission.deniedForever) {
        _error = 'Location permission permanently denied. Please enable in Settings.';
      } else {
        _error = 'Location permission denied.';
      }
    } else {
      _error = null;
    }

    notifyListeners();
    return _permissionGranted;
  }

  /// Get the current location once.
  /// Will request permission if not already granted.
  Future<LatLng?> getCurrentLocation() async {
    // DEBUG: Return override location if set
    if (_debugOverrideLocation != null) {
      _currentPosition = _debugOverrideLocation;
      _log('Using debug override location: $_debugOverrideLocation');
      notifyListeners();
      return _debugOverrideLocation;
    }

    _log('getCurrentLocation called, permissionGranted=$_permissionGranted');
    _log('Stack trace: ${StackTrace.current}');

    // Ensure permission is granted
    if (!_permissionGranted) {
      _log('Permission not granted, requesting...');
      final granted = await checkAndRequestPermission();
      if (!granted) {
        _log('Cannot get location - permission denied');
        return null;
      }
    }

    // Double-check location services
    if (!await Geolocator.isLocationServiceEnabled()) {
      _error = 'Location services are disabled. Please enable GPS.';
      _locationServiceEnabled = false;
      _log('Location services disabled');
      notifyListeners();
      return null;
    }

    try {
      _log('Fetching current position...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      
      _currentPosition = LatLng(position.latitude, position.longitude);
      _error = null;
      _log('Got position: $_currentPosition');
      notifyListeners();
      return _currentPosition;
    } on TimeoutException {
      _error = 'Location request timed out. Please try again.';
      _log('Location request timed out');
      notifyListeners();
      return null;
    } on LocationServiceDisabledException {
      _error = 'Location services are disabled. Please enable GPS.';
      _locationServiceEnabled = false;
      _log('LocationServiceDisabledException');
      notifyListeners();
      return null;
    } on PermissionDeniedException {
      _error = 'Location permission denied.';
      _permissionGranted = false;
      _log('PermissionDeniedException');
      notifyListeners();
      return null;
    } catch (e) {
      _error = 'Failed to get location: $e';
      _log('Error getting location: $e');
      notifyListeners();
      return null;
    }
  }

  /// Start continuous location tracking.
  Future<void> startLocationUpdates() async {
    _log('startLocationUpdates called, isTracking=$_isTracking, permissionGranted=$_permissionGranted');
    
    if (_isTracking) {
      _log('Already tracking');
      return;
    }

    // Ensure permission is granted
    if (!_permissionGranted) {
      _log('Permission not granted, requesting...');
      final granted = await checkAndRequestPermission();
      if (!granted) {
        _log('Cannot start tracking - permission denied');
        return;
      }
    }

    _log('Starting location stream...');
    _positionStreamSubscription?.cancel();

    try {
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update when user moves 10 meters
        ),
      ).listen(
        (Position position) {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isTracking = true;
          _error = null;
          _log('Position update: $_currentPosition');
          notifyListeners();
        },
        onError: (error) {
          _log('Stream error: $error');
          _error = 'Location tracking error: $error';
          _isTracking = false;
          notifyListeners();
        },
        onDone: () {
          _log('Stream closed');
          _isTracking = false;
          notifyListeners();
        },
      );

      _isTracking = true;
      _error = null;
      _log('Location tracking started successfully');
      notifyListeners();
    } catch (e) {
      _error = 'Failed to start location tracking: $e';
      _isTracking = false;
      _log('Error starting tracking: $e');
      notifyListeners();
    }
  }

  /// Stop location tracking.
  void stopLocationUpdates() {
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
      _isTracking = false;
      _log('Stopped location tracking');
      notifyListeners();
    }
  }

  /// Get a stream of position updates (for external use if needed).
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  /// Open app settings for the user to enable location permission.
  Future<bool> openSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Open location settings for the user to enable GPS.
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Clear error state.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopLocationUpdates();
    super.dispose();
  }
}

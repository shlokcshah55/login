import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/services/location_service.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceLocationProvider with ChangeNotifier {
  final LocationService _locationService;

  DeviceLocationProvider(this._locationService);

  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;
  bool _permissionGranted = false;
  String? _error;

  // Getters
  LatLng? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get permissionGranted => _permissionGranted;
  String? get error => _error;

  /// Checks and requests location permission.
  Future<bool> checkAndRequestPermission() async {
    PermissionStatus status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }

    _permissionGranted = status.isGranted;
    if (!_permissionGranted) {
      _error = "Location permission denied.";
      log("DeviceLocationProvider: Location permission denied.");
    } else {
      _error = null; // Clear previous error if permission granted now
      log("DeviceLocationProvider: Location permission granted.");
    }
    notifyListeners(); // Notify about permission status change
    return _permissionGranted;
  }

  /// Fetches the current location once.
  Future<LatLng?> getCurrentLocation() async {
    if (!_permissionGranted) {
      log("DeviceLocationProvider: Cannot get current location, permission not granted.");
      await checkAndRequestPermission(); // Try asking again
      if (!_permissionGranted) return null; // Still no permission
    }

    try {
      // Call the correct method which returns LatLng directly
      _currentPosition = await _locationService.getCurrentLocation();
      _error = null;
      log("DeviceLocationProvider: Fetched current location: $_currentPosition");
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      _error = "Failed to get current location: $e";
      log("DeviceLocationProvider: Error getting current location: $e");
      notifyListeners();
      return null;
    }
  }


  /// Starts tracking the user's live location updates.
  Future<void> startLocationUpdates() async {
    if (_isTracking) {
      log("DeviceLocationProvider: Already tracking location.");
      return; // Already tracking
    }
    if (!_permissionGranted) {
       log("DeviceLocationProvider: Requesting permission before starting tracking.");
       bool granted = await checkAndRequestPermission();
       if (!granted) {
         log("DeviceLocationProvider: Cannot start tracking, permission denied.");
         return; // Don't start if permission denied
       }
    }

    _positionStreamSubscription?.cancel(); // Cancel any previous stream
    try {
      _positionStreamSubscription = _locationService.getPositionStream().listen(
        (Position position) {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isTracking = true; // Ensure tracking state is true
           _error = null; // Clear error on successful update
          // log("DeviceLocationProvider: Location update: $_currentPosition"); // Can be noisy
          notifyListeners(); // Notify UI about the location change
        },
        onError: (error) {
          _error = "Location stream error: $error";
          _isTracking = false; // Stop tracking on error
          log("DeviceLocationProvider: Error in location stream: $error");
          notifyListeners();
        },
        onDone: () {
          _isTracking = false; // Stream closed
          log("DeviceLocationProvider: Location stream closed.");
          notifyListeners();
        },
      );
      _isTracking = true; // Mark as tracking immediately
      _error = null;
      log("DeviceLocationProvider: Started location tracking.");
      notifyListeners(); // Notify that tracking has started
    } catch (e) {
       _error = "Failed to start location stream: $e";
       _isTracking = false;
       log("DeviceLocationProvider: Error starting location stream: $e");
       notifyListeners();
    }
  }

  /// Stops live location tracking.
  void stopLocationUpdates() {
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
      _isTracking = false;
      log("DeviceLocationProvider: Stopped location tracking.");
      notifyListeners(); // Notify that tracking has stopped
    }
  }

  @override
  void dispose() {
    stopLocationUpdates(); // Ensure stream is cancelled
    log("DeviceLocationProvider: Disposed.");
    super.dispose();
  }
}

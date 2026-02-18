import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:login/utils/geo_types.dart';
import 'package:login/services/location_service.dart';

/// DeviceLocationProvider - now a thin wrapper around LocationService.
/// This maintains backward compatibility while delegating to the centralized LocationService.
class DeviceLocationProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();

  DeviceLocationProvider(dynamic locationListManager) {
    // Listen to LocationService changes and propagate them
    _locationService.addListener(_onLocationServiceChanged);
  }

  void _onLocationServiceChanged() {
    notifyListeners();
  }

  // Getters - delegate to LocationService
  LatLng? get currentPosition => _locationService.currentPosition;
  bool get isTracking => _locationService.isTracking;
  bool get permissionGranted => _locationService.permissionGranted;
  String? get error => _locationService.error;

  /// Checks and requests location permission - delegates to LocationService
  Future<bool> checkAndRequestPermission() async {
    return await _locationService.checkAndRequestPermission();
  }

  /// Fetches the current location once - delegates to LocationService
  Future<LatLng?> getCurrentLocation() async {
    return await _locationService.getCurrentLocation();
  }

  /// Starts tracking the user's live location updates - delegates to LocationService
  Future<void> startLocationUpdates() async {
    await _locationService.startLocationUpdates();
  }

  /// Stops live location tracking - delegates to LocationService
  void stopLocationUpdates() {
    _locationService.stopLocationUpdates();
  }

  @override
  void dispose() {
    _locationService.removeListener(_onLocationServiceChanged);
    log("DeviceLocationProvider: Disposed.");
    super.dispose();
  }
}

import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapStateProvider with ChangeNotifier {
  final Completer<GoogleMapController> _completeController = Completer();
  GoogleMapController? _mapController; // Make nullable initially
  Set<Polyline> _polylines = {};
  LatLng? _lastFocusedUserLocation; // To track where the user was last centered

  // Getters
  Future<GoogleMapController> get controllerFuture => _completeController.future;
  GoogleMapController? get mapController => _mapController; // Allow null check
  Set<Polyline> get polylines => _polylines;

  /// Assigns the Google Map controller when the map is created.
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    if (!_completeController.isCompleted) {
      _completeController.complete(controller);
      log("MapStateProvider: GoogleMapController initialized.");
    }
    // No need to notifyListeners here unless UI depends on controller existence
  }

  /// Adds or updates a polyline on the map.
  void setPolyline(Polyline polyline) {
    // Using add instead of clear/add allows multiple polylines if needed later
    _polylines.removeWhere((p) => p.polylineId == polyline.polylineId);
    _polylines.add(polyline);
    log("MapStateProvider: Polyline added/updated: ${polyline.polylineId.value}");
    notifyListeners();
  }

  /// Removes a specific polyline by its ID.
  void removePolylineById(PolylineId polylineId) {
    _polylines.removeWhere((p) => p.polylineId == polylineId);
  }

  /// Clears all polylines from the map.
  void clearPolylines() {
    if (_polylines.isNotEmpty) {
      _polylines.clear();
      log("MapStateProvider: All polylines cleared.");
      notifyListeners();
    }
  }

  /// Animates the camera to a specific LatLng position.
  Future<void> animateCamera(CameraUpdate cameraUpdate) async {
    await _completeController.future; // Ensure controller is ready
    final controller = _mapController; // Assign to local variable first
    if (controller != null) {
       await controller.animateCamera(cameraUpdate); // Use local variable
       log("MapStateProvider: Animating camera.");
    } else {
       log("MapStateProvider: Cannot animate camera, controller is null.");
    }
    // No notifyListeners needed as map animates itself
  }


  /// Focuses the map camera on a specific user location.
  Future<void> focusOnUserLocation(LatLng userPosition, {double zoom = 15.0}) async {
    _lastFocusedUserLocation = userPosition;
    await animateCamera(CameraUpdate.newLatLngZoom(userPosition, zoom));
    log("MapStateProvider: Camera focused on user location: $userPosition");
  }

  /// Focuses the map camera to show bounds containing two points.
  Future<void> focusOnBounds(LatLng point1, LatLng point2, {double padding = 100.0}) async {
     await animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              point1.latitude < point2.latitude ? point1.latitude : point2.latitude,
              point1.longitude < point2.longitude ? point1.longitude : point2.longitude,
            ),
            northeast: LatLng(
              point1.latitude > point2.latitude ? point1.latitude : point2.latitude,
              point1.longitude > point2.longitude ? point1.longitude : point2.longitude,
            ),
          ),
          padding,
        ),
      );
      log("MapStateProvider: Camera focused on bounds containing $point1 and $point2");
  }


  // Optional: Add methods for map bounds, selected markers etc. if needed later

  @override
  void dispose() {
    // While the controller itself might be managed elsewhere (Map widget),
    // clear internal references if necessary.
    _mapController = null; // Help garbage collection
    log("MapStateProvider: Disposed.");
    super.dispose();
  }
}

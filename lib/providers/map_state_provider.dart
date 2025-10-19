import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapStateProvider with ChangeNotifier {
  final Completer<GoogleMapController> _completeController = Completer();
  GoogleMapController? _mapController; // Make nullable initially
  Set<Polyline> _polylines = {};
  LatLng? _lastFocusedUserLocation; // To track where the user was last centered
  LatLng?
      _currentVisibleCenter; // To track the current visible center of the map
  MarkerId? _selectedMarkerId; // To track the currently selected marker
  PageController? _carouselPageController; // To control the carousel page view
  bool _isAwayFromUserArea =
      false; // Track if the map is away from user's location
  bool _showSearchThisAreaButton = false; // Control button visibility

  // Getters
  Future<GoogleMapController> get controllerFuture =>
      _completeController.future;
  GoogleMapController? get mapController => _mapController; // Allow null check
  Set<Polyline> get polylines => _polylines;
  MarkerId? get selectedMarkerId =>
      _selectedMarkerId; // Getter for selected marker
  bool get showSearchThisAreaButton =>
      _showSearchThisAreaButton; // Getter for button visibility

  // Set the carousel page controller
  void setCarouselPageController(PageController controller) {
    _carouselPageController = controller;
  }

  void setLastFocusedUserLocation(LatLng location) {
    _lastFocusedUserLocation = location;
    print("Set last focused user location to: $location");
  }

  // Animate to a specific item in the carousel
  void animateToCarouselItem(int index) {
    if (_carouselPageController != null) {
      _carouselPageController!.animateToPage(index,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    } else {
      log("Cannot animate carousel: pageController is null.");
    }
  }

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
  Future<void> focusOnUserLocation(LatLng userPosition,
      {double zoom = 15.0}) async {
    _lastFocusedUserLocation = userPosition;
    await animateCamera(CameraUpdate.newLatLngZoom(userPosition, zoom));
    log("MapStateProvider: Camera focused on user location: $userPosition");
  }

  /// Focuses the map camera to show bounds containing two points.
  Future<void> focusOnBounds(LatLng point1, LatLng point2,
      {double padding = 100.0}) async {
    await animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            point1.latitude < point2.latitude
                ? point1.latitude
                : point2.latitude,
            point1.longitude < point2.longitude
                ? point1.longitude
                : point2.longitude,
          ),
          northeast: LatLng(
            point1.latitude > point2.latitude
                ? point1.latitude
                : point2.latitude,
            point1.longitude > point2.longitude
                ? point1.longitude
                : point2.longitude,
          ),
        ),
        padding,
      ),
    );
    log("MapStateProvider: Camera focused on bounds containing $point1 and $point2");
  }

  /// Sets the currently selected marker ID and notifies listeners.
  void setSelectedMarkerId(MarkerId? markerId,
      {bool triggeredByCarousel = false}) {
    if (_selectedMarkerId != markerId) {
      _selectedMarkerId = markerId;
      log("MapStateProvider: Selected marker changed to: ${markerId?.value}");
      notifyListeners();
    }
  }

  /// Updates the current visible center of the map from camera position
  void updateMapCenter(CameraPosition position) {
    _currentVisibleCenter = position.target;
    _checkIfAwayFromUserArea();
  }

  /// Check if map has moved significantly from user's location
  void _checkIfAwayFromUserArea() {
    if (_lastFocusedUserLocation != null && _currentVisibleCenter != null) {
      print('Checking if away from user area:');
      print('_lastFocusedUserLocation = $_lastFocusedUserLocation');
      print('_currentVisibleCenter = $_currentVisibleCenter');

      // Calculate the distance between current map center and user's location
      // Use a simple distance check with latitude and longitude differences
      final double distanceThreshold =
          0.01; // Roughly 1km at the equator, adjust as needed

      final double latDiff =
          (_lastFocusedUserLocation!.latitude - _currentVisibleCenter!.latitude)
              .abs();
      final double lngDiff = (_lastFocusedUserLocation!.longitude -
              _currentVisibleCenter!.longitude)
          .abs();

      print(
          'latDiff = $latDiff, lngDiff = $lngDiff, threshold = $distanceThreshold');

      // Store previous state to detect changes
      final bool wasAwayFromUserArea = _isAwayFromUserArea;

      // Update current state
      _isAwayFromUserArea =
          latDiff > distanceThreshold || lngDiff > distanceThreshold;
      print(
          'Is away from user area: $_isAwayFromUserArea (was: $wasAwayFromUserArea)');

      // Only update UI if state changed
      if (wasAwayFromUserArea != _isAwayFromUserArea) {
        // Show button when moving away from area
        if (_isAwayFromUserArea) {
          _showSearchThisAreaButton = true;
          log("MapStateProvider: User moved away from focused area, showing search button");
        }
        // Hide button when returning to original area
        else {
          _showSearchThisAreaButton = false;
          log("MapStateProvider: User returned to focused area, hiding search button");
        }
        notifyListeners();
      }
    } else {
      print(
          'Cannot check if away from user area: _lastFocusedUserLocation = $_lastFocusedUserLocation, _currentVisibleCenter = $_currentVisibleCenter');
    }
  }

  /// Set the visibility of the "Search this area" button
  void setSearchThisAreaButtonVisibility(bool visible) {
    if (_showSearchThisAreaButton != visible) {
      _showSearchThisAreaButton = visible;
      log("MapStateProvider: Search button visibility set to $visible");
      notifyListeners();
    }
  }

  /// Hide the "Search this area" button
  void hideSearchThisAreaButton() {
    setSearchThisAreaButtonVisibility(false);
  }

  /// Handler for when user clicks "Search this area"
  LatLng searchThisArea() {
    // This method will be called when the user taps the "Search this area" button
    if (_currentVisibleCenter != null) {
      // Update the focused location first
      _lastFocusedUserLocation = _currentVisibleCenter;

      // Reset the away state
      _isAwayFromUserArea = false;

      // Hide the button
      hideSearchThisAreaButton();

      // Animate to ensure the map is centered correctly
      animateCamera(CameraUpdate.newLatLng(_currentVisibleCenter!));

      // Force notify to ensure UI updates
      notifyListeners();

      return _currentVisibleCenter!;
    } else {
      log("MapStateProvider: Cannot search this area, current center is null.");
      return LatLng(0, 0); // Return a default value or handle error
    }
  }

  // Optional: Add methods for map bounds, etc. if needed later

  @override
  void dispose() {
    // While the controller itself might be managed elsewhere (Map widget),
    // clear internal references if necessary.
    _mapController = null; // Help garbage collection
    log("MapStateProvider: Disposed.");
    super.dispose();
  }
}

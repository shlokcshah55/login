import 'dart:async';
import 'dart:developer';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapStateProvider with ChangeNotifier {
  final Completer<GoogleMapController> _completeController = Completer();
  GoogleMapController? _mapController; // Make nullable initially
  Set<Polyline> _polylines = {};
  LatLng? _lastFocusedUserLocation; // To track where the user was last centered (for My Location button)
  LatLng? _lastSearchedCenter; // To track the center of the last API search
  double? _lastSearchedRadius; // To track the radius of the last API search (in km)
  LatLng?
      _currentVisibleCenter; // To track the current visible center of the map
  double _currentZoom = 15.0; // To track the current zoom level
  MarkerId? _selectedMarkerId; // To track the currently selected marker
  PageController? _carouselPageController; // To control the carousel page view
  bool _showSearchThisAreaButton = false; // Control button visibility

  // Getters
  Future<GoogleMapController> get controllerFuture =>
      _completeController.future;
  GoogleMapController? get mapController => _mapController;
  Set<Polyline> get polylines => _polylines;
  MarkerId? get selectedMarkerId => _selectedMarkerId;
  bool get showSearchThisAreaButton => _showSearchThisAreaButton;
  double get currentZoom => _currentZoom;
  LatLng? get currentVisibleCenter => _currentVisibleCenter;

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
      _carouselPageController!.jumpToPage(index);
    }
  }

  /// Assigns the Google Map controller when the map is created.
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    if (!_completeController.isCompleted) {
      _completeController.complete(controller);
    }
    // No need to notifyListeners here unless UI depends on controller existence
  }

  /// Adds or updates a polyline on the map.
  void setPolyline(Polyline polyline) {
    // Using add instead of clear/add allows multiple polylines if needed later
    _polylines.removeWhere((p) => p.polylineId == polyline.polylineId);
    _polylines.add(polyline);
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
      notifyListeners();
    }
  }

  /// Animates the camera to a specific LatLng position.
  Future<void> animateCamera(CameraUpdate cameraUpdate) async {
    print('[MapState] animateCamera called');
    await _completeController.future; // Ensure controller is ready
    final controller = _mapController; // Assign to local variable first
    print('[MapState] Controller null? ${controller == null}');
    if (controller != null) {
      print('[MapState] Animating camera...');
      await controller.animateCamera(cameraUpdate); // Use local variable
      print('[MapState] Camera animation complete');
    } else {
      print('[MapState] ERROR: Map controller is null, cannot animate');
    }
    // No notifyListeners needed as map animates itself
  }

  /// Focuses the map camera on a specific user location.
  Future<void> focusOnUserLocation(LatLng userPosition,
      {double zoom = 15.0}) async {
    print('[MapState] focusOnUserLocation called with position: $userPosition, zoom: $zoom');
    _lastFocusedUserLocation = userPosition;
    await animateCamera(CameraUpdate.newLatLngZoom(userPosition, zoom));
    print('[MapState] focusOnUserLocation complete');
  }

  /// Gets the current visible bounds of the map
  Future<LatLngBounds?> getVisibleBounds() async {
    if (_mapController == null) return null;
    try {
      return await _mapController!.getVisibleRegion();
    } catch (e) {
      return null;
    }
  }

  /// Gets the center and radius of the current visible map area
  /// Returns a map with 'center' (LatLng) and 'radius' (double in meters)
  Future<Map<String, dynamic>?> getVisibleCenterAndRadius() async {
    final bounds = await getVisibleBounds();
    if (bounds == null) return null;

    // Calculate center point
    final centerLat = (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
    final centerLng = (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
    final center = LatLng(centerLat, centerLng);

    // Calculate radius as distance from center to northeast corner
    final rawRadius = _calculateDistance(
      center.latitude,
      center.longitude,
      bounds.northeast.latitude,
      bounds.northeast.longitude,
    );

    // IMPORTANT: Adjust radius to account for UI elements that obscure the map
    // The map widget fills the screen, but is partially covered by:
    // - Header at top (~110-120px)
    // - Carousel at bottom (~160-250px depending on nav visibility)
    // This means only ~56-71% of the vertical screen shows the actual map
    // We apply a 0.65 scaling factor to get a radius closer to what's truly visible
    final adjustedRadius = rawRadius * 0.65;

    return {
      'center': center,
      'radius': adjustedRadius / 1000, // Convert to km
    };
  }

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in meters
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degreesToRadians(lat1)) *
        cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) *
        sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
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
  }

  /// Sets the currently selected marker ID and notifies listeners.
  void setSelectedMarkerId(MarkerId? markerId,
      {bool triggeredByCarousel = false}) {
    if (_selectedMarkerId != markerId) {
      _selectedMarkerId = markerId;
      notifyListeners();
    }
  }

  /// Updates the current visible center of the map from camera position
  void updateMapCenter(CameraPosition position) {
    _currentVisibleCenter = position.target;
    _currentZoom = position.zoom;
    _checkIfViewDiffersFromLastSearch();
  }

  /// Check if current view differs significantly from the last searched area
  void _checkIfViewDiffersFromLastSearch() {
    // If no search has been performed yet, don't show the button
    if (_lastSearchedCenter == null || _lastSearchedRadius == null) {
      if (_showSearchThisAreaButton) {
        _showSearchThisAreaButton = false;
        notifyListeners();
      }
      return;
    }

    if (_currentVisibleCenter == null) {
      return;
    }

    // Calculate distance between current center and last searched center
    final distanceKm = _calculateDistance(
      _lastSearchedCenter!.latitude,
      _lastSearchedCenter!.longitude,
      _currentVisibleCenter!.latitude,
      _currentVisibleCenter!.longitude,
    ) / 1000; // Convert meters to km

    // Store previous state
    final bool wasShowingButton = _showSearchThisAreaButton;

    // Show button if the center has moved significantly (more than 25% of the last searched radius)
    // or if the zoom has changed significantly
    final distanceThreshold = _lastSearchedRadius! * 0.25;
    final viewDiffers = distanceKm > distanceThreshold;

    _showSearchThisAreaButton = viewDiffers;

    // Only notify if state changed
    if (wasShowingButton != _showSearchThisAreaButton) {
      notifyListeners();
    }
  }

  /// Set the visibility of the "Search this area" button
  void setSearchThisAreaButtonVisibility(bool visible) {
    if (_showSearchThisAreaButton != visible) {
      _showSearchThisAreaButton = visible;
      notifyListeners();
    }
  }

  /// Hide the "Search this area" button
  void hideSearchThisAreaButton() {
    setSearchThisAreaButtonVisibility(false);
  }

  /// Update the last searched center and radius (called after a successful search)
  void setLastSearchedArea(LatLng center, double radiusKm) {
    _lastSearchedCenter = center;
    _lastSearchedRadius = radiusKm;
    // Hide the button since we just searched this area
    _showSearchThisAreaButton = false;
    notifyListeners();
  }

  /// Handler for when user clicks "Search this area"
  /// Returns the center and radius of the current visible area
  Future<Map<String, dynamic>?> searchThisArea() async {
    // Get the current visible center and radius
    final viewData = await getVisibleCenterAndRadius();

    if (viewData == null) {
      return null;
    }

    // The search will be performed by the caller, and they should call
    // setLastSearchedArea() after a successful search

    return viewData;
  }

  // Optional: Add methods for map bounds, etc. if needed later

  @override
  void dispose() {
    // While the controller itself might be managed elsewhere (Map widget),
    // clear internal references if necessary.
    _mapController = null; // Help garbage collection
    super.dispose();
  }
}

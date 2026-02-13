import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:login/utils/geo_types.dart';

class MapStateProvider with ChangeNotifier {
  mapbox.MapboxMap? _mapboxMap;
  mapbox.PointAnnotationManager? _pointAnnotationManager;
  mapbox.PolylineAnnotationManager? _polylineAnnotationManager;

  LatLng? _lastFocusedUserLocation;
  LatLng? _currentVisibleCenter;
  double _currentZoom = 15.0;
  String? _selectedMarkerId;
  PageController? _carouselPageController;
  bool _isAwayFromUserArea = false;
  bool _showSearchThisAreaButton = false;

  List<LatLng> _polylinePoints = [];

  // Getters
  mapbox.MapboxMap? get mapboxMap => _mapboxMap;
  mapbox.PointAnnotationManager? get pointAnnotationManager => _pointAnnotationManager;
  String? get selectedMarkerId => _selectedMarkerId;
  bool get showSearchThisAreaButton => _showSearchThisAreaButton;
  double get currentZoom => _currentZoom;
  LatLng? get currentVisibleCenter => _currentVisibleCenter;

  void setCarouselPageController(PageController controller) {
    _carouselPageController = controller;
  }

  void setLastFocusedUserLocation(LatLng location) {
    _lastFocusedUserLocation = location;
    print("Set last focused user location to: $location");
  }

  void animateToCarouselItem(int index) {
    if (_carouselPageController != null) {
      _carouselPageController!.animateToPage(index,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    } else {
      log("Cannot animate carousel: pageController is null.");
    }
  }

  /// Call this from MapWidget's onMapCreated callback.
  Future<void> setMapboxMap(mapbox.MapboxMap map) async {
    _mapboxMap = map;
    _pointAnnotationManager = await map.annotations.createPointAnnotationManager();
    _polylineAnnotationManager = await map.annotations.createPolylineAnnotationManager();
    log("MapStateProvider: MapboxMap controller initialized.");
  }

  /// Draws a polyline on the map. Replaces any existing polyline.
  Future<void> setPolyline(List<LatLng> points,
      {Color color = Colors.blue, double width = 4.0}) async {
    _polylinePoints = points;
    await _syncPolylines(color: color, width: width);
    log("MapStateProvider: Polyline set with ${points.length} points.");
    notifyListeners();
  }

  /// Clears all polylines from the map.
  Future<void> clearPolylines() async {
    _polylinePoints = [];
    await _polylineAnnotationManager?.deleteAll();
    log("MapStateProvider: All polylines cleared.");
    notifyListeners();
  }

  Future<void> _syncPolylines({Color color = Colors.blue, double width = 4.0}) async {
    final mgr = _polylineAnnotationManager;
    if (mgr == null || _polylinePoints.isEmpty) return;
    await mgr.deleteAll();
    final coordinates = _polylinePoints
        .map((p) => mapbox.Position(p.longitude, p.latitude))
        .toList();
    await mgr.create(mapbox.PolylineAnnotationOptions(
      geometry: mapbox.LineString(coordinates: coordinates),
      lineColor: color.value,
      lineWidth: width,
    ));
  }

  /// Animate camera to a position with optional zoom.
  Future<void> animateCamera(LatLng target, {double? zoom}) async {
    final map = _mapboxMap;
    if (map == null) {
      log("MapStateProvider: Cannot animate camera, map is null.");
      return;
    }
    await map.flyTo(
      mapbox.CameraOptions(center: target.toPoint(), zoom: zoom ?? _currentZoom),
      mapbox.MapAnimationOptions(duration: 500),
    );
    log("MapStateProvider: Animating camera to $target");
  }

  /// Focuses the map camera on a specific user location.
  Future<void> focusOnUserLocation(LatLng userPosition, {double zoom = 15.0}) async {
    _lastFocusedUserLocation = userPosition;
    await animateCamera(userPosition, zoom: zoom);
    log("MapStateProvider: Camera focused on user location: $userPosition");
  }

  /// Gets the current visible bounds of the map.
  Future<LatLngBounds?> getVisibleBounds() async {
    final map = _mapboxMap;
    if (map == null) return null;
    try {
      final state = await map.getCameraState();
      final bounds = await map.coordinateBoundsForCamera(mapbox.CameraOptions(
        center: state.center,
        zoom: state.zoom,
        bearing: state.bearing,
        pitch: state.pitch,
      ));
      return LatLngBounds.fromCoordinateBounds(bounds);
    } catch (e) {
      log('Error getting visible bounds: $e');
      return null;
    }
  }

  /// Focuses the map to show bounds containing two points.
  Future<void> focusOnBounds(LatLng point1, LatLng point2, {double padding = 100.0}) async {
    final map = _mapboxMap;
    if (map == null) return;
    final sw = LatLng(
      point1.latitude < point2.latitude ? point1.latitude : point2.latitude,
      point1.longitude < point2.longitude ? point1.longitude : point2.longitude,
    );
    final ne = LatLng(
      point1.latitude > point2.latitude ? point1.latitude : point2.latitude,
      point1.longitude > point2.longitude ? point1.longitude : point2.longitude,
    );
    final camera = await map.cameraForCoordinateBounds(
      LatLngBounds(southwest: sw, northeast: ne).toCoordinateBounds(),
      mapbox.MbxEdgeInsets(top: padding, left: padding, bottom: padding, right: padding),
      null, null, null, null,
    );
    await map.flyTo(camera, mapbox.MapAnimationOptions(duration: 600));
    log("MapStateProvider: Camera focused on bounds containing $point1 and $point2");
  }

  /// Sets the currently selected marker ID and notifies listeners.
  void setSelectedMarkerId(String? markerId, {bool triggeredByCarousel = false}) {
    if (_selectedMarkerId != markerId) {
      _selectedMarkerId = markerId;
      log("MapStateProvider: Selected marker changed to: $markerId");
      notifyListeners();
    }
  }

  /// Called from the map's camera-change listener.
  void updateMapCenter(LatLng center, double zoom) {
    _currentVisibleCenter = center;
    _currentZoom = zoom;
    _checkIfAwayFromUserArea();
  }

  void _checkIfAwayFromUserArea() {
    if (_lastFocusedUserLocation != null && _currentVisibleCenter != null) {
      final double distanceThreshold = 0.01;
      final double latDiff = (_lastFocusedUserLocation!.latitude - _currentVisibleCenter!.latitude).abs();
      final double lngDiff = (_lastFocusedUserLocation!.longitude - _currentVisibleCenter!.longitude).abs();
      final bool wasAwayFromUserArea = _isAwayFromUserArea;
      _isAwayFromUserArea = latDiff > distanceThreshold || lngDiff > distanceThreshold;
      if (wasAwayFromUserArea != _isAwayFromUserArea) {
        _showSearchThisAreaButton = _isAwayFromUserArea;
        log(_isAwayFromUserArea
            ? "MapStateProvider: User moved away, showing search button"
            : "MapStateProvider: User returned, hiding search button");
        notifyListeners();
      }
    }
  }

  void setSearchThisAreaButtonVisibility(bool visible) {
    if (_showSearchThisAreaButton != visible) {
      _showSearchThisAreaButton = visible;
      log("MapStateProvider: Search button visibility set to $visible");
      notifyListeners();
    }
  }

  void hideSearchThisAreaButton() {
    setSearchThisAreaButtonVisibility(false);
  }

  LatLng searchThisArea() {
    if (_currentVisibleCenter != null) {
      _lastFocusedUserLocation = _currentVisibleCenter;
      _isAwayFromUserArea = false;
      hideSearchThisAreaButton();
      animateCamera(_currentVisibleCenter!);
      notifyListeners();
      return _currentVisibleCenter!;
    } else {
      log("MapStateProvider: Cannot search this area, current center is null.");
      return const LatLng(0, 0);
    }
  }

  @override
  void dispose() {
    _mapboxMap = null;
    log("MapStateProvider: Disposed.");
    super.dispose();
  }
}

import 'dart:async';
import 'dart:developer' show log;
import 'dart:math' hide log;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:login/models/locations.dart';
import 'package:login/services/geojson_map_layer_service.dart';
import 'package:login/utils/geo_types.dart';

class MapStateProvider with ChangeNotifier {
  mapbox.MapboxMap? _mapboxMap;
  mapbox.PointAnnotationManager? _pointAnnotationManager;
  mapbox.PolylineAnnotationManager? _polylineAnnotationManager;

  // GeoJSON-based map layer service (new approach)
  GeoJsonMapLayerService? _geoJsonLayerService;

  LatLng? _lastFocusedUserLocation;
  LatLng? _lastSearchedCenter; // To track the center of the last API search
  double?
      _lastSearchedRadius; // To track the radius of the last API search (in km)
  LatLng? _currentVisibleCenter;
  double _currentZoom = 15.0;
  String? _selectedMarkerId;
  PageController? _carouselPageController;
  bool _isAwayFromUserArea = false;
  bool _showSearchThisAreaButton = false;

  // Flag to toggle between old and new rendering approaches
  bool _useGeoJsonLayers = true;

  List<LatLng> _polylinePoints = [];

  // Getters
  mapbox.MapboxMap? get mapboxMap => _mapboxMap;
  mapbox.PointAnnotationManager? get pointAnnotationManager =>
      _pointAnnotationManager;
  GeoJsonMapLayerService? get geoJsonLayerService => _geoJsonLayerService;
  bool get useGeoJsonLayers => _useGeoJsonLayers;
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
      _carouselPageController!.jumpToPage(index);
    }
  }

  /// Call this from MapWidget's onMapCreated callback.
  ///
  /// Note: GeoJSON layer service initialization is deferred until the first
  /// location update to ensure supabase restaurants have loaded first.
  Future<void> setMapboxMap(
    mapbox.MapboxMap map, {
    OnLocationTapped? onLocationTapped,
    OnClusterTapped? onClusterTapped,
  }) async {
    _mapboxMap = map;

    if (_useGeoJsonLayers) {
      // Create GeoJSON service but defer initialization until locations arrive
      // This ensures supabase restaurants are loaded before we set up the layers
      _geoJsonLayerService = GeoJsonMapLayerService(
        mapboxMap: map,
        config: const GeoJsonLayerConfig(
          enableClustering: true,
          // Less aggressive clustering for smoother pin reveal.
          clusterRadius: 22,
          clusterMaxZoom: 13,
          showTextLabels: true,
          allowTextOverlap: false,
          // Prevent icon collision culling from making pins "pop" in/out.
          allowIconOverlap: true,
        ),
        onLocationTapped: onLocationTapped,
        onClusterTapped: onClusterTapped,
      );
      log("MapStateProvider: GeoJSON layer service created (initialization deferred until locations arrive).");
    } else {
      // Legacy: use PointAnnotationManager
      _pointAnnotationManager =
          await map.annotations.createPointAnnotationManager();
      log("MapStateProvider: PointAnnotationManager initialized (legacy mode).");
    }

    _polylineAnnotationManager =
        await map.annotations.createPolylineAnnotationManager();
    log("MapStateProvider: MapboxMap controller initialized.");
  }

  /// Update the locations displayed on the map (GeoJSON mode).
  ///
  /// This method should be called when the location list changes.
  /// Mapbox handles clustering automatically.
  /// If the service hasn't been initialized yet, it will be initialized now
  /// (ensuring supabase restaurants have loaded first).
  /// Returns true if the update was actually performed, false if skipped.
  Future<bool> updateMapLocations(List<LocationModel> locations) async {
    if (!_useGeoJsonLayers || _geoJsonLayerService == null) {
      return false;
    }

    // Lazy initialization: initialize on first location update
    if (!_geoJsonLayerService!.isInitialized) {
      try {
        await _geoJsonLayerService!.initialize();
        log("MapStateProvider: GeoJSON layer service initialized on first location update.");
      } catch (e) {
        log("MapStateProvider: Failed to initialize GeoJSON layer service: $e");
        return false;
      }
    }

    await _geoJsonLayerService!.updateLocations(locations);
    log("MapStateProvider: Updated ${locations.length} locations on map.");
    return true;
  }

  /// Handle a tap on the map at the given screen coordinates.
  ///
  /// Delegates to GeoJSON layer service if using GeoJSON mode.
  Future<void> handleMapTap(double x, double y) async {
    if (_useGeoJsonLayers && _geoJsonLayerService != null) {
      await _geoJsonLayerService!.handleTapAtPoint(x, y);
    }
  }

  /// Toggle between GeoJSON layers and legacy PointAnnotation approach.
  void setUseGeoJsonLayers(bool value) {
    if (_useGeoJsonLayers != value) {
      _useGeoJsonLayers = value;
      log("MapStateProvider: useGeoJsonLayers set to $value");
      notifyListeners();
    }
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

  Future<void> _syncPolylines(
      {Color color = Colors.blue, double width = 4.0}) async {
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
      mapbox.CameraOptions(
          center: target.toPoint(), zoom: zoom ?? _currentZoom),
      mapbox.MapAnimationOptions(duration: 500),
    );
    log("MapStateProvider: Animating camera to $target");
  }

  /// Focuses the map camera on a specific user location.
  Future<void> focusOnUserLocation(LatLng userPosition,
      {double zoom = 15.0}) async {
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
      return null;
    }
  }

  /// Gets the center and radius of the current visible map area
  /// Returns a map with 'center' (LatLng) and 'radius' (double in km)
  Future<Map<String, dynamic>?> getVisibleCenterAndRadius() async {
    final bounds = await getVisibleBounds();
    if (bounds == null) return null;

    // Calculate center point
    final centerLat =
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
    final centerLng =
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2;
    final center = LatLng(centerLat, centerLng);

    // Calculate radius as distance from center to northeast corner
    final rawRadius = _calculateDistance(
      center.latitude,
      center.longitude,
      bounds.northeast.latitude,
      bounds.northeast.longitude,
    );

    // IMPORTANT: Adjust radius to account for UI elements that obscure the map
    final adjustedRadius = rawRadius * 0.65;

    return {
      'center': center,
      'radius': adjustedRadius / 1000, // Convert to km
    };
  }

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in meters
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
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

  /// Focuses the map to show bounds containing two points.
  Future<void> focusOnBounds(LatLng point1, LatLng point2,
      {double padding = 100.0}) async {
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
      mapbox.MbxEdgeInsets(
          top: padding, left: padding, bottom: padding, right: padding),
      null,
      null,
      null,
      null,
    );
    await map.flyTo(camera, mapbox.MapAnimationOptions(duration: 600));
    log("MapStateProvider: Camera focused on bounds containing $point1 and $point2");
  }

  /// Sets the currently selected marker ID and notifies listeners.
  void setSelectedMarkerId(String? markerId,
      {bool triggeredByCarousel = false}) {
    if (_selectedMarkerId != markerId) {
      _selectedMarkerId = markerId;
      // Update selection in GeoJSON layer service
      _geoJsonLayerService?.setSelectedLocation(markerId);
      log("MapStateProvider: Selected marker changed to: $markerId");
      notifyListeners();
    }
  }

  /// Called from the map's camera-change listener.
  void updateMapCenter(LatLng center, double zoom) {
    _currentVisibleCenter = center;
    _currentZoom = zoom;
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
        ) /
        1000; // Convert meters to km

    // Store previous state
    final bool wasShowingButton = _showSearchThisAreaButton;

    // Show button if the center has moved significantly (more than 25% of the last searched radius)
    final distanceThreshold = _lastSearchedRadius! * 0.25;
    final viewDiffers = distanceKm > distanceThreshold;

    _showSearchThisAreaButton = viewDiffers;

    // Only notify if state changed
    if (wasShowingButton != _showSearchThisAreaButton) {
      notifyListeners();
    }
  }

  void setSearchThisAreaButtonVisibility(bool visible) {
    if (_showSearchThisAreaButton != visible) {
      _showSearchThisAreaButton = visible;
      notifyListeners();
    }
  }

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

  @override
  void dispose() {
    _geoJsonLayerService?.dispose();
    _geoJsonLayerService = null;
    _mapboxMap = null;
    log("MapStateProvider: Disposed.");
    super.dispose();
  }
}

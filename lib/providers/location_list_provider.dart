import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/recommendations_api.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/services/location_service.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

// Enum to represent the different types of location lists
enum LocationListType { saved, recommended, search }

class LocationListManager with ChangeNotifier {
  final GooglePlacesService _googlePlacesService;
  final SupabaseService _supabaseService = SupabaseService();
  final LocationService _locationService = LocationService();
  static const String _magicSearchEndpoint =
      'https://pinit-recommendations-api-630839392908.europe-west2.run.app/locations/magic-search';

  String? _userId;

  // Device location state is now delegated to LocationService
  double _devicePixelRatio = 1.0; // Default value
  final RecommendationsApi _recommendationsApi = RecommendationsApi();
  CameraPosition? _cameraPosition;
  LatLng? _lastSearchedCenter;
  bool _areaChanged = false;
  bool _isSearchingArea = false;
  String? _error; // Local error for non-location errors

  // Viewport-aware name selection state
  LatLngBounds? _currentViewportBounds;
  Set<int>? _lastSelectedIds;
  double? _lastSelectionZoom;
  
  // Flags to prevent duplicate data fetches
  bool _isLoadingSaved = false;
  bool _savedLocationsLoaded = false;
  bool _isSubscribed = false;

  LocationListManager(this._googlePlacesService);

  // Location lists
  Map<LocationModel, Marker> _savedLocations = {};
  Map<LocationModel, Marker> _recommendedLocations = {};
  Map<LocationModel, Marker> _searchLocations = {};
  Map<LocationModel, Marker> _currentItems = {};
  LocationListType _currentListType =
      LocationListType.saved; // Default to saved

  // Getters
  Map<LocationModel, Marker> get savedLocations => _savedLocations;
  Map<LocationModel, Marker> get recommendedLocations => _recommendedLocations;
  Map<LocationModel, Marker> get searchLocations => _searchLocations;
  Map<LocationModel, Marker> get currentItems => _currentItems;
  LocationListType get currentListType => _currentListType;

  // Device location getters - delegate to LocationService
  LatLng? get currentPosition => _locationService.currentPosition;
  bool get isTracking => _locationService.isTracking;
  bool get permissionGranted => _locationService.permissionGranted;
  String? get error => _error ?? _locationService.error;
  CameraPosition? get cameraPosition => _cameraPosition;
  LocationService get locationService => _locationService;
  
  // Set device pixel ratio (should be called once from a widget with context)
  void setDevicePixelRatio(double dpr) {
    if (_devicePixelRatio != dpr) {
      _devicePixelRatio = dpr;
      print('LocationListManager: Device pixel ratio set to $dpr');
    }
  }

  void setCameraPosition(CameraPosition position) {
    _cameraPosition = position;
    _areaChanged = true;
  }

  void setAreaChanged(bool value) {
    if (_areaChanged != value) {
      _areaChanged = value;
      notifyListeners();
    }
  }

  bool get areaChanged => _areaChanged;
  bool get isSearchingArea => _isSearchingArea;
  LatLng? get lastSearchedCenter => _lastSearchedCenter;

  // Method to update the user ID when the user logs in
  void setUserId(String? userId) {
    // Prevent redundant calls if userId hasn't changed
    if (_userId == userId) {
      print('UserId unchanged, skipping initialization');
      return;
    }
    
    _userId = userId;
    
    // Unsubscribe from previous realtime channel
    print('Unsubscribing from realtime updates');
    _supabaseService.locations.unsubscribeFromUserLocationActions();
    _isSubscribed = false;
    
    // Reset flags when user changes
    _savedLocationsLoaded = false;
    _isLoadingSaved = false;
    
    // Potentially clear locations if user logs out (userId is null)
    if (_userId == null) {
      _savedLocations = {};
      _recommendedLocations = {};
      _searchLocations = {};
      _currentItems = {};
      notifyListeners();
    } else {
      // Fetch initial data ONCE when user logs in
      fetchSavedLocations();
      
      // Subscribe to realtime updates for this user
      // This will handle all future changes without needing to refetch
      _subscribeToRealtime();
    }
  }
  
  /// Subscribe to realtime changes on user_location_actions
  void _subscribeToRealtime() {
    if (_userId == null) return;
    
    // Prevent duplicate subscriptions
    if (_isSubscribed) {
      print('Already subscribed to realtime updates, skipping');
      return;
    }
    
    print('Subscribing to realtime updates for user: $_userId');
    
    _supabaseService.locations.subscribeToUserLocationActions(
      _userId!,
      (payload) {
        print('Realtime event received: ${payload.eventType}');
        _handleRealtimeEvent(payload);
      },
    );
    
    _isSubscribed = true;
  }


  /// Handle realtime events (INSERT, UPDATE, DELETE)
  void _handleRealtimeEvent(PostgresChangePayload payload) async {
    final record = payload.newRecord;
    final oldRecord = payload.oldRecord;
    
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        // New location saved
        if (record['action'] == 'saved' && record['acked'] == true) {
          print('Location saved realtime: ${record['location_id']}');
          await _addLocationToSaved(record['location_id']);
        }
        break;
        
      case PostgresChangeEvent.delete:
        // Location unsaved
        print('Location unsaved realtime: ${oldRecord['location_id']}');
        await _removeLocationFromSaved(oldRecord['location_id']);
        break;
        
      case PostgresChangeEvent.update:
        // Handle acked status change
        if (record['action'] == 'saved') {
          if (record['acked'] == true && oldRecord['acked'] == false) {
            print('Location acknowledged: ${record['location_id']}');
            await _addLocationToSaved(record['location_id']);
          } else if (record['acked'] == false && oldRecord['acked'] == true) {
            print('Location unacknowledged: ${record['location_id']}');
            await _removeLocationFromSaved(record['location_id']);
          }
        }
        break;
        
      default:
        // Ignore all events (includes 'select')
        print('Ignoring realtime event: ${payload.eventType}');
        break;
    }
  }
  
  /// Add a location to saved list by fetching its details
  Future<void> _addLocationToSaved(int locationId) async {
    try {
      // Check if location already exists in saved locations
      final alreadyExists = _savedLocations.keys.any((loc) => loc.locationId == locationId);
      if (alreadyExists) {
        print('Location $locationId already in saved list, skipping');
        return;
      }
      
      // Fetch location details from Supabase
      final locationData = await Supabase.instance.client
          .from('locations')
          .select()
          .eq('location_id', locationId)
          .single();
      
      final locationImage = await _supabaseService.locations
          .getLocationImage(locationId, locationData['google_place_id'], locationData['photo_reference']);
      
      final location = LocationModel.fromJson(locationData, locationImage);

      // Add to saved locations temporarily with a placeholder marker
      _savedLocations[location] = Marker(markerId: MarkerId(locationId.toString()));

      // Re-apply name selection to all saved locations (including the new one)
      final selectedForNames = _selectLocationsForNameDisplay(
        _savedLocations,
        viewportBounds: _currentViewportBounds,
      );

      // Regenerate all markers with updated name visibility
      final updatedMarkers = await Future.wait(
        _savedLocations.keys.map((loc) async {
          final shouldShowName = selectedForNames.contains(loc.locationId);
          final marker = await loc
              .setPreference(LocationPreference.saved)
              .toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
          return MapEntry(loc, marker!);
        }),
      );
      _savedLocations = Map.fromEntries(updatedMarkers);

      // Update current items if viewing saved locations
      if (_currentListType == LocationListType.saved) {
        _currentItems = _savedLocations;
      }

      notifyListeners();
      print('Added location to saved: ${location.name}');
    } catch (e) {
      print('Error adding location realtime: $e');
    }
  }
  
  /// Remove a location from saved list
  Future<void> _removeLocationFromSaved(int locationId) async {
    try {
      // Find and remove the location
      final locationToRemove = _savedLocations.keys.firstWhere(
        (loc) => loc.locationId == locationId,
        orElse: () => throw Exception('Location not found'),
      );
      
      _savedLocations.remove(locationToRemove);
      
      // Update current items if viewing saved locations
      if (_currentListType == LocationListType.saved) {
        _currentItems = _savedLocations;
      }
      
      notifyListeners();
      print('Removed location from saved: ${locationToRemove.name}');
    } catch (e) {
      print('Error removing location realtime: $e');
    }
  }

  /// Checks if a location is within the given viewport bounds
  bool _isLocationInViewport(LocationModel location, LatLngBounds bounds) {
    if (location.lat == null || location.lng == null) return false;

    // Check latitude bounds
    if (location.lat! < bounds.southwest.latitude ||
        location.lat! > bounds.northeast.latitude) {
      return false;
    }

    // Check longitude bounds (handles date line crossing)
    final west = bounds.southwest.longitude;
    final east = bounds.northeast.longitude;

    if (west <= east) {
      return location.lng! >= west && location.lng! <= east;
    } else {
      // Crosses date line
      return location.lng! >= west || location.lng! <= east;
    }
  }

  /// Selects up to 10 locations to display names on the map
  /// Only considers locations within the current viewport bounds
  /// Randomly selects from visible pins
  Set<int> _selectLocationsForNameDisplay(
    Map<LocationModel, Marker> locations, {
    LatLngBounds? viewportBounds,
  }) {
    if (locations.isEmpty) return {};

    // Filter to locations in viewport if bounds provided
    List<LocationModel> visibleLocations;
    if (viewportBounds != null) {
      visibleLocations = locations.keys
          .where((loc) => _isLocationInViewport(loc, viewportBounds))
          .toList();

      // Fallback to all locations if no visible markers
      if (visibleLocations.isEmpty) {
        visibleLocations = locations.keys.toList();
        print('No locations in viewport, falling back to all locations');
      }
    } else {
      visibleLocations = locations.keys.toList();
    }

    final selectedCount = math.min(10, visibleLocations.length);

    // Random selection from visible locations
    final random = math.Random();
    final selected = <int>{};

    while (selected.length < selectedCount) {
      final randomLocation = visibleLocations[random.nextInt(visibleLocations.length)];
      selected.add(randomLocation.locationId);
    }

    return selected;
  }

  /// Regenerates markers in _currentItems with only 10 showing names
  Future<void> _applyNameSelectionToCurrentItems({LatLngBounds? viewportBounds}) async {
    if (_currentItems.isEmpty) return;

    final selectedForNames = _selectLocationsForNameDisplay(
      _currentItems,
      viewportBounds: viewportBounds,
    );

    // Regenerate markers with updated name visibility
    final updatedMarkers = await Future.wait(
      _currentItems.keys.map((location) async {
        final shouldShowName = selectedForNames.contains(location.locationId);
        final marker = await location.toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
        return MapEntry(location, marker!);
      }),
    );

    _currentItems = Map.fromEntries(updatedMarkers);
  }

  /// Call this when map viewport changes (pan/zoom) to update name display
  Future<void> onMapViewportChanged({
    required LatLngBounds? bounds,
    required LatLng? center,
    required double zoom,
  }) async {
    if (_currentItems.isEmpty) return;

    // Store current viewport bounds
    _currentViewportBounds = bounds;

    // Calculate new selection based on viewport
    final newSelection = _selectLocationsForNameDisplay(
      _currentItems,
      viewportBounds: bounds,
    );

    // Check if selection would actually change
    final selectionChanged = _lastSelectedIds == null ||
        !_lastSelectedIds!.containsAll(newSelection) ||
        !newSelection.containsAll(_lastSelectedIds!);

    // Check if zoom changed significantly (>0.5 levels)
    final zoomChanged = _lastSelectionZoom == null ||
        (zoom - _lastSelectionZoom!).abs() > 0.5;

    // Skip regeneration if selection unchanged and zoom similar
    if (!selectionChanged && !zoomChanged) {
      print('Skipping marker regeneration - selection and zoom unchanged');
      return;
    }

    // Update cached state
    _lastSelectedIds = newSelection;
    _lastSelectionZoom = zoom;

    // Regenerate markers with updated name visibility
    final updatedMarkers = await Future.wait(
      _currentItems.keys.map((location) async {
        final shouldShowName = newSelection.contains(location.locationId);
        final marker = await location.toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
        return MapEntry(location, marker!);
      }),
    );

    _currentItems = Map.fromEntries(updatedMarkers);
    notifyListeners();
  }

  /// Sets the currently displayed locations in the carousel
  Future<void> setCurrentListType(LocationListType type) async {
    _currentListType = type;
    switch (type) {
      case LocationListType.saved:
        _currentItems = _savedLocations;
        break;
      case LocationListType.recommended:
        _currentItems = _recommendedLocations;
        break;
      case LocationListType.search:
        _currentItems = _searchLocations;
        break;
    }
    print("Set current list type to: $type, item count: ${_currentItems.length}");

    // Apply name selection with current viewport if available
    await _applyNameSelectionToCurrentItems(viewportBounds: _currentViewportBounds);
    notifyListeners();
  }

  /// Fetches saved locations from Supabase and falls back to Firebase if needed
  Future<void> fetchSavedLocations() async {
    if (_userId == null) {
      print("Cannot fetch saved locations: userId is null.");
      return;
    }

    // Prevent duplicate fetches
    if (_isLoadingSaved) {
      print("Already loading saved locations, skipping duplicate request");
      return;
    }
    
    if (_savedLocationsLoaded && _savedLocations.isNotEmpty) {
      print("Saved locations already loaded (${_savedLocations.length} items), skipping fetch");
      return;
    }

    _isLoadingSaved = true;
    
    try {
      List<LocationModel> supabaseSavedLocations =
          await _supabaseService.locations.getSavedLocations();

      if (supabaseSavedLocations.isNotEmpty) {
        // First create a temporary map to select which locations should show names
        final tempMap = Map.fromEntries(
          supabaseSavedLocations.map((loc) => MapEntry(loc, Marker(markerId: MarkerId(loc.locationId.toString()))))
        );
        final selectedForNames = _selectLocationsForNameDisplay(
          tempMap,
          viewportBounds: _currentViewportBounds,
        );

        // Create markers with name selection applied
        final markers = await Future.wait(
          supabaseSavedLocations.map((location) async {
            final shouldShowName = selectedForNames.contains(location.locationId);
            final marker = await location
                .setPreference(LocationPreference.saved)
                .toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
            return MapEntry(location, marker!);
          }),
        );
        _savedLocations = Map.fromEntries(markers);
        log("Fetched ${supabaseSavedLocations.length} saved locations from Supabase.");
        _savedLocationsLoaded = true;
      }

      // If the current type is saved, update currentItems
      if (_currentListType == LocationListType.saved) {
        _currentItems = _savedLocations;
      }
      notifyListeners();
    } catch (e) {
      log('Error fetching saved locations: $e');
    } finally {
      _isLoadingSaved = false;
    }
  }

  /// Fetches recommended locations from Supabase and falls back to Google Places API
  Future<void> fetchRecommendedLocations(
      {required double latitude, required double longitude}) async {
    try {
      // Try getting nearby locations from Supabase first
      List<LocationModel> nearbyLocations =
          await _supabaseService.locations.getLocationsNearby(
        latitude,
        longitude,
        radiusMeters: 5000, // 5km radius
      );
      print('nearbyLocations: $nearbyLocations');
      log("Supabase nearby locations: ${nearbyLocations.length}");
      if (nearbyLocations.isNotEmpty) {
        // First create a temporary map to select which locations should show names
        final tempMap = Map.fromEntries(
          nearbyLocations.map((loc) => MapEntry(loc, Marker(markerId: MarkerId(loc.locationId.toString()))))
        );
        final selectedForNames = _selectLocationsForNameDisplay(
          tempMap,
          viewportBounds: _currentViewportBounds,
        );

        // Create markers with name selection applied
        final markers = await Future.wait(
          nearbyLocations.map((location) async {
            final shouldShowName = selectedForNames.contains(location.locationId);
            final marker = await location
                .setPreference(LocationPreference.recommended)
                .toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
            return MapEntry(location, marker!);
          }),
        );
        _recommendedLocations = Map.fromEntries(markers);
        log("Fetched ${nearbyLocations.length} nearby locations from Supabase.");
      } else {
        // Fall back to Google Places API during migration
        var recommendations = await _googlePlacesService.fetchNearbyPlaces(
          latitude: latitude,
          longitude: longitude,
          placeType: "restaurant",
        );
        // Select which locations should show names
        final tempMap = Map.fromEntries(
          recommendations.map((loc) => MapEntry(loc, Marker(markerId: MarkerId(loc.locationId.toString()))))
        );
        final selectedForNames = _selectLocationsForNameDisplay(
          tempMap,
          viewportBounds: _currentViewportBounds,
        );

        final markers = await Future.wait(
          recommendations.map((location) async {
            final shouldShowName = selectedForNames.contains(location.locationId);
            final marker = await location
                .setPreference(LocationPreference.recommended)
                .toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
            return MapEntry(location, marker!);
          }),
        );
        _recommendedLocations = Map.fromEntries(markers);
        print(
            "Fetched ${recommendations.length} recommended locations from Google Places.");

        print('recommendations: $recommendations[0]');
      }

      // Optionally set as current list
      // setCurrentListType(LocationListType.recommended);
      notifyListeners();
    } catch (e) {
      log('Error fetching recommended locations from Supabase: $e');

      // Fall back to Google Places API
      try {
        var recommendations = await _googlePlacesService.fetchNearbyPlaces(
          latitude: latitude,
          longitude: longitude,
          placeType: "restaurant",
        );
        // Select which locations should show names
        final tempMap = Map.fromEntries(
          recommendations.map((loc) => MapEntry(loc, Marker(markerId: MarkerId(loc.locationId.toString()))))
        );
        final selectedForNames = _selectLocationsForNameDisplay(
          tempMap,
          viewportBounds: _currentViewportBounds,
        );

        final markers = await Future.wait(
          recommendations.map((location) async {
            final shouldShowName = selectedForNames.contains(location.locationId);
            final marker = await location
                .setPreference(LocationPreference.recommended)
                .toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
            return MapEntry(location, marker!);
          }),
        );
        _recommendedLocations = Map.fromEntries(markers);
        log("Fallback: Fetched ${recommendations.length} recommended locations from Google Places.");
        notifyListeners();
      } catch (fallbackError) {
        log('Error in Google Places fallback: $fallbackError');
      }
    }
  }

  /// Adds recommended locations (can be merged with fetch or kept separate)
  Future<void> addRecommendedLocations(List<LocationModel> locations) async {
    // Add new locations with placeholder markers
    for (var location in locations) {
      _recommendedLocations[location] = Marker(markerId: MarkerId(location.locationId.toString()));
    }

    // Re-apply name selection to all recommended locations
    final selectedForNames = _selectLocationsForNameDisplay(
      _recommendedLocations,
      viewportBounds: _currentViewportBounds,
    );

    // Regenerate all markers with updated name visibility
    final updatedMarkers = await Future.wait(
      _recommendedLocations.keys.map((loc) async {
        final shouldShowName = selectedForNames.contains(loc.locationId);
        final marker = await loc
            .setPreference(LocationPreference.recommended)
            .toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
        return MapEntry(loc, marker!);
      }),
    );
    _recommendedLocations = Map.fromEntries(updatedMarkers);

    if (_currentListType == LocationListType.recommended) {
      _currentItems = _recommendedLocations;
    }
    notifyListeners();
  }

  /// Search recommendations in the visible map area using proximal API.
  Future<void> searchThisArea({
    required LatLng center,
    required LatLngBounds bounds,
    int maxResults = 20,
    double tasteWeight = 0.2,
    double proximityWeight = 0.6,
    double qualityWeight = 0.2,
    bool includeTasteBreakdown = false,
  }) async {
    if (_userId == null) {
      _error = "User not logged in";
      notifyListeners();
      return;
    }

    final radiusKm = _radiusKmFromVisibleRegion(bounds, center);
    _isSearchingArea = true;
    notifyListeners();

    try {
      final response = await _recommendationsApi.fetchProximal(
        userId: _userId!,
        latitude: center.latitude,
        longitude: center.longitude,
        radiusKm: radiusKm,
        maxResults: maxResults,
        tasteWeight: tasteWeight,
        proximityWeight: proximityWeight,
        qualityWeight: qualityWeight,
        includeTasteBreakdown: includeTasteBreakdown,
      );

      final locationIds = response.recommendations
          .map((rec) => rec.locationId)
          .where((id) => id > 0)
          .toList();

      final locations = await _fetchLocationsByIdsInOrder(locationIds);

      // Select which locations should show names
      final tempMap = Map.fromEntries(
        locations.map((loc) => MapEntry(loc, Marker(markerId: MarkerId(loc.locationId.toString()))))
      );
      final selectedForNames = _selectLocationsForNameDisplay(
        tempMap,
        viewportBounds: _currentViewportBounds,
      );

      final markers = await Future.wait(
        locations.map((location) async {
          final shouldShowName = selectedForNames.contains(location.locationId);
          final marker = await location
              .setPreference(LocationPreference.search)
              .toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
          return marker != null ? MapEntry(location, marker) : null;
        }),
      );

      _searchLocations =
          Map.fromEntries(markers.whereType<MapEntry<LocationModel, Marker>>());
      _lastSearchedCenter = center;
      _areaChanged = false;
      _error = null;
      await setCurrentListType(LocationListType.search);
    } catch (e) {
      log('LocationListManager: Search this area failed: $e');
      _error = "Search failed: ${e.toString()}";
      notifyListeners();
    } finally {
      _isSearchingArea = false;
      notifyListeners();
    }
  }

  static double _radiusKmFromVisibleRegion(
    LatLngBounds bounds,
    LatLng center,
  ) {
    final double distanceKm = _haversineKm(
      center.latitude,
      center.longitude,
      bounds.northeast.latitude,
      bounds.northeast.longitude,
    );
    return distanceKm.clamp(0.5, 10.0);
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180);

  /// Removes a location from the appropriate list and from Supabase/Firebase
  Future<void> removeLocation(LocationModel location) async {
    bool removed = false;
    int locationId = location.locationId;

    // Determine which list based on the current list type for UI consistency
    if (_currentListType == LocationListType.saved) {
      if (_savedLocations.containsKey(location)) {
        _savedLocations.remove(location);

        // Try to remove from Supabase first

        await _supabaseService.locations.unsaveLocation(locationId);

        removed = true;
        log("Removed saved location: ${location.name}");
      }
    }

    if (_currentListType == LocationListType.recommended) {
      if (_recommendedLocations.containsKey(location)) {
        _recommendedLocations.remove(location);
        removed = true;
        log("Removed recommended location: ${location.name}");
      }
    }

    if (_currentListType == LocationListType.search) {
      if (_searchLocations.containsKey(location)) {
        _searchLocations.remove(location);
        removed = true;
        log("Removed search location: ${location.name}");
      }
    }

    // Update currentItems if the removed item was in the currently displayed list
    if (removed && _currentItems.containsKey(location)) {
      _currentItems.remove(location);
    }

    notifyListeners();
  }

  /// Saves a location to Supabase/Firebase and adds it to the local saved state
  Future<void> saveLocation(LocationModel location) async {
    if (_userId == null) {
      log("Cannot save location: userId is null.");
      return; // Or handle appropriately, maybe prompt login
    }

    // Add location with placeholder marker
    _savedLocations[location] = Marker(markerId: MarkerId(location.locationId.toString()));

    // Re-apply name selection to all saved locations
    final selectedForNames = _selectLocationsForNameDisplay(
      _savedLocations,
      viewportBounds: _currentViewportBounds,
    );

    // Regenerate all markers with updated name visibility
    final updatedMarkers = await Future.wait(
      _savedLocations.keys.map((loc) async {
        final shouldShowName = selectedForNames.contains(loc.locationId);
        final marker = await loc
            .setPreference(LocationPreference.saved)
            .toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
        return MapEntry(loc, marker!);
      }),
    );
    _savedLocations = Map.fromEntries(updatedMarkers);

    // Try to save in Supabase first
    bool supabaseSuccess =
        await _supabaseService.locations.saveLocation(location.locationId, savedMethod: 'in-app');

    if (supabaseSuccess) {
      log("Saved location to Supabase: ${location.name}");
    }

    // If the user is currently viewing saved locations, update the view
    if (_currentListType == LocationListType.saved) {
      _currentItems = _savedLocations;
    }

    // Optionally remove from recommended/search if it was there
    _recommendedLocations.remove(location);
    _searchLocations.remove(location);

    notifyListeners();
  }

  Future<List<LocationModel>> _fetchLocationsByIdsInOrder(
      List<int> locationIds) async {
    if (locationIds.isEmpty) return [];

    final uniqueIds = locationIds.toSet().toList();
    final response = await Supabase.instance.client
        .from(SupabaseConstants.tableLocations)
        .select()
        .inFilter(SupabaseConstants.columnLocationId, uniqueIds);

    final Map<int, LocationModel> byId = {};
    for (var item in response as List) {
      final int locationId =
          item[SupabaseConstants.columnLocationId] as int;
      String? locationImage = item[SupabaseConstants.columnImageUrl];
      if (locationImage == null || locationImage.isEmpty) {
        locationImage = await _supabaseService.locations.getLocationImage(
          locationId,
          item[SupabaseConstants.columnGooglePlaceId],
          item[SupabaseConstants.columnPhotoReference],
        );
      }
      byId[locationId] = LocationModel.fromJson(item, locationImage);
    }

    final List<LocationModel> ordered = [];
    for (final id in locationIds) {
      final location = byId[id];
      if (location != null) {
        ordered.add(location);
      } else {
        log('LocationListManager: Missing location data for id $id');
      }
    }
    return ordered;
  }

  /// Handles the magic search feature using the recommendations API.
  Future<void> magicSearch(
    String query, {
    double radiusKm = 2.0,
    int maxResults = 20,
    bool includeTasteBreakdown = false,
  }) async {
    print('🎯 LocationListManager.magicSearch CALLED');
    print('   Query: "$query"');
    print('   UserId: $_userId');
    print('[MagicSearchDebug] permissionGranted: $permissionGranted');
    
    if (_userId == null) {
      log("Cannot perform magic search: userId is null.");
      _error = "User not logged in";
      notifyListeners();
      return;
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      log("LocationListManager: Magic search query is empty.");
      return;
    }

    // Get device GPS location
    log("LocationListManager: Getting device GPS location...");
    print('[MagicSearchDebug] About to call getCurrentLocation()');
    final currentLocation = await getCurrentLocation();
    print('[MagicSearchDebug] getCurrentLocation() returned: $currentLocation');
    if (currentLocation == null) {
      log("LocationListManager: Cannot perform magic search without location.");
      _error = "Location permission required for search";
      _searchLocations = {};
      await setCurrentListType(LocationListType.search);
      return;
    }

    log("LocationListManager: Starting magic search for query: '$trimmedQuery'");
    log(
      "LocationListManager: Magic search request params - "
      "userId: $_userId, lat: ${currentLocation.latitude}, "
      "lng: ${currentLocation.longitude}, radiusKm: $radiusKm, "
      "maxResults: $maxResults, includeTasteBreakdown: $includeTasteBreakdown",
    );

    try {
      final response = await http.post(
        Uri.parse(_magicSearchEndpoint),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _userId,
          'latitude': currentLocation.latitude,
          'longitude': currentLocation.longitude,
          'prompt': trimmedQuery,
          'radius_km': radiusKm,
          'max_results': maxResults,
          'include_taste_breakdown': includeTasteBreakdown,
        }),
      );

      log(
        "LocationListManager: Magic search response status ${response.statusCode}",
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        log(
          "LocationListManager: Magic search failed (${response.statusCode}): ${response.body}",
        );
        _error = "Search failed: Server returned error ${response.statusCode}";
        _searchLocations = {};
        await setCurrentListType(LocationListType.search);
        return;
      }
      
      // Clear any previous errors on successful response
      _error = null;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final recommendations = decoded['recommendations'] as List<dynamic>? ?? [];
      log(
        "LocationListManager: Magic search returned ${recommendations.length} recommendations",
      );
      final locationIds = recommendations
          .map((item) => (item as Map<String, dynamic>)['location_id'])
          .where((id) => id != null)
          .map((id) => (id as num).toInt())
          .toList();

      log(
        "LocationListManager: Magic search location IDs count ${locationIds.length}",
      );
      final locations = await _fetchLocationsByIdsInOrder(locationIds);
      log(
        "LocationListManager: Loaded ${locations.length} locations from Supabase for magic search",
      );
      _searchLocations = {};

      // Select which locations should show names
      final tempMap = Map.fromEntries(
        locations.map((loc) => MapEntry(loc, Marker(markerId: MarkerId(loc.locationId.toString()))))
      );
      final selectedForNames = _selectLocationsForNameDisplay(
        tempMap,
        viewportBounds: _currentViewportBounds,
      );

      final markers = await Future.wait(
        locations.map((location) async {
          final shouldShowName = selectedForNames.contains(location.locationId);
          final marker = await location
              .setPreference(LocationPreference.search)
              .toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
          return marker != null ? MapEntry(location, marker) : null;
        }),
      );
      _searchLocations = Map.fromEntries(markers.whereType<MapEntry<LocationModel, Marker>>());

      log(
        "LocationListManager: Magic search returned ${_searchLocations.length} results for '$trimmedQuery'.",
      );
      await setCurrentListType(LocationListType.search);
    } catch (e) {
      log('LocationListManager: Error during magic search: $e');
      _error = "Search error: ${e.toString()}";
      _searchLocations = {};
      await setCurrentListType(LocationListType.search);
    }
    // No need for notifyListeners() here as setCurrentListType calls it
  }


  /// Check if location is saved by current user
  Future<bool> isLocationSaved(LocationModel location) async {
    try {
      return await _supabaseService.locations.isLocationSaved(location.locationId);
    } catch (e) {
      log('Error checking if location is saved: $e');
      return false;
    }
  }


  /// Acknowledge if a location is right or not
  Future<void> acknowledgeLocation(int locationId, bool value) async {
    try {
      await _supabaseService.locations.acknowledgeLocation(locationId, value);
      log("Acknowledged location: ${locationId}, value: $value");
    } catch (e) {
      log('Error acknowledging location: $e');
    }
  }

  /// Clears all data (used for sign out)
  void clearData() {
    _userId = null;
    _savedLocations.clear();
    _recommendedLocations.clear();
    _searchLocations.clear();
    _currentItems.clear();
    _currentListType = LocationListType.saved;
    _locationService.stopLocationUpdates(); // Stop tracking when clearing data
    print("LocationListManager: Cleared all location data");
    notifyListeners();
  }

  /// Checks and requests location permission - delegates to LocationService
  Future<bool> checkAndRequestPermission() async {
    final granted = await _locationService.checkAndRequestPermission();
    notifyListeners(); // Notify listeners since permission state changed
    return granted;
  }

  /// Starts tracking the user's live location updates - delegates to LocationService
  Future<void> startLocationUpdates() async {
    // Set up listener for location changes from LocationService
    _locationService.addListener(_onLocationServiceChanged);
    await _locationService.startLocationUpdates();
    // Defer notification to avoid calling during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Internal callback when LocationService changes
  void _onLocationServiceChanged() {
    // Defer notification to next frame to avoid calling during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Stops live location tracking - delegates to LocationService
  void stopLocationUpdates() {
    _locationService.removeListener(_onLocationServiceChanged);
    _locationService.stopLocationUpdates();
    // Don't call notifyListeners here - it may be called during dispose
    // which causes "setState() called when widget tree was locked" errors
  }

  /// Gets a stream of position updates - delegates to LocationService
  Stream<Position> getPositionStream() {
    return _locationService.getPositionStream();
  }

  /// Gets the current device GPS location - delegates to LocationService
  Future<LatLng?> getCurrentLocation() async {
    print('[LocationDebug] getCurrentLocation called via LocationService');
    final position = await _locationService.getCurrentLocation();
    notifyListeners();
    return position;
  }

  @override
  void dispose() {
    _locationService.removeListener(_onLocationServiceChanged);
    _locationService.stopLocationUpdates();
    log('Unsubscribing from realtime updates on dispose');
    _supabaseService.locations.unsubscribeFromUserLocationActions();
    _isSubscribed = false;
    log("LocationListManager: Disposed.");
    super.dispose();
  }
  
  /// Force refresh saved locations (use sparingly, realtime handles most updates)
  Future<void> refreshSavedLocations() async {
    log('Force refreshing saved locations');
    _savedLocationsLoaded = false;
    await fetchSavedLocations();
  }
}

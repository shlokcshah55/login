import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:login/utils/geo_types.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/recommendations_api.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/services/location_service.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/service.dart';
import 'package:login/utils/marker_clustering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

// Enum to represent the different types of location lists
enum LocationListType { saved, recommended, search }

class LocationListManager with ChangeNotifier {
  final GooglePlacesService _googlePlacesService;
  final SupabaseService _supabaseService = SupabaseService();
  final LocationService _locationService = LocationService();
  static const String _magicSearchEndpoint =
      'https://pinit-recommendations-api-1070859807237.europe-west2.run.app/locations/magic-search';

  String? _userId;

  // Device location state is now delegated to LocationService
  double _devicePixelRatio = 1.0; // Default value
  final RecommendationsApi _recommendationsApi = RecommendationsApi();
  CameraPositionData? _cameraPosition;
  LatLng? _lastSearchedCenter;
  double? _lastSearchedRadius; // in km
  bool _areaChanged = false;
  bool _isSearchingArea = false;
  bool _isLoadingRecommendations = false;
  String? _error; // Local error for non-location errors

  // Filter state
  List<String> _vibeTagIds = [];
  List<String> _cuisineTagIds = [];

  // Viewport-aware name selection state
  LatLngBounds? _currentViewportBounds;
  Set<int>? _lastSelectedIds;
  double? _lastSelectionZoom;
  double _currentZoom = 15.0; // Track current zoom level

  // Flags to prevent duplicate data fetches
  bool _isLoadingSaved = false;
  bool _savedLocationsLoaded = false;
  bool _isSubscribed = false;

  LocationListManager(this._googlePlacesService);

  // Location lists
  Map<LocationModel, MapMarkerData> _savedLocations = {};
  Map<LocationModel, MapMarkerData> _recommendedLocations = {};
  Map<LocationModel, MapMarkerData> _searchLocations = {};
  Map<LocationModel, MapMarkerData> _currentItems = {};
  List<LocationModel> _justDecideLocations = [];
  LocationListType _currentListType =
      LocationListType.saved; // Default to saved

  // Getters
  Map<LocationModel, MapMarkerData> get savedLocations => _savedLocations;
  Map<LocationModel, MapMarkerData> get recommendedLocations => _recommendedLocations;
  Map<LocationModel, MapMarkerData> get searchLocations => _searchLocations;
  Map<LocationModel, MapMarkerData> get currentItems => _currentItems;
  List<LocationModel> get justDecideLocations => _justDecideLocations;
  LocationListType get currentListType => _currentListType;
  List<String> get vibeTagIds => List.unmodifiable(_vibeTagIds);
  List<String> get cuisineTagIds => List.unmodifiable(_cuisineTagIds);
  bool get hasActiveFilters => _vibeTagIds.isNotEmpty || _cuisineTagIds.isNotEmpty;

  // Device location getters - delegate to LocationService
  LatLng? get currentPosition => _locationService.currentPosition;
  bool get isTracking => _locationService.isTracking;
  bool get permissionGranted => _locationService.permissionGranted;
  String? get error => _error ?? _locationService.error;
  CameraPositionData? get cameraPosition => _cameraPosition;
  LocationService get locationService => _locationService;

  // Set device pixel ratio (should be called once from a widget with context)
  void setDevicePixelRatio(double dpr) {
    if (_devicePixelRatio != dpr) {
      _devicePixelRatio = dpr;
      print('LocationListManager: Device pixel ratio set to $dpr');
    }
  }

  void setCameraPosition(CameraPositionData position) {
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
  bool get isLoadingRecommendations => _isLoadingRecommendations;
  LatLng? get lastSearchedCenter => _lastSearchedCenter;
  double? get lastSearchedRadius => _lastSearchedRadius;

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
      final alreadyExists =
          _savedLocations.keys.any((loc) => loc.locationId == locationId);
      if (alreadyExists) {
        print('Location $locationId already in saved list, skipping');
        return;
      }

        // Fetch location details from Supabase
        print('[Supabase] Querying location_id=$locationId');
        final locationData = await Supabase.instance.client
          .from('locations')
          .select()
          .eq('location_id', locationId)
          .single();
        print('[Supabase] Result for location_id=$locationId: ${locationData.toString().substring(0, math.min(200, locationData.toString().length))}');

        // Optionally log image fetch
        print('[Supabase] Fetching image for location_id=$locationId, google_place_id=${locationData['google_place_id']}, photo_reference=${locationData['photo_reference']}');
        final locationImage = await _supabaseService.locations.getLocationImage(
          locationId,
          locationData['google_place_id'],
          locationData['photo_reference']);

      final location = LocationModel.fromJson(locationData, locationImage);

      // Add to saved locations temporarily with a placeholder marker
      _savedLocations[location] =
          MapMarkerData(id: locationId.toString(), position: const LatLng(0, 0), imageBytes: const []);

      // Re-apply name selection to all saved locations (including the new one)
      final selectedForNames = _selectLocationsForNameDisplay(
        _savedLocations,
        viewportBounds: _currentViewportBounds,
        zoom: _currentZoom,
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
  /// Adjusts for carousel/footer covering bottom ~30% of screen
  bool _isLocationInViewport(LocationModel location, LatLngBounds bounds) {
    if (location.lat == null || location.lng == null) return false;

    // Adjust latitude bounds to account for carousel at bottom
    // Carousel takes up ~30% of screen height, so exclude that portion
    final latitudeRange = bounds.northeast.latitude - bounds.southwest.latitude;
    final carouselHeightRatio = 0.30; // 30% of screen
    final adjustedSouthwestLat =
        bounds.southwest.latitude + (latitudeRange * carouselHeightRatio);

    // Check latitude bounds with adjustment
    if (location.lat! < adjustedSouthwestLat ||
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

  /// Selects locations to display names on the map
  /// Uses cached clustering results from MarkerClustering to avoid duplicate calculation
  /// If 10 or fewer unclustered locations: shows all names
  /// If more than 10 unclustered: randomly selects 10 to show names
  Set<int> _selectLocationsForNameDisplay(
    Map<LocationModel, MapMarkerData> locations, {
    LatLngBounds? viewportBounds,
    double zoom = 15.0,
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

    // Get unclustered location IDs from the centralized MarkerClustering cache
    final cachedUnclusteredIds = MarkerClustering.getUnclusteredLocationIds();

    // If cache is empty (clustering hasn't run yet), treat all visible locations as unclustered
    // This ensures labels show before clustering completes
    List<LocationModel> unclusteredLocations;
    if (cachedUnclusteredIds.isEmpty) {
      // No clustering data yet - show names for all visible locations
      unclusteredLocations = visibleLocations;
    } else {
      // Filter visible locations to only those that are unclustered
      unclusteredLocations = visibleLocations
          .where((loc) => cachedUnclusteredIds.contains(loc.locationId))
          .toList();
    }

    // If 10 or fewer unclustered locations, show names for all of them
    if (unclusteredLocations.length <= 10) {
      return unclusteredLocations.map((loc) => loc.locationId).toSet();
    }

    // More than 10 unclustered locations: randomly select 10
    final random = math.Random();
    final selected = <int>{};

    while (selected.length < 10) {
      final randomLocation =
          unclusteredLocations[random.nextInt(unclusteredLocations.length)];
      selected.add(randomLocation.locationId);
    }

    return selected;
  }

  // NOTE: _filterUnclusteredLocations has been removed - we now use
  // MarkerClustering.getUnclusteredLocationIds() to avoid duplicate O(N²) logic

  /// Regenerates markers in _currentItems with names (all if ≤10, random 10 if >10)
  Future<void> _applyNameSelectionToCurrentItems(
      {LatLngBounds? viewportBounds}) async {
    if (_currentItems.isEmpty) return;

    final selectedForNames = _selectLocationsForNameDisplay(
      _currentItems,
      viewportBounds: viewportBounds,
      zoom: _currentZoom,
    );

    // Regenerate markers with updated name visibility
    final updatedMarkers = await Future.wait(
      _currentItems.keys.map((location) async {
        final shouldShowName = selectedForNames.contains(location.locationId);
        final marker = await location.toMarker(_devicePixelRatio,
            shouldShowName: shouldShowName);
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

    // Store current viewport bounds and zoom
    _currentViewportBounds = bounds;
    _currentZoom = zoom;

    // Calculate new selection based on viewport
    final newSelection = _selectLocationsForNameDisplay(
      _currentItems,
      viewportBounds: bounds,
      zoom: zoom,
    );

    // Check if selection would actually change
    final selectionChanged = _lastSelectedIds == null ||
        !_lastSelectedIds!.containsAll(newSelection) ||
        !newSelection.containsAll(_lastSelectedIds!);

    // Check if zoom changed significantly (>0.25 levels) - more responsive
    final zoomChanged =
        _lastSelectionZoom == null || (zoom - _lastSelectionZoom!).abs() > 0.25;

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
        final marker = await location.toMarker(_devicePixelRatio,
            shouldShowName: shouldShowName);
        return MapEntry(location, marker!);
      }),
    );

    _currentItems = Map.fromEntries(updatedMarkers);
    notifyListeners();
  }

  /// Calculates distance between two LatLng points using Haversine formula
  /// Returns distance in kilometers
  double _calculateDistance(LatLng point1, LatLng point2) {
    const earthRadiusKm = 6371.0;
    final lat1Rad = point1.latitude * math.pi / 180.0;
    final lat2Rad = point2.latitude * math.pi / 180.0;
    final deltaLatRad = (point2.latitude - point1.latitude) * math.pi / 180.0;
    final deltaLngRad = (point2.longitude - point1.longitude) * math.pi / 180.0;

    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Sorts locations by distance (nearest first) and then by match score (highest first)
  List<MapEntry<LocationModel, MapMarkerData>> _sortLocationsByDistanceAndScore(
    List<LocationModel> locations,
    List<MapEntry<LocationModel, MapMarkerData>> markers,
    LatLng? userPosition,
  ) {
    if (userPosition == null || locations.isEmpty) {
      // If no user position, sort by match score only (highest first)
      final markersMap = Map.fromEntries(markers);
      final sorted = locations..sort((a, b) {
        final scoreA = a.matchScore ?? 0.0;
        final scoreB = b.matchScore ?? 0.0;
        return scoreB.compareTo(scoreA); // Higher score first
      });
      return sorted.map((loc) => MapEntry(loc, markersMap[loc]!)).toList();
    }

    // Sort with distance as primary key, match score as secondary
    final markersMap = Map.fromEntries(markers);
    final sorted = locations..sort((a, b) {
      if (a.lat == null || a.lng == null || b.lat == null || b.lng == null) {
        return 0; // Can't calculate distance, keep order
      }

      final posA = LatLng(a.lat!, a.lng!);
      final posB = LatLng(b.lat!, b.lng!);
      
      final distA = _calculateDistance(userPosition, posA);
      final distB = _calculateDistance(userPosition, posB);
      
      // Primary sort: by distance (nearest first)
      final distCompare = distA.compareTo(distB);
      if (distCompare != 0) return distCompare;
      
      // Secondary sort: by match score (highest first)
      final scoreA = a.matchScore ?? 0.0;
      final scoreB = b.matchScore ?? 0.0;
      return scoreB.compareTo(scoreA);
    });

    return sorted.map((loc) => MapEntry(loc, markersMap[loc]!)).toList();
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
    final imgCount = _currentItems.keys.where((l) => l.imageUrl != null && l.imageUrl!.isNotEmpty).length;
    print('[ListType] Switched to $type: ${_currentItems.length} items ($imgCount with imageUrl) — notifyListeners()');

    // Apply name selection with current viewport if available
    await _applyNameSelectionToCurrentItems(
        viewportBounds: _currentViewportBounds);
    notifyListeners();
  }

  /// Fetches saved locations from Supabase and falls back to Firebase if needed
  Future<void> fetchSavedLocations() async {
    if (_userId == null) {
      print("Cannot fetch saved locations: userId is null.");
      return;
    }

    // Prevent duplicate fetches while one is in-flight
    if (_isLoadingSaved) {
      log('[fetchSavedLocations] Already in-flight, skipping');
      return;
    }

    // Already completed a successful load — don't re-fetch
    if (_savedLocationsLoaded) {
      log('[fetchSavedLocations] Already loaded (${_savedLocations.length} items), skipping');
      return;
    }

    _isLoadingSaved = true;
    log('[fetchSavedLocations] Starting fetch for user $_userId');
    final stopwatch = Stopwatch()..start();

    try {
      List<LocationModel> supabaseSavedLocations =
          await _supabaseService.locations.getSavedLocations();

      final withImg = supabaseSavedLocations.where((l) => l.imageUrl != null && l.imageUrl!.isNotEmpty).length;
      print('[SavedLocations] Got ${supabaseSavedLocations.length} locations ($withImg with imageUrl, ${supabaseSavedLocations.length - withImg} without) in ${stopwatch.elapsedMilliseconds}ms');
      log('[fetchSavedLocations] Got ${supabaseSavedLocations.length} locations in ${stopwatch.elapsedMilliseconds}ms');

      // Always mark as loaded — even if empty (user simply has no saves yet)
      _savedLocationsLoaded = true;

      if (supabaseSavedLocations.isNotEmpty) {
        // First create a temporary map to select which locations should show names
        final tempMap = Map.fromEntries(supabaseSavedLocations.map((loc) =>
            MapEntry(
                loc, MapMarkerData(id: loc.locationId.toString(), position: const LatLng(0, 0), imageBytes: const []))));
        final selectedForNames = _selectLocationsForNameDisplay(
          tempMap,
          viewportBounds: _currentViewportBounds,
          zoom: _currentZoom,
        );

        // Create markers with name selection applied
        final markers = await Future.wait(
          supabaseSavedLocations.map((location) async {
            final shouldShowName =
                selectedForNames.contains(location.locationId);
            final marker = await location
                .setPreference(LocationPreference.saved)
                .toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
            return MapEntry(location, marker!);
          }),
        );

        // Sort saved locations by distance (nearest first), then by match score (highest first)
        final sortedMarkers = _sortLocationsByDistanceAndScore(
          markers.map((e) => e.key).toList(),
          markers,
          currentPosition,
        );

        _savedLocations = Map.fromEntries(sortedMarkers);
        print('[SavedLocations] Markers created: ${sortedMarkers.length} (${stopwatch.elapsedMilliseconds}ms)');
        log('[fetchSavedLocations] Created ${sortedMarkers.length} markers in ${stopwatch.elapsedMilliseconds}ms');
      }

      // If the current type is saved, update currentItems
      if (_currentListType == LocationListType.saved) {
        _currentItems = _savedLocations;
      }
      print('[SavedLocations] Carousel can now render with ${_savedLocations.length} items — notifyListeners() (${stopwatch.elapsedMilliseconds}ms)');
      notifyListeners();

      // Kick off background image hydration for locations missing images
      final missingImages = supabaseSavedLocations
          .where((loc) => loc.imageUrl == null || loc.imageUrl!.isEmpty)
          .toList();
      if (missingImages.isNotEmpty) {
        print('[SavedLocations] Kicking off hydration for ${missingImages.length} missing images');
        log('[fetchSavedLocations] Hydrating ${missingImages.length} images in background');
        _hydrateImagesInBackground(missingImages);
      } else {
        print('[SavedLocations] All images already available, no hydration needed');
      }
    } catch (e, st) {
      log('[fetchSavedLocations] ERROR: $e\n$st');
      // Still mark as loaded so we don't retry in an infinite loop
      _savedLocationsLoaded = true;
    } finally {
      stopwatch.stop();
      _isLoadingSaved = false;
    }
  }

  /// Fetches recommended locations using the Recommendations API
  Future<void> fetchRecommendedLocations({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    int maxResults = 20,
    double tasteWeight = 0.2,
    double proximityWeight = 0.6,
    double qualityWeight = 0.2,
    List<String>? vibeTagIds,
    List<String>? cuisineTagIds,
  }) async {
    // Guard: check if userId is null
    if (_userId == null) {
      log("Cannot fetch recommendations: userId is null.");
      _error = "Please log in to see personalized recommendations";
      _recommendedLocations = {};
      notifyListeners();
      return;
    }

    // Store the search parameters for later reference
    final searchCenter = LatLng(latitude, longitude);
    final searchRadius = radiusKm;

    _isLoadingRecommendations = true;
    notifyListeners();

    final rsw = Stopwatch()..start();
    print('[Recommendations] START');

    try {
      log("📍 [LocationListManager] fetchRecommendedLocations called");
      log("   User ID: $_userId");
      log("   Location: $latitude, $longitude (radius: ${radiusKm}km)");
      log("   Filters - Vibes: ${vibeTagIds ?? 'none'}, Cuisines: ${cuisineTagIds ?? 'none'}");
      log("   Weights - Taste: $tasteWeight, Proximity: $proximityWeight, Quality: $qualityWeight");

      // Call recommendations API
      final response = await _recommendationsApi.fetchProximal(
        userId: _userId!,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        maxResults: maxResults,
        tasteWeight: tasteWeight,
        proximityWeight: proximityWeight,
        qualityWeight: qualityWeight,
        vibeTagIds: vibeTagIds,
        cuisineTagIds: cuisineTagIds,
      );

      print('[Recommendations] API response received (${rsw.elapsedMilliseconds}ms)');

      // Extract IDs (preserves ranking!)
      final locationIds = response.recommendations
          .map((rec) => rec.locationId)
          .where((id) => id > 0)
          .toList();

      if (locationIds.isEmpty) {
        print('[Recommendations] API returned 0 results (${rsw.elapsedMilliseconds}ms)');
        log("Recommendations API returned no results");
        _error = "No recommendations found in this area";
        _recommendedLocations = {};
        notifyListeners();
        return;
      }

      print('[Recommendations] ${locationIds.length} IDs from API, fetching from Supabase...');

      // Fetch full location data
      final locations = await _fetchLocationsByIdsInOrder(locationIds);
      final withImg = locations.where((l) => l.imageUrl != null && l.imageUrl!.isNotEmpty).length;
      print('[Recommendations] Locations fetched: ${locations.length} total, $withImg with imageUrl, ${locations.length - withImg} without (${rsw.elapsedMilliseconds}ms)');

      // Select which locations should show names
      final tempMap = Map.fromEntries(locations.map((loc) => MapEntry(
          loc, MapMarkerData(id: loc.locationId.toString(), position: const LatLng(0, 0), imageBytes: const []))));
      final selectedForNames = _selectLocationsForNameDisplay(
        tempMap,
        viewportBounds: _currentViewportBounds,
        zoom: _currentZoom,
      );

      // Generate markers with name selection applied
      final markers = await Future.wait(
        locations.map((location) async {
          final shouldShowName = selectedForNames.contains(location.locationId);
          final marker = await location
              .setPreference(LocationPreference.recommended)
              .toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
          return MapEntry(location, marker!);
        }),
      );

      print('[Recommendations] Markers generated: ${markers.length} (${rsw.elapsedMilliseconds}ms)');

      _recommendedLocations = Map.fromEntries(markers);
      _error = null; // Clear any previous errors

      // Update last searched area
      _lastSearchedCenter = searchCenter;
      _lastSearchedRadius = searchRadius;

      log("Fetched ${locations.length} personalized recommendations");

      // Kick off background image hydration for locations missing images
      final missingImages = locations
          .where((loc) => loc.imageUrl == null || loc.imageUrl!.isEmpty)
          .toList();
      if (missingImages.isNotEmpty) {
        print('[Recommendations] Kicking off hydration for ${missingImages.length} missing images');
        _hydrateImagesInBackground(missingImages);
      }

    } catch (e) {
      print('[Recommendations] ERROR: $e (${rsw.elapsedMilliseconds}ms)');
      log('Error fetching personalized recommendations: $e');
      _error = "Failed to load recommendations: ${e.toString()}";
      _recommendedLocations = {};
    } finally {
      _isLoadingRecommendations = false;
      print('[Recommendations] DONE, isLoading=false — notifyListeners() (${rsw.elapsedMilliseconds}ms)');
      notifyListeners();
    }
  }

  /// Updates filter tags and refetches recommendations if on recommended tab
  Future<void> applyFilters({
    required List<String> vibeTagIds,
    required List<String> cuisineTagIds,
  }) async {
    // Update filter state
    _vibeTagIds = List.from(vibeTagIds);
    _cuisineTagIds = List.from(cuisineTagIds);

    log("🎯 [LocationListManager] applyFilters called");
    log("   Vibe tag IDs (${_vibeTagIds.length}): $_vibeTagIds");
    log("   Cuisine tag IDs (${_cuisineTagIds.length}): $_cuisineTagIds");
    log("   Current list type: $_currentListType");

    // If we're currently on the recommended tab, refetch with new filters
    if (_currentListType == LocationListType.recommended) {
      log("   ✅ On recommended tab - refetching with filters");
      // Get current location
      final currentLocation = currentPosition ?? await getCurrentLocation();

      if (currentLocation != null) {
        log("   Location: ${currentLocation.latitude}, ${currentLocation.longitude}");
        await fetchRecommendedLocations(
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
          vibeTagIds: _vibeTagIds.isNotEmpty ? _vibeTagIds : null,
          cuisineTagIds: _cuisineTagIds.isNotEmpty ? _cuisineTagIds : null,
        );
      } else {
        log("   ⚠️ No current location available");
      }
    } else {
      log("   ⏭️ Not on recommended tab - filters saved but not applied yet");
    }

    notifyListeners();
  }

  /// Clears all filters and refetches recommendations if on recommended tab
  Future<void> clearFilters() async {
    await applyFilters(vibeTagIds: [], cuisineTagIds: []);
  }

  /// Fetches bubble (group) recommendations using the Recommendations API
  Future<void> fetchBubbleRecommendations({
    required List<String> memberIds,
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    int maxResults = 20,
    double tasteWeight = 0.3,
    double proximityWeight = 0.5,
    double qualityWeight = 0.2,
  }) async {
    // Guard: check if memberIds is empty
    if (memberIds.isEmpty) {
      log("Cannot fetch bubble recommendations: memberIds is empty.");
      _error = "No members in this bubble";
      _recommendedLocations = {};
      notifyListeners();
      return;
    }

    // Store the search parameters for later reference
    final searchCenter = LatLng(latitude, longitude);
    final searchRadius = radiusKm;

    _isLoadingRecommendations = true;
    notifyListeners();

    try {
      log("Fetching bubble recommendations for ${memberIds.length} members");

      // Call bubble recommendations API
      final response = await _recommendationsApi.fetchProximalBubble(
        userIds: memberIds,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        maxResults: maxResults,
        tasteWeight: tasteWeight,
        proximityWeight: proximityWeight,
        qualityWeight: qualityWeight,
      );

      // Extract IDs (preserves ranking!)
      final locationIds = response.recommendations
          .map((rec) => rec.locationId)
          .where((id) => id > 0)
          .toList();

      if (locationIds.isEmpty) {
        log("Bubble recommendations API returned no results");
        _error = "No group recommendations found in this area";
        _recommendedLocations = {};
        notifyListeners();
        return;
      }

      log("Found ${locationIds.length} bubble recommendation IDs");

      // Fetch full location data
      final locations = await _fetchLocationsByIdsInOrder(locationIds);

      // Select which locations should show names
      final tempMap = Map.fromEntries(locations.map((loc) => MapEntry(
          loc, MapMarkerData(id: loc.locationId.toString(), position: const LatLng(0, 0), imageBytes: const []))));
      final selectedForNames = _selectLocationsForNameDisplay(
        tempMap,
        viewportBounds: _currentViewportBounds,
        zoom: _currentZoom,
      );

      // Generate markers with name selection applied
      final markers = await Future.wait(
        locations.map((location) async {
          final shouldShowName = selectedForNames.contains(location.locationId);
          final marker = await location
              .setPreference(LocationPreference.recommended)
              .toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
          return MapEntry(location, marker!);
        }),
      );

      _recommendedLocations = Map.fromEntries(markers);
      _error = null; // Clear any previous errors

      // Update last searched area
      _lastSearchedCenter = searchCenter;
      _lastSearchedRadius = searchRadius;

      log("Fetched ${locations.length} bubble recommendations");

    } catch (e) {
      log('Error fetching bubble recommendations: $e');
      _error = "Failed to load group recommendations: ${e.toString()}";
      _recommendedLocations = {};
    } finally {
      _isLoadingRecommendations = false;
      notifyListeners();
    }
  }

  /// Fetches "Just Decide" recommendations using the Recommendations API
  Future<void> fetchJustDecideRecommendations({
    required double latitude,
    required double longitude,
    required double radiusKm,
    int maxResults = 5,
  }) async {
    // Guard: check if userId is null
    if (_userId == null) {
      log("Cannot fetch just decide recommendations: userId is null.");
      _error = "Please log in to use Just Decide";
      _justDecideLocations = [];
      notifyListeners();
      return;
    }

    try {
      log("Fetching just decide recommendations for user: $_userId");

      // Call recommendations API with specific weights for "just decide"
      final response = await _recommendationsApi.fetchProximal(
        userId: _userId!,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        maxResults: maxResults,
        tasteWeight: 0.3,      // Moderate taste consideration
        proximityWeight: 0.6,  // Prioritize proximity
        qualityWeight: 0.1,    // Some quality consideration
      );

      // Extract IDs (preserves ranking!)
      final locationIds = response.recommendations
          .map((rec) => rec.locationId)
          .where((id) => id > 0)
          .toList();

      if (locationIds.isEmpty) {
        log("Just decide API returned no results");
        _error = "No recommendations found nearby";
        _justDecideLocations = [];
        notifyListeners();
        return;
      }

      log("Found ${locationIds.length} just decide recommendation IDs");

      // Fetch full location data
      final locations = await _fetchLocationsByIdsInOrder(locationIds);

      _justDecideLocations = locations;
      _error = null; // Clear any previous errors
      log("Fetched ${locations.length} just decide recommendations");
      notifyListeners();

    } catch (e) {
      log('Error fetching just decide recommendations: $e');
      _error = "Failed to load recommendations: ${e.toString()}";
      _justDecideLocations = [];
      notifyListeners();
    }
  }

  /// Adds recommended locations (can be merged with fetch or kept separate)
  Future<void> addRecommendedLocations(List<LocationModel> locations) async {
    // Add new locations with placeholder markers
    for (var location in locations) {
      _recommendedLocations[location] =
          MapMarkerData(id: location.locationId.toString(), position: const LatLng(0, 0), imageBytes: const []);
    }

    // Re-apply name selection to all recommended locations
    final selectedForNames = _selectLocationsForNameDisplay(
      _recommendedLocations,
      viewportBounds: _currentViewportBounds,
      zoom: _currentZoom,
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

    // Kick off background image hydration for locations missing images
    final missingImages = locations
        .where((loc) => loc.imageUrl == null || loc.imageUrl!.isEmpty)
        .toList();
    if (missingImages.isNotEmpty) {
      log('[addRecommendedLocations] Hydrating ${missingImages.length} images in background');
      _hydrateImagesInBackground(missingImages);
    }
  }

  /// Search recommendations in the visible map area using proximal API.
  /// Updates the Recommended tab with results from the current map area.
  Future<void> searchThisArea({
    required LatLng center,
    required double radiusKm,
    int maxResults = 20,
    double tasteWeight = 0.2,
    double proximityWeight = 0.6,
    double qualityWeight = 0.2,
    bool includeTasteBreakdown = false,
    List<String>? vibeTagIds,
    List<String>? cuisineTagIds,
  }) async {
    if (_userId == null) {
      _error = "User not logged in";
      notifyListeners();
      return;
    }

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
        vibeTagIds: vibeTagIds,
        cuisineTagIds: cuisineTagIds,
      );

      final locationIds = response.recommendations
          .map((rec) => rec.locationId)
          .where((id) => id > 0)
          .toList();

      final locations = await _fetchLocationsByIdsInOrder(locationIds);

      // Select which locations should show names
      final tempMap = Map.fromEntries(locations.map((loc) => MapEntry(
          loc, MapMarkerData(id: loc.locationId.toString(), position: const LatLng(0, 0), imageBytes: const []))));
      final selectedForNames = _selectLocationsForNameDisplay(
        tempMap,
        viewportBounds: _currentViewportBounds,
      );

      final markers = await Future.wait(
        locations.map((location) async {
          final shouldShowName = selectedForNames.contains(location.locationId);
          final marker = await location
              .setPreference(LocationPreference.recommended)
              .toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
          return marker != null ? MapEntry(location, marker) : null;
        }),
      );

      // Update recommended locations instead of search locations
      _recommendedLocations =
          Map.fromEntries(markers.whereType<MapEntry<LocationModel, MapMarkerData>>());
      _lastSearchedCenter = center;
      _areaChanged = false;
      _error = null;

      // Update current items if on recommended tab, or switch to recommended tab
      await setCurrentListType(LocationListType.recommended);
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
    _savedLocations[location] =
        MapMarkerData(id: location.locationId.toString(), position: const LatLng(0, 0), imageBytes: const []);

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
    bool supabaseSuccess = await _supabaseService.locations
        .saveLocation(location.locationId, savedMethod: 'in-app');

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

    final sw = Stopwatch()..start();
    final uniqueIds = locationIds.toSet().toList();
    final response = await Supabase.instance.client
        .from(SupabaseConstants.tableLocations)
        .select()
        .inFilter(SupabaseConstants.columnLocationId, uniqueIds);

    print('[FetchByIds] Supabase query done (${sw.elapsedMilliseconds}ms) for ${uniqueIds.length} IDs');

    int withImage = 0;
    int withoutImage = 0;
    final Map<int, LocationModel> byId = {};
    for (var item in response as List) {
      final int locationId = item[SupabaseConstants.columnLocationId] as int;
      final imageStored = item[SupabaseConstants.columnImageStored] == true;
      String? locationImage;
      if (imageStored) {
        locationImage = Supabase.instance.client.storage
            .from('location_photos')
            .getPublicUrl('$locationId.jpg');
        withImage++;
      } else {
        withoutImage++;
      }
      byId[locationId] = LocationModel.fromJson(item, locationImage);
    }

    print('[FetchByIds] ${response.length} locations: $withImage with stored image, $withoutImage without (${sw.elapsedMilliseconds}ms)');

    final List<LocationModel> ordered = [];
    for (final id in locationIds) {
      final location = byId[id];
      if (location != null) {
        ordered.add(location);
      } else {
        log('LocationListManager: Missing location data for id $id');
      }
    }
    print('[FetchByIds] Returning ${ordered.length} ordered locations (${sw.elapsedMilliseconds}ms)');
    return ordered;
  }

  /// Updates a location's image URL across all three location maps.
  /// Does NOT call notifyListeners() — caller is responsible for batching.
  void _updateLocationImage(int locationId, String imageUrl) {
    for (final map in [_recommendedLocations, _savedLocations, _searchLocations]) {
      LocationModel? oldKey;
      for (final loc in map.keys) {
        if (loc.locationId == locationId) {
          oldKey = loc;
          break;
        }
      }
      if (oldKey != null) {
        final markerData = map.remove(oldKey)!;
        final updated = oldKey.copyWith(imageUrl: imageUrl, imageStored: true);
        map[updated] = markerData;
      }
    }

    // Also update _justDecideLocations list
    for (int i = 0; i < _justDecideLocations.length; i++) {
      if (_justDecideLocations[i].locationId == locationId) {
        _justDecideLocations[i] = _justDecideLocations[i]
            .copyWith(imageUrl: imageUrl, imageStored: true);
        break;
      }
    }
  }

  /// Background-fetches images for locations with image_stored == false.
  /// Batches notifyListeners() calls every [batchSize] completions.
  void _hydrateImagesInBackground(List<LocationModel> missingLocations) {
    if (missingLocations.isEmpty) return;

    final sw = Stopwatch()..start();
    final total = missingLocations.length;
    print('[ImageHydration] Starting hydration for $total locations');

    int completed = 0;
    const batchSize = 4;

    Future.wait(missingLocations.map((loc) async {
      try {
        final url = await _supabaseService.locations.getLocationImage(
          loc.locationId,
          loc.googlePlaceId ?? '',
          loc.photoReference,
        );
        if (url != null) {
          _updateLocationImage(loc.locationId, url);
          completed++;
          print('[ImageHydration] "${loc.name}" image ready ($completed/$total, ${sw.elapsedMilliseconds}ms)');
          if (completed % batchSize == 0) {
            print('[ImageHydration] Batch done $completed/$total (${sw.elapsedMilliseconds}ms) — notifyListeners()');
            // Refresh currentItems reference before notifying
            _syncCurrentItems();
            notifyListeners();
          }
        } else {
          print('[ImageHydration] "${loc.name}" returned null URL (${sw.elapsedMilliseconds}ms)');
        }
      } catch (e) {
        print('[ImageHydration] FAILED "${loc.name}": $e (${sw.elapsedMilliseconds}ms)');
        log('Background image hydration failed for ${loc.locationId}: $e');
      }
    })).then((_) {
      // Flush remaining updates
      print('[ImageHydration] All done: $completed/$total hydrated in ${sw.elapsedMilliseconds}ms');
      if (completed % batchSize != 0) {
        print('[ImageHydration] Final flush — notifyListeners()');
        _syncCurrentItems();
        notifyListeners();
      }
    });
  }

  /// Re-points _currentItems at the active map after background mutations.
  void _syncCurrentItems() {
    switch (_currentListType) {
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
    final imgCount = _currentItems.keys.where((l) => l.imageUrl != null && l.imageUrl!.isNotEmpty).length;
    print('[SyncItems] $_currentListType: ${_currentItems.length} items ($imgCount with imageUrl)');
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

    final msw = Stopwatch()..start();
    print('[MagicSearch] START query="$trimmedQuery"');

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

      print('[MagicSearch] API response received: status=${response.statusCode} (${msw.elapsedMilliseconds}ms)');
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
      final recommendations =
          decoded['recommendations'] as List<dynamic>? ?? [];
      print('[MagicSearch] ${recommendations.length} recommendations from API (${msw.elapsedMilliseconds}ms)');
      final locationIds = recommendations
          .map((item) => (item as Map<String, dynamic>)['location_id'])
          .where((id) => id != null)
          .map((id) => (id as num).toInt())
          .toList();

      print('[MagicSearch] Fetching ${locationIds.length} locations from Supabase...');
      final locations = await _fetchLocationsByIdsInOrder(locationIds);
      final withImg = locations.where((l) => l.imageUrl != null && l.imageUrl!.isNotEmpty).length;
      final withoutImg = locations.length - withImg;
      print('[MagicSearch] Locations fetched: ${locations.length} total, $withImg with imageUrl, $withoutImg without (${msw.elapsedMilliseconds}ms)');
      _searchLocations = {};

      // Select which locations should show names
      final tempMap = Map.fromEntries(locations.map((loc) => MapEntry(
          loc, MapMarkerData(id: loc.locationId.toString(), position: const LatLng(0, 0), imageBytes: const []))));
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
          Map.fromEntries(markers.whereType<MapEntry<LocationModel, MapMarkerData>>());

      print('[MagicSearch] Markers generated: ${_searchLocations.length} (${msw.elapsedMilliseconds}ms)');
      print('[MagicSearch] Calling setCurrentListType(search) — carousel will populate');
      await setCurrentListType(LocationListType.search);
      print('[MagicSearch] DONE (${msw.elapsedMilliseconds}ms)');
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
      return await _supabaseService.locations
          .isLocationSaved(location.locationId);
    } catch (e) {
      log('Error checking if location is saved: $e');
      return false;
    }
  }

  /// Check if location is saved by current user (sync check against local cache)
  bool isLocationSavedSync(int locationId) {
    return _savedLocations.keys.any((loc) => loc.locationId == locationId);
  }

  /// Unsaves a location from Supabase and removes it from the local saved state
  Future<bool> unsaveLocation(LocationModel location) async {
    if (_userId == null) {
      log("Cannot unsave location: userId is null.");
      return false;
    }

    // Remove from local state immediately for responsive UI
    _savedLocations.remove(location);

    // Update current items if viewing saved locations
    if (_currentListType == LocationListType.saved) {
      _currentItems = Map.from(_savedLocations);
    }

    notifyListeners();

    // Remove from Supabase
    bool success =
        await _supabaseService.locations.unsaveLocation(location.locationId);

    if (success) {
      log("Unsaved location from Supabase: ${location.name}");
    } else {
      log("Failed to unsave location from Supabase: ${location.name}");
      // Optionally: re-add to local state if Supabase call failed
    }

    return success;
  }

  /// Toggle save state for a location (save if not saved, unsave if saved)
  Future<bool> toggleSaveLocation(LocationModel location) async {
    final isSaved = isLocationSavedSync(location.locationId);

    if (isSaved) {
      return await unsaveLocation(location);
    } else {
      await saveLocation(location);
      return true;
    }
  }

  /// Dislike a location - creates a user action "dislike"
  Future<bool> dislikeLocation(LocationModel location) async {
    if (_userId == null) {
      log("Cannot dislike location: userId is null.");
      return false;
    }

    try {
      bool success =
          await _supabaseService.locations.dislikeLocation(location.locationId);

      if (success) {
        log("Disliked location: ${location.name}");

        // Remove from recommended/search lists since user doesn't want to see it
        _recommendedLocations.remove(location);
        _searchLocations.remove(location);

        // Update current items based on current list type
        if (_currentListType == LocationListType.recommended) {
          _currentItems = Map.from(_recommendedLocations);
        } else if (_currentListType == LocationListType.search) {
          _currentItems = Map.from(_searchLocations);
        }

        notifyListeners();
      }

      return success;
    } catch (e) {
      log('Error disliking location: $e');
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

import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:login/utils/geo_types.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/recommendations_api.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/services/location_service.dart';
import 'package:login/services/natural_language_search_service.dart';
import 'package:login/services/proximity_notification_service.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/service.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/utils/marker_clustering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Enum to represent the different types of location lists
enum LocationListType { saved, recommended, search, bubble }

class LocationListManager with ChangeNotifier {
  static const String noRecommendationsInAreaMessage =
      'No recommendations found in this area';

  final GooglePlacesService _googlePlacesService;
  final SupabaseService _supabaseService = SupabaseService();
  final LocationService _locationService = LocationService();
  final ProximityNotificationService _proximityNotificationService =
      ProximityNotificationService();
  final NaturalLanguageSearchService _naturalLanguageSearchService =
      NaturalLanguageSearchService();

  String? _userId;
  MapStateProvider? _mapStateProvider;

  // Device location state is now delegated to LocationService
  double _devicePixelRatio = 1.0; // Default value
  final RecommendationsApi _recommendationsApi = RecommendationsApi();
  CameraPositionData? _cameraPosition;
  LatLng? _lastSearchedCenter;
  double? _lastSearchedRadius; // in km
  bool _areaChanged = false;
  bool _isSearchingArea = false;
  bool _isLoadingRecommendations = false;
  bool _isMagicSearching = false;
  String? _error; // Local error for non-location errors

  // Filter state
  List<String> _vibeTagIds = [];
  List<String> _cuisineTagIds = [];
  List<String> _vibeTagNames = []; // resolved text values for vibe tags
  List<String> _cuisineTagNames = []; // resolved text values for cuisine tags

  // Cached unfiltered locations for client-side filtering (per list type)
  List<LocationModel> _allRecommendedLocations = [];
  List<LocationModel> _allSavedLocations = [];
  List<LocationModel> _allSearchLocations = [];
  List<LocationModel> _allBubbleLocations = [];

  // Viewport-aware name selection state
  LatLngBounds? _currentViewportBounds;
  Set<int>? _lastSelectedIds;
  double? _lastSelectionZoom;
  double _currentZoom = 15.0; // Track current zoom level

  // Flags to prevent duplicate data fetches
  bool _isLoadingSaved = false;
  bool _savedLocationsLoaded = false;
  bool _isSubscribed = false;
  bool _isLoadingPopular = false;
  bool _isLoadingHiddenGems = false;

  LocationListManager(this._googlePlacesService);

  GooglePlacesService get googlePlacesService => _googlePlacesService;

  void attachMapStateProvider(MapStateProvider mapStateProvider) {
    _mapStateProvider = mapStateProvider;
  }

  // Location lists
  Map<LocationModel, MapMarkerData> _savedLocations = {};
  Map<LocationModel, MapMarkerData> _recommendedLocations = {};
  Map<LocationModel, MapMarkerData> _searchLocations = {};
  Map<LocationModel, MapMarkerData> _bubbleLocations = {};

  // Per-collection marker cache. Keyed by collectionId, capped LRU.
  static const int _collectionCacheMaxEntries = 10;
  final Map<String, Map<LocationModel, MapMarkerData>>
      _collectionMarkerCache = {};
  String? _activeCollectionKey;
  Map<LocationModel, MapMarkerData> _currentItems = {};
  List<LocationModel> _justDecideLocations = [];
  List<LocationModel> _popularLocations = [];
  List<LocationModel> _hiddenGemLocations = [];
  LocationListType _currentListType =
      LocationListType.saved; // Default to saved

  // Getters
  Map<LocationModel, MapMarkerData> get savedLocations => _savedLocations;
  List<LocationModel> get popularLocations => _popularLocations;
  List<LocationModel> get hiddenGemLocations => _hiddenGemLocations;
  Map<LocationModel, MapMarkerData> get recommendedLocations =>
      _recommendedLocations;
  Map<LocationModel, MapMarkerData> get searchLocations => _searchLocations;
  Map<LocationModel, MapMarkerData> get bubbleLocations => _bubbleLocations;
  Map<LocationModel, MapMarkerData> get currentItems => _currentItems;
  List<LocationModel> get justDecideLocations => _justDecideLocations;
  LocationListType get currentListType => _currentListType;
  List<String> get vibeTagIds => List.unmodifiable(_vibeTagIds);
  List<String> get cuisineTagIds => List.unmodifiable(_cuisineTagIds);
  bool get hasActiveFilters =>
      _vibeTagIds.isNotEmpty || _cuisineTagIds.isNotEmpty;
  bool get isLoadingSaved => _isLoadingSaved;
  bool get hasLoadedSavedLocations => _savedLocationsLoaded;

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
  bool get isMagicSearching => _isMagicSearching;
  LatLng? get lastSearchedCenter => _lastSearchedCenter;
  double? get lastSearchedRadius => _lastSearchedRadius;

  void _updateLastSearchedArea(LatLng center, double radiusKm) {
    _lastSearchedCenter = center;
    _lastSearchedRadius = radiusKm;
  }

  void _syncRecommendedItemsIfActive() {
    if (_currentListType == LocationListType.recommended) {
      _currentItems = _recommendedLocations;
    }
  }

  void _syncBubbleItemsIfActive() {
    if (_currentListType == LocationListType.bubble) {
      _currentItems = _bubbleLocations;
    }
  }

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
      _bubbleLocations = {};
      _currentItems = {};
      notifyListeners();
    } else {
      unawaited(_proximityNotificationService.initializeForUser(_userId!));

      // Fetch initial data ONCE when user logs in
      fetchSavedLocations();
      fetchPopularLocations();
      fetchHiddenGems();

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
        if (record['action'] == 'save' && record['acked'] == true) {
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
        if (record['action'] == 'save') {
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
      print(
          '[Supabase] Result for location_id=$locationId: ${locationData.toString().substring(0, math.min(200, locationData.toString().length))}');

      // Optionally print image fetch
      print(
          '[Supabase] Fetching image for location_id=$locationId, google_place_id=${locationData['google_place_id']}, photo_reference=${locationData['photo_reference']}');
      final locationImage = await _supabaseService.locations.getLocationImage(
          locationId,
          locationData['google_place_id'],
          locationData['photo_reference']);

      final location = LocationModel.fromJson(locationData, locationImage);

      // Add to saved locations temporarily with a placeholder marker
      _savedLocations[location] = MapMarkerData(
          id: locationId.toString(),
          position: const LatLng(0, 0),
          imageBytes: const []);

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
      await _proximityNotificationService
          .syncSavedLocations(_savedLocations.keys);
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
      await _proximityNotificationService
          .syncSavedLocations(_savedLocations.keys);
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
      final sorted = locations
        ..sort((a, b) {
          final scoreA = a.matchScore ?? 0.0;
          final scoreB = b.matchScore ?? 0.0;
          return scoreB.compareTo(scoreA); // Higher score first
        });
      return sorted.map((loc) => MapEntry(loc, markersMap[loc]!)).toList();
    }

    // Sort with distance as primary key, match score as secondary
    final markersMap = Map.fromEntries(markers);
    final sorted = locations
      ..sort((a, b) {
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
      case LocationListType.bubble:
        _currentItems = _bubbleLocations;
        break;
    }
    print(
        "Set current list type to: $type, item count: ${_currentItems.length}");

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
      print('[fetchSavedLocations] Already in-flight, skipping');
      return;
    }

    // Already completed a successful load — don't re-fetch
    if (_savedLocationsLoaded) {
      print('[fetchSavedLocations] Already loaded (${_savedLocations.length} items), skipping');
      return;
    }

    _isLoadingSaved = true;
    print('[fetchSavedLocations] Starting fetch for user $_userId');
    final stopwatch = Stopwatch()..start();

    try {
      List<LocationModel> supabaseSavedLocations =
          await _supabaseService.locations.getSavedLocations();

      print('[fetchSavedLocations] Got ${supabaseSavedLocations.length} locations in ${stopwatch.elapsedMilliseconds}ms');

      // Always mark as loaded — even if empty (user simply has no saves yet)
      _savedLocationsLoaded = true;

      if (supabaseSavedLocations.isNotEmpty) {
        // First create a temporary map to select which locations should show names
        final tempMap = Map.fromEntries(supabaseSavedLocations.map((loc) =>
            MapEntry(
                loc,
                MapMarkerData(
                    id: loc.locationId.toString(),
                    position: const LatLng(0, 0),
                    imageBytes: const []))));
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
        print('[fetchSavedLocations] Created ${sortedMarkers.length} markers in ${stopwatch.elapsedMilliseconds}ms');
      }

      // If the current type is saved, update currentItems
      if (_currentListType == LocationListType.saved) {
        _currentItems = _savedLocations;
      }
      await _proximityNotificationService
          .syncSavedLocations(_savedLocations.keys);
      notifyListeners();
    } catch (e, st) {
      print('[fetchSavedLocations] ERROR: $e\n$st');
      // Still mark as loaded so we don't retry in an infinite loop
      _savedLocationsLoaded = true;
    } finally {
      stopwatch.stop();
      _isLoadingSaved = false;
    }
  }

  Future<void> fetchPopularLocations({int limit = 5}) async {
    if (_isLoadingPopular) return;
    _isLoadingPopular = true;
    notifyListeners();
    try {
      _popularLocations =
          await _supabaseService.locations.getPopularLocations(limit: limit);
    } finally {
      _isLoadingPopular = false;
      notifyListeners();
    }
  }

  Future<void> focusSingleLocation(LocationModel location) async {
    final markerData = MapMarkerData(
      id: location.locationId.toString(),
      position: LatLng(location.lat ?? 0, location.lng ?? 0),
      imageBytes: const [],
    );
    _searchLocations = {location: markerData};
    await setCurrentListType(LocationListType.search);
  }

  bool hasCachedCollection(String collectionId) =>
      _collectionMarkerCache.containsKey(collectionId);

  /// Renders a collection on the map, using the per-collection marker cache
  /// when available. Falls back to [locationsLoader] only on a cache miss so
  /// callers can skip a Supabase round-trip for previously-viewed collections.
  /// Returns the ordered list of locations actually shown (empty if none).
  Future<List<LocationModel>> showCollectionLocations(
    String collectionId,
    Future<List<LocationModel>> Function() locationsLoader,
  ) async {
    final cached = _collectionMarkerCache.remove(collectionId);
    if (cached != null) {
      _collectionMarkerCache[collectionId] = cached;
      _activeCollectionKey = collectionId;
      final orderedLocations = cached.keys.toList();
      _searchLocations = Map.of(cached);
      _allSearchLocations = orderedLocations;
      _error = null;
      await setCurrentListType(LocationListType.search);
      return orderedLocations;
    }

    final locations = await locationsLoader();
    // A newer collection request superseded this one — discard.
    if (_activeCollectionKey != null &&
        _activeCollectionKey != collectionId &&
        _collectionMarkerCache.containsKey(_activeCollectionKey)) {
      return const [];
    }

    final validLocations = locations
        .where((location) => location.lat != null && location.lng != null)
        .toList();

    if (validLocations.isEmpty) {
      _searchLocations = {};
      _allSearchLocations = [];
      _activeCollectionKey = collectionId;
      await setCurrentListType(LocationListType.search);
      return const [];
    }

    final tempMap = Map.fromEntries(
      validLocations.map(
        (location) => MapEntry(
          location,
          MapMarkerData(
            id: location.locationId.toString(),
            position: LatLng(location.lat!, location.lng!),
            imageBytes: const [],
          ),
        ),
      ),
    );

    final selectedForNames = _selectLocationsForNameDisplay(
      tempMap,
      viewportBounds: _currentViewportBounds,
    );

    final markers = await Future.wait(
      validLocations.map((location) async {
        final marker = await location
            .setPreference(LocationPreference.search)
            .toMarker(
              _devicePixelRatio,
              shouldShowName: selectedForNames.contains(location.locationId),
            );
        return MapEntry(
          location,
          marker ??
              MapMarkerData(
                id: location.locationId.toString(),
                position: LatLng(location.lat!, location.lng!),
                imageBytes: const [],
                title: location.name,
                snippet: location.vicinity ?? '',
              ),
        );
      }),
    );

    final built = Map<LocationModel, MapMarkerData>.fromEntries(markers);

    // LRU evict before insert.
    while (_collectionMarkerCache.length >= _collectionCacheMaxEntries) {
      _collectionMarkerCache.remove(_collectionMarkerCache.keys.first);
    }
    _collectionMarkerCache[collectionId] = built;
    _activeCollectionKey = collectionId;

    _searchLocations = Map.of(built);
    _allSearchLocations = validLocations;
    _error = null;
    await setCurrentListType(LocationListType.search);
    return validLocations;
  }

  void invalidateCollectionCache(String collectionId) {
    _collectionMarkerCache.remove(collectionId);
    if (_activeCollectionKey == collectionId) {
      _activeCollectionKey = null;
    }
  }

  void invalidateAllCollectionCaches() {
    _collectionMarkerCache.clear();
    _activeCollectionKey = null;
  }

  Future<void> showLocationsOnMap(List<LocationModel> locations) async {
    final validLocations = locations
        .where((location) => location.lat != null && location.lng != null)
        .toList();

    if (validLocations.isEmpty) {
      _searchLocations = {};
      await setCurrentListType(LocationListType.search);
      return;
    }

    final tempMap = Map.fromEntries(
      validLocations.map(
        (location) => MapEntry(
          location,
          MapMarkerData(
            id: location.locationId.toString(),
            position: LatLng(location.lat!, location.lng!),
            imageBytes: const [],
          ),
        ),
      ),
    );

    final selectedForNames = _selectLocationsForNameDisplay(
      tempMap,
      viewportBounds: _currentViewportBounds,
    );

    final markers = await Future.wait(
      validLocations.map((location) async {
        final marker = await location
            .setPreference(LocationPreference.search)
            .toMarker(
              _devicePixelRatio,
              shouldShowName: selectedForNames.contains(location.locationId),
            );

        return MapEntry(
          location,
          marker ??
              MapMarkerData(
                id: location.locationId.toString(),
                position: LatLng(location.lat!, location.lng!),
                imageBytes: const [],
                title: location.name,
                snippet: location.vicinity ?? '',
              ),
        );
      }),
    );

    _searchLocations = Map.fromEntries(markers);
    _error = null;
    await setCurrentListType(LocationListType.search);
  }

  Future<void> fetchHiddenGems() async {
    if (_isLoadingHiddenGems) return;
    final position = currentPosition ?? await getCurrentLocation();
    if (position == null) {
      if (kDebugMode) print('[HiddenGems] Aborting — no location available');
      return;
    }
    _isLoadingHiddenGems = true;
    notifyListeners();
    try {
      _hiddenGemLocations = await _supabaseService.locations.getHiddenGems(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } finally {
      _isLoadingHiddenGems = false;
      notifyListeners();
    }
  }

  /// Fetches recommended locations using the Recommendations API
  Future<void> fetchRecommendedLocations({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    int maxResults = 30,
    double qualityWeight = 0.40,
    double vibeWeight = 0.3,
    double dietaryWeight = 0.30,
    double socialWeight = 0.00,
    double collaborativeWeight = 0.00,
    List<String>? vibeTagIds,
    List<String>? cuisines,
  }) async {
    // Guard: check if userId is null
    if (_userId == null) {
      print("Cannot fetch recommendations: userId is null.");
      _error = "Please sign in to see personalized recommendations";
      _recommendedLocations = {};
      notifyListeners();
      return;
    }

    // Store the search parameters for later reference
    final searchCenter = LatLng(latitude, longitude);
    final searchRadius = radiusKm;

    _isLoadingRecommendations = true;
    _error = null;
    notifyListeners();

    try {
      print("📍 [LocationListManager] fetchRecommendedLocations called");
      print("   User ID: $_userId");
      print("   Location: $latitude, $longitude (radius: ${radiusKm}km)");
      print("   Weights — quality: $qualityWeight, vibe: $vibeWeight, dietary: $dietaryWeight, social: $socialWeight, collaborative: $collaborativeWeight");
      print("   Cuisines (${cuisines?.length ?? 0}): ${cuisines ?? '(none)'}");

      // Fetch recommendations from API. Cuisine filtering happens server-side
      // because free-text cuisine columns on location rows don't reliably
      // match; vibe filtering is done client-side against cached recs.
      final response = await _recommendationsApi.fetchProximal(
        userId: _userId!,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        maxResults: maxResults,
        qualityWeight: qualityWeight,
        vibeWeight: vibeWeight,
        dietaryWeight: dietaryWeight,
        socialWeight: socialWeight,
        collaborativeWeight: collaborativeWeight,
        cuisines: (cuisines != null && cuisines.isNotEmpty) ? cuisines : null,
      );

      // Extract IDs (preserves ranking!)
      final locationIds = response.recommendations
          .map((rec) => rec.locationId)
          .where((id) => id > 0)
          .toList();

      final serverFiltered = cuisines != null && cuisines.isNotEmpty;

      if (locationIds.isEmpty) {
        print("Recommendations API returned no results");
        _error = noRecommendationsInAreaMessage;
        // Only clear the unfiltered cache when this wasn't a filtered
        // request — otherwise a strict filter hit with zero results would
        // wipe the pool we'd use to restore when filters are cleared.
        if (!serverFiltered) {
          _allRecommendedLocations = [];
        }
        _recommendedLocations = {};
        _updateLastSearchedArea(searchCenter, searchRadius);
        _syncRecommendedItemsIfActive();
        notifyListeners();
        return;
      }

      print("Found ${locationIds.length} recommended location IDs"
          "${serverFiltered ? ' (server-filtered)' : ''}");

      // Fetch full location data
      final locations = await _fetchLocationsByIdsInOrder(locationIds);

      // Build markers for all locations
      await _buildMarkersAndSync(locations);
      _error = null;

      if (serverFiltered) {
        // Server already filtered + re-ranked. Don't overwrite the
        // unfiltered cache, and don't re-run client-side filtering on
        // top of the server's output.
        _syncRecommendedItemsIfActive();
      } else {
        // Cache the full unfiltered list for local restoration later.
        _allRecommendedLocations = locations;
        // Apply active filters if any (legacy client-side path — only
        // runs when no tag filters were supplied to this call).
        await _applyFiltersToList(LocationListType.recommended);
      }

      // Update last searched area
      _updateLastSearchedArea(searchCenter, searchRadius);

      print("Fetched ${locations.length} recommendations"
          "${serverFiltered ? ' (filtered)' : ''}");
    } catch (e) {
      print('Error fetching personalized recommendations: $e');
      _error = "Failed to load recommendations: ${e.toString()}";
      _recommendedLocations = {};
    } finally {
      _isLoadingRecommendations = false;
      notifyListeners();
    }
  }

  /// Returns the cached unfiltered list and current marker map for the given list type.
  List<LocationModel> _allLocationsFor(LocationListType type) {
    return switch (type) {
      LocationListType.recommended => _allRecommendedLocations,
      LocationListType.saved => _allSavedLocations,
      LocationListType.search => _allSearchLocations,
      LocationListType.bubble => _allBubbleLocations,
    };
  }

  Map<LocationModel, MapMarkerData> _markerMapFor(LocationListType type) {
    return switch (type) {
      LocationListType.recommended => _recommendedLocations,
      LocationListType.saved => _savedLocations,
      LocationListType.search => _searchLocations,
      LocationListType.bubble => _bubbleLocations,
    };
  }

  void _setAllLocationsFor(LocationListType type, List<LocationModel> list) {
    switch (type) {
      case LocationListType.recommended:
        _allRecommendedLocations = list;
      case LocationListType.saved:
        _allSavedLocations = list;
      case LocationListType.search:
        _allSearchLocations = list;
      case LocationListType.bubble:
        _allBubbleLocations = list;
    }
  }

  void _setMarkerMapFor(
      LocationListType type, Map<LocationModel, MapMarkerData> map) {
    switch (type) {
      case LocationListType.recommended:
        _recommendedLocations = map;
      case LocationListType.saved:
        _savedLocations = map;
      case LocationListType.search:
        _searchLocations = map;
      case LocationListType.bubble:
        _bubbleLocations = map;
    }
  }

  /// Filters the current list type, removing non-matching locations.
  /// Caches the unfiltered list so it can be restored when filters are cleared.
  Future<void> _applyFiltersToList(LocationListType type) async {
    final markerMap = _markerMapFor(type);
    var allCached = _allLocationsFor(type);

    // If no active filters, restore the full list from cache
    if (!hasActiveFilters) {
      print("🔍 [Filter] type=$type — no active filters, restoring "
          "${allCached.length} cached locations");
      if (allCached.isNotEmpty) {
        await _buildMarkersForType(type, allCached);
      }
      _syncCurrentItems();
      notifyListeners();
      _mapStateProvider?.animateToCarouselItem(0);
      return;
    }

    // Cache the full unfiltered list before first filter
    if (allCached.isEmpty && markerMap.isNotEmpty) {
      allCached = markerMap.keys.toList();
      _setAllLocationsFor(type, allCached);
    }

    final source = allCached.isNotEmpty ? allCached : markerMap.keys.toList();

    // Build vibe lookup keys from tag names (snake_case to match vibeTagOrder)
    final vibeKeys = _vibeTagNames
        .map((name) => name.toLowerCase().replaceAll(' ', '_'))
        .toList();
    final cuisineLower =
        _cuisineTagNames.map((name) => name.toLowerCase()).toList();

    print("🔍 [Filter] ────────────────────────────────────");
    print("🔍 [Filter] Applying filters to $type");
    print("🔍 [Filter]   source pool: ${source.length} locations");
    print("🔍 [Filter]   vibe tags (${vibeKeys.length}): "
        "${vibeKeys.isEmpty ? '(none)' : vibeKeys.join(', ')}");
    print("🔍 [Filter]   cuisine tags (${cuisineLower.length}): "
        "${cuisineLower.isEmpty ? '(none)' : cuisineLower.join(', ')}");

    // Score every location and record per-criterion match counts for
    // observability — lets us tell at a glance whether the cuisine filter
    // or the vibe filter is the one eliminating results.
    int cuisineMatches = 0;
    int vibeMatches = 0;
    int missingVibeVector = 0;
    final scored = <MapEntry<LocationModel, double>>[];

    for (final loc in source) {
      double score = 0.0;

      if (cuisineLower.isNotEmpty) {
        final cuisine = loc.cuisine?.toLowerCase() ?? '';
        final cuisinePrimary = loc.cuisinePrimary?.toLowerCase() ?? '';
        final matches = cuisineLower.any((tag) =>
            cuisine == tag ||
            cuisinePrimary == tag ||
            cuisine.contains(tag) ||
            cuisinePrimary.contains(tag));
        if (matches) {
          cuisineMatches++;
          score += 1.0;
        }
      }

      if (vibeKeys.isNotEmpty) {
        final vibe = loc.vibe;
        if (vibe == null) {
          missingVibeVector++;
        } else {
          double vibeSum = 0.0;
          for (final tag in vibeKeys) {
            vibeSum += vibe.scoreFor(tag);
          }
          if (vibeSum > 0) {
            vibeMatches++;
            score += vibeSum;
          }
        }
      }

      if (score > 0) {
        scored.add(MapEntry(loc, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    final filtered = scored.map((e) => e.key).toList();

    print("🔍 [Filter]   cuisine hits: $cuisineMatches/${source.length}");
    print("🔍 [Filter]   vibe hits:    $vibeMatches/${source.length}"
        "${missingVibeVector > 0 ? ' (missing vibe vector: $missingVibeVector)' : ''}");
    print("🔍 [Filter]   ✅ passing:   ${filtered.length}/${source.length}");

    if (scored.isNotEmpty) {
      final topPreview = scored
          .take(5)
          .map((e) => '${e.key.name} (${e.value.toStringAsFixed(2)})')
          .join(', ');
      print("🔍 [Filter]   top 5: $topPreview");

      final minScore = scored.last.value;
      final maxScore = scored.first.value;
      final avg = scored.fold<double>(0, (a, e) => a + e.value) / scored.length;
      print("🔍 [Filter]   score range: "
          "${minScore.toStringAsFixed(2)}..${maxScore.toStringAsFixed(2)} "
          "(avg ${avg.toStringAsFixed(2)})");
    } else {
      // Log a few rejections so the caller can see *why* everything was
      // filtered out — usually a typo in a tag or cuisine mismatch.
      final sampleRejected = source
          .take(5)
          .map((loc) => "${loc.name} "
              "[cuisine=${loc.cuisine ?? '-'}, "
              "primary=${loc.cuisinePrimary ?? '-'}, "
              "vibe=${loc.vibe != null ? 'present' : 'null'}]")
          .join('; ');
      print("🔍 [Filter]   ⚠️ no matches — sample of source: $sampleRejected");
    }
    print("🔍 [Filter] ────────────────────────────────────");

    await _buildMarkersForType(type, filtered);
    _syncCurrentItems();
    notifyListeners();

    _mapStateProvider?.animateToCarouselItem(0);
  }

  /// Builds markers for a list of locations and assigns to the correct list type.
  Future<void> _buildMarkersForType(
      LocationListType type, List<LocationModel> locations) async {
    final tempMap = Map.fromEntries(locations.map((loc) => MapEntry(
        loc,
        MapMarkerData(
            id: loc.locationId.toString(),
            position: const LatLng(0, 0),
            imageBytes: const []))));
    final selectedForNames = _selectLocationsForNameDisplay(
      tempMap,
      viewportBounds: _currentViewportBounds,
      zoom: _currentZoom,
    );

    final preference = switch (type) {
      LocationListType.recommended => LocationPreference.recommended,
      LocationListType.saved => LocationPreference.saved,
      LocationListType.search => LocationPreference.search,
      LocationListType.bubble => LocationPreference.bubble,
    };

    final markers = await Future.wait(
      locations.map((location) async {
        final shouldShowName = selectedForNames.contains(location.locationId);
        final marker = await location
            .setPreference(preference)
            .toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
        return MapEntry(location, marker!);
      }),
    );

    _setMarkerMapFor(type, Map.fromEntries(markers));
  }

  /// Syncs _currentItems to match the current list type's marker map.
  void _syncCurrentItems() {
    _currentItems = _markerMapFor(_currentListType);
  }

  /// Builds markers for a list of locations and sets _recommendedLocations + syncs currentItems.
  Future<void> _buildMarkersAndSync(List<LocationModel> locations) async {
    final tempMap = Map.fromEntries(locations.map((loc) => MapEntry(
        loc,
        MapMarkerData(
            id: loc.locationId.toString(),
            position: const LatLng(0, 0),
            imageBytes: const []))));
    final selectedForNames = _selectLocationsForNameDisplay(
      tempMap,
      viewportBounds: _currentViewportBounds,
      zoom: _currentZoom,
    );

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
    _syncRecommendedItemsIfActive();
  }

  /// Updates filter tags and applies client-side filtering on cached recommendations.
  /// [vibeTagNames] and [cuisineTagNames] are the human-readable tag text values
  /// (e.g. "Cafe", "Italian") resolved by the caller from the tag objects.
  Future<void> applyFilters({
    required List<String> vibeTagIds,
    required List<String> cuisineTagIds,
    List<String> vibeTagNames = const [],
    List<String> cuisineTagNames = const [],
  }) async {
    // Update filter state
    _vibeTagIds = List.from(vibeTagIds);
    _cuisineTagIds = List.from(cuisineTagIds);
    _vibeTagNames = List.from(vibeTagNames);
    _cuisineTagNames = List.from(cuisineTagNames);

    print("🎯 [LocationListManager] applyFilters called");
    print("   Vibe tag IDs (${_vibeTagIds.length}): $_vibeTagIds");
    print("   Vibe tag names: $_vibeTagNames");
    print("   Cuisine tag IDs (${_cuisineTagIds.length}): $_cuisineTagIds");
    print("   Cuisine tag names: $_cuisineTagNames");
    print("   Current list type: $_currentListType");

    final hasCuisine = _cuisineTagIds.isNotEmpty;

    // YOU tab → always filter the saved list locally. Filters here are
    // strictly a client-side narrowing of what the user has already saved;
    // there is no server fetch.
    if (_currentListType == LocationListType.saved) {
      print("   📍 YOU: filtering saved list locally");
      await _applyFiltersToList(LocationListType.saved);
      notifyListeners();
      return;
    }

    // EXPLORE tab + cuisine filters → server-side recommendations fetch.
    // Cuisine matching can't be done reliably on the client (free-text
    // mismatch), so we let the API filter by cuisine_tag_ids and re-rank.
    // Vibe filters tag along when present.
    if (_currentListType == LocationListType.recommended && hasCuisine) {
      print("   🌐 EXPLORE: server-side fetch (cuisine filter active)");
      final currentLocation = currentPosition ?? await getCurrentLocation();
      if (currentLocation == null) {
        print("   ⚠️ No location yet — can't refetch with filters");
        notifyListeners();
        return;
      }
      await fetchRecommendedLocations(
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        vibeTagIds: _vibeTagIds,
        cuisines: _cuisineTagNames
            .map((c) => c.toLowerCase())
            .toList(),
      );
      notifyListeners();
      return;
    }

    // EXPLORE tab + vibe-only filters (or no filters at all) → filter the
    // already-cached recommended list locally. No API call needed for vibes.
    final markerMap = _markerMapFor(_currentListType);
    if (markerMap.isNotEmpty || _allRecommendedLocations.isNotEmpty) {
      print("   ✅ EXPLORE: local filter on cached recs "
          "(${_allRecommendedLocations.length} cached)");
      await _applyFiltersToList(_currentListType);
    } else if (_currentListType == LocationListType.recommended) {
      // No cached recs yet — do an unfiltered fetch so there's something
      // to local-filter against next time.
      print("   ⚠️ No recommendations loaded - fetching fresh (unfiltered)");
      final currentLocation = currentPosition ?? await getCurrentLocation();
      if (currentLocation != null) {
        await fetchRecommendedLocations(
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
        );
      }
    } else {
      print("   ⏭️ No locations loaded for $_currentListType - filters saved for when data arrives");
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
    String? bubbleId,
    required double latitude,
    required double longitude,
    double radiusKm = 2.0,
    int maxResults = 20,
    double vibeWeight = 0.34,
    double dietaryWeight = 0.33,
    double qualityWeight = 0.33,
    bool includeIndividualScores = false,
    bool includeVibeBreakdown = false,
    Map<String, dynamic>? filters,
  }) async {
    // Guard: check if memberIds is empty
    if (memberIds.isEmpty) {
      print("Cannot fetch bubble recommendations: memberIds is empty.");
      _error = "No members in this bubble";
      _bubbleLocations = {};
      _syncBubbleItemsIfActive();
      notifyListeners();
      return;
    }

    // Store the search parameters for later reference
    final searchCenter = LatLng(latitude, longitude);
    final searchRadius = radiusKm;

    _isLoadingRecommendations = true;
    notifyListeners();

    try {
      print("Fetching bubble recommendations for ${memberIds.length} members");

      // Call bubble recommendations API
      final response = await _recommendationsApi.fetchProximalBubble(
        userIds: memberIds,
        bubbleId: bubbleId,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        maxResults: maxResults,
        vibeWeight: vibeWeight,
        dietaryWeight: dietaryWeight,
        qualityWeight: qualityWeight,
        includeIndividualScores: includeIndividualScores,
        includeVibeBreakdown: includeVibeBreakdown,
        filters: filters,
      );

      // Extract IDs (preserves ranking!)
      final locationIds = response.recommendations
          .map((rec) => rec.locationId)
          .where((id) => id > 0)
          .toList();

      if (locationIds.isEmpty) {
        print("Bubble recommendations API returned no results");
        _error = noRecommendationsInAreaMessage;
        _bubbleLocations = {};
        _updateLastSearchedArea(searchCenter, searchRadius);
        _areaChanged = false;
        _syncBubbleItemsIfActive();
        notifyListeners();
        return;
      }

      print("Found ${locationIds.length} bubble recommendation IDs");

      // Fetch full location data
      final locations = await _fetchLocationsByIdsInOrder(locationIds);

      // Select which locations should show names
      final tempMap = Map.fromEntries(locations.map((loc) => MapEntry(
          loc,
          MapMarkerData(
              id: loc.locationId.toString(),
              position: const LatLng(0, 0),
              imageBytes: const []))));
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
              .setPreference(LocationPreference.bubble)
              .toMarker(_devicePixelRatio, shouldShowName: shouldShowName);
          return MapEntry(location, marker!);
        }),
      );

      _bubbleLocations = Map.fromEntries(markers);
      _syncBubbleItemsIfActive();
      _error = null; // Clear any previous errors

      // Update last searched area
      _updateLastSearchedArea(searchCenter, searchRadius);
      _areaChanged = false;

      print("Fetched ${locations.length} bubble recommendations");
    } catch (e) {
      print('Error fetching bubble recommendations: $e');
      _error = "Failed to load group recommendations: ${e.toString()}";
      _bubbleLocations = {};
      _syncBubbleItemsIfActive();
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
      print("Cannot fetch just decide recommendations: userId is null.");
      _error = "Please print in to use Just Decide";
      _justDecideLocations = [];
      notifyListeners();
      return;
    }

    try {
      print("Fetching just decide recommendations for user: $_userId");

      // Call recommendations API with default weights for "just decide"
      final response = await _recommendationsApi.fetchProximal(
        userId: _userId!,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        maxResults: maxResults,
      );

      // Extract IDs (preserves ranking!)
      final locationIds = response.recommendations
          .map((rec) => rec.locationId)
          .where((id) => id > 0)
          .toList();

      if (locationIds.isEmpty) {
        print("Just decide API returned no results");
        _error = "No recommendations found nearby";
        _justDecideLocations = [];
        notifyListeners();
        return;
      }

      print("Found ${locationIds.length} just decide recommendation IDs");

      // Fetch full location data
      final locations = await _fetchLocationsByIdsInOrder(locationIds);

      _justDecideLocations = locations;
      _error = null; // Clear any previous errors
      print("Fetched ${locations.length} just decide recommendations");
      notifyListeners();
    } catch (e) {
      print('Error fetching just decide recommendations: $e');
      _error = "Failed to load recommendations: ${e.toString()}";
      _justDecideLocations = [];
      notifyListeners();
    }
  }

  /// Adds recommended locations (can be merged with fetch or kept separate)
  Future<void> addRecommendedLocations(List<LocationModel> locations) async {
    // Add new locations with placeholder markers
    for (var location in locations) {
      _recommendedLocations[location] = MapMarkerData(
          id: location.locationId.toString(),
          position: const LatLng(0, 0),
          imageBytes: const []);
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
  }

  /// Search recommendations in the visible map area using proximal API.
  /// Updates the Recommended tab with results from the current map area.
  Future<bool> searchThisArea({
    required LatLng center,
    required double radiusKm,
    int maxResults = 100,
    double qualityWeight = 0.30,
    double vibeWeight = 0.25,
    double dietaryWeight = 0.10,
    double socialWeight = 0.20,
    double collaborativeWeight = 0.15,
    bool includeTasteBreakdown = false,
  }) async {
    if (_userId == null) {
      _error = "User not logged in";
      notifyListeners();
      return false;
    }

    _isSearchingArea = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _recommendationsApi.fetchProximal(
        userId: _userId!,
        latitude: center.latitude,
        longitude: center.longitude,
        radiusKm: radiusKm,
        maxResults: maxResults,
        qualityWeight: qualityWeight,
        vibeWeight: vibeWeight,
        dietaryWeight: dietaryWeight,
        socialWeight: socialWeight,
        collaborativeWeight: collaborativeWeight,
        includeTasteBreakdown: includeTasteBreakdown,
      );

      final locationIds = response.recommendations
          .map((rec) => rec.locationId)
          .where((id) => id > 0)
          .toList();

      if (locationIds.isEmpty) {
        _allRecommendedLocations = [];
        _recommendedLocations = {};
        _updateLastSearchedArea(center, radiusKm);
        _areaChanged = false;
        _error = noRecommendationsInAreaMessage;
        await setCurrentListType(LocationListType.recommended);
        return true;
      }

      final locations = await _fetchLocationsByIdsInOrder(locationIds);

      // Cache the full unfiltered list
      _allRecommendedLocations = locations;

      await _buildMarkersAndSync(locations);
      await _applyFiltersToList(LocationListType.recommended);
      _updateLastSearchedArea(center, radiusKm);
      _areaChanged = false;
      _error = null;

      // Update current items if on recommended tab, or switch to recommended tab
      await setCurrentListType(LocationListType.recommended);
      return true;
    } catch (e) {
      print('LocationListManager: Search this area failed: $e');
      _error = "Search failed: ${e.toString()}";
      notifyListeners();
      return false;
    } finally {
      _isSearchingArea = false;
      notifyListeners();
    }
  }

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
        print("Removed saved location: ${location.name}");
      }
    }

    if (_currentListType == LocationListType.recommended) {
      if (_recommendedLocations.containsKey(location)) {
        _recommendedLocations.remove(location);
        removed = true;
        print("Removed recommended location: ${location.name}");
      }
    }

    if (_currentListType == LocationListType.search) {
      if (_searchLocations.containsKey(location)) {
        _searchLocations.remove(location);
        removed = true;
        print("Removed search location: ${location.name}");
      }
    }

    if (_currentListType == LocationListType.bubble) {
      if (_bubbleLocations.containsKey(location)) {
        _bubbleLocations.remove(location);
        removed = true;
        print("Removed bubble location: ${location.name}");
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
      print("Cannot save location: userId is null.");
      return; // Or handle appropriately, maybe prompt login
    }

    final savedLocation = location.setPreference(LocationPreference.saved);

    _savedLocations.removeWhere(
      (existing, _) => existing.locationId == savedLocation.locationId,
    );

    // Add location with placeholder marker immediately for responsive UI.
    _savedLocations[savedLocation] = MapMarkerData(
      id: savedLocation.locationId.toString(),
      position: savedLocation.position ?? const LatLng(0, 0),
      imageBytes: const [],
      title: savedLocation.name,
      snippet: savedLocation.vicinity ?? '',
    );

    // If the user is currently viewing saved locations, update the view now.
    if (_currentListType == LocationListType.saved) {
      _currentItems = Map.from(_savedLocations);
    }

    // Remove from recommended/search right away so the UI reflects the save.
    _recommendedLocations.removeWhere(
      (existing, _) => existing.locationId == savedLocation.locationId,
    );
    _searchLocations.removeWhere(
      (existing, _) => existing.locationId == savedLocation.locationId,
    );
    _bubbleLocations.removeWhere(
      (existing, _) => existing.locationId == savedLocation.locationId,
    );
    _mapStateProvider?.bounceRecentlySaved(savedLocation.locationId);
    invalidateAllCollectionCaches();
    notifyListeners();

    unawaited(_finalizeSavedLocation(savedLocation));
  }

  Future<void> _finalizeSavedLocation(LocationModel location) async {
    if (!_savedLocations.keys
        .any((saved) => saved.locationId == location.locationId)) {
      return;
    }

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
        return MapEntry(
          loc,
          marker ??
              MapMarkerData(
                id: loc.locationId.toString(),
                position: loc.position ?? const LatLng(0, 0),
                imageBytes: const [],
                title: loc.name,
                snippet: loc.vicinity ?? '',
              ),
        );
      }),
    );
    _savedLocations = Map.fromEntries(updatedMarkers);
    if (_currentListType == LocationListType.saved) {
      _currentItems = Map.from(_savedLocations);
    }
    notifyListeners();

    // If location has no vibe data, call locations/add to populate it
    if ((location.vibeVector == null || location.vibeVector!.isEmpty) &&
        location.googlePlaceId != null &&
        location.googlePlaceId!.isNotEmpty) {
      try {
        await _recommendationsApi.addLocationByGooglePlaceId(
          googlePlaceId: location.googlePlaceId!,
        );
        print("Populated vibe data for location: ${location.name}");
      } catch (e) {
        print("Failed to populate vibe data for ${location.name}: $e");
      }
    }

    final supabaseSuccess = await _supabaseService.locations
        .saveLocation(location.locationId, savedMethod: 'in-app');
    if (supabaseSuccess) {
      print("Saved location to Supabase: ${location.name}");
    } else {
      print("Failed to save location to Supabase: ${location.name}");
    }
  }

  Future<List<LocationModel>> _fetchLocationsByIdsInOrder(
      List<int> locationIds) async {
    if (locationIds.isEmpty) return [];

    final uniqueIds = locationIds.toSet().toList();
    final response = await Supabase.instance.client
        .from(SupabaseConstants.tableLocations)
        .select()
        .inFilter(SupabaseConstants.columnLocationId, uniqueIds);

    // Non-blocking: constructs public URLs immediately, background-downloads any missing images
    final locations = await _supabaseService.locations
        .processLocationsWithImages(response as List);

    // Restore the ranking order from the recommendations API
    final Map<int, LocationModel> byId = {
      for (final loc in locations) loc.locationId: loc,
    };
    final List<LocationModel> ordered = [];
    for (final id in locationIds) {
      final location = byId[id];
      if (location != null) {
        ordered.add(location);
      } else {
        print('LocationListManager: Missing location data for id $id');
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
    if (_userId == null) {
      print("Cannot perform magic search: userId is null.");
      _error = "User not logged in";
      notifyListeners();
      return;
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      print("LocationListManager: Magic search query is empty.");
      return;
    }

    // Prefer the camera position so results centre on the visible map area,
    // falling back to the device GPS location when the map hasn't been moved.
    final currentLocation =
        _cameraPosition?.target ?? await getCurrentLocation();
    if (currentLocation == null) {
      print("LocationListManager: Cannot perform magic search without location.");
      _error = "Location permission required for search";
      _searchLocations = {};
      await setCurrentListType(LocationListType.search);
      return;
    }

    final locationSource =
        _cameraPosition?.target != null ? 'camera' : 'gps';
    print(
      "LocationListManager: Magic search request — "
      "query: '$trimmedQuery', source: $locationSource, "
      "lat: ${currentLocation.latitude}, lng: ${currentLocation.longitude}, "
      "radiusKm: $radiusKm, maxResults: $maxResults, "
      "includeTasteBreakdown: $includeTasteBreakdown, userId: $_userId",
    );

    _isMagicSearching = true;
    _searchLocations = {};
    await setCurrentListType(LocationListType.search);

    try {
      final locations = await _naturalLanguageSearchService.search(
        userId: _userId!,
        query: trimmedQuery,
        currentLocation: currentLocation,
        radiusKm: radiusKm,
        maxResults: maxResults,
        includeTasteBreakdown: includeTasteBreakdown,
      );
      _error = null;
      print(
        "LocationListManager: Loaded ${locations.length} locations from Supabase for magic search",
      );
      _searchLocations = {};

      // Select which locations should show names
      final tempMap = Map.fromEntries(locations.map((loc) => MapEntry(
          loc,
          MapMarkerData(
              id: loc.locationId.toString(),
              position: const LatLng(0, 0),
              imageBytes: const []))));
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
      _searchLocations = Map.fromEntries(
          markers.whereType<MapEntry<LocationModel, MapMarkerData>>());

      print(
        "LocationListManager: Magic search returned ${_searchLocations.length} results for '$trimmedQuery'.",
      );
      _isMagicSearching = false;
      await setCurrentListType(LocationListType.search);
    } catch (e) {
      print('LocationListManager: Error during magic search: $e');
      _error = "Search error: ${e.toString()}";
      _isMagicSearching = false;
      _searchLocations = {};
      await setCurrentListType(LocationListType.search);
    }
  }

  /// Check if location is saved by current user
  Future<bool> isLocationSaved(LocationModel location) async {
    try {
      return await _supabaseService.locations
          .isLocationSaved(location.locationId);
    } catch (e) {
      print('Error checking if location is saved: $e');
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
      print("Cannot unsave location: userId is null.");
      return false;
    }

    // Remove from local state immediately for responsive UI
    _savedLocations.removeWhere(
      (existing, _) => existing.locationId == location.locationId,
    );

    // Update current items if viewing saved locations
    if (_currentListType == LocationListType.saved) {
      _currentItems = Map.from(_savedLocations);
    }

    invalidateAllCollectionCaches();
    notifyListeners();

    // Remove from Supabase
    bool success =
        await _supabaseService.locations.unsaveLocation(location.locationId);

    if (success) {
      print("Unsaved location from Supabase: ${location.name}");
    } else {
      print("Failed to unsave location from Supabase: ${location.name}");
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
      print("Cannot dislike location: userId is null.");
      return false;
    }

    try {
      bool success =
          await _supabaseService.locations.dislikeLocation(location.locationId);

      if (success) {
        print("Disliked location: ${location.name}");

        // Remove from recommended/search lists since user doesn't want to see it
        _recommendedLocations.remove(location);
        _searchLocations.remove(location);
        _bubbleLocations.remove(location);

        // Update current items based on current list type
        if (_currentListType == LocationListType.recommended) {
          _currentItems = Map.from(_recommendedLocations);
        } else if (_currentListType == LocationListType.search) {
          _currentItems = Map.from(_searchLocations);
        } else if (_currentListType == LocationListType.bubble) {
          _currentItems = Map.from(_bubbleLocations);
        }

        notifyListeners();
      }

      return success;
    } catch (e) {
      print('Error disliking location: $e');
      return false;
    }
  }

  /// Acknowledge if a location is right or not
  Future<void> acknowledgeLocation(int locationId, bool value) async {
    try {
      await _supabaseService.locations.acknowledgeLocation(locationId, value);
      print("Acknowledged location: ${locationId}, value: $value");
    } catch (e) {
      print('Error acknowledging location: $e');
    }
  }

  /// Clears all data (used for sign out)
  void clearData() {
    _userId = null;
    _savedLocations.clear();
    _recommendedLocations.clear();
    _searchLocations.clear();
    _bubbleLocations.clear();
    _currentItems.clear();
    _currentListType = LocationListType.saved;
    _proximityNotificationService.clear();
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
    _proximityNotificationService.clear();
    print('Unsubscribing from realtime updates on dispose');
    _supabaseService.locations.unsubscribeFromUserLocationActions();
    _isSubscribed = false;
    print("LocationListManager: Disposed.");
    super.dispose();
  }

  /// Force refresh saved locations (use sparingly, realtime handles most updates)
  Future<void> refreshSavedLocations() async {
    print('Force refreshing saved locations');
    _savedLocationsLoaded = false;
    await fetchSavedLocations();
  }
}

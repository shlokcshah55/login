import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

// Enum to represent the different types of location lists
enum LocationListType { saved, recommended, search }

class LocationListManager with ChangeNotifier {
  final GooglePlacesService _googlePlacesService;
  final SupabaseService _supabaseService = SupabaseService();
  static const String _magicSearchEndpoint =
      'https://pinit-recommendations-api-630839392908.europe-west2.run.app/locations/magic-search';

  String? _userId;

  // Device location tracking state
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;
  bool _permissionGranted = false;
  String? _error;
  
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

  // Device location getters
  LatLng? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get permissionGranted => _permissionGranted;
  String? get error => _error;

  // Method to update the user ID when the user logs in
  void setUserId(String? userId) {
    // Prevent redundant calls if userId hasn't changed
    if (_userId == userId) {
      log('UserId unchanged, skipping initialization');
      return;
    }
    
    _userId = userId;
    
    // Unsubscribe from previous realtime channel
    log('Unsubscribing from realtime updates');
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
      log('Already subscribed to realtime updates, skipping');
      return;
    }
    
    log('Subscribing to realtime updates for user: $_userId');
    
    _supabaseService.locations.subscribeToUserLocationActions(
      _userId!,
      (payload) {
        log('Realtime event received: ${payload.eventType}');
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
          log('Location saved realtime: ${record['location_id']}');
          await _addLocationToSaved(record['location_id']);
        }
        break;
        
      case PostgresChangeEvent.delete:
        // Location unsaved
        log('Location unsaved realtime: ${oldRecord['location_id']}');
        await _removeLocationFromSaved(oldRecord['location_id']);
        break;
        
      case PostgresChangeEvent.update:
        // Handle acked status change
        if (record['action'] == 'saved') {
          if (record['acked'] == true && oldRecord['acked'] == false) {
            log('Location acknowledged: ${record['location_id']}');
            await _addLocationToSaved(record['location_id']);
          } else if (record['acked'] == false && oldRecord['acked'] == true) {
            log('Location unacknowledged: ${record['location_id']}');
            await _removeLocationFromSaved(record['location_id']);
          }
        }
        break;
        
      default:
        // Ignore all events (includes 'select')
        log('Ignoring realtime event: ${payload.eventType}');
        break;
    }
  }
  
  /// Add a location to saved list by fetching its details
  Future<void> _addLocationToSaved(int locationId) async {
    try {
      // Check if location already exists in saved locations
      final alreadyExists = _savedLocations.keys.any((loc) => loc.locationId == locationId);
      if (alreadyExists) {
        log('Location $locationId already in saved list, skipping');
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
      final marker = location.setPreference(LocationPreference.saved).toMarker();
      
      if (marker != null) {
        _savedLocations[location] = marker;
        
        // Update current items if viewing saved locations
        if (_currentListType == LocationListType.saved) {
          _currentItems = _savedLocations;
        }
        
        notifyListeners();
        log('Added location to saved: ${location.name}');
      }
    } catch (e) {
      log('Error adding location realtime: $e');
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
      log('Removed location from saved: ${locationToRemove.name}');
    } catch (e) {
      log('Error removing location realtime: $e');
    }
  }

  /// Sets the currently displayed locations in the carousel
  void setCurrentListType(LocationListType type) {
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
    log("Set current list type to: $type, item count: ${_currentItems.length}");
    notifyListeners();
  }

  /// Fetches saved locations from Supabase and falls back to Firebase if needed
  Future<void> fetchSavedLocations() async {
    if (_userId == null) {
      log("Cannot fetch saved locations: userId is null.");
      return;
    }

    // Prevent duplicate fetches
    if (_isLoadingSaved) {
      log("Already loading saved locations, skipping duplicate request");
      return;
    }
    
    if (_savedLocationsLoaded && _savedLocations.isNotEmpty) {
      log("Saved locations already loaded (${_savedLocations.length} items), skipping fetch");
      return;
    }

    _isLoadingSaved = true;
    
    try {
      List<LocationModel> supabaseSavedLocations =
          await _supabaseService.locations.getSavedLocations();

      if (supabaseSavedLocations.isNotEmpty) {
        // Use Supabase data if available
        _savedLocations = {
          for (var location in supabaseSavedLocations)
            location:
                location.setPreference(LocationPreference.saved).toMarker()!
        };
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
        // Use Supabase data if available
        _recommendedLocations = {
          for (var location in nearbyLocations)
            location: location
                .setPreference(LocationPreference.recommended)
                .toMarker()!
        };
        log("Fetched ${nearbyLocations.length} nearby locations from Supabase.");
      } else {
        // Fall back to Google Places API during migration
        var recommendations = await _googlePlacesService.fetchNearbyPlaces(
          latitude: latitude,
          longitude: longitude,
          placeType: "restaurant",
        );
        _recommendedLocations = {
          for (var location in recommendations)
            location: location
                .setPreference(LocationPreference.recommended)
                .toMarker()!
        };
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
        _recommendedLocations = {
          for (var location in recommendations)
            location: location
                .setPreference(LocationPreference.recommended)
                .toMarker()!
        };
        log("Fallback: Fetched ${recommendations.length} recommended locations from Google Places.");
        notifyListeners();
      } catch (fallbackError) {
        log('Error in Google Places fallback: $fallbackError');
      }
    }
  }

  /// Adds recommended locations (can be merged with fetch or kept separate)
  void addRecommendedLocations(List<LocationModel> locations) {
    final Map<LocationModel, Marker> newLocations = {
      for (var location in locations)
        location:
            location.setPreference(LocationPreference.recommended).toMarker()!
    };
    _recommendedLocations.addEntries(newLocations.entries);
    if (_currentListType == LocationListType.recommended) {
      _currentItems = _recommendedLocations;
    }
    notifyListeners();
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

    // Add location to local state
    _savedLocations.putIfAbsent(location,
        () => location.setPreference(LocationPreference.saved).toMarker()!);

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

    // Always fetch fresh location for magic search to ensure accuracy
    log("LocationListManager: Fetching current location for magic search...");
    final currentLocation = await getCurrentLocation();
    if (currentLocation == null) {
      log("LocationListManager: Cannot perform magic search without location.");
      _error = "Unable to get your location. Please check location permissions.";
      _searchLocations = {};
      setCurrentListType(LocationListType.search);
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
        setCurrentListType(LocationListType.search);
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
      for (final location in locations) {
        final marker =
            location.setPreference(LocationPreference.search).toMarker();
        if (marker != null) {
          _searchLocations[location] = marker;
        }
      }

      log(
        "LocationListManager: Magic search returned ${_searchLocations.length} results for '$trimmedQuery'.",
      );
      setCurrentListType(LocationListType.search);
    } catch (e) {
      log('LocationListManager: Error during magic search: $e');
      _error = "Search error: ${e.toString()}";
      _searchLocations = {};
      setCurrentListType(LocationListType.search);
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
    stopLocationUpdates(); // Stop tracking when clearing data
    log("LocationListManager: Cleared all location data");
    notifyListeners();
  }

  /// Checks and requests location permission
  Future<bool> checkAndRequestPermission() async {
    PermissionStatus status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }

    _permissionGranted = status.isGranted;
    if (!_permissionGranted) {
      _error = "Location permission denied.";
      log("LocationListManager: Location permission denied.");
    } else {
      _error = null; // Clear previous error if permission granted now
      log("LocationListManager: Location permission granted.");
    }
    notifyListeners(); // Notify about permission status change
    return _permissionGranted;
  }

  /// Starts tracking the user's live location updates
  Future<void> startLocationUpdates() async {
    if (_isTracking) {
      log("LocationListManager: Already tracking location.");
      return; // Already tracking
    }
    if (!_permissionGranted) {
       log("LocationListManager: Requesting permission before starting tracking.");
       bool granted = await checkAndRequestPermission();
       if (!granted) {
         log("LocationListManager: Cannot start tracking, permission denied.");
         return; // Don't start if permission denied
       }
    }

    _positionStreamSubscription?.cancel(); // Cancel any previous stream
    try {
      _positionStreamSubscription = getPositionStream().listen(
        (Position position) {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isTracking = true; // Ensure tracking state is true
           _error = null; // Clear error on successful update
          // log("LocationListManager: Location update: $_currentPosition"); // Can be noisy
          notifyListeners(); // Notify UI about the location change
        },
        onError: (error) {
          _error = "Location stream error: $error";
          _isTracking = false; // Stop tracking on error
          log("LocationListManager: Error in location stream: $error");
          notifyListeners();
        },
        onDone: () {
          _isTracking = false; // Stream closed
          log("LocationListManager: Location stream closed.");
          notifyListeners();
        },
      );
      _isTracking = true; // Mark as tracking immediately
      _error = null;
      log("LocationListManager: Started location tracking.");
      notifyListeners(); // Notify that tracking has started
    } catch (e) {
       _error = "Failed to start location stream: $e";
       _isTracking = false;
       log("LocationListManager: Error starting location stream: $e");
       notifyListeners();
    }
  }

  /// Stops live location tracking
  void stopLocationUpdates() {
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
      _isTracking = false;
      log("LocationListManager: Stopped location tracking.");
      notifyListeners(); // Notify that tracking has stopped
    }
  }

  /// Gets a stream of position updates
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Updates when user moves 10 meters
      ),
    );
  }

  /// Gets the current location with permission handling (fetches once)
  Future<LatLng?> getCurrentLocation() async {
    if (!_permissionGranted) {
      log("LocationListManager: Cannot get current location, permission not granted.");
      await checkAndRequestPermission(); // Try asking again
      if (!_permissionGranted) {
        log("LocationListManager: Permission still denied after request");
        return null; // Still no permission
      }
    }

    try {
      // Get the current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final newPosition = LatLng(position.latitude, position.longitude);
      _currentPosition = newPosition;
      _error = null;
      log("LocationListManager: Fetched current location: $_currentPosition");
      notifyListeners();
      return newPosition;
    } catch (e) {
      _error = "Failed to get current location: $e";
      log("LocationListManager: Error getting current location: $e");
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    stopLocationUpdates(); // Ensure stream is cancelled
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

import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/supabase/service.dart';
import 'package:permission_handler/permission_handler.dart';

// Enum to represent the different types of location lists
enum LocationListType { saved, recommended, search }

class LocationListManager with ChangeNotifier {
  final GooglePlacesService _googlePlacesService;
  final SupabaseService _supabaseService = SupabaseService();

  String? _userId;

  // Device location tracking state
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;
  bool _permissionGranted = false;
  String? _error;

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
    _userId = userId;
    // Potentially clear locations if user logs out (userId is null)
    if (_userId == null) {
      _savedLocations = {};
      _recommendedLocations = {};
      _searchLocations = {};
      _currentItems = {};
      notifyListeners();
    } else {
      // Fetch initial data if needed, e.g., saved locations
      fetchSavedLocations();
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
        print(
            "Fetched ${supabaseSavedLocations.length} saved locations from Supabase.");
      }

      // If the current type is saved, update currentItems
      if (_currentListType == LocationListType.saved) {
        _currentItems = _savedLocations;
      }
      notifyListeners();
    } catch (e) {
      log('Error fetching saved locations: $e');
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

  /// Handles the magic search feature - could be enhanced with Supabase PostgreSQL full-text search
  Future<void> magicSearch(String query) async {
    if (_userId == null) {
      log("Cannot perform magic search: userId is null.");
      return;
    }

    // Use Google Places API text search instead of external endpoint
    log("LocationListManager: Starting magic search for query: '$query'");
    
    try {
      // Use the improved search method from GooglePlacesService
      var searchModels = await _googlePlacesService.searchPlaces(query: query);
      
      _searchLocations = {
        for (var location in searchModels)
          location: location.setPreference(LocationPreference.search).toMarker()!
      };
      
      log("LocationListManager: Magic search returned ${searchModels.length} results for '$query'.");
      setCurrentListType(LocationListType.search); // Automatically switch view to search results
    } catch (e) {
      log('LocationListManager: Error during magic search: $e');
      _searchLocations = {}; // Clear previous search results on error
      // Still update UI to show empty results
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

  /// Get saved locations since last time the app was opened
  Future<List<LocationModel>> getSavedLocationsSinceLastOpened() async {
    try {
      return await _supabaseService.locations.getSavedLocationsSinceLastOpened();
    } catch (e) {
      log('Error fetching saved locations since last opened: $e');
      return [];
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
      if (!_permissionGranted) return null; // Still no permission
    }

    try {
      // Get the current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = LatLng(position.latitude, position.longitude);
      _error = null;
      log("LocationListManager: Fetched current location: $_currentPosition");
      notifyListeners();
      return _currentPosition;
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
    log("LocationListManager: Disposed.");
    super.dispose();
  }
}

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/supabase_flutter/models/location_model.dart';
import 'package:login/services/firebase_service.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/supabase_flutter/repositories/location_repository.dart';

// Enum to represent the different types of location lists
enum LocationListType { saved, recommended, search }

class LocationListManager with ChangeNotifier {
  // Keep Firebase service for backward compatibility
  final FirebaseService _firebaseService;
  final GooglePlacesService _googlePlacesService;

  // Add Supabase repository
  final LocationRepository _locationRepository = LocationRepository();

  String? _userId; // Needed for saving/fetching user-specific data

  LocationListManager(this._firebaseService, this._googlePlacesService);

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
      // Try Supabase first
      List<LocationModel> supabaseSavedLocations =
          await _locationRepository.getSavedLocations();

      if (supabaseSavedLocations.isNotEmpty) {
        // Use Supabase data if available
        _savedLocations = {
          for (var location in supabaseSavedLocations)
            location:
                location.setPreference(LocationPreference.saved).toMarker()
        };
        log("Fetched ${supabaseSavedLocations.length} saved locations from Supabase.");
      } else {
        // Fall back to Firebase during migration
        // List<LocationModel> firebaseSavedLocations =
        //     await _firebaseService.getSavedLocations();
        // _savedLocations = {
        //   for (var location in firebaseSavedLocations)
        //     location:
        //         location.setPreference(LocationPreference.saved).toMarker()
        // };
        // log("Fetched ${firebaseSavedLocations.length} saved locations from Firebase.");
      }

      // If the current type is saved, update currentItems
      if (_currentListType == LocationListType.saved) {
        _currentItems = _savedLocations;
      }
      notifyListeners();
    } catch (e) {
      log('Error fetching saved locations: $e');
      // Attempt to fetch from Firebase as a fallback
      try {
        // List<LocationModel> firebaseSavedLocations =
        //     await _firebaseService.getSavedLocations();
        // _savedLocations = {
        //   for (var location in firebaseSavedLocations)
        //     location:
        //         location.setPreference(LocationPreference.saved).toMarker()
        // };
        // if (_currentListType == LocationListType.saved) {
        //   _currentItems = _savedLocations;
        // }
        // notifyListeners();
        // log("Fallback: Fetched ${firebaseSavedLocations.length} saved locations from Firebase.");
      } catch (fallbackError) {
        log('Error in Firebase fallback: $fallbackError');
      }
    }
  }

  /// Fetches recommended locations from Supabase and falls back to Google Places API
  Future<void> fetchRecommendedLocations(
      {required double latitude, required double longitude}) async {
    try {
      // Try getting nearby locations from Supabase first
      List<LocationModel> nearbyLocations =
          await _locationRepository.getLocationsNearby(
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
                .toMarker()
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
                .toMarker()
        };
        print(
            "Fetched ${recommendations.length} recommended locations from Google Places.");
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
                .toMarker()
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
            location.setPreference(LocationPreference.recommended).toMarker()
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
        bool supabaseSuccess =
            await _locationRepository.unsaveLocation(locationId);

        if (!supabaseSuccess) {
          // Fall back to Firebase
          _firebaseService.removeSavedLocation(locationId.toString());
        }

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
        () => location.setPreference(LocationPreference.saved).toMarker());

    // Try to save in Supabase first
    try {
      bool supabaseSuccess = await _locationRepository
          .saveLocation(location.locationId, savedMethod: 'in-app');

      if (supabaseSuccess) {
        log("Saved location to Supabase: ${location.name}");
      } else {
        // Fall back to Firebase if Supabase fails
        _firebaseService.storeLocation(location);
        log("Saved location to Firebase: ${location.name}");
      }
    } catch (e) {
      // Fall back to Firebase if Supabase throws an error
      _firebaseService.storeLocation(location);
      log("Exception with Supabase, saved to Firebase: ${location.name}");
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

    // TODO: Implement Supabase full-text search for locations
    // This would use the Supabase PostgreSQL full-text search capabilities
    // For now, we'll continue to use the existing search service

    final url =
        'https://search-places-endpoint-lqmy33nkaa-nw.a.run.app?query=$query';
    try {
      var searchModels = await _googlePlacesService.handleMagicSearchQuery(url);
      _searchLocations = {
        for (var location in searchModels)
          location: location.setPreference(LocationPreference.search).toMarker()
      };
      log("Magic search returned ${searchModels.length} results for '$query'.");
      setCurrentListType(LocationListType
          .search); // Automatically switch view to search results
    } catch (e) {
      log('Error during magic search: $e');
      _searchLocations = {}; // Clear previous search results on error
      // Optionally notify the user of the error
      setCurrentListType(
          LocationListType.search); // Still update UI to show empty results
    }
    // No need for notifyListeners() here as setCurrentListType calls it
  }

  /// Adds a new location to Supabase
  Future<LocationModel?> addNewLocation(LocationModel location) async {
    try {
      // Add location to Supabase
      LocationModel? addedLocation =
          await _locationRepository.addLocation(location);
      if (addedLocation != null) {
        log("Added new location to Supabase: ${location.name}");

        // Also save it for the current user
        await saveLocation(addedLocation);

        return addedLocation;
      } else {
        // If Supabase addition fails, fall back to Firebase
        _firebaseService.storeLocation(location);
        log("Added new location to Firebase: ${location.name}");
        return location;
      }
    } catch (e) {
      log('Error adding new location: $e');
      return null;
    }
  }

  /// Check if location is saved by current user
  Future<bool> isLocationSaved(LocationModel location) async {
    try {
      return await _locationRepository.isLocationSaved(location.locationId);
    } catch (e) {
      log('Error checking if location is saved: $e');
      return false;
    }
  }
}

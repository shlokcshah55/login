import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/location_model.dart';
import 'package:login/services/firebase_service.dart';
import 'package:login/services/google_place_service.dart';

// Enum to represent the different types of location lists
enum LocationListType { saved, recommended, search }

class LocationListManager with ChangeNotifier {
  final FirebaseService _firebaseService;
  final GooglePlacesService _googlePlacesService;
  String? _userId; // Needed for saving/fetching user-specific data

  LocationListManager(this._firebaseService, this._googlePlacesService);

  // Location lists
  Map<LocationModel, Marker> _savedLocations = {};
  Map<LocationModel, Marker> _recommendedLocations = {};
  Map<LocationModel, Marker> _searchLocations = {};
  Map<LocationModel, Marker> _currentItems = {};
  LocationListType _currentListType = LocationListType.saved; // Default to saved

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

  /// Fetches saved locations from Firebase
  Future<void> fetchSavedLocations() async {
    if (_userId == null) {
      log("Cannot fetch saved locations: userId is null.");
      return;
    }
    try {
      List<LocationModel> savedLocModels = await _firebaseService.getSavedLocations(); // Assumes getSavedLocations uses the logged-in user context internally
      _savedLocations = {
        for (var location in savedLocModels) location: location.toMarker()
      };
      log("Fetched ${savedLocModels.length} saved locations.");
      // If the current type is saved, update currentItems
      if (_currentListType == LocationListType.saved) {
        _currentItems = _savedLocations;
      }
      notifyListeners();
    } catch (e) {
      log('Error fetching saved locations: $e');
      // Handle error appropriately
    }
  }

   /// Fetches recommended locations (example implementation)
  Future<void> fetchRecommendedLocations({required double latitude, required double longitude}) async {
     try {
        var recommendations = await _googlePlacesService.fetchNearbyPlaces(
          latitude: latitude, // Example coordinates
          longitude: longitude,
          placeType: "restaurant",
        );
        _recommendedLocations = {
          for (var location in recommendations) location: location.toMarker()
        };
         log("Fetched ${recommendations.length} recommended locations.");
        // Optionally set as current list
        // setCurrentListType(LocationListType.recommended);
        notifyListeners();
     } catch (e) {
        log('Error fetching recommended locations: $e');
     }
  }


  /// Adds recommended locations (can be merged with fetch or kept separate)
  void addRecommendedLocations(List<LocationModel> locations) {
    final Map<LocationModel, Marker> newLocations = {
      for (var location in locations) location: location.toMarker()
    };
    _recommendedLocations.addEntries(newLocations.entries);
     if (_currentListType == LocationListType.recommended) {
        _currentItems = _recommendedLocations;
      }
    notifyListeners();
  }

  /// Removes a location from the appropriate list and Firebase if saved
  void removeLocation(LocationModel location) {
     bool removed = false;
    // Determine which list it *might* be in based on its preference,
    // but also check the current list type for UI consistency.
    if (_currentListType == LocationListType.saved || location.preference == LocationPreference.saved) {
       if (_savedLocations.containsKey(location)) {
         _savedLocations.remove(location);
         _firebaseService.removeSavedLocation(location.id); // Assumes uses logged-in user context
         removed = true;
         log("Removed saved location: ${location.name}");
       }
    }
    if (_currentListType == LocationListType.recommended || location.preference == LocationPreference.recommended) {
       if (_recommendedLocations.containsKey(location)) {
         _recommendedLocations.remove(location);
         removed = true;
          log("Removed recommended location: ${location.name}");
       }
    }
     if (_currentListType == LocationListType.search || location.preference == LocationPreference.search) {
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

  /// Saves a location to Firebase and adds it to the local saved state
  void saveLocation(LocationModel location) {
    if (_userId == null) {
      log("Cannot save location: userId is null.");
      return; // Or handle appropriately, maybe prompt login
    }
    // Ensure preference is set correctly before saving
    location.preference = LocationPreference.saved;
    _firebaseService.storeLocation(location); // Assumes uses logged-in user context
    _savedLocations.putIfAbsent(location, () => location.toMarker());
    log("Saved location: ${location.name}");

    // If the user is currently viewing saved locations, update the view
    if (_currentListType == LocationListType.saved) {
      _currentItems = _savedLocations;
    }
    // Optionally remove from recommended/search if it was there
     _recommendedLocations.remove(location);
     _searchLocations.remove(location);

    notifyListeners();
  }

  /// Handles the magic search feature
  Future<void> magicSearch(String query) async {
     if (_userId == null) {
      log("Cannot perform magic search: userId is null.");
      return;
    }
    // TODO: Update endpoint URL if necessary
    final url = 'https://search-places-endpoint-lqmy33nkaa-nw.a.run.app?query=$query';
    try {
      var searchModels = await _googlePlacesService.handleMagicSearchQuery(url);
      _searchLocations = {
        for (var location in searchModels) location: location.toMarker()
      };
      log("Magic search returned ${searchModels.length} results for '$query'.");
      setCurrentListType(LocationListType.search); // Automatically switch view to search results
    } catch (e) {
       log('Error during magic search: $e');
       _searchLocations = {}; // Clear previous search results on error
       // Optionally notify the user of the error
       setCurrentListType(LocationListType.search); // Still update UI to show empty results
    }
    // No need for notifyListeners() here as setCurrentListType calls it
  }
}

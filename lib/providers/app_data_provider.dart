import 'dart:async';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:login/models/location_model.dart';
import 'package:login/services/firebase_service.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/services/location_service.dart';

class AppStateProvider with ChangeNotifier {
  late String userId;
  late Map<String, dynamic> _userData;
  final Completer<GoogleMapController> _completeController = Completer();
  late GoogleMapController _mapController;
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStream;
  final LocationService _locationService = LocationService();

  // Carousel items
  Map<LocationModel, Marker> currentItems = {};
  Map<LocationModel, Marker> _savedLocations = {};
  Map<LocationModel, Marker> _recommendedLocations = {};
  Map<LocationModel, Marker> _searchLocations = {}; // TODO: Magic search results

  // Firebase service instance
  final FirebaseService firebaseService = FirebaseService();
  final GooglePlacesService googlePlacesService = GooglePlacesService();

  // Getters
  Future<GoogleMapController> get controllerFuture => _completeController.future;
  GoogleMapController get mapController => _mapController;
  LatLng? get currentPosition => _currentPosition;
  Map<LocationModel, Marker> get savedLocations => _savedLocations;
  Map<LocationModel, Marker> get recommendedLocations => _recommendedLocations;
  Map<String, dynamic> get userData => _userData;
  Set<Polyline> polylines = {};
  /// Sets the currently displayed locations in the carousel
  void setCurrentItems(String preference) {
    if (preference == 'saved') {
      currentItems = _savedLocations;
    } else if (preference == 'recommended') {
      currentItems = _recommendedLocations;
    }
    notifyListeners();
  }

  /// Fetches user data from Firebase and populates saved locations
  Future<void> fetchUserData() async {
    
    try {
      final Map<String, dynamic>? maybeUserData = await firebaseService.getUser(userId);
      if (maybeUserData != null) {
        _userData = maybeUserData;
        print("fetchUserData: $_userData");
        List<LocationModel> savedLocModels = await firebaseService.getSavedLocations();
        _savedLocations = {
          for (var location in savedLocModels) location: location.toMarker()
        };
        for (var location in _savedLocations.keys) {
          print("fetchUserData: ${location.name}");
        }
        currentItems = _savedLocations;
      
        notifyListeners();
      } else {
        log('No user data found for ID: $userId');
        await FirebaseAuth.instance.signOut();
        throw Exception('No user data found for $userId');
      }
    } catch (e) {
      log('Error fetching user data: $e');
      await FirebaseAuth.instance.signOut();
    }
  }

  /// Assigns the Google Map controller
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    if (!_completeController.isCompleted) {
      _completeController.complete(controller);
    }
    notifyListeners();
  }

  /// Updates the user's current position and moves the map camera
  Future<void> updateCurrentPosition(LatLng position) async {
    _currentPosition = position;
    await _completeController.future;
    _mapController.animateCamera(CameraUpdate.newLatLng(position));
    notifyListeners();
  }

  /// Starts tracking the user's live location
  void startLocationUpdates() {
    _positionStream = _locationService.getPositionStream().listen((Position position) {
      _currentPosition = LatLng(position.latitude, position.longitude);
      notifyListeners(); // Notify UI about the location change
    });
  }

  /// Stops live location tracking
  void stopLocationUpdates() {
    _positionStream?.cancel();
  }

  /// Adds recommended locations to the map
  void addRecommendedLocations(List<LocationModel> locations) {
    final Map<LocationModel, Marker> newLocations = {
      for (var location in locations) location: location.toMarker()
    };
    _recommendedLocations.addEntries(newLocations.entries);
    notifyListeners();
  }

  /// Removes a location from saved/recommended lists
  void removeLocation(LocationModel location) {
    currentItems.remove(location);
    if (location.preference == LocationPreference.saved) {
      _savedLocations.remove(location);
      firebaseService.removeSavedLocation(location.id);
    } else if (location.preference == LocationPreference.recommended) {
      _recommendedLocations.remove(location);
    } else if (location.preference == LocationPreference.search) {
      _searchLocations.remove(location);
    }
    notifyListeners();
  }

  /// Saves a location to Firebase and the local state
  void saveLocation(LocationModel location) {
    if (location.preference == LocationPreference.saved) {
      _savedLocations.putIfAbsent(location, () => location.toMarker());
    } else if (location.preference == LocationPreference.recommended || location.preference == LocationPreference.search) {
      location.preference = LocationPreference.saved;
      firebaseService.storeLocation(location);
    }
    notifyListeners();
  }

  /// Cleans up resources to prevent memory leaks
  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  void setPolyline(Polyline polyline) {
    polylines.clear();
    polylines.add(polyline);
    notifyListeners();
  }

  void removePolyline() {
    polylines.clear();
    notifyListeners();
  }

  Future<void> focusOnUserLocation() async {
  if (_currentPosition != null && _mapController != null) {
    _mapController.animateCamera(
      CameraUpdate.newLatLngZoom(_currentPosition!, 15), // Zoom level 15 for user focus
    );
    log("Camera focused on user location: $_currentPosition");
  } else {
    log("User location is not available");
  }
}

  /// Handles the magic search feature 
  void magicSearch(String query) async {
    final url = 'https://search-places-endpoint-lqmy33nkaa-nw.a.run.app?query=$query';
    var searchModels = await googlePlacesService.handleMagicSearchQuery(url) ;
    _searchLocations = {
      for (var location in searchModels) location: location.toMarker()
    };
    currentItems = _searchLocations;
    notifyListeners();
  }

}

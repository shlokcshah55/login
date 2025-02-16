import 'dart:async';
import 'dart:developer';


import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/location_model.dart';
import 'package:login/services/firebase_service.dart';
import 'package:login/services/google_place_service.dart';

class AppStateProvider with ChangeNotifier {
  late String userId;
  late Map<String, dynamic> _userData;
  final Completer<GoogleMapController> _completeController = Completer();
  late GoogleMapController _mapController;
  LatLng? _currentPosition;

  // carousel items
  Map<LocationModel, Marker> currentItems = {};
  Map<LocationModel, Marker> _savedLocations = {};
  Map<LocationModel, Marker> _recommendedLocations = {};
  Map<LocationModel, Marker> _searchLocations = {};  // TODO: Magic search results

  // Carousel data
  final FirebaseService firebaseService = FirebaseService();
  final GooglePlacesService googlePlacesService = GooglePlacesService();

  Future<GoogleMapController> get controllerFuture => _completeController.future;
  GoogleMapController get mapController => _mapController;
  LatLng? get currentPosition => _currentPosition;
  Map<LocationModel, Marker> get savedLocations => _savedLocations;
  Map<LocationModel, Marker> get recommendedLocations => _recommendedLocations;
  Map<String, dynamic> get userData => _userData;

  void setCurrentItems(String preference) {
    if (preference == 'saved') {
      currentItems = _savedLocations;
    } else if (preference == 'recommended') {
      currentItems = _recommendedLocations;
    }
    notifyListeners();
  }

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
      } 
      else {
        // Sign out - invalid user and return to login screen
        log('No user data found for ID: $userId');
        await FirebaseAuth.instance.signOut();
        throw Exception('No user data found for $userId');
      }
    } catch (e) {
      log('Error fetching user data: $e');
      await FirebaseAuth.instance.signOut();
    }
  }

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    if (!_completeController.isCompleted) {
      _completeController.complete(controller);
    }
    notifyListeners(); 
  }

  Future<void> updateCurrentPosition(LatLng position) async {
    _currentPosition = position;
    await _completeController.future;
    _mapController.animateCamera(CameraUpdate.newLatLng(position));
    notifyListeners();
  }

  void addRecommendedLocations(List<LocationModel> locations) {
    final Map<LocationModel, Marker> newLocations = {
      for (var location in locations) location: location.toMarker()
    };
    _recommendedLocations.addEntries(newLocations.entries);
    notifyListeners();
  }

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

  void saveLocation(LocationModel location) {
    if (location.preference == LocationPreference.saved) {
      _savedLocations.putIfAbsent(location, () => location.toMarker());
    } else if (location.preference == LocationPreference.recommended || location.preference == LocationPreference.search) {
      location.preference = LocationPreference.saved;
      firebaseService.storeLocation(location);
    }
    notifyListeners();
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

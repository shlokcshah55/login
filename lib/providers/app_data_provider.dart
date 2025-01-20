import 'dart:async';
import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/location_model.dart';
import 'package:login/services/firebase_service.dart';

class AppStateProvider with ChangeNotifier {
  late String userId;
  late Map<String, dynamic> _userData;
  final Completer<GoogleMapController> _completeController = Completer();
  late GoogleMapController _mapController;
  LatLng? _currentPosition;
  List<LocationModel> _savedLocations = [];
  List<LocationModel> _recommendedLocations = [];

  // Map data
  Set<Marker> _markers = {};

  // Carousel data

  final FirebaseService firebaseService = FirebaseService();

  Future<GoogleMapController> get controllerFuture => _completeController.future;
  
  GoogleMapController get mapController => _mapController;
  LatLng? get currentPosition => _currentPosition;
  Set<Marker> get markers => _markers;
  List<LocationModel> get savedLocations => _savedLocations;
  List<LocationModel> get recommendedLocations => _recommendedLocations;
  Map<String, dynamic> get userData => _userData;

  Future<void> fetchUserData() async {
    try {
      final Map<String, dynamic>? maybeUserData = await firebaseService.getUser(userId);
      if (maybeUserData != null) {
        _userData = maybeUserData;
        _savedLocations = await firebaseService.getSavedLocations();
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

  void addMarker(LocationModel marker) {
    _markers.add(marker.toMarker());
    notifyListeners();
  }

  void addRecommendedLocations(List<LocationModel> locations) {
    _recommendedLocations.addAll(locations);
    notifyListeners();
  }

  void removeLocation(LocationModel location) {
    if (location.preference == LocationPreference.saved) {
      _savedLocations.remove(location);
      firebaseService.removeSavedLocation(location.id);
    } else if (location.preference == LocationPreference.recommended) {
      _recommendedLocations.remove(location);
    }
    log("AppStateProvider: Removing marker with id: ${location.id}, markers: $_markers");
    markers.removeWhere((marker) => marker.markerId.value == location.id);
    notifyListeners();
  }

  void saveLocation(LocationModel location) {
    if (location.preference == LocationPreference.saved) {
      _savedLocations.add(location);
    } else if (location.preference == LocationPreference.recommended) {
      firebaseService.storeLocation(location);
    }
    notifyListeners();
  }
}

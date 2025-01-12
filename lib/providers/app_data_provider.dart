import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/location_model.dart';
import 'package:login/services/firebase_service.dart';

class AppStateProvider with ChangeNotifier {
  late GoogleMapController _mapController;
  LatLng? _currentPosition;
  List<LocationModel> _savedLocations = [];
  List<LocationModel> _recommendedLocaitons = [];

  // Map data
  Set<Marker> _markers = {};

  // Carousel data

  final FirebaseService firebaseService = FirebaseService();

  GoogleMapController get mapController => _mapController;
  LatLng? get currentPosition => _currentPosition;
  Set<Marker> get markers => _markers;
  List<LocationModel> get savedLocations => _savedLocations;
  List<LocationModel> get recommendedLocations => _recommendedLocaitons;


  void setMapController(GoogleMapController controller) {
      _mapController = controller;
      notifyListeners(); // Notify listeners if necessary (e.g., UI reacts to changes)
    }

  void updateCurrentPosition(LatLng position) {
    _currentPosition = position;
    mapController?.animateCamera(CameraUpdate.newLatLng(position));
    notifyListeners();
  }

  void addMarker(LocationModel marker) {
    _markers.add(marker.toMarker());
    notifyListeners();
  }

  void addRecommendedLocations(List<LocationModel> locations) {
    _recommendedLocaitons.addAll(locations);
    notifyListeners();
  }

  void removeLocation(LocationModel location) {
    if (location.preference == locationPreference.saved) {
      _savedLocations.remove(location);

      //TODO: Remove from Firestore

    } else if (location.preference == locationPreference.recommended) {
      _recommendedLocaitons.remove(location);
    }
    markers.removeWhere((marker) => marker.markerId.value == location.id);
    notifyListeners();
  }

  void saveLocation(LocationModel location) {
    if (location.preference == locationPreference.saved) {
      _savedLocations.add(location);
    } else if (location.preference == locationPreference.recommended) {
      FirebaseService().storeLocation(location);
    }
    notifyListeners();
  }
}

import 'dart:developer';

import 'package:flutter/foundation.dart';

import '../models/location_model.dart';
import '../services/supabase_location_service.dart';

/// Repository for location-related operations
class LocationRepository {
  final SupabaseLocationService _locationService = SupabaseLocationService();

  /// Get all locations
  Future<List<LocationModel>> getAllLocations() async {
    try {
      return await _locationService.getAllLocations();
    } catch (e) {
      if (kDebugMode) {
        print('Error in LocationRepository.getAllLocations: $e');
      }
      return [];
    }
  }

  /// Get locations near coordinates
  Future<List<LocationModel>> getLocationsNearby(
      double latitude, double longitude,
      {double radiusMeters = 5000}) async {
    try {
      print('Brev are we here?');
      return await _locationService.getLocationsNearby(
        latitude,
        longitude,
        radiusMeters: radiusMeters,
      );
    } catch (e) {
      print('Are we bloody catching it');
      if (kDebugMode) {
        print('Error in LocationRepository.getLocationsNearby: $e');
      }
      print('Brev are we here?');
      return [];
    }
  }

  /// Get a location by ID
  Future<LocationModel?> getLocationById(int locationId) async {
    try {
      return await _locationService.getLocationById(locationId);
    } catch (e) {
      if (kDebugMode) {
        print('Error in LocationRepository.getLocationById: $e');
      }
      return null;
    }
  }

  /// Save a location for current user
  Future<bool> saveLocation(LocationModel location,
      {String? savedMethod}) async {
    try {
      return await _locationService.saveLocation(location,
          savedMethod: savedMethod);
    } catch (e) {
      if (kDebugMode) {
        print('Error in LocationRepository.saveLocation: $e');
      }
      return false;
    }
  }

  /// Unsave a location for current user
  Future<bool> unsaveLocation(int locationId) async {
    try {
      return await _locationService.unsaveLocation(locationId);
    } catch (e) {
      if (kDebugMode) {
        print('Error in LocationRepository.unsaveLocation: $e');
      }
      return false;
    }
  }

  /// Like a location for current user
  Future<bool> likeLocation(int locationId) async {
    try {
      return await _locationService.likeLocation(locationId);
    } catch (e) {
      if (kDebugMode) {
        print('Error in LocationRepository.likeLocation: $e');
      }
      return false;
    }
  }

  /// Unlike a location for current user
  Future<bool> unlikeLocation(int locationId) async {
    try {
      return await _locationService.unlikeLocation(locationId);
    } catch (e) {
      if (kDebugMode) {
        print('Error in LocationRepository.unlikeLocation: $e');
      }
      return false;
    }
  }

  /// Check if a location is liked by current user
  Future<bool> isLocationLiked(int locationId) async {
    try {
      return await _locationService.isLocationLiked(locationId);
    } catch (e) {
      if (kDebugMode) {
        print('Error in LocationRepository.isLocationLiked: $e');
      }
      return false;
    }
  }

  /// Check if location is saved by current user
  Future<bool> isLocationSaved(int locationId) async {
    try {
      return await _locationService.isLocationSaved(locationId);
    } catch (e) {
      if (kDebugMode) {
        print('Error in LocationRepository.isLocationSaved: $e');
      }
      return false;
    }
  }

  /// Get saved locations for current user
  Future<List<LocationModel>> getSavedLocations() async {
    try {
      return await _locationService.getSavedLocations();
    } catch (e) {
      if (kDebugMode) {
        print('Error in LocationRepository.getSavedLocations: $e');
      }
      return [];
    }
  }

  /// Get popular locations
  Future<List<LocationModel>> getPopularLocations({int limit = 10}) async {
    try {
      return await _locationService.getPopularLocations(limit: limit);
    } catch (e) {
      if (kDebugMode) {
        print('Error in LocationRepository.getPopularLocations: $e');
      }
      return [];
    }
  }

  /// Add a new location
  Future<LocationModel?> addLocation(LocationModel location) async {
    try {
      return await _locationService.addLocation(location);
    } catch (e) {
      if (kDebugMode) {
        print('Error in LocationRepository.addLocation: $e');
      }
      return null;
    }
  }

  /// Get saved locations since last opened
  Future<List<LocationModel>> getSavedLocationsSinceLastOpened() async {
    try {
      return await _locationService.getSavedLocationsSinceLastOpened();
    } catch (e) {
      if (kDebugMode) {
        print(
            'Error in LocationRepository.getSavedLocationsSinceLastOpened: $e');
      }
      return [];
    }
  }

  /// Acknoledge if the location is right or not
  Future<bool> acknowledgeLocation(int locationId, bool value) async {
    try {
      return await _locationService.acknowledgeLocation(locationId, value);
    } catch (e) {
      if (kDebugMode) {
        print('Error in LocationRepository.ackLocation: $e');
      }
      return false;
    }
  }
}

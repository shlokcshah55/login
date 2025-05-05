import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../models/location_model.dart';
import '../models/action_model.dart';
import '../supabase_client.dart';

/// Service for handling Supabase location operations
class SupabaseLocationService {
  final SupabaseClient _client = SupabaseClientManager().client;

  /// Get all locations
  Future<List<LocationModel>> getAllLocations() async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableLocations)
          .select()
          .order(SupabaseConstants.columnCreatedAt, ascending: false);

      return (response as List)
          .map((data) => LocationModel.fromJson(data))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting locations: $e');
      }
      return [];
    }
  }

  /// Get locations near a specific coordinate using PostgreSQL's earthdistance module
  /// Note: Requires the earthdistance and cube extensions in your Supabase database
  Future<List<LocationModel>> getLocationsNearby(
      double latitude, double longitude,
      {double radiusMeters = 5000}) async {
    try {
      // This query uses PostGIS functionality through a raw SQL query
      // Make sure to have PostGIS extension enabled in your Supabase database
      final response = await _client.rpc('nearby_locations', params: {
        'lat': latitude,
        'lng': longitude,
        'radius': radiusMeters,
      });

      return (response as List)
          .map((data) => LocationModel.fromJson(data))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting nearby locations: $e');
      }
      return [];
    }
  }

  /// Get a single location by ID
  Future<LocationModel?> getLocationById(int locationId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableLocations)
          .select()
          .eq(SupabaseConstants.columnLocationId, locationId)
          .single();

      return LocationModel.fromJson(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting location by ID: $e');
      }
      return null;
    }
  }

  /// Add a new location
  Future<LocationModel?> addLocation(LocationModel location) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableLocations)
          .insert(location.toJson())
          .select()
          .single();

      return LocationModel.fromJson(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error adding location: $e');
      }
      return null;
    }
  }

  // /// Update a location
  // Future<LocationModel?> updateLocation(LocationModel location) async {
  //   try {
  //     if (location.locationId == null) {
  //       throw Exception('Location ID cannot be null for update operation');
  //     }

  //     final response = await _client
  //         .from(SupabaseConstants.tableLocations)
  //         .update(location.toJson())
  //         .eq(SupabaseConstants.columnLocationId, location.locationId)
  //         .select()
  //         .single();

  //     return LocationModel.fromJson(response);
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Error updating location: $e');
  //     }
  //     return null;
  //   }
  // }

  /// Get saved locations for the current user
  Future<List<LocationModel>> getSavedLocations() async {
    try {
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // First get all user_location_actions with 'save' action for this user
      final savedActions = await _client
          .from(SupabaseConstants.tableUserLocationActions)
          .select('${SupabaseConstants.columnLocationId}')
          .eq(SupabaseConstants.columnUserId, user.id)
          .eq(SupabaseConstants.columnAction, SupabaseConstants.actionSave);

      if (savedActions.isEmpty) {
        return [];
      }

      // Extract location IDs
      final locationIds = (savedActions as List)
          .map((action) => action[SupabaseConstants.columnLocationId] as int)
          .toList();

      if (locationIds.isEmpty) {
        return [];
      }

      // Then fetch the actual location data
      final locations = await _client
          .from(SupabaseConstants.tableLocations)
          .select()
          .inFilter(SupabaseConstants.columnLocationId, locationIds);

      return (locations as List)
          .map((data) => LocationModel.fromJson(data))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting saved locations: $e');
      }
      return [];
    }
  }

  /// Save a location for the current user
  Future<bool> saveLocation(int locationId, {String? savedMethod}) async {
    try {
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if location exists first
      final locationExists = await _client
          .from(SupabaseConstants.tableLocations)
          .select(SupabaseConstants.columnLocationId)
          .eq(SupabaseConstants.columnLocationId, locationId)
          .single();

      if (locationExists == null) {
        throw Exception('Location not found');
      }

      // Create the action
      await _client.from(SupabaseConstants.tableUserLocationActions).upsert({
        SupabaseConstants.columnUserId: user.id,
        SupabaseConstants.columnLocationId: locationId,
        SupabaseConstants.columnAction: SupabaseConstants.actionSave,
        SupabaseConstants.columnSavedMethod: savedMethod,
        SupabaseConstants.columnCreatedAt: DateTime.now().toIso8601String(),
      });

      // Update location popularity counter
      await _client.rpc('increment_saves_count', params: {
        'loc_id': locationId,
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving location: $e');
      }
      return false;
    }
  }

  /// Like a location for the current user
  Future<bool> likeLocation(int locationId) async {
    try {
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create the action
      await _client.from(SupabaseConstants.tableUserLocationActions).upsert({
        SupabaseConstants.columnUserId: user.id,
        SupabaseConstants.columnLocationId: locationId,
        SupabaseConstants.columnAction: SupabaseConstants.actionLike,
        SupabaseConstants.columnCreatedAt: DateTime.now().toIso8601String(),
      });

      // Update location popularity counter
      await _client.rpc('increment_likes_count', params: {
        'loc_id': locationId,
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error liking location: $e');
      }
      return false;
    }
  }

  /// Check if a location is saved by the current user
  Future<bool> isLocationSaved(int locationId) async {
    try {
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        return false;
      }

      final response = await _client
          .from(SupabaseConstants.tableUserLocationActions)
          .select()
          .eq(SupabaseConstants.columnUserId, user.id)
          .eq(SupabaseConstants.columnLocationId, locationId)
          .eq(SupabaseConstants.columnAction, SupabaseConstants.actionSave)
          .maybeSingle();

      return response != null;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking if location is saved: $e');
      }
      return false;
    }
  }

  /// Unsave a location for the current user
  Future<bool> unsaveLocation(int locationId) async {
    try {
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from(SupabaseConstants.tableUserLocationActions)
          .delete()
          .eq(SupabaseConstants.columnUserId, user.id)
          .eq(SupabaseConstants.columnLocationId, locationId)
          .eq(SupabaseConstants.columnAction, SupabaseConstants.actionSave);

      // Update location popularity counter
      await _client.rpc('decrement_saves_count', params: {
        'loc_id': locationId,
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error unsaving location: $e');
      }
      return false;
    }
  }

  /// Get popular locations based on app-wide metrics
  Future<List<LocationModel>> getPopularLocations({int limit = 10}) async {
    try {
      // Join popularity table with locations
      final response = await _client
          .from(SupabaseConstants.tableLocationPopularityApp)
          .select('*, ${SupabaseConstants.tableLocations}(*)')
          .order(SupabaseConstants.columnSavesCount, ascending: false)
          .limit(limit);

      return (response as List).map((data) {
        final locationData =
            data[SupabaseConstants.tableLocations] as Map<String, dynamic>;
        // Add popularity metrics
        locationData[SupabaseConstants.columnSavesCount] =
            data[SupabaseConstants.columnSavesCount];
        locationData[SupabaseConstants.columnLikesCount] =
            data[SupabaseConstants.columnLikesCount];

        return LocationModel.fromJson(locationData);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting popular locations: $e');
      }
      return [];
    }
  }
}

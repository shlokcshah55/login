import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../../models/locations.dart';
import '../supabase_client.dart';

// Service for handling Supabase location operations
class LocationHelper {
  final SupabaseClient _client = SupabaseClientManager().client;

  // Get all locations
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
      final responseLocation = await _client
          .from(SupabaseConstants.tableLocations)
          .insert(location.toJson())
          .select()
          .single();

      await _client
          .from(SupabaseConstants.tableLocationPopularityApp)
          .insert({
            SupabaseConstants.columnLocationId:
                responseLocation[SupabaseConstants.columnLocationId],
            SupabaseConstants.columnSavesCount: 0,
            SupabaseConstants.columnLikesCount: 0,
            SupabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return LocationModel.fromJson(responseLocation);
    } catch (e) {
      if (kDebugMode) {
        print('Error adding location: $e');
      }
      return null;
    }
  }

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
          .eq(SupabaseConstants.columnAction, SupabaseConstants.actionSave)
          .eq(SupabaseConstants.columnAcked, true);

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
  Future<bool> saveLocation(LocationModel location,
      {String? savedMethod}) async {
    try {
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }
      final isSaved = await isLocationSaved(location.locationId);
      if (isSaved) {
        // If already saved, return true
        return true;
      }
      var locationId;
      locationId = location.locationId;

      // Check if location exists first
      final locationExists = await _client
          .from(SupabaseConstants.tableLocations)
          .select(SupabaseConstants.columnLocationId)
          .eq(SupabaseConstants.columnLocationId, location.locationId)
          .maybeSingle();
      if (locationExists == null) {
        LocationModel? addedlocation = await addLocation(location);
        if (addedlocation == null) {
          throw Exception('Failed to add location');
        }
        locationId = addedlocation.locationId;
      }

      // Check if the location is already saved

      // Create the action
      await _client.from(SupabaseConstants.tableUserLocationActions).upsert({
        SupabaseConstants.columnUserId: user.id,
        SupabaseConstants.columnLocationId: locationId,
        SupabaseConstants.columnAction: SupabaseConstants.actionSave,
        SupabaseConstants.columnSavedMethod: savedMethod,
        SupabaseConstants.columnCreatedAt: DateTime.now().toIso8601String(),
        SupabaseConstants.columnAcked: true,
      });

      incrementSaveCount(locationId);
      // Update location popularity counter
      // await _client.rpc('increment_saves_count', params: {
      //   'loc_id': location.locationId,
      // });

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

      // Check if the location is already liked
      final isLiked = await isLocationLiked(locationId);
      if (isLiked) {
        // If already liked, return true
        return true;
      }

      // Create the action
      await _client.from(SupabaseConstants.tableUserLocationActions).upsert({
        SupabaseConstants.columnUserId: user.id,
        SupabaseConstants.columnLocationId: locationId,
        SupabaseConstants.columnAction: SupabaseConstants.actionLike,
        SupabaseConstants.columnCreatedAt: DateTime.now().toIso8601String(),
      });

      // Update location popularity counter using direct method instead of RPC
      await incrementLikesCount(locationId);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error liking location: $e');
      }
      return false;
    }
  }

    /// Disike a location for the current user
  Future<bool> dislikeLocation(int locationId) async {
    try {
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create the action
      await _client.from(SupabaseConstants.tableUserLocationActions).upsert({
        SupabaseConstants.columnUserId: user.id,
        SupabaseConstants.columnLocationId: locationId,
        SupabaseConstants.columnAction: SupabaseConstants.actionDislike,
        SupabaseConstants.columnCreatedAt: DateTime.now().toIso8601String(),
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
      decrementSaveCount(locationId);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error unsaving location: $e');
      }
      return false;
    }
  }

  /// Increment the save count for a location
  Future<bool> incrementSaveCount(int locationId) async {
    try {
      // First check if a row exists for this location in the popularity table
      final existingRow = await _client
          .from(SupabaseConstants.tableLocationPopularityApp)
          .select()
          .eq(SupabaseConstants.columnLocationId, locationId)
          .maybeSingle();

      if (existingRow != null) {
        // Update existing row
        final currentCount =
            existingRow[SupabaseConstants.columnSavesCount] as int? ?? 0;
        await _client
            .from(SupabaseConstants.tableLocationPopularityApp)
            .update({
          SupabaseConstants.columnSavesCount: currentCount + 1,
          SupabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        }).eq(SupabaseConstants.columnLocationId, locationId);
      } else {
        // Create new row with initial count of 1
        await _client
            .from(SupabaseConstants.tableLocationPopularityApp)
            .insert({
          SupabaseConstants.columnLocationId: locationId,
          SupabaseConstants.columnSavesCount: 1,
          SupabaseConstants.columnLikesCount: 0,
          SupabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        });
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error incrementing save count: $e');
      }
      return false;
    }
  }

  /// Decrement the save count for a location
  Future<bool> decrementSaveCount(int locationId) async {
    try {
      // First check if a row exists for this location
      final existingRow = await _client
          .from(SupabaseConstants.tableLocationPopularityApp)
          .select()
          .eq(SupabaseConstants.columnLocationId, locationId)
          .maybeSingle();

      if (existingRow != null) {
        // Update existing row (ensure count doesn't go below 0)
        final currentCount =
            existingRow[SupabaseConstants.columnSavesCount] as int? ?? 0;
        final newCount = currentCount > 0 ? currentCount - 1 : 0;

        await _client
            .from(SupabaseConstants.tableLocationPopularityApp)
            .update({
          SupabaseConstants.columnSavesCount: newCount,
          SupabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        }).eq(SupabaseConstants.columnLocationId, locationId);
      } else {
        // Create new row with count of 0 (rare case, but handled for completeness)
        await _client
            .from(SupabaseConstants.tableLocationPopularityApp)
            .insert({
          SupabaseConstants.columnLocationId: locationId,
          SupabaseConstants.columnSavesCount: 0,
          SupabaseConstants.columnLikesCount: 0,
          SupabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        });
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error decrementing save count: $e');
      }
      return false;
    }
  }

  /// Check if a location is liked by the current user
  Future<bool> isLocationLiked(int locationId) async {
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
          .eq(SupabaseConstants.columnAction, SupabaseConstants.actionLike)
          .maybeSingle();

      return response != null;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking if location is liked: $e');
      }
      return false;
    }
  }

  /// Unlike a location for the current user
  Future<bool> unlikeLocation(int locationId) async {
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
          .eq(SupabaseConstants.columnAction, SupabaseConstants.actionLike);

      // Update location popularity counter
      await decrementLikesCount(locationId);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error unliking location: $e');
      }
      return false;
    }
  }

  /// Increment the likes count for a location
  Future<bool> incrementLikesCount(int locationId) async {
    try {
      // First check if a row exists for this location in the popularity table
      final existingRow = await _client
          .from(SupabaseConstants.tableLocationPopularityApp)
          .select()
          .eq(SupabaseConstants.columnLocationId, locationId)
          .maybeSingle();

      if (existingRow != null) {
        // Update existing row
        final currentCount =
            existingRow[SupabaseConstants.columnLikesCount] as int? ?? 0;
        await _client
            .from(SupabaseConstants.tableLocationPopularityApp)
            .update({
          SupabaseConstants.columnLikesCount: currentCount + 1,
          SupabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        }).eq(SupabaseConstants.columnLocationId, locationId);
      } else {
        // Create new row with initial count of 1
        await _client
            .from(SupabaseConstants.tableLocationPopularityApp)
            .insert({
          SupabaseConstants.columnLocationId: locationId,
          SupabaseConstants.columnSavesCount: 0,
          SupabaseConstants.columnLikesCount: 1,
          SupabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        });
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error incrementing likes count: $e');
      }
      return false;
    }
  }

  /// Decrement the likes count for a location
  Future<bool> decrementLikesCount(int locationId) async {
    try {
      // First check if a row exists for this location
      final existingRow = await _client
          .from(SupabaseConstants.tableLocationPopularityApp)
          .select()
          .eq(SupabaseConstants.columnLocationId, locationId)
          .maybeSingle();

      if (existingRow != null) {
        // Update existing row (ensure count doesn't go below 0)
        final currentCount =
            existingRow[SupabaseConstants.columnLikesCount] as int? ?? 0;
        final newCount = currentCount > 0 ? currentCount - 1 : 0;

        await _client
            .from(SupabaseConstants.tableLocationPopularityApp)
            .update({
          SupabaseConstants.columnLikesCount: newCount,
          SupabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        }).eq(SupabaseConstants.columnLocationId, locationId);
      } else {
        // Create new row with count of 0 (rare case, but handled for completeness)
        await _client
            .from(SupabaseConstants.tableLocationPopularityApp)
            .insert({
          SupabaseConstants.columnLocationId: locationId,
          SupabaseConstants.columnSavesCount: 0,
          SupabaseConstants.columnLikesCount: 0,
          SupabaseConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
        });
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error decrementing likes count: $e');
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

  // Get saved locations since the app was last opened
  Future<List<LocationModel>> getSavedLocationsSinceLastOpened() async {
    try {
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get the not acknowledged location IDs and their creation timestamps
      final notAckedLocations = await _client
          .from(SupabaseConstants.tableUserLocationActions)
          .select(
              "${SupabaseConstants.columnLocationId}, ${SupabaseConstants.columnCreatedAt}")
          .isFilter(SupabaseConstants.columnAcked, null)
          .eq(SupabaseConstants.columnUserId, user.id);

      if ((notAckedLocations as List).isEmpty) {
        return [];
      }

      // Create a map of locationId to createdAt timestamp from the actions table
      final Map<int, DateTime> locationTimestamps = {};
      for (var action in notAckedLocations) {
        final locationId = action[SupabaseConstants.columnLocationId] as int;
        final createdAt =
            DateTime.parse(action[SupabaseConstants.columnCreatedAt]);
        locationTimestamps[locationId] = createdAt;
      }

      // Extract location IDs
      final locationIds = locationTimestamps.keys.toList();

      // Then fetch the actual location data
      final locations = await _client
          .from(SupabaseConstants.tableLocations)
          .select()
          .inFilter(SupabaseConstants.columnLocationId, locationIds);

      // Convert to LocationModel and override the createdAt with the timestamp from actions
      return (locations as List).map((data) {
        // First create the model with the location data
        final locationModel = LocationModel.fromJson(data);
        // Then override the createdAt timestamp with the one from the actions table
        final originalTimestamp = locationTimestamps[locationModel.locationId];
        return locationModel.copyWith(createdAt: originalTimestamp);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting saved locations since last opened: $e');
      }
      return [];
    }
  }

  /// Set a location as acknowledged
  Future<bool> acknowledgeLocation(int locationId, bool value) async {
    try {
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from(SupabaseConstants.tableUserLocationActions)
          .update({SupabaseConstants.columnAcked: value})
          .eq(SupabaseConstants.columnUserId, user.id)
          .eq(SupabaseConstants.columnLocationId, locationId);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error acknowledging location: $e');
      }
      return false;
    }
  }

  /// Get all saved locations from a list of user IDs
  /// Used by bubbles to show all member locations
  Future<List<LocationModel>> getLocationsByUserIds(List<String> userIds) async {
    try {
      if (userIds.isEmpty) {
        return [];
      }

      // Get all saved locations for these users
      final locationsResponse = await _client
          .from(SupabaseConstants.tableUserLocationActions)
          .select('''
            ${SupabaseConstants.columnLocationId},
            ${SupabaseConstants.columnUserId},
            ${SupabaseConstants.columnAction},
            ${SupabaseConstants.columnCreatedAt},
            ${SupabaseConstants.tableLocations}!inner(
              ${SupabaseConstants.columnLocationId},
              ${SupabaseConstants.columnName},
              ${SupabaseConstants.columnVicinity},
              ${SupabaseConstants.columnLat},
              ${SupabaseConstants.columnLng},
              ${SupabaseConstants.columnCreatedAt},
              ${SupabaseConstants.columnPhoneNumber},
              ${SupabaseConstants.columnCuisine},
              ${SupabaseConstants.columnRating},
              ${SupabaseConstants.columnUserRatingsTotal},
              ${SupabaseConstants.columnPriceLevel},
              ${SupabaseConstants.columnPhotoReference},
              ${SupabaseConstants.columnSavedCount}
            )
          ''')
          .inFilter(SupabaseConstants.columnUserId, userIds)
          .eq(SupabaseConstants.columnAction, SupabaseConstants.actionSave);

      if ((locationsResponse as List).isEmpty) {
        return [];
      }

      // Convert to LocationModel and remove duplicates by location_id
      final Map<int, LocationModel> uniqueLocations = {};

      for (var item in locationsResponse) {
        final location = item[SupabaseConstants.tableLocations];
        final locationId = location[SupabaseConstants.columnLocationId];

        if (!uniqueLocations.containsKey(locationId)) {
          uniqueLocations[locationId] = LocationModel(
            locationId: location[SupabaseConstants.columnLocationId],
            name: location[SupabaseConstants.columnName] ?? '',
            vicinity: location[SupabaseConstants.columnVicinity] ?? '',
            lat: (location[SupabaseConstants.columnLat] as num?)?.toDouble() ?? 0.0,
            lng: (location[SupabaseConstants.columnLng] as num?)?.toDouble() ?? 0.0,
            createdAt: DateTime.parse(location[SupabaseConstants.columnCreatedAt]),
            phoneNumber: location[SupabaseConstants.columnPhoneNumber],
            cuisine: location[SupabaseConstants.columnCuisine],
            rating: (location[SupabaseConstants.columnRating] as num?)?.toDouble(),
            userRatingsTotal: location[SupabaseConstants.columnUserRatingsTotal],
            priceLevel: location[SupabaseConstants.columnPriceLevel],
            photoReference: location[SupabaseConstants.columnPhotoReference],
            savedCount: location[SupabaseConstants.columnSavedCount],
          );
        }
      }

      return uniqueLocations.values.toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching locations by user IDs: $e');
      }
      return [];
    }
  }

  /// Get all tags for a specific location with their scores
  /// Returns a list of maps containing tag information and scores
  Future<List<Map<String, dynamic>>> getLocationTags(int locationId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableLocationTags)
          .select('''
            ${SupabaseConstants.columnId},
            ${SupabaseConstants.columnScore},
            ${SupabaseConstants.tableTags}!inner(
              ${SupabaseConstants.columnTagId},
              ${SupabaseConstants.columnText},
              ${SupabaseConstants.columnPromptDescription},
              ${SupabaseConstants.columnTagType}
            )
          ''')
          .eq(SupabaseConstants.columnLocationId, locationId)
          .order(SupabaseConstants.columnScore, ascending: false);

      if ((response as List).isEmpty) {
        return [];
      }

      return (response as List).map((item) {
        final tag = item[SupabaseConstants.tableTags] as Map<String, dynamic>;
        return {
          'id': item[SupabaseConstants.columnId],
          'score': item[SupabaseConstants.columnScore],
          'tag_id': tag[SupabaseConstants.columnTagId],
          'text': tag[SupabaseConstants.columnText],
          'prompt_description': tag[SupabaseConstants.columnPromptDescription],
          'tag_type': tag[SupabaseConstants.columnTagType],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting location tags: $e');
      }
      return [];
    }
  }

  /// Get location presence/popularity metrics
  /// Returns combined metrics from app and social popularity tables
  Future<Map<String, dynamic>?> getLocationPresence(int locationId) async {
    try {
      // Get app popularity metrics
      final appPopularity = await _client
          .from(SupabaseConstants.tableLocationPopularityApp)
          .select()
          .eq(SupabaseConstants.columnLocationId, locationId)
          .maybeSingle();

      // Get social popularity metrics
      final socialPopularity = await _client
          .from(SupabaseConstants.tableLocationPopularitySocial)
          .select()
          .eq(SupabaseConstants.columnLocationId, locationId)
          .maybeSingle();

      // Combine metrics
      return {
        'location_id': locationId,
        'saves_count': appPopularity?[SupabaseConstants.columnSavesCount] ?? 0,
        'likes_count': appPopularity?[SupabaseConstants.columnLikesCount] ?? 0,
        'app_updated_at': appPopularity?[SupabaseConstants.columnUpdatedAt],
        'mention_count': socialPopularity?[SupabaseConstants.columnMentionCount] ?? 0,
        'last_scanned': socialPopularity?[SupabaseConstants.columnLastScanned],
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting location presence: $e');
      }
      return null;
    }
  }
}

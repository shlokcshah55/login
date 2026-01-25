import 'package:flutter/foundation.dart';
import 'package:login/supabase/helpers/tags.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../constants.dart';
import '../../models/locations.dart';
import '../supabase_client.dart';

// Service for handling Supabase location operations
class LocationHelper {
  final SupabaseClient _client = SupabaseClientManager().client;
  RealtimeChannel? _realtimeChannel;

  // In-memory lock to prevent duplicate downloads for the same location
  // Key: location_id, Value: Future that completes when download is done
  static final Map<int, Future<String?>> _activeDownloads = {};

  // This is temporary until we replace this with reccomendation call
  Future<List<LocationModel>> getFiveLocations() async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableLocations)
          .select()
          .order(SupabaseConstants.columnCreatedAt, ascending: false)
          .limit(5);
      print(response);
      List<LocationModel> locations = [];
      for (var item in response as List) {
        print(item[SupabaseConstants.columnLocationId]);

        // Check if image_url already exists in the database
        var locationImage;
        var filename = '${item[SupabaseConstants.columnLocationId]}.jpg';

        // Check if file already exists in storage
        try {
          final existingFiles = await _client.storage
              .from('location_photos')
              .list(path: '', searchOptions: SearchOptions(search: filename));

          if (existingFiles.isNotEmpty && existingFiles.any((file) => file.name == filename)) {
            if (kDebugMode) {
              print('✅ Image already exists in Supabase Storage!');
              print('   Filename: $filename');
              print('   Skipping upload - using existing file');
            }

            // Return the URL of the existing file
            locationImage = _client.storage
                .from('location_photos')
                .getPublicUrl(filename);
          }
        } catch (e) {
          if (kDebugMode) print('⚠️  Could not check for existing file: $e (will proceed with upload)');
        }

        // Then make a call to get the location image from google places API 
        if (locationImage == null || locationImage.isEmpty) {
          locationImage = await getLocationImage(
            item[SupabaseConstants.columnLocationId],
            item[SupabaseConstants.columnGooglePlaceId],
            item[SupabaseConstants.columnPhotoReference]
          );
        }
        locations.add(LocationModel.fromJson(item, locationImage));
      }
      return locations;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting locations: $e');
      }
      return [];
    }
  }

  /// TODO: Replace this with the POST /recommendations/proximal endpoint
  Future<List<LocationModel>> getLocationsNearby(
      double latitude, double longitude,
      {double radiusMeters = 5000}) async {
      return [];
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

      // Then fetch the actual location data (including image_url!)
      final locations = await _client
          .from(SupabaseConstants.tableLocations)
          .select()
          .inFilter(SupabaseConstants.columnLocationId, locationIds);

      List<LocationModel> locationModels = [];
      for (var item in locations as List) {
        print("${item[SupabaseConstants.columnName]} place emoji: ${item[SupabaseConstants.columnEmoji]}");
        var locationImage;
        var filename = '${item[SupabaseConstants.columnLocationId]}.jpg';
        
        // Check if file already exists in storage
        try {
          final existingFiles = await _client.storage
              .from('location_photos')
              .list(path: '', searchOptions: SearchOptions(search: filename));

          if (existingFiles.isNotEmpty && existingFiles.any((file) => file.name == filename)) {
            if (kDebugMode) {
              print('✅ Image already exists in Supabase Storage!');
              print('   Filename: $filename');
              print('   Skipping upload - using existing file');
            }

            // Return the URL of the existing file
            locationImage = _client.storage
                .from('location_photos')
                .getPublicUrl(filename);
          }
        } catch (e) {
          if (kDebugMode) print('⚠️  Could not check for existing file: $e (will proceed with upload)');
        }

        if (locationImage == null || locationImage.isEmpty) {
          locationImage = await getLocationImage(
            item[SupabaseConstants.columnLocationId],
            item[SupabaseConstants.columnGooglePlaceId],
            item[SupabaseConstants.columnPhotoReference]
          );
        }

        locationModels.add(LocationModel.fromJson(item, locationImage));
      }
      return locationModels;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting saved locations: $e');
      }
      return [];
    }
  }

  /// Get popular locations based on app-wide metrics
  /// Ordered by (saves_count - dislikes_count) in descending order
  Future<List<LocationModel>> getPopularLocations({int limit = 10}) async {
    try {
      final response = await _client.rpc('get_popular_locations', params: {
        'p_limit': limit,
      });

      List<LocationModel> locations = [];
      for (var item in response as List) {
        var locationImage;
        var filename = '${item[SupabaseConstants.columnLocationId]}.jpg';
        
        // Check if file already exists in storage
        try {
          final existingFiles = await _client.storage
              .from('location_photos')
              .list(path: '', searchOptions: SearchOptions(search: filename));

          if (existingFiles.isNotEmpty && existingFiles.any((file) => file.name == filename)) {
            if (kDebugMode) {
              print('✅ Image already exists in Supabase Storage!');
              print('   Filename: $filename');
              print('   Skipping upload - using existing file');
            }

            // Return the URL of the existing file
            locationImage = _client.storage
                .from('location_photos')
                .getPublicUrl(filename);
          }
        } catch (e) {
          if (kDebugMode) print('⚠️  Could not check for existing file: $e (will proceed with upload)');
        }

        if (locationImage == null || locationImage.isEmpty) {
          locationImage = await getLocationImage(
            item[SupabaseConstants.columnLocationId],
            item[SupabaseConstants.columnGooglePlaceId],
            item[SupabaseConstants.columnPhotoReference]
          );
        }

        locations.add(LocationModel.fromJson(item, locationImage));
      }
      return locations;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting popular locations: $e');
      }
      return [];
    }
  }

  /// Set a logition as acknowledged
  Future<bool> acknowledgeLocation(int locationId, bool value) async {
    try {
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _client.rpc('acknowledge_location', params: {
        'p_user_id': user.id,
        'p_location_id': locationId,
        'p_acked': value,
      });

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
              ${SupabaseConstants.columnInternationalPhoneNumber},
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
            phoneNumber: location[SupabaseConstants.columnPhoneNumber] ??
                location[SupabaseConstants.columnInternationalPhoneNumber],
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
  Future<List<Map<String, dynamic>>> getLocationTags(int locationId, String? type) async {
    try {
      var query = _client
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
          .eq(SupabaseConstants.columnLocationId, locationId);

      if (type != null) {
        query = query.eq('${SupabaseConstants.tableTags}.${SupabaseConstants.columnTagType}', type);
      }

      final response = await query.order(SupabaseConstants.columnScore, ascending: false);

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

  /// Save a location for the current user
  Future<bool> saveLocation(int locationId, {String? savedMethod}) async {
    try {
      final user = SupabaseClientManager().currentUser;
      final TagsHelper tagsHelper = TagsHelper();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final isSaved = await isLocationSaved(locationId);
      if (isSaved) {
        // If already saved, return true
        return true;
      }

      // Create the action
      await _client.rpc('create_user_location_action', params: {
        'p_user_id': user.id,
        'p_location_id': locationId,
        'p_action': SupabaseConstants.actionSave,
        'p_saved_method': savedMethod,
        'p_acked': true,
      });

      incrementSaveCount(locationId);
      if (savedMethod != null) {
        if (savedMethod == SupabaseConstants.savedMethodInApp) {
          await tagsHelper.updateUserTagsSaving(user.id, locationId);
        }
        if (savedMethod == SupabaseConstants.savedMethodTikTok) {
          await tagsHelper.updateUserTagsSharing(user.id, locationId);

        }
      }
      tagsHelper.updateUserTagsSaving(user.id, locationId);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving location: $e');
      }
      return false;
    }
  }

  /// Disike a location for the current user
  Future<bool> dislikeLocation(int locationId) async {
    try {
      final TagsHelper tagsHelper = TagsHelper();
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _client.rpc('create_user_location_action', params: {
      'p_user_id': user.id,
      'p_location_id': locationId,
      'p_action': SupabaseConstants.actionDislike,
      'p_acked': true,
    });

      await tagsHelper.updateUserTagsDismissGavel(user.id, locationId);
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

      await _client.rpc('unsave_location', params: {
        'p_user_id': user.id,
        'p_location_id': locationId,
      });

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
      await _client.rpc('update_location_popularity', params: {
        'p_location_id': locationId,
        'p_saves_delta': 1,
      });
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
      await _client.rpc('update_location_popularity', params: {
        'p_location_id': locationId,
        'p_saves_delta': -1,
      });
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error decrementing save count: $e');
      }
      return false;
    }
  }

  Future<String?> getLocationImage(int locationId, String google_place_id, String? photoReference) async {
    try {
      if (photoReference == null || photoReference.isEmpty) {
        return null;
      }

      // Check if another call is already downloading this location
      if (_activeDownloads.containsKey(locationId)) {
        return await _activeDownloads[locationId];
      }

      // Download from Google and upload to Supabase
      final downloadFuture = _performImageDownload(locationId, photoReference, google_place_id);
      _activeDownloads[locationId] = downloadFuture;

      try {
        final result = await downloadFuture;
        return result;
      } finally {
        _activeDownloads.remove(locationId);
      }
    } catch (e) {
      return null;
    }
  }

  // Helper function to fetch new photo reference from Google Places API v1
  Future<String?> _fetchNewPhotoReference(String placeId) async {
    try {
      final apiKey = dotenv.env["GOOGLE_PLACE_API_KEY"];
      if (apiKey == null || apiKey.isEmpty) {
        if (kDebugMode) print('GOOGLE_PLACE_API_KEY not found');
        return null;
      }

      final url = 'https://places.googleapis.com/v1/places/$placeId';
      final headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask': 'id,displayName,photos',
      };
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['photos'] != null && (data['photos'] as List).isNotEmpty) {
          return data['photos'][0]['name'] as String?;
        }
      }

      if (kDebugMode) print('⚠️  Places API returned status: ${response.statusCode}');
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error in Places API call: $e');
      return null;
    }
  }

    // Method that performs the actual download (called only once per location)
  Future<String?> _performImageDownload(int locationId, String photoReference, String placeId) async {
    try {
      if (photoReference.isEmpty) {
          String? obtainedPhotoReference = await _fetchNewPhotoReference(placeId);
          if (obtainedPhotoReference != null) {
            photoReference = obtainedPhotoReference;
            await _client.rpc('update_location_photo_reference', params: {
              'p_location_id': locationId,
              'p_photo_reference': photoReference,
            },
            );
          }
      } else {
        if (kDebugMode) print('✓ Photo reference found in database');
      }

      // Download image bytes and upload to Supabase (pass locationId for filename)
      final permanentUrl = await _downloadAndUploadImage(photoReference, locationId);
      if (permanentUrl != null) {
        await _client.rpc('update_location_image_url', params: {
          'p_location_id': locationId,
          'p_image_url': permanentUrl,
          },
          );
      }
      return permanentUrl;
    } catch (e) {
      if (kDebugMode) print('❌ Error in _performImageDownload: $e');
      return null;
    }
  }

    // Helper function to download image from Google and upload to Supabase Storage
  Future<String?> _downloadAndUploadImage(String photoReference, int locationId) async {
    try {
      if (kDebugMode) {
        print('');
        print('🔄 Starting image download and upload process...');
      }

      // Use location_id as the filename for easy identification and deduplication
      final filename = '$locationId.jpg';

      // 1. Get temporary signed URL from Google Media API (1 API call)
      final tempImageUrl = await _tryMediaApi(photoReference);
      if (tempImageUrl == null) {
        return null;
      }

      // 2. Download actual image before the URL expires
      final response = await http.get(Uri.parse(tempImageUrl));
      if (response.statusCode != 200) {
        return null;
      }
      final imageBytes = response.bodyBytes;  // The actual image data

      // 3. Upload image bytes to Supabase Storage
      await _client.storage
          .from('location_photos')  // Existing bucket name
          .uploadBinary(filename, imageBytes);

      final permanentUrl = _client.storage
          .from('location_photos')  // Existing bucket name
          .getPublicUrl(filename);
      return permanentUrl;  // This URL will work forever
    } catch (e) {
      if (kDebugMode) print('❌ Error downloading and uploading image: $e');
      return null;
    }
  }


   // Helper function to try fetching image from Google Places API v1 media endpoint
  Future<String?> _tryMediaApi(String photoReference) async {
    try {
      final apiKey = dotenv.env["GOOGLE_PLACE_API_KEY"];
      if (apiKey == null || apiKey.isEmpty) {
        if (kDebugMode) print('GOOGLE_PLACE_API_KEY not found');
        return null;
      }

      final url = 'https://places.googleapis.com/v1/$photoReference/media?maxHeightPx=400&maxWidthPx=400&key=$apiKey';

      // ===== 💰 BILLABLE API CALL =====
      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('💰 GOOGLE API CALL #1: Places Photo Media API');
        print('   Endpoint: Media API v1');
        print('   Purpose: Get photo URL from reference');
        print('   Cost: ~\$0.007 per call');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      // Create a client to manually handle redirects
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url))
          ..followRedirects = false; // Don't follow redirects automatically

        final streamedResponse = await client.send(request);

        // Check for redirect status codes
        if (streamedResponse.statusCode == 302 || streamedResponse.statusCode == 301 || streamedResponse.statusCode == 307) {
          final redirectUrl = streamedResponse.headers['location'];
          if (redirectUrl != null) {
            if (kDebugMode) print('✅ Media API call successful - Got redirect URL');
            return redirectUrl;
          }
        }

        // If it's a direct 200, the URL itself might be usable
        if (streamedResponse.statusCode == 200) {
          if (kDebugMode) print('✅ Media API call successful - Status 200');
          return url;
        }

        if (kDebugMode) print('⚠️  Media API returned status: ${streamedResponse.statusCode}');
        return null;
      } finally {
        client.close();
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error in Media API call: $e');
      return null;
    }
  }



  // TODO : Get the recommended locations (Applying the masks onto the locaitons table)
  // Future<List<LocationModel>> getRecommendedLocations(String userId) async {}

  
  
  /// Subscribe to realtime changes on user_location_actions table
  /// Calls the provided callback when INSERT, UPDATE, or DELETE events occur
  void subscribeToUserLocationActions(
    String userId,
    void Function(PostgresChangePayload) onEvent,
  ) {
    // Clean up any existing subscription first
    unsubscribeFromUserLocationActions();
    
    if (kDebugMode) {
      print('LocationHelper: Subscribing to realtime updates for user: $userId');
    }
    
    _realtimeChannel = _client
        .channel('user_location_actions:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConstants.tableUserLocationActions,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: SupabaseConstants.columnUserId,
            value: userId,
          ),
          callback: onEvent,
        )
        .subscribe();
  }

  /// Unsubscribe from realtime updates on user_location_actions
  void unsubscribeFromUserLocationActions() {
    if (_realtimeChannel != null) {
      if (kDebugMode) {
        print('LocationHelper: Unsubscribing from realtime updates');
      }
      _client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }
}



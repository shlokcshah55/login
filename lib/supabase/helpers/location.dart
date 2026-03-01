import 'dart:developer' as developer;

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

  // ==================== CACHING LAYER ====================
  // In-memory cache for locations with TTL
  static final Map<int, _CachedLocation> _locationCache = {};
  static const Duration _cacheTTL = Duration(minutes: 10);

  // Request deduplication - prevents concurrent identical requests
  static Future<List<LocationModel>>? _activeSavedLocationsRequest;
  static Future<List<LocationModel>>? _activePopularLocationsRequest;

  // Cache a single location
  void _cacheLocation(LocationModel location) {
    _locationCache[location.locationId] = _CachedLocation(
      location: location,
      cachedAt: DateTime.now(),
    );
  }

  // Get from cache if valid
  LocationModel? _getFromCache(int locationId) {
    final cached = _locationCache[locationId];
    if (cached == null) return null;

    if (DateTime.now().difference(cached.cachedAt) > _cacheTTL) {
      _locationCache.remove(locationId);
      return null;
    }
    return cached.location;
  }

  // Clear expired cache entries
  void _cleanExpiredCache() {
    final now = DateTime.now();
    _locationCache.removeWhere(
        (_, cached) => now.difference(cached.cachedAt) > _cacheTTL);
  }

  // ==================== IMAGE URL HELPER ====================
  /// Constructs the image URL for a location using the `image_stored` boolean.
  /// Synchronous — no awaits, no network calls.
  /// Returns the storage URL if the image is stored, otherwise null.
  String? _getLocationImageUrl(Map<String, dynamic> locationData) {
    final locationId = locationData[SupabaseConstants.columnLocationId] as int;
    final imageStored = locationData[SupabaseConstants.columnImageStored] == true;

    if (imageStored) {
      return _client.storage.from('location_photos').getPublicUrl('$locationId.jpg');
    }
    return null; // no image yet — caller handles background fetch
  }

  /// Process a list of location JSON objects into LocationModel list.
  /// Handles image URLs efficiently with parallel processing.
  /// Individual location parsing errors are caught and logged so one bad
  /// row does not kill the entire batch.
  /// Optionally calculates match scores using user affinity vectors.
  Future<List<LocationModel>> _processLocationsWithImages(
      List<dynamic> locationsData, {
      List<int>? userVibeAffinity,
      List<int>? userDietaryAffinity,
  }) async {
    if (locationsData.isEmpty) return [];

    // Process in parallel — errors per-item are caught individually
    final futures = locationsData.map((item) async {
      try {
        final locationId = item[SupabaseConstants.columnLocationId] as int;

        // Check cache first
        final cached = _getFromCache(locationId);
        if (cached != null) {
          // Always refresh imageUrl even for cached locations
          // in case it was added or updated
          final imageUrl = _getLocationImageUrl(item);
          if (imageUrl != null && imageUrl != cached.imageUrl) {
            final updated = cached.copyWith(imageUrl: imageUrl);
            _cacheLocation(updated);
            return updated;
          }
          return cached;
        }

        // Get image URL (synchronous - just constructs URL if image_stored)
        final imageUrl = _getLocationImageUrl(item);
        developer.log(
          '[LocationHelper] Location $locationId - imageUrl: $imageUrl',
          name: 'LocationHelper',
        );

        var location = LocationModel.fromJson(item, imageUrl);
        
        // Calculate match score if user affinity data is available
        if (userVibeAffinity != null || userDietaryAffinity != null) {
          final score = LocationModel.calculateMatchScore(
            userVibeAffinity: userVibeAffinity,
            userDietaryAffinity: userDietaryAffinity,
            locationVibeVector: location.vibeVector,
            locationDietaryVector: location.dietaryRequirementVector,
          );
          location = location.copyWith(matchScore: score);
        }
        
        _cacheLocation(location);
        return location;
      } catch (e, st) {
        final id = item[SupabaseConstants.columnLocationId];
        developer.log(
          '[LocationHelper] Failed to parse location $id',
          error: e,
          stackTrace: st,
          name: 'LocationHelper',
        );
        return null;
      }
    }).toList();

    final processed = await Future.wait(futures);
    return processed.whereType<LocationModel>().toList();
  }

  // This is temporary until we replace this with reccomendation call
  Future<List<LocationModel>> getFiveLocations() async {
    try {
      // Clean expired cache periodically
      _cleanExpiredCache();

      final response = await _client
          .from(SupabaseConstants.tableLocations)
          .select()
          .order(SupabaseConstants.columnCreatedAt, ascending: false)
          .limit(5);

      // Use the efficient batch processor
      return await _processLocationsWithImages(response as List);
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
  /// Uses request deduplication to prevent concurrent identical requests
  Future<List<LocationModel>> getSavedLocations() async {
    // Request deduplication - reuse in-flight request
    if (_activeSavedLocationsRequest != null) {
      return _activeSavedLocationsRequest!;
    }

    _activeSavedLocationsRequest = _fetchSavedLocations();
    try {
      return await _activeSavedLocationsRequest!;
    } finally {
      _activeSavedLocationsRequest = null;
    }
  }

  Future<List<LocationModel>> _fetchSavedLocations() async {
    final stopwatch = Stopwatch()..start();
    try {
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Clean expired cache periodically
      _cleanExpiredCache();

      // Fetch user affinity vectors for match scoring
      List<int>? userVibeAffinity;
      List<int>? userDietaryAffinity;
      try {
        final userProf = await _client
            .from(SupabaseConstants.tableUsers)
            .select(
              '${SupabaseConstants.columnVibeTagAffinity}, ${SupabaseConstants.columnDietaryRequirementTagAffinity}',
            )
            .eq(SupabaseConstants.columnSupabaseId, user.id)
            .maybeSingle();

        if (userProf != null) {
          final vibeRaw = userProf[SupabaseConstants.columnVibeTagAffinity];
          if (vibeRaw is List) {
            userVibeAffinity = List<int>.from(vibeRaw.map((e) => (e as num).toInt()));
          }
          
          final dietaryRaw = userProf[SupabaseConstants.columnDietaryRequirementTagAffinity];
          if (dietaryRaw is List) {
            userDietaryAffinity = List<int>.from(dietaryRaw.map((e) => (e as num).toInt()));
          }
        }
      } catch (e) {
        developer.log('[Saved] Could not fetch user affinity data: $e', name: 'LocationHelper');
      }

      // First get all user_location_actions with 'save' action for this user
      developer.log('[Saved] Querying saved actions for user ${user.id}', name: 'LocationHelper');
      final savedActions = await _client
          .from(SupabaseConstants.tableUserLocationActions)
          .select('${SupabaseConstants.columnLocationId}')
          .eq(SupabaseConstants.columnUserId, user.id)
          .eq(SupabaseConstants.columnAction, SupabaseConstants.actionSave)
          .eq(SupabaseConstants.columnAcked, true);

      if (savedActions.isEmpty) {
        developer.log('[Saved] No saved actions found (${stopwatch.elapsedMilliseconds}ms)', name: 'LocationHelper');
        return [];
      }

      // Extract location IDs
      final locationIds = (savedActions as List)
          .map((action) => action[SupabaseConstants.columnLocationId] as int)
          .toList();
      developer.log('[Saved] Found ${locationIds.length} saved IDs: $locationIds', name: 'LocationHelper');

      if (locationIds.isEmpty) {
        return [];
      }

      // Then fetch the actual location data
      final locations = await _client
          .from(SupabaseConstants.tableLocations)
          .select()
          .inFilter(SupabaseConstants.columnLocationId, locationIds);

      developer.log(
        '[Saved] Fetched ${(locations as List).length} rows from DB in ${stopwatch.elapsedMilliseconds}ms',
        name: 'LocationHelper',
      );

      // Log first couple of locations for quick sanity check
      for (var i = 0; i < (locations as List).length && i < 2; i++) {
        final loc = locations[i];
        developer.log(
          '[Saved] Sample [$i]: id=${loc['location_id']}, name=${loc['name']}, '
          'keys=${(loc as Map).keys.length}',
          name: 'LocationHelper',
        );
      }

      // Use the efficient batch processor with user affinity for match scoring
      final result = await _processLocationsWithImages(
        locations,
        userVibeAffinity: userVibeAffinity,
        userDietaryAffinity: userDietaryAffinity,
      );
      developer.log(
        '[Saved] Processed ${result.length}/${(locations as List).length} locations OK in ${stopwatch.elapsedMilliseconds}ms',
        name: 'LocationHelper',
      );
      return result;
    } catch (e, st) {
      developer.log(
        '[Saved] ERROR fetching saved locations',
        error: e,
        stackTrace: st,
        name: 'LocationHelper',
      );
      return [];
    } finally {
      stopwatch.stop();
    }
  }

  /// Get saved locations for a specific user (for viewing other user profiles)
  Future<List<LocationModel>> getUserSavedLocations(String userId) async {
    try {
      // First get all user_location_actions with 'save' action for this user
      final savedActions = await _client
          .from(SupabaseConstants.tableUserLocationActions)
          .select('${SupabaseConstants.columnLocationId}')
          .eq(SupabaseConstants.columnUserId, userId)
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

      // Use the efficient batch processor
      return await _processLocationsWithImages(locations as List);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user saved locations: $e');
      }
      return [];
    }
  }

  /// Get popular locations based on app-wide metrics
  /// Ordered by (saves_count - dislikes_count) in descending order
  /// Uses request deduplication to prevent concurrent identical requests
  Future<List<LocationModel>> getPopularLocations({int limit = 10}) async {
    // Request deduplication
    if (_activePopularLocationsRequest != null) {
      return _activePopularLocationsRequest!;
    }

    _activePopularLocationsRequest = _fetchPopularLocations(limit);
    try {
      return await _activePopularLocationsRequest!;
    } finally {
      _activePopularLocationsRequest = null;
    }
  }

  Future<List<LocationModel>> _fetchPopularLocations(int limit) async {
    try {
      // Clean expired cache periodically
      _cleanExpiredCache();

      final response = await _client.rpc('get_popular_locations', params: {
        'p_limit': limit,
      });

      // Use the efficient batch processor
      return await _processLocationsWithImages(response as List);
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
  Future<List<LocationModel>> getLocationsByUserIds(
      List<String> userIds) async {
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
            ${SupabaseConstants.tableLocations}!inner(*)
          ''')
          .inFilter(SupabaseConstants.columnUserId, userIds)
          .eq(SupabaseConstants.columnAction, SupabaseConstants.actionSave);

      if ((locationsResponse as List).isEmpty) {
        return [];
      }

      // Extract unique location data and deduplicate
      final Map<int, Map<String, dynamic>> uniqueLocationData = {};

      for (var item in locationsResponse) {
        final location =
            item[SupabaseConstants.tableLocations] as Map<String, dynamic>;
        final locationId = location[SupabaseConstants.columnLocationId] as int;

        if (!uniqueLocationData.containsKey(locationId)) {
          uniqueLocationData[locationId] = location;
        }
      }

      // Use the efficient batch processor with the location data
      return await _processLocationsWithImages(
          uniqueLocationData.values.toList());
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching locations by user IDs: $e');
      }
      return [];
    }
  }

  /// Get all tags for a specific location with their scores
  /// Returns a list of maps containing tag information and scores
  Future<List<Map<String, dynamic>>> getLocationTags(
      int locationId, String? type) async {
    try {
      var query = _client.from(SupabaseConstants.tableLocationTags).select('''
            ${SupabaseConstants.columnId},
            ${SupabaseConstants.columnScore},
            ${SupabaseConstants.tableTags}!inner(
              ${SupabaseConstants.columnTagId},
              ${SupabaseConstants.columnText},
              ${SupabaseConstants.columnPromptDescription},
              ${SupabaseConstants.columnTagType}
            )
          ''').eq(SupabaseConstants.columnLocationId, locationId);

      if (type != null) {
        query = query.eq(
            '${SupabaseConstants.tableTags}.${SupabaseConstants.columnTagType}',
            type);
      }

      final response =
          await query.order(SupabaseConstants.columnScore, ascending: false);

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
        'mention_count':
            socialPopularity?[SupabaseConstants.columnMentionCount] ?? 0,
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

  Future<String?> getLocationImage(
      int locationId, String google_place_id, String? photoReference) async {
    try {
      if (photoReference == null || photoReference.isEmpty) {
        return null;
      }

      // Check if another call is already downloading this location
      if (_activeDownloads.containsKey(locationId)) {
        return await _activeDownloads[locationId];
      }

      // Download from Google and upload to Supabase
      final downloadFuture =
          _performImageDownload(locationId, photoReference, google_place_id);
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

      if (kDebugMode)
        print('⚠️  Places API returned status: ${response.statusCode}');
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ Error in Places API call: $e');
      return null;
    }
  }

  // Method that performs the actual download (called only once per location)
  // Downloads image bytes from Google, then fires off the storage upload + DB
  // update in the background. Returns the predictable storage URL immediately
  // once we have the bytes (so the caller can update the UI fast).
  Future<String?> _performImageDownload(
      int locationId, String photoReference, String placeId) async {
    try {
      if (photoReference.isEmpty) {
        String? obtainedPhotoReference = await _fetchNewPhotoReference(placeId);
        if (obtainedPhotoReference != null) {
          photoReference = obtainedPhotoReference;
          await _client.rpc(
            'update_location_photo_reference',
            params: {
              'p_location_id': locationId,
              'p_photo_reference': photoReference,
            },
          );
        } else {
          return null; // no photo reference available
        }
      } else {
        if (kDebugMode) print('✓ Photo reference found in database');
      }

      // Download image bytes from Google (need to await — we need the bytes)
      final filename = '$locationId.jpg';
      final tempImageUrl = await _tryMediaApi(photoReference);
      if (tempImageUrl == null) return null;

      final response = await http.get(Uri.parse(tempImageUrl));
      if (response.statusCode != 200) return null;
      final imageBytes = response.bodyBytes;

      // Construct the permanent storage URL (predictable)
      final permanentUrl =
          _client.storage.from('location_photos').getPublicUrl(filename);

      // Fire-and-forget: upload to storage + update DB (image_url + image_stored)
      // The URL will be live once the upload completes; CachedNetworkImage
      // will retry on its own.
      _uploadAndPersist(locationId, filename, imageBytes, permanentUrl);

      return permanentUrl;
    } catch (e) {
      if (kDebugMode) print('❌ Error in _performImageDownload: $e');
      return null;
    }
  }

  /// Fire-and-forget helper: uploads image bytes to storage and updates the DB.
  void _uploadAndPersist(
      int locationId, String filename, Uint8List imageBytes, String permanentUrl) async {
    try {
      await _client.storage
          .from('location_photos')
          .uploadBinary(filename, imageBytes);

      await _client.rpc(
        'update_location_image_url',
        params: {
          'p_location_id': locationId,
          'p_image_url': permanentUrl,
        },
      );
    } catch (e) {
      if (kDebugMode) print('❌ Background upload/persist failed for $locationId: $e');
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

      final url =
          'https://places.googleapis.com/v1/$photoReference/media?maxHeightPx=400&maxWidthPx=400&key=$apiKey';

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
        if (streamedResponse.statusCode == 302 ||
            streamedResponse.statusCode == 301 ||
            streamedResponse.statusCode == 307) {
          final redirectUrl = streamedResponse.headers['location'];
          if (redirectUrl != null) {
            if (kDebugMode)
              print('✅ Media API call successful - Got redirect URL');
            return redirectUrl;
          }
        }

        // If it's a direct 200, the URL itself might be usable
        if (streamedResponse.statusCode == 200) {
          if (kDebugMode) print('✅ Media API call successful - Status 200');
          return url;
        }

        if (kDebugMode)
          print(
              '⚠️  Media API returned status: ${streamedResponse.statusCode}');
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
      print(
          'LocationHelper: Subscribing to realtime updates for user: $userId');
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

  /// Clear all cached locations (useful when user logs out)
  void clearCache() {
    _locationCache.clear();
  }

  /// Invalidate a specific location from cache (useful after save/unsave)
  void invalidateCachedLocation(int locationId) {
    _locationCache.remove(locationId);
  }
}

/// Helper class for caching locations with TTL
class _CachedLocation {
  final LocationModel location;
  final DateTime cachedAt;

  _CachedLocation({
    required this.location,
    required this.cachedAt,
  });
}

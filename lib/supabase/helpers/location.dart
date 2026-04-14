import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
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

  // Locations confirmed to have no image available (Google returned no photos).
  // Persisted in-memory for the session; the DB flag prevents retries across sessions.
  static final Set<int> _noImageAvailable = {};

  // ==================== CACHING LAYER ====================
  // In-memory cache for locations with TTL
  static final Map<int, _CachedLocation> _locationCache = {};
  static const Duration _cacheTTL = Duration(minutes: 10);

  // Request deduplication - prevents concurrent identical requests
  static Future<List<LocationModel>>? _activeSavedLocationsRequest;
  static String? _activeSavedLocationsRequestUserId;
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
  /// Constructs the image URL for a location.
  /// If image_stored is true, the image is already in storage — return its public URL.
  /// Otherwise, trigger a background download from Google and return the URL optimistically.
  Future<String?> _getLocationImageUrl(
      Map<String, dynamic> locationData) async {
    final locationId = locationData[SupabaseConstants.columnLocationId] as int;
    final filename = '$locationId.jpg';

    final publicUrl =
        _client.storage.from('location_photos').getPublicUrl(filename);

    // If image_stored is true, the file is already in storage — return immediately.
    final imageStored = locationData[SupabaseConstants.columnImageStored];
    if (imageStored == true) {
      return publicUrl;
    }

    // If previously confirmed no image is available, skip and return null.
    final imageUnavailable = locationData['image_unavailable'];
    if (imageUnavailable == true) {
      _noImageAvailable.add(locationId); // sync in-memory set from DB
      return null;
    }

    // Image not yet in storage — kick off a background download if we have a reference or place ID.
    final photoReference = locationData[SupabaseConstants.columnPhotoReference];
    final googlePlaceId = locationData[SupabaseConstants.columnGooglePlaceId];

    final hasPhotoRef =
        photoReference != null && photoReference.toString().isNotEmpty;
    final hasPlaceId =
        googlePlaceId != null && googlePlaceId.toString().isNotEmpty;
    if ((hasPhotoRef || hasPlaceId) && !_noImageAvailable.contains(locationId)) {
      _ensureImageUploaded(locationId, googlePlaceId?.toString() ?? '',
          photoReference?.toString() ?? '');
    }

    return publicUrl;
  }

  /// Background task to ensure image is uploaded to storage
  /// This is fire-and-forget - doesn't block the main flow
  Future<void> _ensureImageUploaded(
      int locationId, String googlePlaceId, String photoReference) async {
    // Skip locations confirmed to have no image source
    if (_noImageAvailable.contains(locationId)) return;
    // Skip if already downloading
    if (_activeDownloads.containsKey(locationId)) return;

    try {
      await getLocationImage(locationId, googlePlaceId, photoReference);
    } catch (e) {
      // silent — background task, don't surface errors to UI
    }
  }

  /// Process a list of location JSON objects into LocationModel list.
  /// Handles image URLs efficiently with parallel processing.
  /// Individual location parsing errors are caught and logged so one bad
  /// row does not kill the entire batch.
  /// Optionally calculates match scores using user affinity vectors.
  Future<List<LocationModel>> processLocationsWithImages(
    List<dynamic> locationsData, {
    List<int>? userVibeAffinity,
    List<int>? userDietaryAffinity,
  }) async {
    if (locationsData.isEmpty) return [];

    // Log image source breakdown on home page load
    final total = locationsData.length;
    final fromStorage = locationsData
        .where((item) => item[SupabaseConstants.columnImageStored] == true)
        .length;
    final unavailable = locationsData
        .where((item) => item['image_unavailable'] == true)
        .length;
    final needsApi = locationsData.where((item) {
      final imageStored = item[SupabaseConstants.columnImageStored];
      final imageUnavailable = item['image_unavailable'];
      final hasPhotoRef = (item[SupabaseConstants.columnPhotoReference] ?? '').toString().isNotEmpty;
      final hasPlaceId = (item[SupabaseConstants.columnGooglePlaceId] ?? '').toString().isNotEmpty;
      return imageStored != true && imageUnavailable != true && (hasPhotoRef || hasPlaceId);
    }).length;
    final noSource = total - fromStorage - unavailable - needsApi;
    developer.log(
      '[ImageAudit] $total locations — '
      '$fromStorage from storage (free) | '
      '$needsApi need API call | '
      '$unavailable permanently unavailable (skipped) | '
      '$noSource have no image source',
      name: 'LocationHelper',
    );

    // Process in parallel — errors per-item are caught individually
    final futures = locationsData.map((item) async {
      try {
        final locationId = item[SupabaseConstants.columnLocationId] as int;

        // Check cache first
        final cached = _getFromCache(locationId);
        if (cached != null) {
          // Always refresh imageUrl even for cached locations
          // in case it was added or updated
          final imageUrl = await _getLocationImageUrl(item);
          if (imageUrl != null && imageUrl != cached.imageUrl) {
            final updated = cached.copyWith(imageUrl: imageUrl);
            _cacheLocation(updated);
            return updated;
          }
          return cached;
        }

        // Get image URL (fast path - just constructs URL)
        final imageUrl = await _getLocationImageUrl(item);
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
      return await processLocationsWithImages(response as List);
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
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Request deduplication - reuse in-flight request
    if (_activeSavedLocationsRequest != null &&
        _activeSavedLocationsRequestUserId == userId) {
      return _activeSavedLocationsRequest!;
    }

    _activeSavedLocationsRequestUserId = userId;
    _activeSavedLocationsRequest = _fetchSavedLocations(userId);
    try {
      return await _activeSavedLocationsRequest!;
    } finally {
      if (_activeSavedLocationsRequestUserId == userId) {
        _activeSavedLocationsRequest = null;
        _activeSavedLocationsRequestUserId = null;
      }
    }
  }

  Future<List<LocationModel>> _fetchSavedLocations(String userId) async {
    final stopwatch = Stopwatch()..start();
    try {
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
            .eq(SupabaseConstants.columnSupabaseId, userId)
            .maybeSingle();

        if (userProf != null) {
          final vibeRaw = userProf[SupabaseConstants.columnVibeTagAffinity];
          if (vibeRaw is List) {
            userVibeAffinity =
                List<int>.from(vibeRaw.map((e) => (e as num).toInt()));
          }

          final dietaryRaw =
              userProf[SupabaseConstants.columnDietaryRequirementTagAffinity];
          if (dietaryRaw is List) {
            userDietaryAffinity =
                List<int>.from(dietaryRaw.map((e) => (e as num).toInt()));
          }
        }
      } catch (e) {
        developer.log('[Saved] Could not fetch user affinity data: $e',
            name: 'LocationHelper');
      }

      // First get all user_location_actions with 'save' action for this user
      developer.log('[Saved] Querying saved actions for user $userId',
          name: 'LocationHelper');
      final savedActions = await _client
          .from(SupabaseConstants.tableUserLocationActions)
          .select(
            '${SupabaseConstants.columnLocationId}, '
            '${SupabaseConstants.columnSourceVideoUrl}, '
            '${SupabaseConstants.columnSavedMethod}',
          )
          .eq(SupabaseConstants.columnUserId, userId)
          .eq(SupabaseConstants.columnAction, SupabaseConstants.actionSave)
          .eq(SupabaseConstants.columnAcked, true);

      if (savedActions.isEmpty) {
        developer.log(
            '[Saved] No saved actions found (${stopwatch.elapsedMilliseconds}ms)',
            name: 'LocationHelper');
        return [];
      }

      // Build a per-locationId map of (savedFrom, savedMethod) so we can stamp
      // each LocationModel after the batch processor returns. If a user has
      // multiple save actions for the same location, the most recently seen
      // entry wins.
      final actionMetaByLocationId =
          <int, ({String? savedFrom, String? savedMethod})>{};
      final locationIds = <int>[];
      for (final action in (savedActions as List)) {
        final id = action[SupabaseConstants.columnLocationId] as int;
        if (!actionMetaByLocationId.containsKey(id)) {
          locationIds.add(id);
        }
        actionMetaByLocationId[id] = (
          savedFrom: action[SupabaseConstants.columnSourceVideoUrl] as String?,
          savedMethod: action[SupabaseConstants.columnSavedMethod] as String?,
        );
      }
      developer.log(
          '[Saved] Found ${locationIds.length} saved IDs: $locationIds',
          name: 'LocationHelper');

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
      final processed = await processLocationsWithImages(
        locations,
        userVibeAffinity: userVibeAffinity,
        userDietaryAffinity: userDietaryAffinity,
      );

      // Stamp each location with its saved-action metadata.
      final result = processed.map((loc) {
        final meta = actionMetaByLocationId[loc.locationId];
        if (meta == null) return loc;
        return loc.copyWith(
          savedFrom: meta.savedFrom,
          savedMethod: meta.savedMethod,
        );
      }).toList();

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
          .select(
            '${SupabaseConstants.columnLocationId}, '
            '${SupabaseConstants.columnSourceVideoUrl}, '
            '${SupabaseConstants.columnSavedMethod}',
          )
          .eq(SupabaseConstants.columnUserId, userId)
          .eq(SupabaseConstants.columnAction, SupabaseConstants.actionSave)
          .eq(SupabaseConstants.columnAcked, true);

      if (savedActions.isEmpty) {
        return [];
      }

      // Build a per-locationId map of (savedFrom, savedMethod) so we can stamp
      // each LocationModel after the batch processor returns.
      final actionMetaByLocationId =
          <int, ({String? savedFrom, String? savedMethod})>{};
      final locationIds = <int>[];
      for (final action in (savedActions as List)) {
        final id = action[SupabaseConstants.columnLocationId] as int;
        if (!actionMetaByLocationId.containsKey(id)) {
          locationIds.add(id);
        }
        actionMetaByLocationId[id] = (
          savedFrom: action[SupabaseConstants.columnSourceVideoUrl] as String?,
          savedMethod: action[SupabaseConstants.columnSavedMethod] as String?,
        );
      }

      if (locationIds.isEmpty) {
        return [];
      }

      // Then fetch the actual location data
      final locations = await _client
          .from(SupabaseConstants.tableLocations)
          .select()
          .inFilter(SupabaseConstants.columnLocationId, locationIds);

      // Use the efficient batch processor, then stamp action metadata.
      final processed = await processLocationsWithImages(locations as List);
      return processed.map((loc) {
        final meta = actionMetaByLocationId[loc.locationId];
        if (meta == null) return loc;
        return loc.copyWith(
          savedFrom: meta.savedFrom,
          savedMethod: meta.savedMethod,
        );
      }).toList();
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
      return await processLocationsWithImages(response as List);
    } catch (e) {
      if (kDebugMode) print('Error getting popular locations: $e');
      return [];
    }
  }

  Future<List<LocationModel>> getLocationsByIds(List<int> locationIds) async {
    try {
      if (locationIds.isEmpty) {
        return [];
      }

      final response = await _client
          .from(SupabaseConstants.tableLocations)
          .select()
          .inFilter(SupabaseConstants.columnLocationId, locationIds);

      return await processLocationsWithImages(response as List);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting locations by ids: $e');
      }
      return [];
    }
  }

  Future<List<LocationModel>> getHiddenGems({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    int maxResults = 10,
    int minReviews = 5,
  }) async {
    try {
      final uri = Uri.parse(
        'https://pinit-recommendations-api-1070859807237.europe-west2.run.app/hidden-gems',
      ).replace(queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius_km': radiusKm.toString(),
        'max_results': maxResults.toString(),
        'min_reviews': minReviews.toString(),
      });

      if (kDebugMode) print('[HiddenGems] Requesting: $uri');

      final httpResponse =
          await http.get(uri).timeout(const Duration(seconds: 30));

      if (kDebugMode) print('[HiddenGems] Status: ${httpResponse.statusCode}');

      if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
        if (kDebugMode) print('[HiddenGems] Error body: ${httpResponse.body}');
        return [];
      }

      if (kDebugMode) print('[HiddenGems] Response body: ${httpResponse.body}');

      final decoded = jsonDecode(httpResponse.body);
      final recommendations = decoded['recommendations'] as List;
      if (kDebugMode)
        print('[HiddenGems] Recommendations count: ${recommendations.length}');

      final locationIds =
          recommendations.map((r) => r['location_id'] as int).toList();
      if (kDebugMode) print('[HiddenGems] Location IDs: $locationIds');

      if (locationIds.isEmpty) {
        if (kDebugMode)
          print('[HiddenGems] No location IDs returned — empty result');
        return [];
      }

      final response = await _client
          .from(SupabaseConstants.tableLocations)
          .select()
          .inFilter(SupabaseConstants.columnLocationId, locationIds);

      if (kDebugMode)
        print('[HiddenGems] DB rows fetched: ${(response as List).length}');

      return await processLocationsWithImages(response);
    } catch (e, stack) {
      if (kDebugMode) {
        print('[HiddenGems] Exception: $e');
        print('[HiddenGems] Stack: $stack');
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
      return await processLocationsWithImages(
          uniqueLocationData.values.toList());
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching locations by user IDs: $e');
      }
      return [];
    }
  }

  /// Save a location for the current user via the
  /// `save_location_with_tags` RPC.
  ///
  /// The RPC is the single source of truth for save side-effects
  /// (action row, popularity bump, vibe affinity nudge). Vibe affinity
  /// only fires the first time a given (user, location) is saved, ever
  /// — see `user_tag_affinity_grants` for the gating.
  ///
  /// [sourceVideoUrl] is forwarded to `source_video_url` and is what
  /// powers the "Saved from this TikTok" provenance badge on the
  /// expanded card. Pass it whenever the save originates from a
  /// social-video flow.
  Future<bool> saveLocation(
    int locationId, {
    String? savedMethod,
    String? sourceVideoUrl,
  }) async {
    try {
      final user = SupabaseClientManager().currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print(
          '[LocationHelper] Saving location $locationId for user ${user.id} with method $savedMethod and sourceVideoUrl $sourceVideoUrl');
      final result = await _client.rpc('save_location_with_tags', params: {
        'p_user_id': user.id,
        'p_location_id': locationId,
        'p_saved_method': savedMethod ?? 'in-app',
        'p_acked': true,
        'p_source_video_url': sourceVideoUrl,
      });

      return result['success'] == true;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving location: $e');
      }
      return false;
    }
  }

  /// Dislike a location for the current user
  Future<bool> dislikeLocation(int locationId) async {
    try {
      final user = SupabaseClientManager().currentUser;

      if (user == null) {
        throw Exception('User not authenticated');
      }

      print(
          '[LocationHelper] Disliking location $locationId for user ${user.id}');
      final result = await _client.rpc('dislike_location_with_tags', params: {
        'p_user_id': user.id,
        'p_location_id': locationId,
      });

      return result['success'] == true;
    } catch (e) {
      if (kDebugMode) {
        print('Error disliking location: $e');
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

  /// Unsave a location for the current user via the `unsave_location`
  /// RPC.
  ///
  /// The RPC is the single source of truth for unsave side-effects:
  /// applies a stock negated vibe-affinity nudge (the inverse of
  /// save_location_with_tags' formula, using the same multiplier the
  /// original save used), deletes the action row, and decrements the
  /// popularity counter. Callers do not need a second round-trip.
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

  // Helper function to fetch photos array from Google Places API v1
  Future<List<dynamic>?> _fetchPlacePhotos(String placeId) async {
    try {
      final apiKey = dotenv.env["GOOGLE_PLACE_API_KEY"];
      if (apiKey == null || apiKey.isEmpty) {
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
        final photos = data['photos'] as List?;
        if (photos != null && photos.isNotEmpty) {
          return photos;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Method that performs the actual download (called only once per location)
  Future<String?> _performImageDownload(
      int locationId, String? photoReference, String placeId) async {
    // Step 3: Try the stored photo reference first if we have one
    if (photoReference != null && photoReference.isNotEmpty) {
      if (kDebugMode)
        print('[Image] [$locationId] Step 3: Trying stored photo_reference...');
      final permanentUrl =
          await _downloadAndUploadImage(photoReference, locationId);
      if (permanentUrl != null) {
        try {
          await _client.rpc('update_location_image_url', params: {
            'p_location_id': locationId,
            'p_image_url': permanentUrl,
          });
        } catch (e) {
          // best-effort DB update
        }
        if (kDebugMode)
          print(
              '[Image] [$locationId] Step 3: Stored photo_reference succeeded.');
        return permanentUrl;
      }
      if (kDebugMode)
        print(
            '[Image] [$locationId] Step 3: Stored photo_reference failed — falling back to google_place_id.');
    } else {
      if (kDebugMode)
        print(
            '[Image] [$locationId] Step 3: No stored photo_reference — will use google_place_id.');
    }

    // Step 4: Fetch fresh photo references from Google Places API using place ID
    if (placeId.isEmpty) {
      if (kDebugMode)
        print(
            '[Image] [$locationId] Step 4: No google_place_id available — cannot fetch image.');
      return null;
    }

    if (kDebugMode)
      print(
          '[Image] [$locationId] Step 4: Fetching photo references from Google Places API for place $placeId...');
    final freshPhotos = await _fetchPlacePhotos(placeId);
    if (freshPhotos == null || freshPhotos.isEmpty) {
      if (kDebugMode)
        print(
            '[Image] [$locationId] Step 4: Google Places API returned no photos — marking as unavailable.');
      _noImageAvailable.add(locationId);
      try {
        await _client.rpc('mark_location_image_unavailable', params: {
          'p_location_id': locationId,
        });
      } catch (e) {
        // best-effort — in-memory flag still prevents retries this session
      }
      return null;
    }

    final freshReference = freshPhotos[0]['name'] as String;
    if (kDebugMode)
      print(
          '[Image] [$locationId] Step 4: Got ${freshPhotos.length} photo reference(s). Using first: $freshReference');

    // Step 5: Save fresh references back to DB for future use
    if (kDebugMode)
      print(
          '[Image] [$locationId] Step 5: Saving fresh photo reference and photos array to DB...');
    try {
      await _client.rpc('update_location_photo_reference', params: {
        'p_location_id': locationId,
        'p_photo_reference': freshReference,
      });
      await _client.rpc('update_location_photos', params: {
        'p_location_id': locationId,
        'p_photos': jsonEncode(freshPhotos),
      });
      if (kDebugMode)
        print('[Image] [$locationId] Step 5: DB updated successfully.');
    } catch (e) {
      if (kDebugMode)
        print(
            '[Image] [$locationId] Step 5: Failed to save to DB (non-fatal): $e');
    }

    final permanentUrl =
        await _downloadAndUploadImage(freshReference, locationId);
    if (permanentUrl != null) {
      try {
        await _client.rpc('update_location_image_url', params: {
          'p_location_id': locationId,
          'p_image_url': permanentUrl,
        });
      } catch (e) {
        // best-effort DB update
      }
    }
    return permanentUrl;
  }

  // Helper function to download image from Google and upload to Supabase Storage
  Future<String?> _downloadAndUploadImage(
      String photoReference, int locationId) async {
    try {
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
      final imageBytes = response.bodyBytes; // The actual image data

      // 3. Upload image bytes to Supabase Storage.
      // upsert: true so a pre-existing file (e.g. from a previous session where
      // the RPC failed) doesn't throw a 409 and break the image_stored write.
      await _client.storage
          .from('location_photos')
          .uploadBinary(
            filename,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final permanentUrl = _client.storage
          .from('location_photos')
          .getPublicUrl(filename);
      return permanentUrl;
    } catch (e) {
      print('[Image] [$locationId] Upload failed: $e');
      return null;
    }
  }

  // Helper function to try fetching image from Google Places API v1 media endpoint
  Future<String?> _tryMediaApi(String photoReference) async {
    try {
      final apiKey = dotenv.env["GOOGLE_PLACE_API_KEY"];
      if (apiKey == null || apiKey.isEmpty) {
        return null;
      }

      final url =
          'https://places.googleapis.com/v1/$photoReference/media?maxHeightPx=400&maxWidthPx=400&key=$apiKey';

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
            return redirectUrl;
          }
        }

        // If it's a direct 200, the URL itself might be usable
        if (streamedResponse.statusCode == 200) {
          return url;
        }

        return null;
      } finally {
        client.close();
      }
    } catch (e) {
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
    _activeSavedLocationsRequest = null;
    _activeSavedLocationsRequestUserId = null;
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

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:login/services/analytics_service.dart';

import '../constants.dart';
import '../../models/locations.dart';
import '../../models/video_extras.dart';
import '../supabase_client.dart';

// Service for handling Supabase location operations
class LocationHelper {
  final SupabaseClient _client = SupabaseClientManager().client;
  final AnalyticsService _analyticsService = AnalyticsService();
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
  // Authoritative state lives in the DB:
  //   image_stored=true        -> `{id}.jpg` exists in Supabase Storage
  //   image_unavailable=true   -> Google returned no photos; never retry
  //   photos jsonb             -> cached list of photo resource names from
  //                               a previous Place Details call (avoids
  //                               paying for another one)
  //   extra_photos_stored      -> how many `{id}_1.jpg`..`{id}_N.jpg` extras
  //                               are in storage for the expanded card
  //
  // Every fetched list row must include image_stored / image_unavailable in
  // its SELECT, otherwise this check sees null and refires the download.
  // See `get_locations_with_quality` and the photo pipeline migration.
  Future<String?> _getLocationImageUrl(
      Map<String, dynamic> locationData) async {
    final locationId = locationData[SupabaseConstants.columnLocationId] as int;
    final filename = '$locationId.jpg';

    final publicUrl =
        _client.storage.from('location_photos').getPublicUrl(filename);

    if (locationData[SupabaseConstants.columnImageStored] == true) {
      return publicUrl;
    }

    if (locationData[SupabaseConstants.columnImageUnavailable] == true) {
      _noImageAvailable.add(locationId);
      return null;
    }

    final googlePlaceId = locationData[SupabaseConstants.columnGooglePlaceId];
    final hasPlaceId =
        googlePlaceId != null && googlePlaceId.toString().isNotEmpty;
    if (!hasPlaceId || _noImageAvailable.contains(locationId)) {
      return null;
    }

    // Pass the cached `photos` jsonb through so we can skip the Details call
    // for any row that was populated by a prior download.
    final cachedPhotos =
        _coercePhotosJson(locationData[SupabaseConstants.columnPhotos]);

    _ensureImageUploaded(
      locationId: locationId,
      googlePlaceId: googlePlaceId.toString(),
      cachedPhotos: cachedPhotos,
    );

    return publicUrl;
  }

  /// Coerce the `photos` column (which may come back as List<dynamic> of
  /// maps, or a JSON string depending on the transport) into a typed list.
  List<Map<String, dynamic>>? _coercePhotosJson(dynamic raw) {
    if (raw == null) return null;
    try {
      if (raw is String) {
        if (raw.isEmpty) return null;
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
        return null;
      }
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return null;
  }

  /// Fire-and-forget background task: ensures the primary photo for this
  /// location ends up in Supabase Storage. Deduped via `_activeDownloads`.
  Future<void> _ensureImageUploaded({
    required int locationId,
    required String googlePlaceId,
    List<Map<String, dynamic>>? cachedPhotos,
  }) async {
    if (_noImageAvailable.contains(locationId)) return;
    if (_activeDownloads.containsKey(locationId)) return;

    final future = _performImageDownload(
      locationId: locationId,
      placeId: googlePlaceId,
      cachedPhotos: cachedPhotos,
    );
    _activeDownloads[locationId] = future;
    try {
      await future;
    } catch (_) {
      // background — swallow
    } finally {
      _activeDownloads.remove(locationId);
    }
  }

  /// Process a list of location JSON objects into LocationModel list.
  /// Handles image URLs efficiently with parallel processing.
  /// Individual location parsing errors are caught and logged so one bad
  /// row does not kill the entire batch.
  /// Optionally calculates match scores using user affinity vectors.
  Future<List<LocationModel>> processLocationsWithImages(
    List<dynamic> locationsData, {
    List<double>? userVibeAffinity,
    List<int>? userDietaryAffinity,
  }) async {
    if (locationsData.isEmpty) return [];

    // Log image source breakdown on home page load
    final total = locationsData.length;
    final fromStorage = locationsData
        .where((item) => item[SupabaseConstants.columnImageStored] == true)
        .length;
    final unavailable =
        locationsData.where((item) => item['image_unavailable'] == true).length;
    final needsApi = locationsData.where((item) {
      final imageStored = item[SupabaseConstants.columnImageStored];
      final imageUnavailable = item['image_unavailable'];
      final hasPhotoRef = (item[SupabaseConstants.columnPhotoReference] ?? '')
          .toString()
          .isNotEmpty;
      final hasPlaceId = (item[SupabaseConstants.columnGooglePlaceId] ?? '')
          .toString()
          .isNotEmpty;
      return imageStored != true &&
          imageUnavailable != true &&
          (hasPhotoRef || hasPlaceId);
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

        // Check cache first. Only re-resolve the image URL if the cached
        // entry doesn't already have one — otherwise every list refresh
        // re-fires the background download pipeline for every visible
        // location, which was a major source of Google Places API spam.
        final cached = _getFromCache(locationId);
        if (cached != null) {
          if (cached.imageUrl != null && cached.imageUrl!.isNotEmpty) {
            return cached;
          }
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

  /// Streaming variant of [processLocationsWithImages]. Emits each
  /// [LocationModel] as its parse + image-URL resolution completes, instead
  /// of blocking on the whole batch. Designed for search suggestions where
  /// perceived latency matters more than list stability. Items arrive in
  /// completion order, so cache-hot rows appear first.
  ///
  /// No affinity scoring — see the comment in the repo call site for why
  /// we skip it for transient suggestions.
  Stream<LocationModel> streamLocationsWithImages(
    List<dynamic> locationsData,
  ) {
    if (locationsData.isEmpty) {
      return const Stream<LocationModel>.empty();
    }

    final futures = locationsData.map<Future<LocationModel?>>((item) async {
      try {
        final locationId = item[SupabaseConstants.columnLocationId] as int;

        final cached = _getFromCache(locationId);
        if (cached != null) {
          if (cached.imageUrl != null && cached.imageUrl!.isNotEmpty) {
            return cached;
          }
          final imageUrl = await _getLocationImageUrl(item);
          if (imageUrl != null && imageUrl != cached.imageUrl) {
            final updated = cached.copyWith(imageUrl: imageUrl);
            _cacheLocation(updated);
            return updated;
          }
          return cached;
        }

        final imageUrl = await _getLocationImageUrl(item);
        final location = LocationModel.fromJson(item, imageUrl);
        _cacheLocation(location);
        return location;
      } catch (_) {
        return null;
      }
    });

    // Stream.fromFutures emits in completion order — fast items (cache
    // hits, rows with image_stored=true) surface first.
    return Stream<LocationModel?>.fromFutures(futures)
        .where((loc) => loc != null)
        .cast<LocationModel>();
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
      List<double>? userVibeAffinity;
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
            userVibeAffinity = <double>[
              for (final e in vibeRaw) (e as num).toDouble(),
            ];
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
      final actionMetaByLocationId = <int,
          ({
        String? savedFrom,
        String? savedMethod,
        VideoExtras? videoExtras
      })>{};
      final locationIds = <int>[];
      for (final action in (savedActions as List)) {
        final id = action[SupabaseConstants.columnLocationId] as int;
        if (!actionMetaByLocationId.containsKey(id)) {
          locationIds.add(id);
        }
        final rawExtras = action[SupabaseConstants.columnVideoExtras];
        actionMetaByLocationId[id] = (
          savedFrom: action[SupabaseConstants.columnSourceVideoUrl] as String?,
          savedMethod: action[SupabaseConstants.columnSavedMethod] as String?,
          videoExtras: rawExtras is Map<String, dynamic>
              ? VideoExtras.fromJson(rawExtras)
              : null,
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
          videoExtras: meta.videoExtras,
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
            '${SupabaseConstants.columnSavedMethod}, '
            '${SupabaseConstants.columnVideoExtras}',
          )
          .eq(SupabaseConstants.columnUserId, userId)
          .eq(SupabaseConstants.columnAction, SupabaseConstants.actionSave)
          .eq(SupabaseConstants.columnAcked, true);

      if (savedActions.isEmpty) {
        return [];
      }

      // Build a per-locationId map of (savedFrom, savedMethod) so we can stamp
      // each LocationModel after the batch processor returns.
      final actionMetaByLocationId = <int,
          ({
        String? savedFrom,
        String? savedMethod,
        VideoExtras? videoExtras
      })>{};
      final locationIds = <int>[];
      for (final action in (savedActions as List)) {
        final id = action[SupabaseConstants.columnLocationId] as int;
        if (!actionMetaByLocationId.containsKey(id)) {
          locationIds.add(id);
        }
        final rawExtras = action[SupabaseConstants.columnVideoExtras];
        actionMetaByLocationId[id] = (
          savedFrom: action[SupabaseConstants.columnSourceVideoUrl] as String?,
          savedMethod: action[SupabaseConstants.columnSavedMethod] as String?,
          videoExtras: rawExtras is Map<String, dynamic>
              ? VideoExtras.fromJson(rawExtras)
              : null,
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
          videoExtras: meta.videoExtras,
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
    int minReviews = 50,
  }) async {
    try {
      final uri = Uri.parse(
        'https://pinit-recommendations-api-jkqbw4i75a-nw.a.run.app/hidden-gems',
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

      final success = result['success'] == true;
      if (success) {
        _analyticsService.trackFeature(
          'location_saved',
          featureName: 'save_location',
          properties: <String, dynamic>{
            'location_id': locationId,
            'saved_method': savedMethod ?? 'in-app',
            'has_source_video':
                sourceVideoUrl != null && sourceVideoUrl.isNotEmpty,
          },
          registerTap: true,
          interactionKey: 'location_saved',
        );
      }
      return success;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving location: $e');
      }
      _analyticsService.recordError(
        key: 'save_location_error',
        properties: <String, dynamic>{'location_id': locationId},
      );
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

      final success = result['success'] == true;
      if (success) {
        _analyticsService.trackFeature(
          'location_disliked',
          featureName: 'dislike_location',
          properties: <String, dynamic>{'location_id': locationId},
          registerTap: true,
          interactionKey: 'location_disliked',
        );
      }
      return success;
    } catch (e) {
      if (kDebugMode) {
        print('Error disliking location: $e');
      }
      _analyticsService.recordError(
        key: 'dislike_location_error',
        properties: <String, dynamic>{'location_id': locationId},
      );
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

  /// Public entry point used by callers that only know the placeId +
  /// (optional) photo_reference hint. The photo_reference argument is kept
  /// for signature compatibility but is ignored — stored references expire
  /// and are unreliable, so we always drive from the cached `photos` jsonb
  /// or (failing that) a one-time Place Details call.
  Future<String?> getLocationImage(
      int locationId, String google_place_id, String? photoReference) async {
    if (_activeDownloads.containsKey(locationId)) {
      return _activeDownloads[locationId];
    }
    final future = _performImageDownload(
      locationId: locationId,
      placeId: google_place_id,
      cachedPhotos: null,
    );
    _activeDownloads[locationId] = future;
    try {
      return await future;
    } finally {
      _activeDownloads.remove(locationId);
    }
  }

  /// Call Google Places Details v1 with a minimal field mask (`id,photos`)
  /// and return the `photos` array. One call = one billable Pro-SKU hit, so
  /// this should only ever be invoked when we don't already have the array
  /// cached in the DB `photos` column.
  Future<List<Map<String, dynamic>>?> _fetchPlacePhotos(String placeId) async {
    try {
      final apiKey = dotenv.env["GOOGLE_PLACE_API_KEY"];
      if (apiKey == null || apiKey.isEmpty) return null;

      final response = await http.get(
        Uri.parse('https://places.googleapis.com/v1/places/$placeId'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask': 'id,photos',
        },
      );
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final photos = data['photos'];
      if (photos is! List || photos.isEmpty) return null;
      return photos
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Core download pipeline. Guaranteed to be called at most once per
  /// location-per-session because every public entry point wraps it in
  /// `_activeDownloads`. Flow:
  ///
  ///   1. Pick the source for photo resource names, in priority order:
  ///        a. cachedPhotos passed in from a list row (zero Google cost)
  ///        b. Place Details API (1 billable call)
  ///   2. If no photos available -> mark_location_image_unavailable, bail.
  ///   3. Download photo[0] via the Media API, upload as `{id}.jpg`.
  ///   4. Persist photos + flag via `mark_location_image_uploaded` RPC.
  ///
  /// After this succeeds, `image_stored=true` so every future list fetch
  /// short-circuits in `_getLocationImageUrl` with zero Google calls.
  Future<String?> _performImageDownload({
    required int locationId,
    required String placeId,
    List<Map<String, dynamic>>? cachedPhotos,
  }) async {
    List<Map<String, dynamic>>? photos = cachedPhotos;

    if (photos == null || photos.isEmpty) {
      if (placeId.isEmpty) {
        if (kDebugMode) {
          print('[Image] [$locationId] No placeId and no cached photos.');
        }
        return null;
      }
      if (kDebugMode) {
        print(
            '[Image] [$locationId] Calling Place Details for place $placeId...');
      }
      photos = await _fetchPlacePhotos(placeId);
      if (photos == null || photos.isEmpty) {
        if (kDebugMode) {
          print(
              '[Image] [$locationId] Place Details returned no photos — marking unavailable.');
        }
        _noImageAvailable.add(locationId);
        try {
          await _client.rpc('mark_location_image_unavailable',
              params: {'p_location_id': locationId});
        } catch (_) {}
        return null;
      }
    } else if (kDebugMode) {
      print(
          '[Image] [$locationId] Using ${photos.length} cached photo ref(s) — skipping Place Details.');
    }

    final firstReference = photos[0]['name'] as String?;
    if (firstReference == null || firstReference.isEmpty) return null;

    final permanentUrl =
        await _downloadAndUploadImage(firstReference, locationId);
    if (permanentUrl == null) return null;

    try {
      await _client.rpc('mark_location_image_uploaded', params: {
        'p_location_id': locationId,
        'p_photos': photos,
        'p_photo_reference': firstReference,
      });
      if (kDebugMode) {
        print('[Image] [$locationId] Upload complete, image_stored=true.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[Image] [$locationId] mark_location_image_uploaded failed: $e');
      }
    }
    return permanentUrl;
  }

  // ==================== EXPANDED CARD GALLERY ====================
  /// Returns the list of Supabase Storage URLs for every photo we have
  /// stored for this location — primary first, then `_1`, `_2`, … up to
  /// `extra_photos_stored`.
  ///
  /// If the DB `photos` jsonb has more entries than we've persisted yet,
  /// this lazily fetches the missing ones via the Media API, uploads them
  /// to storage, and bumps `extra_photos_stored`. After the first open of
  /// an expanded card, every subsequent open is zero Google calls.
  ///
  /// Cost model (per-location, lifetime):
  ///   first open with 10 photos  -> up to 9 Media calls  (~$0.063)
  ///   every open after that      -> 0 Google calls
  ///
  /// `maxPhotos` caps how many extras we'll ever fetch; Google's photos
  /// array is typically 10 entries, which is the sensible default.
  /// Fetches every photo we can for the expanded card, with maximum
  /// parallelism and progressive delivery. The [onPartial] callback fires
  /// each time a new contiguous prefix of photos is ready, so the UI can
  /// render photo 0 as soon as it lands and progressively fill the
  /// carousel as 1, 2, 3 … arrive.
  ///
  /// Latency model:
  ///   - primary already in storage: 0 network round-trips for photo 0
  ///   - primary not in storage:     1 Place Details + 1 Media (serial),
  ///                                 then all extras Media calls in
  ///                                 parallel (single RTT cost, not N)
  ///   - primary in storage, extras missing: all extras in parallel
  ///
  /// On-device caching: every emitted URL is a Supabase Storage public
  /// URL, which [CachedNetworkImage] persists to the app's sandboxed
  /// cache directory on first display (iOS `NSCachesDirectory`, Android
  /// app-private cache). Subsequent opens read from disk with no network.
  Future<List<String>> fetchExpandedCardPhotos(
    LocationModel location, {
    int maxPhotos = 10,
    void Function(List<String> contiguousPrefix)? onPartial,
  }) async {
    final locationId = location.locationId;
    final bucket = _client.storage.from('location_photos');

    if (kDebugMode) {
      print(
          '[Gallery] [$locationId] open: image_stored=${location.imageStored}, '
          'photos_cached=${location.photos?.length ?? 0}, '
          'extras_stored=${location.extraPhotosStored ?? 0}, '
          'place_id=${location.googlePlaceId}');
    }

    // Wait out any background primary-photo download so we don't race it.
    final inflight = _activeDownloads[locationId];
    if (inflight != null) {
      try {
        await inflight;
      } catch (_) {}
    }

    // ─── Resolve photos metadata (Place Details only if jsonb empty) ────
    List<Map<String, dynamic>>? photosJson = location.photos;
    if (photosJson == null || photosJson.isEmpty) {
      final placeId = location.googlePlaceId;
      if (placeId == null || placeId.isEmpty) {
        if (kDebugMode) {
          print('[Gallery] [$locationId] No photos and no place_id.');
        }
        if (location.imageStored == true) {
          final only = [bucket.getPublicUrl('$locationId.jpg')];
          onPartial?.call(only);
          return only;
        }
        return const [];
      }
      if (kDebugMode) {
        print('[Gallery] [$locationId] Calling Place Details (one-time)...');
      }
      photosJson = await _fetchPlacePhotos(placeId);
      if (photosJson == null || photosJson.isEmpty) {
        if (kDebugMode) {
          print(
              '[Gallery] [$locationId] Place Details returned no photos — marking unavailable.');
        }
        _noImageAvailable.add(locationId);
        try {
          await _client.rpc('mark_location_image_unavailable',
              params: {'p_location_id': locationId});
        } catch (_) {}
        return const [];
      }
    }

    final desired =
        photosJson.length < maxPhotos ? photosJson.length : maxPhotos;
    if (desired == 0) return const [];

    // Sparse map keyed by index; we build the contiguous prefix on the
    // fly. Concurrent completions mutate this under a single isolate's
    // event loop, so no explicit locking is required.
    final results = <int, String>{};

    List<String> contiguousPrefix() {
      final out = <String>[];
      for (var i = 0; i < desired; i++) {
        final v = results[i];
        if (v == null) break;
        out.add(v);
      }
      return out;
    }

    void emit() {
      if (onPartial != null) onPartial(contiguousPrefix());
    }

    // ─── Seed anything we can resolve for free from storage ─────────────
    if (location.imageStored == true) {
      results[0] = bucket.getPublicUrl('$locationId.jpg');
    }
    var alreadyStored = location.extraPhotosStored ?? 0;
    if (alreadyStored > desired - 1) alreadyStored = desired - 1;
    for (var i = 1; i <= alreadyStored; i++) {
      results[i] = bucket.getPublicUrl('${locationId}_$i.jpg');
    }
    if (results.isNotEmpty) emit();

    // ─── Identify the indices that still need a Media round-trip ────────
    final needsFetch = <int>[];
    if (results[0] == null) needsFetch.add(0);
    for (var i = alreadyStored + 1; i <= desired - 1; i++) {
      needsFetch.add(i);
    }

    if (needsFetch.isEmpty) {
      return contiguousPrefix();
    }

    if (kDebugMode) {
      print('[Gallery] [$locationId] Fetching indices $needsFetch in parallel');
    }

    // ─── Kick every missing index off in parallel ───────────────────────
    // One of them may be index 0, which needs the primary-filename upload
    // path + mark_location_image_uploaded RPC. The rest get the
    // extras path + mark_location_extra_photos_stored at the end.
    bool primaryWasFetched = false;
    final futures = <Future<void>>[];
    for (final i in needsFetch) {
      final ref = photosJson[i]['name'] as String?;
      if (ref == null || ref.isEmpty) continue;

      futures.add(() async {
        final url = i == 0
            ? await _downloadAndUploadImage(ref, locationId)
            : await _downloadAndUploadExtraPhoto(
                photoReference: ref,
                locationId: locationId,
                index: i,
              );
        if (url != null) {
          results[i] = url;
          if (i == 0) primaryWasFetched = true;
          emit();
        }
      }());
    }

    await Future.wait(futures);

    // ─── Persist state back to the DB ───────────────────────────────────
    // Primary upload → mark_location_image_uploaded. We only call this if
    // we had to actually fetch the primary; otherwise image_stored was
    // already true and the photos jsonb is already persisted.
    if (primaryWasFetched) {
      final primaryRef = photosJson[0]['name'] as String?;
      try {
        await _client.rpc('mark_location_image_uploaded', params: {
          'p_location_id': locationId,
          'p_photos': photosJson,
          'p_photo_reference': primaryRef,
        });
      } catch (e) {
        if (kDebugMode) {
          print(
              '[Gallery] [$locationId] mark_location_image_uploaded failed: $e');
        }
      }
    }

    // Count the largest contiguous run of extras we now have, to bump
    // extra_photos_stored. Because uploads land in parallel a failure at
    // any one index leaves a gap — we intentionally only count up to the
    // gap so next open can retry the hole (which is a Media call at most,
    // not a billed Details call).
    var highestContiguousExtra = 0;
    for (var i = 1; i <= desired - 1; i++) {
      if (results[i] == null) break;
      highestContiguousExtra = i;
    }
    if (highestContiguousExtra > alreadyStored) {
      try {
        await _client.rpc('mark_location_extra_photos_stored', params: {
          'p_location_id': locationId,
          'p_count': highestContiguousExtra,
        });
        if (kDebugMode) {
          print(
              '[Gallery] [$locationId] extras_stored updated to $highestContiguousExtra');
        }
      } catch (e) {
        if (kDebugMode) {
          print(
              '[Gallery] [$locationId] mark_location_extra_photos_stored failed: $e');
        }
      }
    }

    return contiguousPrefix();
  }

  /// Fetch one extra photo via the Media API and upload it as
  /// `{locationId}_{index}.jpg`. Returns the public URL on success.
  Future<String?> _downloadAndUploadExtraPhoto({
    required String photoReference,
    required int locationId,
    required int index,
  }) async {
    try {
      final tempImageUrl = await _tryMediaApi(photoReference);
      if (tempImageUrl == null) return null;

      final response = await http.get(Uri.parse(tempImageUrl));
      if (response.statusCode != 200) return null;

      final filename = '${locationId}_$index.jpg';
      await _client.storage.from('location_photos').uploadBinary(
            filename,
            response.bodyBytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return _client.storage.from('location_photos').getPublicUrl(filename);
    } catch (e) {
      if (kDebugMode) {
        print('[Image] [$locationId] Extra photo #$index upload failed: $e');
      }
      return null;
    }
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
      await _client.storage.from('location_photos').uploadBinary(
            filename,
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final permanentUrl =
          _client.storage.from('location_photos').getPublicUrl(filename);
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

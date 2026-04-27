import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import '../constants.dart';
import '../../models/locations.dart';
import 'location.dart';

class CollectionItem {
  final String collectionId;
  final String name;
  final String? emoji;
  final String? coverColor;
  final String? photo;
  final int placeCount;
  final String? ownerName;
  final String? ownerAvatarUrl;

  const CollectionItem({
    required this.collectionId,
    required this.name,
    this.emoji,
    this.coverColor,
    this.photo,
    required this.placeCount,
    this.ownerName,
    this.ownerAvatarUrl,
  });

  factory CollectionItem.fromJson(Map<String, dynamic> json) => CollectionItem(
        collectionId: json['collection_id'] as String,
        name: json['name'] as String,
        emoji: json['emoji'] as String?,
        coverColor: json['cover_color'] as String?,
        photo: json['photo'] as String?,
        placeCount: (json['place_count'] as num).toInt(),
        ownerName: json['owner_name'] as String?,
        ownerAvatarUrl: json['owner_avatar_url'] as String?,
      );
}

class GenerateCollectionsResult {
  final bool success;
  final int collectionsCreated;

  const GenerateCollectionsResult({
    required this.success,
    required this.collectionsCreated,
  });

  factory GenerateCollectionsResult.fromJson(Map<String, dynamic> json) =>
      GenerateCollectionsResult(
        success: json['success'] as bool,
        collectionsCreated: (json['collections_created'] as num).toInt(),
      );
}

class CollectionsGenerationException implements Exception {
  final String message;
  const CollectionsGenerationException(this.message);
  @override
  String toString() => message;
}

class CollectionsHelper {
  static const String _serviceUrl =
      'https://collections-generator-jkqbw4i75a-ew.a.run.app';

  final SupabaseClient _client = SupabaseClientManager().client;
  final http.Client _http;

  CollectionsHelper({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// Load collections for [userId] via the get_user_collections RPC.
  /// Throws on failure so the caller can show an appropriate error state.
  Future<List<CollectionItem>> getUserCollections(String userId) async {
    debugPrint('[CollectionsHelper] getUserCollections — calling RPC for $userId');
    final response = await _client.rpc(
      'get_user_collections',
      params: {'p_user_id': userId},
    );
    debugPrint('[CollectionsHelper] raw response type: ${response.runtimeType}');
    debugPrint('[CollectionsHelper] raw response: $response');
    final items = (response as List)
        .map((row) => CollectionItem.fromJson(row as Map<String, dynamic>))
        .toList();
    debugPrint('[CollectionsHelper] parsed ${items.length} collections');
    return items;
  }

  /// Fetch full [LocationModel] objects for all locations in [collectionId].
  /// The RPC now returns all location columns directly, so no second query needed.
  Future<List<LocationModel>> getLocationsForCollection(String collectionId) async {
    debugPrint('[CollectionsHelper] getLocationsForCollection $collectionId');

    final rows = await _client.rpc(
      'get_locations_in_collection',
      params: {'p_collection_id': collectionId},
    ) as List;

    debugPrint('[CollectionsHelper] got ${rows.length} location rows');

    if (rows.isEmpty) return [];

    return LocationHelper().processLocationsWithImages(rows);
  }

  Future<GenerateCollectionsResult> _callGenerationEndpoint(
      String endpoint, String userId) async {
    final uri = Uri.parse('$_serviceUrl/$endpoint');
    final session = _client.auth.currentSession;
    if (session == null) throw CollectionsGenerationException('Not logged in');

    final response = await _http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
          body: jsonEncode({'user_id': userId}),
        )
        .timeout(const Duration(seconds: 90));

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CollectionsGenerationException(
          'Authentication failed. Please log in again.');
    }
    if (response.statusCode == 422) {
      throw CollectionsGenerationException(
          decoded['error'] as String? ?? 'Not enough saved locations');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CollectionsGenerationException(
          decoded['error'] as String? ?? 'Generation failed');
    }
    return GenerateCollectionsResult.fromJson(decoded);
  }

  Future<GenerateCollectionsResult> generateCollections(String userId) =>
      _callGenerationEndpoint('generate-collections', userId);

  Future<GenerateCollectionsResult> autoUpdateCollections(String userId) =>
      _callGenerationEndpoint('auto-update-collections', userId);

  /// Upload a cover photo and return its public URL.
  Future<String> uploadCollectionCover(String collectionId, File file) async {
    final ext = file.path.split('.').last;
    final path = '$collectionId/cover.$ext';
    await _client.storage
        .from(SupabaseConstants.supabaseStorageBucketCollectionCovers)
        .upload(path, file, fileOptions: const FileOptions(upsert: true));
    return _client.storage
        .from(SupabaseConstants.supabaseStorageBucketCollectionCovers)
        .getPublicUrl(path);
  }

  /// Delete a collection the current user owns. The DB-side RPC refuses
  /// to delete the auto-generated "Been To" and "Shared Finds" collections.
  /// Throws on failure with the server error message.
  Future<void> deleteCollection(String collectionId) async {
    final response = await _client.rpc(
      'delete_collection',
      params: {'p_collection_id': collectionId},
    );
    final result = Map<String, dynamic>.from(response as Map);
    if (result['success'] != true) {
      throw Exception(result['error'] as String? ?? 'Failed to delete collection');
    }
  }

  /// Update a collection's name and cover_color (stores photo URL).
  Future<void> updateCollection({
    required String collectionId,
    required String name,
    String? coverColor,
  }) async {
    await _client.rpc('update_collection', params: {
      'p_collection_id': collectionId,
      'p_name': name,
      'p_cover_color': coverColor,
    });
  }

  /// Load the public collections belonging to a specific user.
  Future<List<CollectionItem>> getUserPublicCollections(String userId) async {
    debugPrint('[CollectionsHelper] getUserPublicCollections — calling RPC for $userId');
    final response = await _client.rpc(
      'get_user_public_collections',
      params: {'p_user_id': userId},
    );
    final items = (response as List)
        .map((row) => CollectionItem.fromJson(row as Map<String, dynamic>))
        .toList();
    debugPrint('[CollectionsHelper] parsed ${items.length} public collections');
    return items;
  }

  /// Load public collections from friends (people the current user follows).
  Future<List<CollectionItem>> getFriendsCollections(String userId) async {
    debugPrint('[CollectionsHelper] getFriendsCollections — calling RPC for $userId');
    final response = await _client.rpc(
      'get_other_collections',
      params: {'p_user_id': userId},
    );
    final items = (response as List)
        .map((row) => CollectionItem.fromJson(row as Map<String, dynamic>))
        .toList();
    debugPrint('[CollectionsHelper] parsed ${items.length} friends collections');
    return items;
  }
}

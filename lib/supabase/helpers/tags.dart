import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../supabase_client.dart';

/// Service for handling Supabase tags operations
class TagsHelper {
  final SupabaseClient _client = SupabaseClientManager().client;  

  /// Get all tags, optionally filtered by type
  Future<List<Map<String, dynamic>>> getAllTags({String? tagType}) async {
    try {
      var query = _client
          .from(SupabaseConstants.tableTags)
          .select();

      if (tagType != null) {
        query = query.eq(SupabaseConstants.columnTagType, tagType);
      }

      final response = await query.order(SupabaseConstants.columnText, ascending: true);

      if (kDebugMode) {
        print('Tags response: $response');
      }

      if ((response as List).isEmpty) {
        return [];
      }

      return (response as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting all tags: $e');
      }
      return [];
    }
  }

  /// Get tags of a specific type
  Future<List<Map<String, dynamic>>> getTagsByType(String tagType) async {
    return getAllTags(tagType: tagType);
  }

  /// Get all dietary requirement tags
  Future<List<Map<String, dynamic>>> getDietaryRequirementTags() async {
    return await getTagsByType(SupabaseConstants.tagTypeDietaryRequirement);
  }

  /// Get all vibe tags
  Future<List<Map<String, dynamic>>> getVibeTags() async {
    return await getTagsByType(SupabaseConstants.tagTypeVibe);
  }

  /// Get all cuisine tags
  Future<List<Map<String, dynamic>>> getCuisineTags() async {
    return await getTagsByType(SupabaseConstants.tagTypeCuisine);
  }

  /// Get a single tag by its ID
  Future<Map<String, dynamic>?> getTagById(int tagId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableTags)
          .select()
          .eq(SupabaseConstants.columnTagId, tagId)
          .maybeSingle();

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting tag by ID: $e');
      }
      return null;
    }
  }

  /// Search tags by text, optionally filtered by type
  Future<List<Map<String, dynamic>>> searchTags(String query,
      {String? tagType}) async {
    try {
      if (query.isEmpty) return [];

      var supabaseQuery = _client
          .from(SupabaseConstants.tableTags)
          .select()
          .ilike(SupabaseConstants.columnText, '%$query%')
          .order(SupabaseConstants.columnText, ascending: true);


      final response = await supabaseQuery;

      if ((response as List).isEmpty) {
        return [];
      }

      return (response as List)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error searching tags: $e');
      }
      return [];
    }
  }

  /// Get tags used by the most users
  Future<List<Map<String, dynamic>>> getPopularTagsByUsers(
      {String? tagType, int limit = 10}) async {
    try {
      var query = _client.from(SupabaseConstants.tableUserTags).select('''
            ${SupabaseConstants.columnTagId},
            ${SupabaseConstants.columnUserId},
            ${SupabaseConstants.tableTags}!inner(
              ${SupabaseConstants.columnTagId},
              ${SupabaseConstants.columnText},
              ${SupabaseConstants.columnPromptDescription},
              ${SupabaseConstants.columnTagType}
            )
          ''');

      if (tagType != null) {
        query = query.eq(
            '${SupabaseConstants.tableTags}.${SupabaseConstants.columnTagType}',
            tagType);
      }

      final response = await query;

      if ((response as List).isEmpty) {
        return [];
      }

      // Count distinct users for each tag
      final Map<int, Map<String, dynamic>> tagUserCounts = {};
      for (var item in response as List) {
        final tagId = item[SupabaseConstants.columnTagId] as int;
        final userId = item[SupabaseConstants.columnUserId] as String;
        final tag =
            item[SupabaseConstants.tableTags] as Map<String, dynamic>;

        if (tagUserCounts.containsKey(tagId)) {
          // Add user to the set of unique users
          (tagUserCounts[tagId]!['user_ids'] as Set<String>).add(userId);
        } else {
          tagUserCounts[tagId] = {
            'tag_id': tag[SupabaseConstants.columnTagId],
            'text': tag[SupabaseConstants.columnText],
            'prompt_description': tag[SupabaseConstants.columnPromptDescription],
            'tag_type': tag[SupabaseConstants.columnTagType],
            'user_ids': {userId},
          };
        }
      }

      // Convert to list with user count
      final tagList = tagUserCounts.values.map((tag) {
        return {
          'tag_id': tag['tag_id'],
          'text': tag['text'],
          'prompt_description': tag['prompt_description'],
          'tag_type': tag['tag_type'],
          'user_count': (tag['user_ids'] as Set<String>).length,
        };
      }).toList();

      // Sort by user count and limit
      tagList.sort(
          (a, b) => (b['user_count'] as int).compareTo(a['user_count'] as int));

      return tagList.take(limit).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting popular tags by users: $e');
      }
      return [];
    }
  }

  // Initalise all vibe tags for a user
  Future<bool> initializeVibeTagsForUser(String userId) async {
   try {
      await _client.rpc('initialize_vibe_tags_for_user', params: {
        'p_user_id': userId,
      });

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing vibe tags for user: $e');
      }
      return false;
    }
  }

  // Canonical vibe tag order — must stay in sync with the comment on
  // users.vibe_tag_affinity (see remote_schema.sql). Duplicated here
  // because the server-side update_user_tag_affinity RPC writes to the
  // wrong table (profiles) and no replacement RPC targets users.vibe_tag_affinity
  // directly from a (tag_id, affinity) pair.
  static const List<String> _vibeTagOrder = [
    'cafe', 'casual', 'cozy', 'coffee_shop', 'bar',
    'elegant', 'fine_dining', 'food_truck', 'hole_in_the_wall', 'late_night',
    'live_music', 'bougie', 'modern', 'fast_food', 'quiet',
    'romantic', 'sports_bar', 'trendy', 'takeout_friendly', 'pub',
    'shop', 'brunch', 'outdoor_dining', 'wavy', 'bossman',
  ];

  /// Writes vibe affinities (80 per selected tag) directly onto users.vibe_tag_affinity.
  /// Called from the signup wizard vibe step so downstream proximal recommendation
  /// calls see the user's vibe vector before they're fetched.
  ///
  /// Implementation notes:
  /// - We don't read the existing vector because during signup the user has
  ///   just been initialized with defaults; overwriting is fine.
  /// - We write integers (not doubles) so we don't have to guess the column's
  ///   element type — Postgres accepts int literals for both integer[] and real[].
  Future<bool> updateUserTagsPhotos(String userId, List<String> vibeTagIds) async {
    if (vibeTagIds.isEmpty) return true;
    try {
      // 1. Resolve tag names for the supplied tag_ids.
      final tagRows = await _client
          .from(SupabaseConstants.tableTags)
          .select('${SupabaseConstants.columnTagId}, text')
          .inFilter(SupabaseConstants.columnTagId, vibeTagIds);

      final tagNames = <String>{};
      for (final row in tagRows as List) {
        final name = row['text'];
        if (name is String) tagNames.add(name);
      }
      print('updateUserTagsPhotos: resolved tag names: $tagNames');
      if (tagNames.isEmpty) return false;

      // 2. Build a fresh default vector (matches initialize_vibe_tags_for_user).
      //    Column is real[] so we write doubles end-to-end — no rounding.
      final affinity = List<double>.filled(_vibeTagOrder.length, 50.0);
      affinity[20] = 0.0; // grocery_store

      // 3. Bump matched indices to 80.
      var applied = 0;
      for (final name in tagNames) {
        final idx = _vibeTagOrder.indexOf(name);
        if (idx >= 0) {
          affinity[idx] = 80.0;
          applied++;
        }
      }
      print('updateUserTagsPhotos: applied=$applied new affinity=$affinity');
      if (applied == 0) return false;

      // 4. Write it.
      await _client
          .from(SupabaseConstants.tableUsers)
          .update({'vibe_tag_affinity': affinity})
          .eq(SupabaseConstants.columnSupabaseId, userId);

      print('updateUserTagsPhotos: wrote $applied affinities for user $userId');
      return true;
    } catch (e, st) {
      print('updateUserTagsPhotos failed: $e');
      print(st);
      return false;
    }
  }

}

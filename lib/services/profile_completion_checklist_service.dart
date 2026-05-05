import 'package:login/supabase/constants.dart';
import 'package:login/supabase/supabase_client.dart';

class ProfileCompletionChecklistState {
  final bool hasEatList;
  final int savedCount;
  final bool hasSocialSave;
  final bool isFollowingSomeone;
  final bool isInAnyBubble;

  const ProfileCompletionChecklistState({
    required this.hasEatList,
    required this.savedCount,
    required this.hasSocialSave,
    required this.isFollowingSomeone,
    required this.isInAnyBubble,
  });

  bool get hasSavedFiveLocations => savedCount >= 5;

  bool get hasFollowedFriendAndCreatedBubble =>
      isFollowingSomeone && isInAnyBubble;

  int get completedCount => <bool>[
        hasEatList,
        hasSavedFiveLocations,
        hasSocialSave,
        hasFollowedFriendAndCreatedBubble,
      ].where((v) => v).length;

  bool get isComplete => completedCount >= 4;
}

/// Computes checklist progress using existing tables (least invasive):
/// - eat list: owns a collection OR has saved/adopted a collection
/// - saved 5: derived from saved count passed in (LocationListManager)
/// - shared TikTok/Reel: any save with saved_method in (tiktok, instagram)
/// - follow+ bubble: accepted follow + membership in any bubble
class ProfileCompletionChecklistService {
  final _client = SupabaseClientManager().client;

  static const Set<String> _ignoredOwnedCollectionNames = <String>{
    'Been To',
    'Shared Finds',
  };

  Future<ProfileCompletionChecklistState> fetch({
    required String userId,
    required int savedCount,
  }) async {
    final results = await Future.wait<bool>([
      _hasEatList(userId),
      _hasSocialSave(userId),
      _isFollowingSomeone(userId),
      _isInAnyBubble(userId),
    ]);

    return ProfileCompletionChecklistState(
      hasEatList: results[0],
      savedCount: savedCount,
      hasSocialSave: results[1],
      isFollowingSomeone: results[2],
      isInAnyBubble: results[3],
    );
  }

  Future<bool> _hasEatList(String userId) async {
    // 1) Any adopted/saved collection.
    final saved = await _client
        .from(SupabaseConstants.tableCollectionSaves)
        .select('collection_id')
        .eq(SupabaseConstants.columnUserId, userId)
        .limit(1);
    if ((saved as List).isNotEmpty) return true;

    // 2) Any owned collection (excluding system ones).
    final owned = await _client
        .from(SupabaseConstants.tableCollections)
        .select('name')
        .eq(SupabaseConstants.columnCreatedBy, userId)
        .limit(20);

    final rows = (owned as List).whereType<Map>().toList();
    for (final row in rows) {
      final name = (row['name'] as String?)?.trim();
      if (name != null &&
          name.isNotEmpty &&
          !_ignoredOwnedCollectionNames.contains(name)) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _hasSocialSave(String userId) async {
    final rows = await _client
        .from(SupabaseConstants.tableUserLocationActions)
        .select(SupabaseConstants.columnActionId)
        .eq(SupabaseConstants.columnUserId, userId)
        .eq(SupabaseConstants.columnAction, SupabaseConstants.actionSave)
        .eq(SupabaseConstants.columnAcked, true)
        // PostgREST "in" syntax.
        .inFilter(SupabaseConstants.columnSavedMethod,
            const ['tiktok', 'instagram']).limit(1);
    return (rows as List).isNotEmpty;
  }

  Future<bool> _isFollowingSomeone(String userId) async {
    final rows = await _client
        .from(SupabaseConstants.tableUserFriends)
        .select(SupabaseConstants.columnFollowerId)
        .eq(SupabaseConstants.columnFollowerId, userId)
        .eq(SupabaseConstants.columnStatus,
            SupabaseConstants.relationshipStatusAccepted)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  Future<bool> _isInAnyBubble(String userId) async {
    final rows = await _client
        .from(SupabaseConstants.tableBubbleMembers)
        .select(SupabaseConstants.columnBubbleId)
        .eq(SupabaseConstants.columnUserId, userId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }
}

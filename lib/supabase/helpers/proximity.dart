import 'package:flutter/foundation.dart';
import 'package:login/services/proximity/proximity_candidate.dart';
import 'package:login/services/proximity/proximity_data_source.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-side data for proximity notifications: the social context behind
/// each saved place and a log of pushes already sent.
class ProximityHelper implements ProximityDataSource {
  ProximityHelper({SupabaseClient? client})
      : _client = client ?? SupabaseClientManager().client;

  final SupabaseClient _client;

  /// Social context per saved location id (`get_proximity_context`). Empty on
  /// failure, in which case places fall back to plain copy and no gating by
  /// confidence or been-to.
  @override
  Future<Map<int, ProximityInsight>> fetchInsights() async {
    try {
      final rows = await _client.rpc(SupabaseConstants.rpcGetProximityContext);
      if (rows is! List) return const {};

      final result = <int, ProximityInsight>{};
      for (final row in rows) {
        if (row is! Map<String, dynamic>) continue;
        final id = (row['location_id'] as num?)?.toInt();
        if (id == null) continue;
        result[id] = ProximityInsight.fromJson(row);
      }
      return result;
    } catch (e) {
      debugPrint('[ProximityHelper] get_proximity_context failed: $e');
      return const {};
    }
  }

  /// Proximity pushes sent in the last [window], newest first.
  @override
  Future<List<({int locationId, DateTime sentAt})>> fetchRecentLog({
    Duration window = const Duration(days: 4),
  }) async {
    try {
      final since = DateTime.now().toUtc().subtract(window);
      final rows = await _client
          .from(SupabaseConstants.tableProximityNotificationLog)
          .select('location_id, sent_at')
          .gte('sent_at', since.toIso8601String())
          .order('sent_at', ascending: false)
          .limit(500);

      final result = <({int locationId, DateTime sentAt})>[];
      for (final row in rows) {
        final id = (row['location_id'] as num?)?.toInt();
        final sentAt = DateTime.tryParse('${row['sent_at']}')?.toLocal();
        if (id == null || sentAt == null) continue;
        result.add((locationId: id, sentAt: sentAt));
      }
      return result;
    } catch (e) {
      debugPrint('[ProximityHelper] fetchRecentLog failed: $e');
      return const [];
    }
  }

  /// Records a sent proximity push. Best effort: the on-device history still
  /// applies if this fails.
  @override
  Future<void> logSent(int locationId) async {
    try {
      await _client
          .from(SupabaseConstants.tableProximityNotificationLog)
          .insert({'location_id': locationId});
    } catch (e) {
      debugPrint('[ProximityHelper] logSent failed: $e');
    }
  }
}

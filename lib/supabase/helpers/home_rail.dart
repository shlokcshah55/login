import 'package:flutter/foundation.dart';
import 'package:login/models/home_rail_candidate.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-ranked home rail candidates (`get_home_rail`): area-lifted and
/// personal cuisines plus the caller's bubbles with places nearby.
class HomeRailHelper {
  HomeRailHelper({SupabaseClient? client})
      : _client = client ?? SupabaseClientManager().client;

  final SupabaseClient _client;

  static const int defaultRadiusMeters = 1500;

  /// Returns an empty list on failure — the rail falls back to client tiles.
  Future<List<HomeRailCandidate>> fetch({
    required double latitude,
    required double longitude,
    int radiusMeters = defaultRadiusMeters,
    int limit = 10,
  }) async {
    try {
      final rows = await _client.rpc(
        SupabaseConstants.rpcGetHomeRail,
        params: {
          'p_lat': latitude,
          'p_lng': longitude,
          'p_radius_m': radiusMeters,
          'p_limit': limit,
        },
      );
      if (rows is! List) return const [];
      return rows
          .map(HomeRailCandidate.tryParse)
          .whereType<HomeRailCandidate>()
          .toList(growable: false);
    } catch (e) {
      debugPrint('[HomeRailHelper] get_home_rail failed: $e');
      return const [];
    }
  }
}

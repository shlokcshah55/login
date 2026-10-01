import 'package:login/services/proximity/proximity_candidate.dart';

/// Server-backed data the proximity service needs. Implemented by
/// `ProximityHelper`; faked in tests.
abstract class ProximityDataSource {
  /// Social context per saved location id.
  Future<Map<int, ProximityInsight>> fetchInsights();

  /// Pushes sent within [window], newest first.
  Future<List<({int locationId, DateTime sentAt})>> fetchRecentLog({
    Duration window,
  });

  Future<void> logSent(int locationId);
}

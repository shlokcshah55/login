import 'package:geolocator/geolocator.dart';
import 'package:login/services/proximity/proximity_candidate.dart';
import 'package:login/services/proximity/proximity_policy.dart';
import 'package:login/utils/geo_types.dart';

/// A circular region handed to the OS for background monitoring.
class GeofenceRegion {
  const GeofenceRegion({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  /// The saved place's location id, as a string (OS region identifier).
  final String id;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  Map<String, Object> toMap() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radiusMeters,
      };

  @override
  bool operator ==(Object other) =>
      other is GeofenceRegion &&
      other.id == id &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.radiusMeters == radiusMeters;

  @override
  int get hashCode => Object.hash(id, latitude, longitude, radiusMeters);
}

/// iOS caps an app at 20 monitored regions. Leave headroom for the system.
const int defaultMaxGeofenceRegions = 15;

/// Picks which saved places to register with the OS.
///
/// Places that cannot notify regardless of position (been-to, cooling down,
/// unconfirmed low-confidence shares) are skipped so they don't use up slots.
/// With a known [position] the nearest places win, since those are the ones
/// the user is about to walk into. Without one, the policy's own ranking is
/// used so social saves and better-rated places come first.
List<GeofenceRegion> selectGeofenceRegions({
  required Iterable<ProximityCandidate> candidates,
  required ProximityPolicy policy,
  required ProximityContext context,
  LatLng? position,
  int maxRegions = defaultMaxGeofenceRegions,
}) {
  final worthwhile =
      candidates.where((c) => policy.isWorthMonitoring(c, context)).toList();

  double rank(ProximityCandidate c) {
    if (position == null) {
      // Higher score first, so negate for an ascending sort.
      return -policy.score(c, policy.config.radiusMeters);
    }
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      c.latitude,
      c.longitude,
    );
  }

  final ranked = {for (final c in worthwhile) c.locationId: rank(c)};
  worthwhile.sort((a, b) {
    final byRank = ranked[a.locationId]!.compareTo(ranked[b.locationId]!);
    return byRank != 0 ? byRank : a.locationId.compareTo(b.locationId);
  });

  return worthwhile
      .take(maxRegions)
      .map(
        (c) => GeofenceRegion(
          id: c.locationId.toString(),
          latitude: c.latitude,
          longitude: c.longitude,
          radiusMeters: policy.config.radiusMeters,
        ),
      )
      .toList(growable: false);
}

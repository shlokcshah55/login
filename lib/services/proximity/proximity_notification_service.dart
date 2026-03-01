import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/proximity/local_notification_service.dart';
import 'package:login/services/proximity/proximity_notification_gate.dart';
import 'package:login/supabase/helpers/location.dart';

/// Stream-based proximity notification prong.
/// Listens to Geolocator position stream and checks distance to saved locations.
/// Works while the app is alive (foreground + background with location permission).
class ProximityNotificationService {
  static final ProximityNotificationService _instance =
      ProximityNotificationService._internal();
  factory ProximityNotificationService() => _instance;
  ProximityNotificationService._internal();

  static const double _proximityRadiusKm = 1.0;
  static const Duration _locationRefreshInterval = Duration(minutes: 15);

  StreamSubscription<Position>? _positionSubscription;
  List<LocationModel> _savedLocations = [];
  DateTime? _lastLocationFetch;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await LocalNotificationService().initialize();
    await _refreshSavedLocations();
    _startListening();
  }

  void dispose() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _initialized = false;
  }

  Future<void> _refreshSavedLocations() async {
    try {
      _savedLocations = await LocationHelper().getSavedLocations();
      _lastLocationFetch = DateTime.now();
      print('[ProximityNotification] Refreshed ${_savedLocations.length} saved locations');
    } catch (e) {
      print('[ProximityNotification] Error refreshing locations: $e');
    }
  }

  void _startListening() {
    _positionSubscription?.cancel();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      _onPositionUpdate,
      onError: (e) {
        print('[ProximityNotification] Position stream error: $e');
      },
    );
  }

  Future<void> _onPositionUpdate(Position position) async {
    // Refresh saved locations if stale
    if (_lastLocationFetch == null ||
        DateTime.now().difference(_lastLocationFetch!) >
            _locationRefreshInterval) {
      await _refreshSavedLocations();
    }

    final gate = ProximityNotificationGate();

    for (final location in _savedLocations) {
      if (location.lat == null || location.lng == null) continue;

      // Reuse LocationModel's Haversine logic
      final isNear = location.isWithinRadius(
        _proximityRadiusKm.toInt(),
        position.latitude,
        position.longitude,
      );

      if (isNear && await gate.canNotify(location.locationId)) {
        await LocalNotificationService().showProximityNotification(
          locationId: location.locationId,
          locationName: location.name,
        );
        await gate.recordNotification(location.locationId);
      }
    }
  }
}

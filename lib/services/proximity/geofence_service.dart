import 'package:flutter/services.dart';
import 'package:login/services/proximity/local_notification_service.dart';
import 'package:login/services/proximity/proximity_notification_gate.dart';
import 'package:login/supabase/helpers/location.dart';

/// Flutter side of the geofence method channel.
/// Registers top-20 saved locations as native CLCircularRegion geofences
/// and handles entry events from the native side.
class GeofenceService {
  static final GeofenceService _instance = GeofenceService._internal();
  factory GeofenceService() => _instance;
  GeofenceService._internal();

  static const _channel =
      MethodChannel('com.example.srishlok.pinit/geofence');
  static const double _radiusMeters = 1000.0; // 1km

  bool _listening = false;

  /// Register geofences for the user's top-20 saved locations (by matchScore).
  /// Also starts listening for geofence entry events from native.
  Future<void> registerGeofences() async {
    _startListening();

    try {
      final locations = await LocationHelper().getSavedLocations();

      // Filter out locations without coordinates
      final valid = locations
          .where((loc) => loc.lat != null && loc.lng != null)
          .toList();

      // Sort by matchScore descending, take top 20
      valid.sort(
          (a, b) => (b.matchScore ?? 0).compareTo(a.matchScore ?? 0));
      final top20 = valid.take(20).toList();

      final regions = top20.map((loc) => {
            'id': loc.locationId,
            'lat': loc.lat!,
            'lng': loc.lng!,
            'radius': _radiusMeters,
            'name': loc.name,
          }).toList();

      await _channel.invokeMethod('registerGeofences', regions);
      print('[GeofenceService] Registered ${regions.length} geofences');
    } catch (e) {
      print('[GeofenceService] Error registering geofences: $e');
    }
  }

  /// Clear all native geofences.
  Future<void> clearGeofences() async {
    try {
      await _channel.invokeMethod('clearGeofences');
      print('[GeofenceService] Cleared all geofences');
    } catch (e) {
      print('[GeofenceService] Error clearing geofences: $e');
    }
  }

  /// Listen for geofence entry events from native side.
  void _startListening() {
    if (_listening) return;
    _listening = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onGeofenceEntry') {
        final args = call.arguments as Map;
        final locationId = args['locationId'] as int;
        final name = args['name'] as String? ?? 'a saved place';

        final gate = ProximityNotificationGate();
        if (await gate.canNotify(locationId)) {
          await LocalNotificationService().showProximityNotification(
            locationId: locationId,
            locationName: name,
          );
          await gate.recordNotification(locationId);
        }
      }
    });
  }
}

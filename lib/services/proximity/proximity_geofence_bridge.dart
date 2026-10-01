import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:login/services/proximity/proximity_regions.dart';
import 'package:login/utils/geo_types.dart';

/// Mirrors CLAuthorizationStatus.
enum LocationAuthStatus {
  notDetermined,
  restricted,
  denied,
  whenInUse,
  always,
  unsupported;

  bool get isAlways => this == always;

  /// True when the user has not said no outright and Always could still be
  /// granted (the system prompt only ever shows once).
  bool get canStillUpgrade => this == notDetermined || this == whenInUse;

  static LocationAuthStatus parse(Object? raw) {
    switch (raw) {
      case 'notDetermined':
        return notDetermined;
      case 'restricted':
        return restricted;
      case 'denied':
        return denied;
      case 'whenInUse':
        return whenInUse;
      case 'always':
        return always;
      default:
        return unsupported;
    }
  }
}

sealed class GeofenceEvent {
  const GeofenceEvent();
}

/// The OS reports the user entered a monitored region.
class GeofenceEntered extends GeofenceEvent {
  const GeofenceEntered(this.locationId, {this.position});

  final int locationId;

  /// The device's last known position, when the OS had one.
  final LatLng? position;
}

/// The user moved far enough (~500 m) for the OS to wake the app so it can
/// re-pick which places to monitor.
class SignificantLocationChange extends GeofenceEvent {
  const SignificantLocationChange(this.position);

  final LatLng position;
}

class AuthorizationChanged extends GeofenceEvent {
  const AuthorizationChanged(this.status);

  final LocationAuthStatus status;
}

/// The user tapped a local notification posted by [GeofenceBridge].
class NotificationTapped extends GeofenceEvent {
  const NotificationTapped(this.payload);

  final Map<String, dynamic> payload;
}

/// Native side of background proximity: OS region monitoring, significant
/// location changes, and local notifications.
abstract class GeofenceBridge {
  bool get isSupported;

  Stream<GeofenceEvent> get events;

  Future<LocationAuthStatus> authorizationStatus();

  /// Shows the system "Always" upgrade prompt. The result arrives as an
  /// [AuthorizationChanged] event.
  Future<void> requestAlwaysAuthorization();

  /// Replaces the monitored regions, keeping unchanged ones in place.
  Future<void> registerRegions(List<GeofenceRegion> regions);

  Future<void> clearRegions();

  Future<void> setSignificantChangesEnabled(bool enabled);

  /// Tells native code Dart is listening, so it flushes events queued while
  /// the app was launching in the background.
  Future<void> signalReady();

  /// Posts a local notification. [payload] comes back in [NotificationTapped].
  Future<bool> postNotification({
    required String id,
    required String title,
    required String body,
    required Map<String, String> payload,
  });
}

/// iOS implementation over the `…/geofence` channel (see `GeofenceManager`).
/// Everything is a safe no-op on other platforms.
class MethodChannelGeofenceBridge implements GeofenceBridge {
  MethodChannelGeofenceBridge()
      : _channel = const MethodChannel(channelName),
        _supported = !kIsWeb && Platform.isIOS {
    if (_supported) _channel.setMethodCallHandler(_onNativeCall);
  }

  /// Exercises the channel logic on a non-iOS host.
  @visibleForTesting
  MethodChannelGeofenceBridge.forTesting(MethodChannel channel)
      : _channel = channel,
        _supported = true {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static const String channelName = 'com.example.srishlok.pinit/geofence';

  final MethodChannel _channel;
  final bool _supported;
  final StreamController<GeofenceEvent> _events =
      StreamController<GeofenceEvent>.broadcast();

  @override
  bool get isSupported => _supported;

  @override
  Stream<GeofenceEvent> get events => _events.stream;

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      debugPrint('[GeofenceBridge] $method failed: ${e.code} ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<LocationAuthStatus> authorizationStatus() async {
    if (!_supported) return LocationAuthStatus.unsupported;
    return LocationAuthStatus.parse(
      await _invoke<String>('authorizationStatus'),
    );
  }

  @override
  Future<void> requestAlwaysAuthorization() =>
      _invoke<void>('requestAlwaysAuthorization');

  @override
  Future<void> registerRegions(List<GeofenceRegion> regions) =>
      _invoke<void>('registerRegions', {
        'regions': regions.map((r) => r.toMap()).toList(),
      });

  @override
  Future<void> clearRegions() => _invoke<void>('clearRegions');

  @override
  Future<void> setSignificantChangesEnabled(bool enabled) =>
      _invoke<void>('setSignificantChangesEnabled', {'enabled': enabled});

  @override
  Future<void> signalReady() => _invoke<void>('ready');

  @override
  Future<bool> postNotification({
    required String id,
    required String title,
    required String body,
    required Map<String, String> payload,
  }) async {
    final ok = await _invoke<bool>('postNotification', {
      'id': id,
      'title': title,
      'body': body,
      'payload': payload,
    });
    return ok == true;
  }

  Future<dynamic> _onNativeCall(MethodCall call) async {
    final args = call.arguments is Map
        ? Map<String, dynamic>.from(call.arguments as Map)
        : const <String, dynamic>{};

    LatLng? position() {
      final lat = (args['latitude'] as num?)?.toDouble();
      final lng = (args['longitude'] as num?)?.toDouble();
      return (lat == null || lng == null) ? null : LatLng(lat, lng);
    }

    switch (call.method) {
      case 'onGeofenceEvent':
        final id = int.tryParse('${args['identifier']}');
        if (args['event'] == 'enter' && id != null) {
          _events.add(GeofenceEntered(id, position: position()));
        }
        break;
      case 'onSignificantLocationChange':
        final at = position();
        if (at != null) _events.add(SignificantLocationChange(at));
        break;
      case 'onAuthorizationChanged':
        _events.add(
          AuthorizationChanged(LocationAuthStatus.parse(args['status'])),
        );
        break;
      case 'onNotificationTap':
        final payload = args['payload'];
        if (payload is Map) {
          _events.add(
            NotificationTapped(Map<String, dynamic>.from(payload)),
          );
        }
        break;
    }
    return null;
  }
}

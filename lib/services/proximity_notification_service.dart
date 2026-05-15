import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/location_service.dart';
import 'package:login/services/push_notification_service.dart';
import 'package:login/utils/geo_types.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProximityNotificationService {
  static final ProximityNotificationService _instance =
      ProximityNotificationService._internal();

  factory ProximityNotificationService() => _instance;

  ProximityNotificationService._internal();

  static const double walkingDistanceMeters = 1000;
  static const int maxNotificationsPerHour = 2;
  static const Duration perLocationCooldown = Duration(days: 4);
  static const String _insideKeyPrefix = 'proximity_inside_v1';
  static const String _historyKeyPrefix = 'proximity_history_v1';
  static const String _cooldownKeyPrefix = 'proximity_cooldown_v1';

  final LocationService _locationService = LocationService();
  final PushNotificationService _pushNotificationService =
      PushNotificationService();

  SharedPreferences? _prefs;
  String? _userId;
  final Map<int, _SavedLocationGeofence> _geofences = {};
  Set<int> _insideLocationIds = <int>{};
  List<DateTime> _notificationHistory = <DateTime>[];
  Map<int, DateTime> _locationCooldowns = {};

  bool _listenerAttached = false;
  bool _isProcessingLocation = false;
  LatLng? _pendingPosition;

  Future<void> initializeForUser(String userId) async {
    final userChanged = _userId != userId;
    _userId = userId;

    await _ensurePrefs();

    if (userChanged) {
      _insideLocationIds = await _loadInsideLocationIds(userId);
      _notificationHistory = await _loadNotificationHistory(userId);
      _locationCooldowns = await _loadLocationCooldowns(userId);
    }

    _attachLocationListener();
    await _locationService.startLocationUpdates();
  }

  Future<void> syncSavedLocations(
      Iterable<LocationModel> savedLocations) async {
    final previousGeofenceIds = _geofences.keys.toSet();
    final nextGeofences = <int, _SavedLocationGeofence>{};

    for (final location in savedLocations) {
      if (location.lat == null || location.lng == null) {
        continue;
      }

      nextGeofences[location.locationId] = _SavedLocationGeofence(
        locationId: location.locationId,
        locationName: location.name,
        latitude: location.lat!,
        longitude: location.lng!,
      );
    }

    _geofences
      ..clear()
      ..addAll(nextGeofences);

    _insideLocationIds = _insideLocationIds
        .where((locationId) => _geofences.containsKey(locationId))
        .toSet();

    final currentPosition = _locationService.currentPosition;
    if (currentPosition != null) {
      final newGeofenceIds =
          nextGeofences.keys.where((id) => !previousGeofenceIds.contains(id));
      for (final locationId in newGeofenceIds) {
        final geofence = nextGeofences[locationId];
        if (geofence == null) {
          continue;
        }

        if (_isWithinWalkingDistance(currentPosition, geofence)) {
          _insideLocationIds.add(locationId);
        }
      }
    }

    await _persistInsideLocationIds();
  }

  void clear() {
    if (_listenerAttached) {
      _locationService.removeListener(_handleLocationServiceChange);
      _listenerAttached = false;
    }

    _userId = null;
    _geofences.clear();
    _insideLocationIds = <int>{};
    _notificationHistory = <DateTime>[];
    _locationCooldowns = {};
    _pendingPosition = null;
    _isProcessingLocation = false;
  }

  void _attachLocationListener() {
    if (_listenerAttached) {
      return;
    }

    _locationService.addListener(_handleLocationServiceChange);
    _listenerAttached = true;
  }

  void _handleLocationServiceChange() {
    final currentPosition = _locationService.currentPosition;
    if (currentPosition == null || _userId == null || _geofences.isEmpty) {
      return;
    }

    _pendingPosition = currentPosition;
    if (_isProcessingLocation) {
      return;
    }

    unawaited(_drainPendingLocationUpdates());
  }

  Future<void> _drainPendingLocationUpdates() async {
    _isProcessingLocation = true;

    try {
      while (_pendingPosition != null) {
        final currentPosition = _pendingPosition!;
        _pendingPosition = null;
        await _processLocationUpdate(currentPosition);
      }
    } finally {
      _isProcessingLocation = false;
    }
  }

  Future<void> _processLocationUpdate(LatLng currentPosition) async {
    final userId = _userId;
    if (userId == null || _geofences.isEmpty) {
      return;
    }

    final now = DateTime.now();
    _trimNotificationHistory(now);

    final nextInsideLocationIds = <int>{};
    final enteredGeofences = <_GeofenceDistance>[];

    for (final geofence in _geofences.values) {
      final distanceMeters = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        geofence.latitude,
        geofence.longitude,
      );

      if (distanceMeters > walkingDistanceMeters) {
        continue;
      }

      nextInsideLocationIds.add(geofence.locationId);
      if (!_insideLocationIds.contains(geofence.locationId)) {
        enteredGeofences.add(
          _GeofenceDistance(
            geofence: geofence,
            distanceMeters: distanceMeters,
          ),
        );
      }
    }

    enteredGeofences.sort(
      (left, right) => left.distanceMeters.compareTo(right.distanceMeters),
    );

    var notificationHistoryChanged = false;
    var cooldownsChanged = false;
    for (final entry in enteredGeofences) {
      if (_notificationHistory.length >= maxNotificationsPerHour) {
        break;
      }

      final lastSent = _locationCooldowns[entry.geofence.locationId];
      if (lastSent != null &&
          now.difference(lastSent) < perLocationCooldown) {
        continue;
      }

      final sent =
          await _pushNotificationService.sendProximityLocationNotification(
        recipientUserId: userId,
        locationId: entry.geofence.locationId.toString(),
        locationName: entry.geofence.locationName,
        distanceMeters: entry.distanceMeters.round(),
      );

      if (!sent) {
        continue;
      }

      _notificationHistory.add(DateTime.now());
      notificationHistoryChanged = true;
      _locationCooldowns[entry.geofence.locationId] = DateTime.now();
      cooldownsChanged = true;
      _trimNotificationHistory(DateTime.now());
    }

    final insideChanged =
        !_hasSameEntries(_insideLocationIds, nextInsideLocationIds);
    _insideLocationIds = nextInsideLocationIds;

    if (insideChanged) {
      await _persistInsideLocationIds();
    }

    if (notificationHistoryChanged) {
      await _persistNotificationHistory();
    }

    if (cooldownsChanged) {
      await _persistLocationCooldowns();
    }
  }

  bool _isWithinWalkingDistance(
    LatLng currentPosition,
    _SavedLocationGeofence geofence,
  ) {
    final distanceMeters = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      geofence.latitude,
      geofence.longitude,
    );
    return distanceMeters <= walkingDistanceMeters;
  }

  bool _hasSameEntries(Set<int> left, Set<int> right) {
    if (left.length != right.length) {
      return false;
    }

    return left.containsAll(right);
  }

  void _trimNotificationHistory(DateTime now) {
    _notificationHistory = _notificationHistory.where((timestamp) {
      return now.difference(timestamp) < const Duration(hours: 1);
    }).toList();
  }

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<Set<int>> _loadInsideLocationIds(String userId) async {
    final values =
        _prefs?.getStringList(_insideKey(userId)) ?? const <String>[];
    return values.map(int.tryParse).whereType<int>().toSet();
  }

  Future<List<DateTime>> _loadNotificationHistory(String userId) async {
    final values =
        _prefs?.getStringList(_historyKey(userId)) ?? const <String>[];
    final now = DateTime.now();
    return values
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .where(
            (timestamp) => now.difference(timestamp) < const Duration(hours: 1))
        .toList();
  }

  Future<void> _persistInsideLocationIds() async {
    final userId = _userId;
    if (userId == null) {
      return;
    }

    final values =
        _insideLocationIds.map((locationId) => locationId.toString()).toList();
    await _prefs?.setStringList(_insideKey(userId), values);
  }

  Future<void> _persistNotificationHistory() async {
    final userId = _userId;
    if (userId == null) {
      return;
    }

    _trimNotificationHistory(DateTime.now());
    final values = _notificationHistory
        .map((timestamp) => timestamp.toIso8601String())
        .toList();
    await _prefs?.setStringList(_historyKey(userId), values);
  }

  Future<Map<int, DateTime>> _loadLocationCooldowns(String userId) async {
    final raw = _prefs?.getString(_cooldownKey(userId));
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final now = DateTime.now();
      final result = <int, DateTime>{};
      for (final entry in decoded.entries) {
        final id = int.tryParse(entry.key);
        final timestamp = DateTime.tryParse(entry.value as String);
        if (id == null || timestamp == null) continue;
        if (now.difference(timestamp) < perLocationCooldown) {
          result[id] = timestamp;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> _persistLocationCooldowns() async {
    final userId = _userId;
    if (userId == null) return;

    final now = DateTime.now();
    final toStore = {
      for (final entry in _locationCooldowns.entries)
        if (now.difference(entry.value) < perLocationCooldown)
          entry.key.toString(): entry.value.toIso8601String(),
    };
    await _prefs?.setString(_cooldownKey(userId), jsonEncode(toStore));
  }

  String _insideKey(String userId) => '$_insideKeyPrefix:$userId';

  String _historyKey(String userId) => '$_historyKeyPrefix:$userId';

  String _cooldownKey(String userId) => '$_cooldownKeyPrefix:$userId';
}

class _SavedLocationGeofence {
  const _SavedLocationGeofence({
    required this.locationId,
    required this.locationName,
    required this.latitude,
    required this.longitude,
  });

  final int locationId;
  final String locationName;
  final double latitude;
  final double longitude;
}

class _GeofenceDistance {
  const _GeofenceDistance({
    required this.geofence,
    required this.distanceMeters,
  });

  final _SavedLocationGeofence geofence;
  final double distanceMeters;
}

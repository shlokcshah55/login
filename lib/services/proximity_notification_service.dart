import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/location_service.dart';
import 'package:login/services/proximity/proximity_candidate.dart';
import 'package:login/services/proximity/proximity_copy.dart';
import 'package:login/services/proximity/proximity_data_source.dart';
import 'package:login/services/proximity/proximity_policy.dart';
import 'package:login/services/push_notification_service.dart';
import 'package:login/supabase/service.dart';
import 'package:login/utils/geo_types.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef ProximityMessageSender = Future<bool> Function(
  String recipientUserId,
  ProximityMessage message,
);

/// Notifies the user when they come near a place they saved.
///
/// This class owns state and I/O (location stream, prefs, server log, push).
/// Every decision about *whether* and *what* to send lives in
/// `ProximityPolicy` and `buildProximityMessage`.
class ProximityNotificationService {
  static final ProximityNotificationService _instance =
      ProximityNotificationService._internal();

  factory ProximityNotificationService() => _instance;

  ProximityNotificationService._internal()
      : _policy = const ProximityPolicy(),
        _now = DateTime.now;

  @visibleForTesting
  ProximityNotificationService.withDependencies({
    required ProximityDataSource dataSource,
    required ProximityMessageSender sender,
    ProximityPolicy policy = const ProximityPolicy(),
    DateTime Function()? now,
  })  : _dataSource = dataSource,
        _sender = sender,
        _policy = policy,
        _now = now ?? DateTime.now;

  static const String _insideKeyPrefix = 'proximity_inside_v1';
  static const String _historyKeyPrefix = 'proximity_history_v1';
  static const String _cooldownKeyPrefix = 'proximity_cooldown_v1';
  static const Duration _insightsMaxAge = Duration(minutes: 10);
  static const Duration _historyRetention = Duration(hours: 24);

  final ProximityPolicy _policy;
  final DateTime Function() _now;
  ProximityDataSource? _dataSource;
  ProximityMessageSender? _sender;

  final LocationService _locationService = LocationService();

  ProximityDataSource get _data => _dataSource ??= SupabaseService().proximity;

  ProximityMessageSender get _send => _sender ??=
      (userId, message) => PushNotificationService().sendProximityMessage(
            recipientUserId: userId,
            message: message,
          );

  SharedPreferences? _prefs;
  String? _userId;
  final Map<int, LocationModel> _savedLocations = {};
  final Map<int, ProximityCandidate> _candidates = {};
  Map<int, ProximityInsight> _insights = {};
  DateTime? _insightsFetchedAt;
  Set<int> _insideLocationIds = <int>{};
  List<DateTime> _sentTimestamps = <DateTime>[];
  Map<int, DateTime> _locationCooldowns = {};

  bool _listenerAttached = false;
  bool _isProcessingLocation = false;
  LatLng? _pendingPosition;

  Future<void> initializeForUser(String userId) async {
    final userChanged = await _loadUserState(userId);
    if (userChanged) unawaited(_mergeServerLog(userId));

    _attachLocationListener();
    await _locationService.startLocationUpdates();
  }

  /// Returns true when [userId] differs from the previously loaded user.
  Future<bool> _loadUserState(String userId) async {
    final userChanged = _userId != userId;
    _userId = userId;

    await _ensurePrefs();

    if (userChanged) {
      _insideLocationIds = await _loadInsideLocationIds(userId);
      _sentTimestamps = await _loadSentTimestamps(userId);
      _locationCooldowns = await _loadLocationCooldowns(userId);
      _insights = {};
      _insightsFetchedAt = null;
    }
    return userChanged;
  }

  /// Loads per-user state and the server log without starting the location
  /// stream, so tests can drive [processPosition] directly.
  @visibleForTesting
  Future<void> loadUserStateForTest(String userId) async {
    if (await _loadUserState(userId)) await _mergeServerLog(userId);
  }

  Future<void> syncSavedLocations(
      Iterable<LocationModel> savedLocations) async {
    final previousIds = _candidates.keys.toSet();

    _savedLocations
      ..clear()
      ..addEntries(
        savedLocations
            .where((l) => l.lat != null && l.lng != null)
            .map((l) => MapEntry(l.locationId, l)),
      );

    final hasNewPlaces =
        _savedLocations.keys.any((id) => !previousIds.contains(id));
    if (hasNewPlaces || _insightsAreStale) {
      await _refreshInsights();
    }
    _rebuildCandidates();

    _insideLocationIds = _insideLocationIds
        .where((locationId) => _candidates.containsKey(locationId))
        .toSet();

    // A place saved while the user is already standing next to it should not
    // fire immediately.
    final currentPosition = _locationService.currentPosition;
    if (currentPosition != null) {
      for (final candidate in _candidates.values) {
        if (previousIds.contains(candidate.locationId)) continue;
        if (_distanceTo(currentPosition, candidate) <=
            _policy.config.radiusMeters) {
          _insideLocationIds.add(candidate.locationId);
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
    _savedLocations.clear();
    _candidates.clear();
    _insights = {};
    _insightsFetchedAt = null;
    _insideLocationIds = <int>{};
    _sentTimestamps = <DateTime>[];
    _locationCooldowns = {};
    _pendingPosition = null;
    _isProcessingLocation = false;
  }

  /// Runs one location update through the policy. Exposed for tests; the app
  /// reaches it through the location stream.
  @visibleForTesting
  Future<void> processPosition(LatLng position) =>
      _processLocationUpdate(position);

  @visibleForTesting
  Set<int> get insideLocationIds => Set.unmodifiable(_insideLocationIds);

  bool get _insightsAreStale {
    final fetchedAt = _insightsFetchedAt;
    return fetchedAt == null || _now().difference(fetchedAt) > _insightsMaxAge;
  }

  Future<void> _refreshInsights() async {
    try {
      _insights = await _data.fetchInsights();
      _insightsFetchedAt = _now();
    } catch (e) {
      debugPrint('[Proximity] insight refresh failed: $e');
    }
  }

  void _rebuildCandidates() {
    _candidates.clear();
    for (final location in _savedLocations.values) {
      final candidate = ProximityCandidate.fromLocation(
        location,
        insight: _insights[location.locationId] ?? const ProximityInsight(),
      );
      if (candidate != null) _candidates[candidate.locationId] = candidate;
    }
  }

  /// Pulls the server's send log so caps and cooldowns hold across devices
  /// and reinstalls.
  Future<void> _mergeServerLog(String userId) async {
    try {
      final entries =
          await _data.fetchRecentLog(window: _policy.config.perPlaceCooldown);
      if (_userId != userId || entries.isEmpty) return;

      final now = _now();
      final known =
          _sentTimestamps.map((t) => t.millisecondsSinceEpoch).toSet();
      for (final entry in entries) {
        if (now.difference(entry.sentAt) < _historyRetention &&
            known.add(entry.sentAt.millisecondsSinceEpoch)) {
          _sentTimestamps.add(entry.sentAt);
        }
        final previous = _locationCooldowns[entry.locationId];
        if (previous == null || entry.sentAt.isAfter(previous)) {
          _locationCooldowns[entry.locationId] = entry.sentAt;
        }
      }
      await _persistSentTimestamps();
      await _persistLocationCooldowns();
    } catch (e) {
      debugPrint('[Proximity] server log merge failed: $e');
    }
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
    if (currentPosition == null || _userId == null || _candidates.isEmpty) {
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
    if (userId == null || _candidates.isEmpty) {
      return;
    }

    final now = _now();
    _trimSentTimestamps(now);

    final withinRadius = <int>{};
    final entered = <({ProximityCandidate candidate, double distanceMeters})>[];

    for (final candidate in _candidates.values) {
      final distance = _distanceTo(currentPosition, candidate);
      if (distance > _policy.config.radiusMeters) continue;

      withinRadius.add(candidate.locationId);
      if (!_insideLocationIds.contains(candidate.locationId)) {
        entered.add((candidate: candidate, distanceMeters: distance));
      }
    }

    final evaluation = _policy.evaluate(
      candidates: entered,
      context: ProximityContext(
        now: now,
        sentTimestamps: _sentTimestamps,
        lastSentByLocation: _locationCooldowns,
      ),
    );

    // Places we are still waiting to tell the user about stay "outside" so a
    // later update can fire once the blocker clears (it opens, quiet hours
    // end, the hourly cap frees up). Everything else is consumed.
    final deferred = <int>{};
    final selectedIds =
        evaluation.selected.map((d) => d.candidate.locationId).toSet();
    for (final entry in entered) {
      final id = entry.candidate.locationId;
      if (selectedIds.contains(id)) continue;
      final reason = evaluation.suppressed[id];
      final isTransient = reason == null ||
          reason == SuppressReason.closed ||
          reason == SuppressReason.closingSoon;
      if (evaluation.globalReason != null || isTransient) deferred.add(id);
    }

    var sentChanged = false;
    for (final decision in evaluation.selected) {
      final message = buildProximityMessage(decision);
      final sent = await _send(userId, message);
      if (!sent) continue;

      final sentAt = _now();
      _sentTimestamps.add(sentAt);
      _locationCooldowns[decision.candidate.locationId] = sentAt;
      sentChanged = true;
      unawaited(_data.logSent(decision.candidate.locationId));
    }

    final nextInside = withinRadius.difference(deferred);
    final insideChanged = !_hasSameEntries(_insideLocationIds, nextInside);
    _insideLocationIds = nextInside;

    if (insideChanged) {
      await _persistInsideLocationIds();
    }
    if (sentChanged) {
      await _persistSentTimestamps();
      await _persistLocationCooldowns();
    }
  }

  double _distanceTo(LatLng position, ProximityCandidate candidate) {
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      candidate.latitude,
      candidate.longitude,
    );
  }

  bool _hasSameEntries(Set<int> left, Set<int> right) {
    if (left.length != right.length) {
      return false;
    }

    return left.containsAll(right);
  }

  void _trimSentTimestamps(DateTime now) {
    _sentTimestamps = _sentTimestamps
        .where((timestamp) => now.difference(timestamp) < _historyRetention)
        .toList();
  }

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<Set<int>> _loadInsideLocationIds(String userId) async {
    final values =
        _prefs?.getStringList(_insideKey(userId)) ?? const <String>[];
    return values.map(int.tryParse).whereType<int>().toSet();
  }

  Future<List<DateTime>> _loadSentTimestamps(String userId) async {
    final values =
        _prefs?.getStringList(_historyKey(userId)) ?? const <String>[];
    final now = _now();
    return values
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .where((timestamp) => now.difference(timestamp) < _historyRetention)
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

  Future<void> _persistSentTimestamps() async {
    final userId = _userId;
    if (userId == null) {
      return;
    }

    _trimSentTimestamps(_now());
    final values = _sentTimestamps
        .map((timestamp) => timestamp.toIso8601String())
        .toList();
    await _prefs?.setStringList(_historyKey(userId), values);
  }

  Future<Map<int, DateTime>> _loadLocationCooldowns(String userId) async {
    final raw = _prefs?.getString(_cooldownKey(userId));
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final now = _now();
      final cooldown = _policy.config.perPlaceCooldown;
      final result = <int, DateTime>{};
      for (final entry in decoded.entries) {
        final id = int.tryParse(entry.key);
        final timestamp = DateTime.tryParse(entry.value as String);
        if (id == null || timestamp == null) continue;
        if (now.difference(timestamp) < cooldown) {
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

    final now = _now();
    final cooldown = _policy.config.perPlaceCooldown;
    final toStore = {
      for (final entry in _locationCooldowns.entries)
        if (now.difference(entry.value) < cooldown)
          entry.key.toString(): entry.value.toIso8601String(),
    };
    await _prefs?.setString(_cooldownKey(userId), jsonEncode(toStore));
  }

  String _insideKey(String userId) => '$_insideKeyPrefix:$userId';

  String _historyKey(String userId) => '$_historyKeyPrefix:$userId';

  String _cooldownKey(String userId) => '$_cooldownKeyPrefix:$userId';
}

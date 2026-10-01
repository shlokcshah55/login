import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:login/models/locations.dart';
import 'package:login/services/fcm_service.dart';
import 'package:login/services/location_service.dart';
import 'package:login/services/proximity/proximity_candidate.dart';
import 'package:login/services/proximity/proximity_copy.dart';
import 'package:login/services/proximity/proximity_data_source.dart';
import 'package:login/services/proximity/proximity_geofence_bridge.dart';
import 'package:login/services/proximity/proximity_permission.dart';
import 'package:login/services/proximity/proximity_policy.dart';
import 'package:login/services/proximity/proximity_priming_presenter.dart';
import 'package:login/services/proximity/proximity_regions.dart';
import 'package:login/services/push_notification_service.dart';
import 'package:login/supabase/service.dart';
import 'package:login/utils/geo_types.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef ProximityMessageSender = Future<bool> Function(
  String recipientUserId,
  ProximityMessage message,
);

/// Shows the "turn on nudges" explainer. See [presentProximityPriming].
typedef ProximityPrimingPresenter = Future<bool?> Function();

typedef ProximityTapHandler = Future<void> Function(
  String deepLink,
  Map<String, dynamic> payload,
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
    GeofenceBridge? bridge,
    ProximityTapHandler? onNotificationTap,
    ProximityPrimingPresenter? primingPresenter,
    ProximityPolicy policy = const ProximityPolicy(),
    DateTime Function()? now,
  })  : _dataSource = dataSource,
        _sender = sender,
        _bridge = bridge,
        _onNotificationTap = onNotificationTap,
        _primingPresenter = primingPresenter,
        _policy = policy,
        _now = now ?? DateTime.now;

  static const String _insideKeyPrefix = 'proximity_inside_v1';
  static const String _historyKeyPrefix = 'proximity_history_v1';
  static const String _cooldownKeyPrefix = 'proximity_cooldown_v1';
  static const String _candidatesKeyPrefix = 'proximity_candidates_v1';
  static const String _promptHistoryKeyPrefix = 'proximity_always_prompt_v1';
  static const String _promptPendingKeyPrefix = 'proximity_always_pending_v1';
  static const Duration _insightsMaxAge = Duration(minutes: 10);
  static const Duration _historyRetention = Duration(hours: 24);

  final ProximityPolicy _policy;
  final DateTime Function() _now;
  ProximityDataSource? _dataSource;
  ProximityMessageSender? _sender;
  GeofenceBridge? _bridge;
  ProximityTapHandler? _onNotificationTap;
  ProximityPrimingPresenter? _primingPresenter;
  final AlwaysPromptPolicy _promptPolicy = const AlwaysPromptPolicy();

  final LocationService _locationService = LocationService();

  ProximityDataSource get _data => _dataSource ??= SupabaseService().proximity;

  GeofenceBridge get _geo => _bridge ??= MethodChannelGeofenceBridge();

  ProximityPrimingPresenter get _presentPriming =>
      _primingPresenter ??= presentProximityPriming;

  ProximityTapHandler get _tapHandler => _onNotificationTap ??=
      (deepLink, payload) => FCMService().openDeepLink(deepLink, data: payload);

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

  StreamSubscription<GeofenceEvent>? _geofenceSubscription;
  LocationAuthStatus _authStatus = LocationAuthStatus.unsupported;
  List<GeofenceRegion> _registeredRegions = const [];
  LatLng? _lastKnownPosition;

  /// The first sync after sign-in only establishes a baseline of what was
  /// already saved, so it never counts as a "new social save".
  bool _hasSynced = false;
  bool _pendingSocialPrompt = false;
  bool _isPrompting = false;

  /// The stream path and the OS geofence path can fire for the same place at
  /// the same moment. Running them one at a time lets the second one see the
  /// first one's cooldown.
  Future<void> _serialTail = Future<void>.value();

  Future<void> initializeForUser(String userId) async {
    final userChanged = await _loadUserState(userId);
    if (userChanged) unawaited(_mergeServerLog(userId));

    _attachLocationListener();
    await _startBackgroundMonitoring();
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
      _loadCandidateSnapshot(userId);
      _pendingSocialPrompt =
          _prefs?.getBool(_promptPendingKey(userId)) ?? false;
      _hasSynced = false;
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

    final savedSocialPlace = _hasSynced &&
        _candidates.values
            .any((c) => c.isSocial && !previousIds.contains(c.locationId));
    _hasSynced = true;
    if (savedSocialPlace) await _setPendingSocialPrompt(true);

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
    await _persistCandidateSnapshot();
    unawaited(_refreshRegions());
    unawaited(maybePromptForAlwaysLocation());
  }

  void clear() {
    if (_listenerAttached) {
      _locationService.removeListener(_handleLocationServiceChange);
      _listenerAttached = false;
    }

    final userId = _userId;
    if (userId != null) unawaited(_prefs?.remove(_candidatesKey(userId)));
    unawaited(_stopBackgroundMonitoring());

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
    _hasSynced = false;
    _pendingSocialPrompt = false;
  }

  /// Runs one location update through the policy. Exposed for tests; the app
  /// reaches it through the location stream.
  @visibleForTesting
  Future<void> processPosition(LatLng position) =>
      _serialized(() => _processLocationUpdate(position));

  @visibleForTesting
  Future<void> handleGeofenceEnterForTest(int locationId, {LatLng? at}) =>
      _serialized(() => _handleGeofenceEnter(locationId, at));

  @visibleForTesting
  Future<void> startBackgroundMonitoringForTest() =>
      _startBackgroundMonitoring();

  @visibleForTesting
  List<GeofenceRegion> get registeredRegions =>
      List.unmodifiable(_registeredRegions);

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

  // MARK: - Asking for Always location

  /// After the user's first social save, offers to turn on background nudges.
  /// Safe to call often (on sync and on app resume): it does nothing unless a
  /// social save is waiting, iOS still allows the upgrade, and we have not
  /// asked recently. If the app is not on screen the request stays pending.
  Future<void> maybePromptForAlwaysLocation() async {
    final userId = _userId;
    if (userId == null || !_pendingSocialPrompt || _isPrompting) return;

    final geo = _geo;
    if (!geo.isSupported) return;

    _isPrompting = true;
    try {
      _authStatus = await geo.authorizationStatus();
      if (_authStatus == LocationAuthStatus.notDetermined)
        return; // keep waiting
      final history = AlwaysPromptHistory.decode(
          _prefs?.getString(_promptHistoryKey(userId)));
      final eligible = _promptPolicy.shouldPrompt(
        status: _authStatus,
        hasPendingSocialSave: true,
        history: history,
        now: _now(),
      );
      if (!eligible) {
        // Already Always, denied, or asked too recently: nothing to offer.
        await _setPendingSocialPrompt(false);
        return;
      }

      final accepted = await _presentPriming();
      if (accepted == null) return; // could not show it now; stay pending

      await _prefs?.setString(
        _promptHistoryKey(userId),
        history.asked(_now()).encode(),
      );
      await _setPendingSocialPrompt(false);
      if (accepted) await geo.requestAlwaysAuthorization();
    } finally {
      _isPrompting = false;
    }
  }

  Future<void> _setPendingSocialPrompt(bool pending) async {
    _pendingSocialPrompt = pending;
    final userId = _userId;
    if (userId == null) return;
    if (pending) {
      await _prefs?.setBool(_promptPendingKey(userId), true);
    } else {
      await _prefs?.remove(_promptPendingKey(userId));
    }
  }

  // MARK: - Background (OS geofencing)

  Future<void> _serialized(Future<void> Function() action) {
    final next = _serialTail.then((_) => action());
    _serialTail = next.catchError((Object e) {
      debugPrint('[Proximity] serialized action failed: $e');
    });
    return next;
  }

  ProximityContext _context() => ProximityContext(
        now: _now(),
        sentTimestamps: _sentTimestamps,
        lastSentByLocation: _locationCooldowns,
      );

  /// Starts listening to the OS and, if the user granted Always, registers
  /// the nearest saved places for region monitoring.
  Future<void> _startBackgroundMonitoring() async {
    final geo = _geo;
    if (!geo.isSupported) return;

    _geofenceSubscription ??= geo.events.listen(_onGeofenceEvent);
    _authStatus = await geo.authorizationStatus();
    if (_authStatus.isAlways) {
      await geo.setSignificantChangesEnabled(true);
      await _refreshRegions();
    }
    // Last, so events queued while the app was launching arrive after we are
    // listening and have loaded the snapshot.
    await geo.signalReady();
  }

  Future<void> _stopBackgroundMonitoring() async {
    await _geofenceSubscription?.cancel();
    _geofenceSubscription = null;
    _registeredRegions = const [];
    _lastKnownPosition = null;

    final geo = _geo;
    if (!geo.isSupported) return;
    await geo.clearRegions();
    await geo.setSignificantChangesEnabled(false);
  }

  void _onGeofenceEvent(GeofenceEvent event) {
    switch (event) {
      case GeofenceEntered():
        unawaited(
          _serialized(
              () => _handleGeofenceEnter(event.locationId, event.position)),
        );
      case SignificantLocationChange():
        _lastKnownPosition = event.position;
        unawaited(_refreshRegions());
      case AuthorizationChanged():
        unawaited(_onAuthorizationChanged(event.status));
      case NotificationTapped():
        unawaited(_routeNotificationTap(event.payload));
    }
  }

  Future<void> _onAuthorizationChanged(LocationAuthStatus status) async {
    _authStatus = status;
    final geo = _geo;
    if (status.isAlways) {
      await geo.setSignificantChangesEnabled(true);
      await _refreshRegions();
    } else {
      _registeredRegions = const [];
      await geo.clearRegions();
      await geo.setSignificantChangesEnabled(false);
    }
  }

  /// Re-picks the places to monitor. Cheap to call: it only talks to the OS
  /// when the chosen set actually changed.
  Future<void> _refreshRegions() async {
    if (!_authStatus.isAlways || _userId == null) return;

    final regions = selectGeofenceRegions(
      candidates: _candidates.values,
      policy: _policy,
      context: _context(),
      position: _locationService.currentPosition ?? _lastKnownPosition,
    );
    if (listEquals(regions, _registeredRegions)) return;

    _registeredRegions = regions;
    debugPrint('[Proximity] monitoring ${regions.length} regions');
    await _geo.registerRegions(regions);
  }

  /// The OS says the user entered a monitored place. This may run in a fresh
  /// background launch, so it uses only on-device state and posts a local
  /// notification. Places blocked right now (closed, quiet hours, hourly cap)
  /// are simply skipped: without location ticks there is nothing to retry on.
  Future<void> _handleGeofenceEnter(int locationId, LatLng? at) async {
    final userId = _userId;
    final candidate = _candidates[locationId];
    if (userId == null || candidate == null) return;

    _trimSentTimestamps(_now());
    final radius = _policy.config.radiusMeters;
    final distance =
        at == null ? radius : math.min(_distanceTo(at, candidate), radius);

    final evaluation = _policy.evaluate(
      candidates: [(candidate: candidate, distanceMeters: distance)],
      context: _context(),
    );
    if (evaluation.selected.isEmpty) return;

    final decision = evaluation.selected.first;
    final message = buildProximityMessage(decision);
    final posted = await _geo.postNotification(
      id: 'proximity_$locationId',
      title: message.title,
      body: message.body,
      payload: {
        ...message.metadata,
        'type': 'proximity_location',
        'deepLink': 'pinit://location/$locationId',
      },
    );
    if (!posted) return;

    final sentAt = _now();
    _sentTimestamps.add(sentAt);
    _locationCooldowns[locationId] = sentAt;
    _insideLocationIds.add(locationId);
    await _persistSentTimestamps();
    await _persistLocationCooldowns();
    await _persistInsideLocationIds();
    unawaited(_data.logSent(locationId));
    // The cooled-down place frees its OS region slot for the next nearest.
    unawaited(_refreshRegions());
  }

  Future<void> _routeNotificationTap(Map<String, dynamic> payload) async {
    final deepLink = payload['deepLink']?.toString().trim();
    if (deepLink == null || deepLink.isEmpty) return;
    try {
      await _tapHandler(deepLink, payload);
    } catch (e) {
      debugPrint('[Proximity] notification tap routing failed: $e');
    }
  }

  void _loadCandidateSnapshot(String userId) {
    final raw = _prefs?.getString(_candidatesKey(userId));
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _candidates.clear();
      for (final entry in decoded) {
        final candidate = ProximityCandidate.tryFromJson(entry);
        if (candidate != null) _candidates[candidate.locationId] = candidate;
      }
    } catch (e) {
      debugPrint('[Proximity] snapshot load failed: $e');
    }
  }

  Future<void> _persistCandidateSnapshot() async {
    final userId = _userId;
    if (userId == null) return;
    final json = jsonEncode(_candidates.values.map((c) => c.toJson()).toList());
    await _prefs?.setString(_candidatesKey(userId), json);
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
        await _serialized(() => _processLocationUpdate(currentPosition));
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

  String _candidatesKey(String userId) => '$_candidatesKeyPrefix:$userId';

  String _promptHistoryKey(String userId) => '$_promptHistoryKeyPrefix:$userId';

  String _promptPendingKey(String userId) => '$_promptPendingKeyPrefix:$userId';
}

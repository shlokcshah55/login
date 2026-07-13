import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/users.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/services/startup_cache/startup_snapshot.dart';
import 'package:login/services/startup_cache/startup_snapshot_store.dart';

enum StartupCacheRefreshStatus { idle, refreshing, fresh, stale }

class StartupHydrationResult {
  const StartupHydrationResult({
    required this.profileHydrated,
    required this.savedLocationsHydrated,
    required this.hasCurrentConsent,
    this.writtenAt,
  });

  static const empty = StartupHydrationResult(
    profileHydrated: false,
    savedLocationsHydrated: false,
    hasCurrentConsent: false,
  );

  final bool profileHydrated;
  final bool savedLocationsHydrated;
  final bool hasCurrentConsent;
  final DateTime? writtenAt;

  bool get hasUsableHomeData =>
      profileHydrated && savedLocationsHydrated && hasCurrentConsent;
}

class StartupCacheCoordinator extends ChangeNotifier {
  StartupCacheCoordinator({
    required StartupSnapshotStore store,
    this.requiredConsentVersion = currentLegalConsentVersion,
    this.writeDebounce = const Duration(milliseconds: 500),
    this.enabled = const bool.fromEnvironment(
      'PINIT_STARTUP_CACHE_ENABLED',
      defaultValue: true,
    ),
    DateTime Function()? now,
  })  : _store = store,
        _now = now ?? DateTime.now;

  static const String currentLegalConsentVersion = 'v1';

  final StartupSnapshotStore _store;
  final String requiredConsentVersion;
  final Duration writeDebounce;
  final bool enabled;
  final DateTime Function() _now;

  String? _activeUserId;
  String? _acceptedConsentVersion;
  String? _lastFingerprint;
  StartupSnapshot? _pendingSnapshot;
  Timer? _writeTimer;
  bool _hasHydratedData = false;
  StartupCacheRefreshStatus _refreshStatus = StartupCacheRefreshStatus.idle;
  StartupSnapshotReadResult? _lastReadResult;

  String? get activeUserId => _activeUserId;
  StartupCacheRefreshStatus get refreshStatus => _refreshStatus;
  StartupSnapshotReadResult? get lastReadResult => _lastReadResult;

  Future<StartupHydrationResult> hydrate({
    required String userId,
    required UserDataProvider userDataProvider,
    required LocationListManager locationListManager,
  }) async {
    _activeUserId = userId;
    _hasHydratedData = false;
    _refreshStatus = StartupCacheRefreshStatus.idle;
    if (!enabled) return StartupHydrationResult.empty;

    final result = await _store.read(userId);
    if (_activeUserId != userId) return StartupHydrationResult.empty;
    _lastReadResult = result;
    final snapshot = result.snapshot;
    if (result.status != StartupSnapshotReadStatus.hit || snapshot == null) {
      _acceptedConsentVersion = null;
      _lastFingerprint = null;
      return StartupHydrationResult.empty;
    }

    final profile = snapshot.profile;
    if (profile != null) {
      userDataProvider.hydrateCachedProfile(userId, profile);
    }
    locationListManager.hydrateCachedSavedLocations(snapshot.savedLocations);

    _acceptedConsentVersion = snapshot.acceptedConsentVersion;
    _hasHydratedData = true;
    _lastFingerprint = _fingerprint(snapshot);
    return StartupHydrationResult(
      profileHydrated: profile != null,
      savedLocationsHydrated: true,
      hasCurrentConsent:
          snapshot.acceptedConsentVersion == requiredConsentVersion,
      writtenAt: snapshot.writtenAt,
    );
  }

  void scheduleWrite({
    required String userId,
    required UserModel? profile,
    required List<LocationModel> savedLocations,
    String? acceptedConsentVersion,
  }) {
    if (!enabled || _activeUserId != userId) return;
    if (acceptedConsentVersion != null) {
      _acceptedConsentVersion = acceptedConsentVersion;
    }
    final snapshot = StartupSnapshot(
      schemaVersion: StartupSnapshot.currentSchemaVersion,
      userId: userId,
      writtenAt: _now().toUtc(),
      profile: profile,
      savedLocations: List<LocationModel>.of(savedLocations),
      acceptedConsentVersion: _acceptedConsentVersion,
    );
    if (_fingerprint(snapshot) == _lastFingerprint) return;

    _pendingSnapshot = snapshot;
    _writeTimer?.cancel();
    _writeTimer = Timer(writeDebounce, () {
      unawaited(_flushPendingWrite());
    });
  }

  void markConsentAccepted({
    required String userId,
    required UserModel? profile,
    required List<LocationModel> savedLocations,
  }) {
    scheduleWrite(
      userId: userId,
      profile: profile,
      savedLocations: savedLocations,
      acceptedConsentVersion: requiredConsentVersion,
    );
  }

  void clearConsentAcceptance({
    required String userId,
    required UserModel? profile,
    required List<LocationModel> savedLocations,
  }) {
    if (!enabled || _activeUserId != userId) return;
    _acceptedConsentVersion = null;
    scheduleWrite(
      userId: userId,
      profile: profile,
      savedLocations: savedLocations,
    );
  }

  void markRefreshStarted() {
    _setRefreshStatus(StartupCacheRefreshStatus.refreshing);
  }

  void markRefreshCompleted({required bool hadFailure}) {
    _setRefreshStatus(
      hadFailure
          ? (_hasHydratedData
              ? StartupCacheRefreshStatus.stale
              : StartupCacheRefreshStatus.idle)
          : StartupCacheRefreshStatus.fresh,
    );
  }

  Future<void> clearActiveUser() async {
    final userId = _activeUserId;
    if (userId == null) return;
    await clearUser(userId);
  }

  Future<void> clearUser(String userId) async {
    if (_activeUserId == userId) {
      _writeTimer?.cancel();
      _writeTimer = null;
      _pendingSnapshot = null;
      _activeUserId = null;
      _acceptedConsentVersion = null;
      _lastFingerprint = null;
      _lastReadResult = null;
      _hasHydratedData = false;
      _setRefreshStatus(StartupCacheRefreshStatus.idle);
    }
    await _store.clear(userId);
  }

  Future<void> _flushPendingWrite() async {
    final snapshot = _pendingSnapshot;
    _pendingSnapshot = null;
    if (snapshot == null || _activeUserId != snapshot.userId) return;

    final fingerprint = _fingerprint(snapshot);
    if (fingerprint == _lastFingerprint) return;
    try {
      await _store.write(snapshot);
      if (_activeUserId == snapshot.userId) {
        _lastFingerprint = fingerprint;
      }
    } catch (error) {
      debugPrint('Startup snapshot write failed: $error');
    }
  }

  String _fingerprint(StartupSnapshot snapshot) {
    final json = snapshot.toJson()..remove('written_at');
    return jsonEncode(json);
  }

  void _setRefreshStatus(StartupCacheRefreshStatus status) {
    if (_refreshStatus == status) return;
    _refreshStatus = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _writeTimer?.cancel();
    super.dispose();
  }
}

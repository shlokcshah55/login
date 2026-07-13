# Device Startup Cache Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make signed-in cold launches materially faster by hydrating profile, legal-consent, and saved-location state from a user-scoped device snapshot before refreshing from Supabase.

**Architecture:** Add a versioned JSON snapshot codec and atomic file store behind a narrow interface. A startup cache coordinator hydrates existing providers, debounces persistence, and is consumed by `AuthHandler`; remote loads stay authoritative and run stale-while-revalidate. Keep Firebase and notification-open registration early, while moving location setup, permission prompting, marker setup, and full FCM initialization into an idempotent post-frame initializer.

**Tech Stack:** Flutter/Dart, Provider, Supabase Flutter, `path_provider`, `crypto`, `cached_network_image`, `flutter_test`, `mocktail`

---

## File Map

**Create**

- `lib/services/startup_cache/startup_snapshot.dart` — immutable snapshot and cache-only codecs.
- `lib/services/startup_cache/startup_snapshot_store.dart` — store interface and atomic JSON implementation.
- `lib/services/startup_cache/startup_cache_coordinator.dart` — hydration, consent versioning, and debounced writes.
- `lib/services/startup_cache/startup_timing.dart` — monotonic launch milestones.
- `lib/widgets/startup_cache_status_banner.dart` — subtle stale-data indicator after refresh failure.
- `test/services/startup_cache/startup_snapshot_test.dart`
- `test/services/startup_cache/startup_snapshot_store_test.dart`
- `test/services/startup_cache/startup_cache_coordinator_test.dart`
- `test/services/startup_cache/startup_timing_test.dart`
- `test/providers/startup_cache_provider_hydration_test.dart`
- `test/bootstrap/app_bootstrap_test.dart`
- `test/widgets/startup_cache_status_banner_test.dart`

**Modify**

- `lib/bootstrap/app_dependencies.dart`
- `lib/bootstrap/app_bootstrap.dart`
- `lib/main.dart`
- `lib/app/app_providers.dart`
- `lib/app/app_root.dart`
- `lib/models/users.dart`
- `lib/providers/user_data_provider.dart`
- `lib/providers/location_list_provider.dart`
- `lib/pages/auth_handler.dart`
- `lib/services/analytics_service.dart`
- `test/models/user_model_referral_code_test.dart`
- `test/pages/auth_handler_test.dart`

## Task 1: Versioned Snapshot Codec

**Files:**

- Create: `lib/services/startup_cache/startup_snapshot.dart`
- Create: `test/services/startup_cache/startup_snapshot_test.dart`
- Modify: `lib/models/users.dart:164-189`
- Modify: `test/models/user_model_referral_code_test.dart`

- [ ] **Step 1: Write the failing round-trip tests**

```dart
test('round trip preserves startup fields and saved metadata', () {
  final snapshot = StartupSnapshot(
    schemaVersion: StartupSnapshot.currentSchemaVersion,
    userId: 'user-1',
    writtenAt: DateTime.utc(2026, 7, 13, 10),
    acceptedConsentVersion: 'v1',
    profile: UserModel(
      supabaseId: 'user-1',
      email: 'pinit@example.com',
      name: 'Pinit User',
      wizardCompleted: true,
      verified: true,
    ),
    savedLocations: <LocationModel>[
      LocationModel(
        locationId: 42,
        name: 'Cafe Cache',
        createdAt: DateTime.utc(2026, 7, 1),
        lat: 51.5,
        lng: -0.1,
        imageUrl: 'https://images.example/42.jpg',
        savedMethod: 'tiktok',
        savedAt: DateTime.utc(2026, 7, 12),
        videoExtras: const VideoExtras(personalNotes: 'Order the bun'),
      ),
    ],
  );

  final decoded = StartupSnapshot.fromJson(snapshot.toJson());

  expect(decoded.userId, 'user-1');
  expect(decoded.profile?.wizardCompleted, isTrue);
  expect(decoded.profile?.verified, isTrue);
  expect(decoded.acceptedConsentVersion, 'v1');
  expect(decoded.savedLocations.single.imageUrl,
      'https://images.example/42.jpg');
  expect(decoded.savedLocations.single.savedMethod, 'tiktok');
  expect(decoded.savedLocations.single.videoExtras?.personalNotes,
      'Order the bun');
});

test('unsupported schema throws a format exception', () {
  expect(
    () => StartupSnapshot.fromJson(<String, dynamic>{
      'schema_version': 999,
      'user_id': 'user-1',
      'written_at': '2026-07-13T10:00:00.000Z',
      'saved_locations': <dynamic>[],
    }),
    throwsA(isA<StartupSnapshotFormatException>()),
  );
});
```

- [ ] **Step 2: Run the tests to verify failure**

Run:

```bash
flutter test test/services/startup_cache/startup_snapshot_test.dart test/models/user_model_referral_code_test.dart
```

Expected: FAIL because the snapshot types do not exist and `UserModel.toJson()` drops startup fields.

- [ ] **Step 3: Implement the snapshot types and codecs**

```dart
class StartupSnapshotFormatException implements Exception {
  const StartupSnapshotFormatException(this.message);
  final String message;
}

class StartupSnapshotUnsupportedSchemaException
    extends StartupSnapshotFormatException {
  const StartupSnapshotUnsupportedSchemaException(super.message);
}

class StartupSnapshot {
  const StartupSnapshot({
    required this.schemaVersion,
    required this.userId,
    required this.writtenAt,
    required this.savedLocations,
    this.profile,
    this.acceptedConsentVersion,
  });

  static const int currentSchemaVersion = 1;
  final int schemaVersion;
  final String userId;
  final DateTime writtenAt;
  final UserModel? profile;
  final List<LocationModel> savedLocations;
  final String? acceptedConsentVersion;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schema_version': schemaVersion,
        'user_id': userId,
        'written_at': writtenAt.toUtc().toIso8601String(),
        'accepted_consent_version': acceptedConsentVersion,
        'profile': profile?.toJson(),
        'saved_locations': savedLocations.map(_encodeLocation).toList(),
      };
}
```

`StartupSnapshot.fromJson` must reject unsupported schemas and invalid ownership metadata. Parse profile and saved-location sections independently: an invalid profile becomes `null`, and each invalid location record is skipped without discarding valid records. `_encodeLocation` merges `LocationModel.toJson()` with `_cache_image_url`, `_cache_match_score`, `_cache_saved_from`, `_cache_saved_method`, `_cache_saved_at`, and `_cache_video_extras`. `_decodeLocation` calls `LocationModel.fromJson`, then `copyWith` for cached match and saved metadata. Encode `VideoExtras` as `special_offers` and `personal_notes`.

Extend `UserModel.toJson()` to include the exact fields already accepted by `fromJson`: `created_at`, `last_login`, `followers_count`, `following_count`, `wizard_completed`, `generated_collections`, and `verified`. Update `fromJson` so `generated_collections: false` remains false instead of being interpreted as true merely because the key exists.

- [ ] **Step 4: Format and rerun tests**

```bash
dart format lib/services/startup_cache/startup_snapshot.dart lib/models/users.dart test/services/startup_cache/startup_snapshot_test.dart test/models/user_model_referral_code_test.dart
flutter test test/services/startup_cache/startup_snapshot_test.dart test/models/user_model_referral_code_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/startup_cache/startup_snapshot.dart lib/models/users.dart test/services/startup_cache/startup_snapshot_test.dart test/models/user_model_referral_code_test.dart
git commit -m "feat: add startup snapshot codec"
```

## Task 2: Atomic User-Scoped Store

**Files:**

- Create: `lib/services/startup_cache/startup_snapshot_store.dart`
- Create: `test/services/startup_cache/startup_snapshot_store_test.dart`

- [ ] **Step 1: Write failing file-store tests**

```dart
setUp(() async {
  directory = await Directory.systemTemp.createTemp('pinit-startup-cache-');
  store = JsonStartupSnapshotStore(
    directoryProvider: () async => directory,
    maxBytes: 1024 * 1024,
  );
});

test('reads only the matching user snapshot', () async {
  await store.write(startupSnapshot(userId: 'user-1'));
  expect((await store.read('user-1')).snapshot?.userId, 'user-1');
  expect((await store.read('user-2')).status,
      StartupSnapshotReadStatus.miss);
});

test('corrupt JSON is a cache miss', () async {
  await store.write(startupSnapshot(userId: 'user-1'));
  final file = await store.debugFileForUser('user-1');
  await file.writeAsString('{broken');
  expect((await store.read('user-1')).status,
      StartupSnapshotReadStatus.corrupt);
});
```

Also cover unsupported schema, maximum size, replacement, `clear(userId)`, and `clearAll()`.

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/services/startup_cache/startup_snapshot_store_test.dart
```

Expected: FAIL because the store types do not exist.

- [ ] **Step 3: Implement the interface and JSON store**

```dart
abstract interface class StartupSnapshotStore {
  Future<StartupSnapshotReadResult> read(String userId);
  Future<void> write(StartupSnapshot snapshot);
  Future<void> clear(String userId);
  Future<void> clearAll();
}

enum StartupSnapshotReadStatus {
  hit,
  miss,
  corrupt,
  unsupportedSchema,
  ownershipMismatch,
  tooLarge,
}

class StartupSnapshotReadResult {
  const StartupSnapshotReadResult({
    required this.status,
    this.snapshot,
    this.byteSize = 0,
  });
  final StartupSnapshotReadStatus status;
  final StartupSnapshot? snapshot;
  final int byteSize;
}

typedef CacheDirectoryProvider = Future<Directory> Function();

class JsonStartupSnapshotStore implements StartupSnapshotStore {
  JsonStartupSnapshotStore({
    CacheDirectoryProvider? directoryProvider,
    this.maxBytes = 5 * 1024 * 1024,
  }) : _directoryProvider =
            directoryProvider ?? getApplicationSupportDirectory;

  final CacheDirectoryProvider _directoryProvider;
  final int maxBytes;
  Future<void> _writeQueue = Future<void>.value();
}
```

Hash user IDs with SHA-256 for filenames. `read` returns a typed status for missing, too-large, corrupt, unsupported-schema, ownership-mismatch, and successful reads; include byte size but no personal data. Serialize writes by chaining `_writeQueue`; UTF-8 encode once, reject oversized output, write `<hash>.json.tmp` with `flush: true`, then replace `<hash>.json`. `clearAll` deletes only the `pinit_startup_cache` subdirectory.

- [ ] **Step 4: Format and rerun tests**

```bash
dart format lib/services/startup_cache/startup_snapshot_store.dart test/services/startup_cache/startup_snapshot_store_test.dart
flutter test test/services/startup_cache/startup_snapshot_store_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/startup_cache/startup_snapshot_store.dart test/services/startup_cache/startup_snapshot_store_test.dart
git commit -m "feat: persist startup snapshots atomically"
```

## Task 3: Provider Hydration Seams

**Files:**

- Modify: `lib/providers/user_data_provider.dart:40-121`
- Modify: `lib/providers/location_list_provider.dart:82-145,287-336,846-951,2533-2556`
- Create: `test/providers/startup_cache_provider_hydration_test.dart`

- [ ] **Step 1: Write failing provider tests**

```dart
test('cached profile publishes without a remote fetch', () {
  final provider = UserDataProvider();
  final profile = UserModel(
    supabaseId: 'user-1',
    email: 'cached@example.com',
    name: 'Cached User',
  );
  provider.hydrateCachedProfile('user-1', profile);
  expect(provider.supabaseUserData, same(profile));
  expect(provider.isLoading, isFalse);
  expect(provider.isStale, isTrue);
});

test('cached locations are usable before marker rebuild', () {
  final manager = LocationListManager(FakeGooglePlacesService());
  manager.setUserId('user-1', fetchSavedLocations: false);
  manager.hydrateCachedSavedLocations(<LocationModel>[
    LocationModel(
      locationId: 7,
      name: 'Cached Place',
      createdAt: DateTime.utc(2026, 7, 1),
      lat: 51.5,
      lng: -0.1,
    ),
  ]);
  expect(manager.hasLoadedSavedLocations, isTrue);
  expect(manager.isSavedDataStale, isTrue);
  expect(manager.savedLocations.values.single.position.latitude, 51.5);
});
```

- [ ] **Step 2: Run tests to verify missing APIs**

```bash
flutter test test/providers/startup_cache_provider_hydration_test.dart
```

Expected: FAIL because hydration and stale-state APIs do not exist.

- [ ] **Step 3: Implement cached profile state**

Add `_isStale`, `isStale`, `hydrateCachedProfile`, and `refreshUserData`. Extract the repeated legacy map creation into `_legacyMapFor(UserModel)`. Add `preserveExisting = false` to `setUserIdAndFetchData`; a failed preserved refresh retains the cached model and stale flag, while success sets `_isStale = false`.

```dart
void hydrateCachedProfile(String userId, UserModel profile) {
  if (profile.supabaseId != null && profile.supabaseId != userId) return;
  _userId = userId;
  _supabaseUserData = profile;
  _userData = _legacyMapFor(profile);
  _isLoading = false;
  _isStale = true;
  _error = null;
  notifyListeners();
}
```

- [ ] **Step 4: Implement cached saved-location state**

Change `setUserId` to `setUserId(String? userId, {bool fetchSavedLocations = true})`, guarding only the initial saved-location fetch. Add `hydrateCachedSavedLocations`, `isSavedDataStale`, and `isRebuildingCachedMarkers`.

```dart
void hydrateCachedSavedLocations(List<LocationModel> locations) {
  _allSavedLocations = List<LocationModel>.of(locations);
  _savedLocations = <LocationModel, MapMarkerData>{
    for (final location in locations)
      location: MapMarkerData(
        id: location.locationId.toString(),
        position: LatLng(location.lat ?? 0, location.lng ?? 0),
        imageBytes: const <int>[],
      ),
  };
  _savedLocationsLoaded = true;
  _isSavedDataStale = true;
  if (_currentListType == LocationListType.saved) {
    _currentItems = Map.of(_savedLocations);
  }
  notifyListeners();
  unawaited(_rebuildCachedSavedMarkers(locations));
}
```

Marker rebuilding checks the active user/location IDs before swapping maps and retains placeholders on failure. Add `force = false` to `fetchSavedLocations`; forced refresh bypasses the loaded guard without clearing usable cached data. On success set `_isSavedDataStale = false`. Make `refreshSavedLocations` call `fetchSavedLocations(force: true)`.

- [ ] **Step 5: Format and run provider regression tests**

```bash
dart format lib/providers/user_data_provider.dart lib/providers/location_list_provider.dart test/providers/startup_cache_provider_hydration_test.dart
flutter test test/providers/startup_cache_provider_hydration_test.dart test/pages/home/widgets/home_map_sync_gate_test.dart test/providers/location_list_manager_clear_bubble_locations_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/providers/user_data_provider.dart lib/providers/location_list_provider.dart test/providers/startup_cache_provider_hydration_test.dart
git commit -m "feat: hydrate startup providers from cache"
```

## Task 4: Startup Cache Coordinator

**Files:**

- Create: `lib/services/startup_cache/startup_cache_coordinator.dart`
- Create: `test/services/startup_cache/startup_cache_coordinator_test.dart`

- [ ] **Step 1: Write failing coordinator tests**

```dart
test('hydrates matching cached sections before refresh work', () async {
  final coordinator = StartupCacheCoordinator(
    store: FakeStartupSnapshotStore(
      startupSnapshot(userId: 'user-1', consentVersion: 'v1'),
    ),
    requiredConsentVersion: 'v1',
    writeDebounce: Duration.zero,
  );
  final result = await coordinator.hydrate(
    userId: 'user-1',
    userDataProvider: userProvider,
    locationListManager: locationManager,
  );
  expect(result.profileHydrated, isTrue);
  expect(result.savedLocationsHydrated, isTrue);
  expect(result.hasCurrentConsent, isTrue);
});
```

Also test partial snapshots, debounced writes, duplicate suppression, clear-on-logout, and a user switch during an outstanding read.

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/services/startup_cache/startup_cache_coordinator_test.dart
```

Expected: FAIL because coordinator types do not exist.

- [ ] **Step 3: Implement results, hydration, and debounced writes**

```dart
class StartupHydrationResult {
  const StartupHydrationResult({
    required this.profileHydrated,
    required this.savedLocationsHydrated,
    required this.hasCurrentConsent,
    this.writtenAt,
  });
  final bool profileHydrated;
  final bool savedLocationsHydrated;
  final bool hasCurrentConsent;
  final DateTime? writtenAt;
  bool get hasUsableHomeData =>
      profileHydrated && savedLocationsHydrated && hasCurrentConsent;
}

enum StartupCacheRefreshStatus { idle, refreshing, fresh, stale }

class StartupCacheCoordinator extends ChangeNotifier {
  StartupCacheCoordinator({
    required StartupSnapshotStore store,
    this.requiredConsentVersion = currentLegalConsentVersion,
    this.writeDebounce = const Duration(milliseconds: 500),
    this.enabled = const bool.fromEnvironment(
      'PINIT_STARTUP_CACHE_ENABLED',
      defaultValue: true,
    ),
  }) : _store = store;

  static const String currentLegalConsentVersion = 'v1';
  final StartupSnapshotStore _store;
  final String requiredConsentVersion;
  final Duration writeDebounce;
  final bool enabled;
  StartupCacheRefreshStatus _refreshStatus =
      StartupCacheRefreshStatus.idle;
  StartupCacheRefreshStatus get refreshStatus => _refreshStatus;
}
```

`hydrate` checks ownership both before and after the store await, records the typed read status, and hydrates valid sections independently. `scheduleWrite` captures profile and saved locations, preserves accepted consent unless replaced, resets one timer, and writes only if the active user still matches and encoded JSON changed. `markConsentAccepted` writes the current version. `clearUser` cancels pending work and deletes that user's file. When `enabled` is false, hydration and writes are no-ops while clearing remains active; test this as the `--dart-define=PINIT_STARTUP_CACHE_ENABLED=false` kill switch.

The coordinator owns `refreshStatus`. `markRefreshStarted()` selects `refreshing`; `markRefreshCompleted(hadFailure: false)` selects `fresh`; a failed refresh with cached content selects `stale`. Test every transition and notification.

- [ ] **Step 4: Format and rerun tests**

```bash
dart format lib/services/startup_cache/startup_cache_coordinator.dart test/services/startup_cache/startup_cache_coordinator_test.dart
flutter test test/services/startup_cache/startup_cache_coordinator_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/startup_cache/startup_cache_coordinator.dart test/services/startup_cache/startup_cache_coordinator_test.dart
git commit -m "feat: coordinate cached startup state"
```

## Task 5: Authentication and Consent Integration

**Files:**

- Modify: `lib/bootstrap/app_dependencies.dart`
- Modify: `lib/app/app_providers.dart`
- Modify: `lib/bootstrap/app_bootstrap.dart`
- Modify: `lib/app/app_root.dart:45-74`
- Modify: `lib/pages/auth_handler.dart:29-377`
- Create: `lib/widgets/startup_cache_status_banner.dart`
- Modify: `test/pages/auth_handler_test.dart`
- Create: `test/widgets/startup_cache_status_banner_test.dart`

- [ ] **Step 1: Write failing routing decision tests**

```dart
test('complete cache shows home while remote refresh is pending', () {
  expect(
    resolveAuthenticatedStartupSurface(
      hasValidSession: true,
      hasProfile: true,
      hasSavedLocations: true,
      hasCurrentConsent: true,
    ),
    AuthenticatedStartupSurface.home,
  );
});

test('consent mismatch returns the legal gate', () {
  expect(
    resolveAuthenticatedStartupSurface(
      hasValidSession: true,
      hasProfile: true,
      hasSavedLocations: true,
      hasCurrentConsent: false,
    ),
    AuthenticatedStartupSurface.legalConsent,
  );
});
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/pages/auth_handler_test.dart
```

Expected: FAIL because the surface decision types do not exist.

- [ ] **Step 3: Inject one coordinator instance**

Add `StartupCacheCoordinator startupCacheCoordinator` to `AppDependencies`, construct it with `JsonStartupSnapshotStore()` in `bootstrap`, and provide it using `ChangeNotifierProvider<StartupCacheCoordinator>.value` in `AppProviders`.

- [ ] **Step 4: Hydrate before network-backed user initialization**

Refactor `_initializeUserData` to set the user scope without fetching saved locations, hydrate the cache, publish complete cached state, and launch `_refreshAuthenticatedData` without awaiting it.

```dart
locationListManager.setUserId(
  supabaseUser.id,
  fetchSavedLocations: false,
);
final cached = await coordinator.hydrate(
  userId: supabaseUser.id,
  userDataProvider: userDataProvider,
  locationListManager: locationListManager,
);
if (cached.hasCurrentConsent) {
  _legalConsentCheckedUserId = supabaseUser.id;
  _hasAcceptedLegalConsent = true;
}
if (cached.profileHydrated && cached.savedLocationsHydrated) {
  _hasInitializedData = true;
  _isInitializing = false;
  if (mounted) setState(() {});
  unawaited(_refreshAuthenticatedData(
    supabaseUser.id,
    userDataProvider,
    locationListManager,
  ));
  return;
}
```

For partial or absent cache, await only missing sections. `_refreshAuthenticatedData` runs profile refresh, forced saved-location refresh, and consent refresh concurrently, retaining cache on errors. Check the active user after every await.

- [ ] **Step 5: Persist provider changes and version consent**

Attach listeners after the user scope is established; listener callbacks call coordinator `scheduleWrite` and rely on debounce/duplicate suppression. On server-confirmed consent and `_acceptLegalConsent`, call `markConsentAccepted`. On logout, account cleanup, or user switch, remove listeners and clear the prior user's snapshot.

In the existing app-level auth listener, call `clearActiveUser()` when the session becomes null. This guarantees cache cleanup for logout and account deletion even when `AuthHandler` is not mounted. On a user switch, clear the prior active user before hydrating the next one.

- [ ] **Step 6: Implement and use the pure surface decision**

```dart
enum AuthenticatedStartupSurface { splash, legalConsent, home }

AuthenticatedStartupSurface resolveAuthenticatedStartupSurface({
  required bool hasValidSession,
  required bool hasProfile,
  required bool hasSavedLocations,
  required bool hasCurrentConsent,
}) {
  if (!hasValidSession || !hasProfile || !hasSavedLocations) {
    return AuthenticatedStartupSurface.splash;
  }
  if (!hasCurrentConsent) return AuthenticatedStartupSurface.legalConsent;
  return AuthenticatedStartupSurface.home;
}
```

Remote-refresh state alone must never return the splash after cached state is usable.

- [ ] **Step 7: Show stale state only after refresh failure**

Call `markRefreshStarted()` before background refresh and `markRefreshCompleted(hadFailure: ...)` afterward. Wrap the home surface with a banner that only renders for `stale`:

```dart
class StartupCacheStatusBanner extends StatelessWidget {
  const StartupCacheStatusBanner({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final status = context.watch<StartupCacheCoordinator>().refreshStatus;
    return Stack(
      children: <Widget>[
        child,
        if (status == StartupCacheRefreshStatus.stale)
          const SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Material(child: Text('Showing saved data')),
            ),
          ),
      ],
    );
  }
}
```

Widget tests assert the message is absent for `idle`, `refreshing`, and `fresh`, and present for `stale` without replacing the child.

- [ ] **Step 8: Format and run integration tests**

```bash
dart format lib/bootstrap/app_dependencies.dart lib/app/app_providers.dart lib/bootstrap/app_bootstrap.dart lib/app/app_root.dart lib/pages/auth_handler.dart lib/widgets/startup_cache_status_banner.dart test/pages/auth_handler_test.dart test/widgets/startup_cache_status_banner_test.dart
flutter test test/pages/auth_handler_test.dart test/services/startup_cache test/providers/startup_cache_provider_hydration_test.dart test/widgets/startup_cache_status_banner_test.dart
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/bootstrap/app_dependencies.dart lib/app/app_providers.dart lib/bootstrap/app_bootstrap.dart lib/app/app_root.dart lib/pages/auth_handler.dart lib/widgets/startup_cache_status_banner.dart test/pages/auth_handler_test.dart test/widgets/startup_cache_status_banner_test.dart
git commit -m "feat: show cached home state during refresh"
```

## Task 6: Deferred Noncritical Bootstrap

**Files:**

- Modify: `lib/bootstrap/app_dependencies.dart`
- Modify: `lib/bootstrap/app_bootstrap.dart`
- Modify: `lib/app/app_root.dart`
- Create: `test/bootstrap/app_bootstrap_test.dart`

- [ ] **Step 1: Write the failing idempotence test**

```dart
test('deferred initializer runs once', () async {
  var calls = 0;
  final initializer = DeferredAppInitializer(
    initialize: () async => calls += 1,
  );
  await Future.wait(<Future<void>>[
    initializer.start(),
    initializer.start(),
  ]);
  expect(calls, 1);
});
```

- [ ] **Step 2: Run the test to verify failure**

```bash
flutter test test/bootstrap/app_bootstrap_test.dart
```

Expected: FAIL because `DeferredAppInitializer` does not exist.

- [ ] **Step 3: Implement the initializer**

```dart
class DeferredAppInitializer {
  DeferredAppInitializer({required Future<void> Function() initialize})
      : _initialize = initialize;
  final Future<void> Function() _initialize;
  Future<void>? _active;
  Future<void> start() => _active ??= _initialize();
}
```

Keep bindings, analytics metadata, Firebase, background-message registration, notification-open registration, `.env`, Mapbox token, Supabase, and dependency construction in essential bootstrap. Move notification permission, `LocationService.initialize`, `LocationModel.initializeCustomMarker`, and `FCMService.initialize` into the deferred initializer with independent error handling.

- [ ] **Step 4: Start deferred work after first frame**

Pass the initializer through `AppDependencies`. Add `AppDependencies dependencies` to `MyApp`, construct it from `AppRoot`, and schedule:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  unawaited(widget.dependencies.deferredInitializer.start());
});
```

- [ ] **Step 5: Format and run bootstrap/notification tests**

```bash
dart format lib/bootstrap/app_dependencies.dart lib/bootstrap/app_bootstrap.dart lib/app/app_root.dart test/bootstrap/app_bootstrap_test.dart
flutter test test/bootstrap/app_bootstrap_test.dart test/services/fcm_service_test.dart test/ios/share_extension_app_group_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/bootstrap/app_dependencies.dart lib/bootstrap/app_bootstrap.dart lib/app/app_root.dart test/bootstrap/app_bootstrap_test.dart
git commit -m "perf: defer noncritical app initialization"
```

## Task 7: Startup Timing Instrumentation

**Files:**

- Create: `lib/services/startup_cache/startup_timing.dart`
- Create: `test/services/startup_cache/startup_timing_test.dart`
- Modify: `lib/main.dart`
- Modify: `lib/app/app_root.dart`
- Modify: `lib/pages/auth_handler.dart`
- Modify: `lib/services/analytics_service.dart`

- [ ] **Step 1: Write failing milestone tests**

```dart
test('records monotonic milestone duration once', () {
  final timing = StartupTiming(clock: fakeStopwatch)..markDartEntry();
  fakeStopwatch.elapse(const Duration(milliseconds: 12));
  timing.mark(StartupMilestone.runApp);
  timing.mark(StartupMilestone.runApp);
  expect(timing.elapsedFor(StartupMilestone.runApp), 12);
});
```

- [ ] **Step 2: Run tests to verify failure**

```bash
flutter test test/services/startup_cache/startup_timing_test.dart
```

Expected: FAIL because timing types do not exist.

- [ ] **Step 3: Implement milestone and outcome types**

Define `StartupMilestone` values for `runApp`, `firstFrame`, `snapshotRead`, `cachedProvidersUsable`, `firstUsableHome`, `profileRefresh`, `savedLocationsRefresh`, and `markerBuild`. Project `StartupSnapshotReadStatus` plus partial-hit detection into analytics. Use one started `Stopwatch`, ignore duplicate marks, and expose analytics properties containing only names, durations, byte size, and outcome.

- [ ] **Step 4: Wire timing**

Mark Dart entry before `bootstrap`, `runApp` immediately before `runApp`, first frame in the app post-frame callback, snapshot outcome in the coordinator, and first usable home when `AuthHandler` first selects home. Emit one `startup_performance` event and separate background-refresh events without profile/location data.

- [ ] **Step 5: Format and run timing/analytics tests**

```bash
dart format lib/services/startup_cache/startup_timing.dart lib/main.dart lib/app/app_root.dart lib/pages/auth_handler.dart lib/services/analytics_service.dart test/services/startup_cache/startup_timing_test.dart
flutter test test/services/startup_cache/startup_timing_test.dart test/services/analytics_service_test.dart test/pages/auth_handler_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/services/startup_cache/startup_timing.dart lib/main.dart lib/app/app_root.dart lib/pages/auth_handler.dart lib/services/analytics_service.dart test/services/startup_cache/startup_timing_test.dart
git commit -m "feat: measure cached startup milestones"
```

## Task 8: Regression and Device Verification

**Files:**

- Modify only files needed to correct regressions introduced by Tasks 1-7.

- [ ] **Step 1: Run focused tests**

```bash
flutter test test/services/startup_cache test/providers/startup_cache_provider_hydration_test.dart test/pages/auth_handler_test.dart test/bootstrap/app_bootstrap_test.dart test/services/analytics_service_test.dart test/services/fcm_service_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run static analysis**

```bash
flutter analyze
```

Expected: no new diagnostics in files changed by this plan.

- [ ] **Step 3: Run the complete suite**

```bash
flutter test
```

Expected: PASS.

- [ ] **Step 4: Run profile-mode cold launches**

```bash
flutter run --profile
```

On Android and iOS, launch once to populate the snapshot, force-stop, and launch again. Verify cached profile and saves appear before refresh completion, refresh never restores the splash, logout clears the snapshot, offline launch retains cache, and notification/deep-link routing still works.

- [ ] **Step 5: Record honest evidence**

Report exact focused-test, full-suite, analysis, and device results. Label simulator-only or single-platform runs as partial verification.

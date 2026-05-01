# Default Picks Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Default the home pin list to Picks when the user's saved pins are too sparse to make the saved list useful.

**Architecture:** Put the saved-list sparsity calculation in `LocationListManager` so it can be tested independently and reused by startup orchestration. Let `HomeViewModel` run the startup decision once after saved pins have loaded and a user position is available, then switch to `recommended` and fetch Picks only when the helper says saved pins are sparse.

**Tech Stack:** Flutter, Dart, Provider `ChangeNotifier`, `flutter_test`, existing `LocationModel` and `LatLng` coordinate types.

---

### Task 1: Sparse Saved-List Decision Helper

**Files:**
- Modify: `lib/providers/location_list_provider.dart`
- Test: `test/providers/location_list_manager_default_picks_fallback_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/providers/location_list_manager_default_picks_fallback_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:login/models/locations.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:login/utils/geo_types.dart';
import 'package:mocktail/mocktail.dart';

class _MockGooglePlacesService extends Mock implements GooglePlacesService {}

void main() {
  setUpAll(() {
    dotenv.testLoad(
      fileInput: 'GOOGLE_PLACE_API_KEY=test\nAPI_SECRET_KEY=test\n',
    );
  });

  test('defaults to Picks when fewer than 10 saved locations exist', () {
    final manager = LocationListManager(_MockGooglePlacesService());

    final shouldUsePicks = manager.shouldDefaultPinsToRecommendations(
      userPosition: const LatLng(51.5000, -0.1200),
      savedLocations: List.generate(
        9,
        (index) => _location(
          index,
          51.5000,
          -0.1200 + index * 0.001,
        ),
      ),
    );

    expect(shouldUsePicks, isTrue);
  });

  test('defaults to Picks when fewer than 5 saved locations are within 4km', () {
    final manager = LocationListManager(_MockGooglePlacesService());

    final shouldUsePicks = manager.shouldDefaultPinsToRecommendations(
      userPosition: const LatLng(51.5000, -0.1200),
      savedLocations: [
        ...List.generate(
          4,
          (index) => _location(
            index,
            51.5000,
            -0.1200 + index * 0.001,
          ),
        ),
        ...List.generate(
          6,
          (index) => _location(
            100 + index,
            51.9000,
            -0.1200,
          ),
        ),
      ],
    );

    expect(shouldUsePicks, isTrue);
  });

  test('keeps saved pins when total and nearby saved thresholds are met', () {
    final manager = LocationListManager(_MockGooglePlacesService());

    final shouldUsePicks = manager.shouldDefaultPinsToRecommendations(
      userPosition: const LatLng(51.5000, -0.1200),
      savedLocations: [
        ...List.generate(
          5,
          (index) => _location(
            index,
            51.5000,
            -0.1200 + index * 0.001,
          ),
        ),
        ...List.generate(
          5,
          (index) => _location(
            100 + index,
            51.9000,
            -0.1200,
          ),
        ),
      ],
    );

    expect(shouldUsePicks, isFalse);
  });
}

LocationModel _location(int id, double lat, double lng) {
  return LocationModel(
    locationId: id,
    name: 'Location $id',
    lat: lat,
    lng: lng,
    createdAt: DateTime(2026, 5, 1),
  );
}
```

- [ ] **Step 2: Run the helper tests to verify they fail**

Run: `flutter test test/providers/location_list_manager_default_picks_fallback_test.dart`

Expected: FAIL because `LocationListManager.shouldDefaultPinsToRecommendations` is not defined.

- [ ] **Step 3: Add the minimal helper implementation**

In `lib/providers/location_list_provider.dart`, add constants near the other static constants:

```dart
  static const int defaultPinsMinimumSavedTotal = 10;
  static const int defaultPinsMinimumNearbySaved = 5;
  static const double defaultPinsNearbyRadiusKm = 4.0;
```

Add this public method after `_calculateDistance`:

```dart
  bool shouldDefaultPinsToRecommendations({
    required LatLng userPosition,
    Iterable<LocationModel>? savedLocations,
  }) {
    final locations = (savedLocations ?? _allSavedLocations).toList();
    if (locations.length < defaultPinsMinimumSavedTotal) {
      return true;
    }

    final nearbySavedCount = locations.where((location) {
      final lat = location.lat;
      final lng = location.lng;
      if (lat == null || lng == null) return false;
      return _calculateDistance(userPosition, LatLng(lat, lng)) <=
          defaultPinsNearbyRadiusKm;
    }).length;

    return nearbySavedCount < defaultPinsMinimumNearbySaved;
  }
```

- [ ] **Step 4: Run the helper tests to verify they pass**

Run: `flutter test test/providers/location_list_manager_default_picks_fallback_test.dart`

Expected: PASS.

### Task 2: Startup Default-List Orchestration

**Files:**
- Modify: `lib/pages/home/home_view_model.dart`
- Test: `test/providers/location_list_manager_default_picks_fallback_test.dart`

- [ ] **Step 1: Add one boundary test for missing coordinates**

Append this test to `test/providers/location_list_manager_default_picks_fallback_test.dart`:

```dart
  test('saved locations without coordinates do not count as nearby', () {
    final manager = LocationListManager(_MockGooglePlacesService());

    final shouldUsePicks = manager.shouldDefaultPinsToRecommendations(
      userPosition: const LatLng(51.5000, -0.1200),
      savedLocations: [
        ...List.generate(
          5,
          (index) => LocationModel(
            locationId: index,
            name: 'Missing coordinates $index',
            createdAt: DateTime(2026, 5, 1),
          ),
        ),
        ...List.generate(
          5,
          (index) => _location(
            100 + index,
            51.9000,
            -0.1200,
          ),
        ),
      ],
    );

    expect(shouldUsePicks, isTrue);
  });
```

- [ ] **Step 2: Run the boundary test to verify it passes with the helper**

Run: `flutter test test/providers/location_list_manager_default_picks_fallback_test.dart`

Expected: PASS. This protects the startup flow from treating incomplete saved rows as nearby coverage.

- [ ] **Step 3: Add startup fallback state to the view model**

In `lib/pages/home/home_view_model.dart`, add these fields near `_initialRecommendationsFetched`:

```dart
  bool _initialDefaultListResolved = false;
  bool _isResolvingInitialDefaultList = false;
  bool _userSelectedHomeMode = false;
```

- [ ] **Step 4: Wire the startup decision into initialization and provider updates**

In `init()`, after registering listeners and before `loadCollections()`, add:

```dart
    unawaited(_resolveInitialDefaultListIfReady());
```

In `_onExternalStateChanged()`, add this before `notifyListeners()`:

```dart
    unawaited(_resolveInitialDefaultListIfReady());
```

- [ ] **Step 5: Preserve manual mode changes**

At the top of `setHomeMode(HomeMode mode)`, before the early return, add:

```dart
    _userSelectedHomeMode = true;
```

- [ ] **Step 6: Implement the startup fallback method**

Add this private method near `_maybeFetchInitialRecommendations()`:

```dart
  Future<void> _resolveInitialDefaultListIfReady() async {
    if (_initialDefaultListResolved ||
        _isResolvingInitialDefaultList ||
        _userSelectedHomeMode ||
        _isBubbleModeActive ||
        _activeCollectionId != null ||
        locationListManager.currentListType != LocationListType.saved ||
        locationListManager.isLoadingSaved ||
        !locationListManager.hasLoadedSavedLocations) {
      return;
    }

    _isResolvingInitialDefaultList = true;
    try {
      final position = locationListManager.currentPosition;
      if (position == null) {
        return;
      }

      _initialDefaultListResolved = true;
      final shouldUsePicks =
          locationListManager.shouldDefaultPinsToRecommendations(
        userPosition: position,
      );
      if (!shouldUsePicks) {
        return;
      }

      await locationListManager.setCurrentListType(LocationListType.recommended);
      await _homeController.fetchAndPlotRecommendedPins(position);
    } finally {
      _isResolvingInitialDefaultList = false;
    }
  }
```

- [ ] **Step 7: Run focused tests and analysis**

Run: `flutter test test/providers/location_list_manager_default_picks_fallback_test.dart`

Expected: PASS.

Run: `dart analyze lib/providers/location_list_provider.dart lib/pages/home/home_view_model.dart test/providers/location_list_manager_default_picks_fallback_test.dart`

Expected: no errors.

### Task 3: Final Verification

**Files:**
- Verify: `lib/providers/location_list_provider.dart`
- Verify: `lib/pages/home/home_view_model.dart`
- Verify: `test/providers/location_list_manager_default_picks_fallback_test.dart`

- [ ] **Step 1: Run related provider tests**

Run: `flutter test test/providers/location_list_manager_default_picks_fallback_test.dart test/providers/location_list_manager_clear_bubble_locations_test.dart`

Expected: PASS.

- [ ] **Step 2: Run related home/search tests**

Run: `flutter test test/pages/home/search/header_search_logic_test.dart test/pages/home/search/header_search_waterfall_test.dart`

Expected: PASS.

- [ ] **Step 3: Inspect diff**

Run: `git diff -- lib/providers/location_list_provider.dart lib/pages/home/home_view_model.dart test/providers/location_list_manager_default_picks_fallback_test.dart docs/superpowers/plans/2026-05-01-default-picks-fallback.md`

Expected: Diff only contains the helper, startup orchestration, focused tests, and this plan.

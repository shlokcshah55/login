import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:login/utils/geo_types.dart';
import 'package:login/models/bubble.dart';
import 'package:login/models/home_rail_candidate.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/categories/home_category.dart';
import 'package:login/pages/home/categories/home_category_builder.dart';
import 'package:login/pages/home/widgets/mode_toggle.dart';
import 'package:login/pages/home/search/header_search_coordinator.dart';
import 'package:login/pages/home/search/header_search_types.dart';
import 'package:login/pages/home/search/live_header_search_repository.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/nav_bar/visibility_provider.dart';
import 'package:login/providers/shortlist_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/services/analytics_service.dart';
import 'package:login/services/area_name_service.dart';
import 'package:login/services/collections_library_events.dart';
import 'package:login/services/profile_completion_checklist_service.dart';
import 'package:login/services/startup_cache/startup_cache_coordinator.dart';
import 'package:login/services/startup_cache/startup_snapshot.dart';
import 'package:login/supabase/helpers/collections.dart';
import 'package:login/supabase/service.dart';
import 'package:login/supabase/supabase_client.dart';

/// Which tier of the home browse flow the carousel is showing.
/// [categories] → the small category tiles; [focused] → the full-size
/// location cards for the tapped category.
enum HomeBrowseStage { categories, focused }

class HomeViewModel extends ChangeNotifier {
  final LocationListManager locationListManager;
  final MapStateProvider mapStateProvider;
  final BottomNavVisibilityProvider bottomNavVisibilityProvider;
  final ShortlistProvider shortlistProvider;
  final SupabaseService supabaseService;
  final UserDataProvider userDataProvider;
  final StartupCacheCoordinator? _startupCache;
  final AreaNameService _areaNameService;
  late final HeaderSearchCoordinator _headerSearchCoordinator;
  final CollectionsHelper _collectionsHelper = CollectionsHelper();
  final AnalyticsService _analyticsService = AnalyticsService();
  final ProfileCompletionChecklistService _profileChecklistService =
      ProfileCompletionChecklistService();
  StreamSubscription<void>? _collectionsLibrarySub;

  final TextEditingController magicSearchController = TextEditingController();
  final TextEditingController headerSearchController = TextEditingController();
  final FocusNode headerSearchFocusNode = FocusNode();
  final PageController pageController = PageController(viewportFraction: 0.80);

  // ── Overlay state ─────────────────────────────────────────────
  bool _showSearchOverlay = false;
  bool _showGavelOverlay = false;
  bool _isMagicSearchActive = false;
  bool _showMagicSearchSuggestions = true;
  double _justDecideMinutes = 15.0;
  bool _showJustDecideSwipeMode = false;
  List<LocationModel> _justDecideLocations = [];
  List<CollectionItem> _collections = [];
  bool _isLoadingCollections = false;
  String? _activeCollectionId;
  bool _isEatListsOpen = false;

  // ── Category browse state ─────────────────────────────────────
  HomeBrowseStage _browseStage = HomeBrowseStage.categories;
  HomeCategory? _activeCategory;
  bool _overviewFramed = false;
  static const int _overviewFramePlaceCount = 8;
  List<HomeCategory>? _cachedCategories;
  List<double>? _lastVibeAffinity;

  // ── Server home rail (get_home_rail) ──────────────────────────
  /// Refetch once the point we'd rank for is this far from the last fetch.
  static const double _railRefetchDistanceM = 750;
  List<HomeRailCandidate>? _railCandidates;
  LatLng? _railCenter;
  LatLng? _railGpsAnchor;
  LatLng? _lastSeenSearchCenter;
  LatLng? _railQueuedCenter;
  String? _railAreaLabel;
  bool _railFetchInFlight = false;
  bool _railLiveFetched = false;
  Map<String, List<String>> _bubbleAvatars = const {};
  bool _bubbleAvatarsRequested = false;

  /// Rollout flag (B4): `HOME_RAIL_SERVER=true` in `.env` switches the rail to
  /// server-ranked cuisines + bubbles. Off means the client-only rail.
  static bool get serverRailEnabled {
    try {
      return dotenv.env['HOME_RAIL_SERVER']?.toLowerCase() == 'true';
    } catch (_) {
      return false; // dotenv not loaded (tests)
    }
  }

  // ── Mode toggle state ─────────────────────────────────────────
  HomeMode _homeMode = HomeMode.you;
  HomeMode _lastNonBubbleMode = HomeMode.you;

  // ── Internal state ────────────────────────────────────────────
  String? _lastSelectedMarkerId;
  Timer? _debounce;
  bool _initialized = false;
  bool _isBubbleModeActive = false;
  Bubble? _activeBubble;
  Future<void>? _initialRecommendationsPrefetch;
  bool _initialDefaultListResolved = false;
  bool _isResolvingInitialDefaultList = false;
  bool _userSelectedHomeMode = false;
  String? _selectedMarkerBeforeHeaderPreview;
  bool _disposed = false;
  bool _externalNotifyQueued = false;
  bool _prefetchQueued = false;

  // Tracks the saved/pick counts the overview was last built from, so the
  // category-stage map only rebuilds (and reshuffles) when the data changes.
  int _overviewSavedCount = -1;
  int _overviewRecCount = -1;

  ProfileCompletionChecklistState? _profileChecklistState;
  String? _profileChecklistUserId;
  int _profileChecklistSavedCount = -1;
  bool _profileChecklistFetching = false;
  bool _profileChecklistFetchQueued = false;

  HomeViewModel({
    required this.locationListManager,
    required this.mapStateProvider,
    required this.bottomNavVisibilityProvider,
    required this.shortlistProvider,
    required this.supabaseService,
    required this.userDataProvider,
    StartupCacheCoordinator? startupCache,
    AreaNameService? areaNameService,
  })  : _startupCache = startupCache,
        _areaNameService = areaNameService ?? AreaNameService.instance {
    _headerSearchCoordinator = HeaderSearchCoordinator(
      repository: LiveHeaderSearchRepository(
        locationListManager: locationListManager,
        userDataProvider: userDataProvider,
      ),
    );
    _headerSearchCoordinator.addListener(_onHeaderSearchChanged);
    headerSearchFocusNode.addListener(_onHeaderSearchFocusChanged);
  }

  // ── Getters ───────────────────────────────────────────────────

  bool get showSearchOverlay => _showSearchOverlay;
  bool get showGavelOverlay => _showGavelOverlay;
  bool get isMagicSearchActive => _isMagicSearchActive;
  bool get showMagicSearchSuggestions => _showMagicSearchSuggestions;
  double get justDecideMinutes => _justDecideMinutes;
  bool get showJustDecideSwipeMode => _showJustDecideSwipeMode;
  List<LocationModel> get justDecideLocations => _justDecideLocations;
  List<CollectionItem> get collections => List.unmodifiable(_collections);
  bool get isLoadingCollections => _isLoadingCollections;
  String? get activeCollectionId => _activeCollectionId;
  bool get isEatListsOpen => _isEatListsOpen;
  ProfileCompletionChecklistState? get profileChecklistState =>
      _profileChecklistState;
  bool get isProfileChecklistComplete =>
      _profileChecklistState?.isComplete == true;

  Future<void> refreshProfileChecklist({bool force = false}) {
    return _refreshProfileChecklistIfNeeded(force: force);
  }

  void setEatListsOpen(bool value) {
    if (_isEatListsOpen == value) return;
    _isEatListsOpen = value;
    notifyListeners();
  }

  bool get bottomNavVisible => bottomNavVisibilityProvider.isVisible;
  LocationListType get currentListType => locationListManager.currentListType;
  String? get selectedMarkerId => mapStateProvider.selectedMarkerId;
  List<LocationModel> get locations =>
      locationListManager.currentItems.keys.toList();
  bool get shouldShowProfileChecklistCard {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return false;
    if (!locationListManager.hasLoadedSavedLocations ||
        locationListManager.isLoadingSaved) {
      return false;
    }
    if (isProfileChecklistComplete) return false;
    final type = locationListManager.currentListType;
    if (type == LocationListType.recommended) return true;
    // Fresh accounts often start in Saved before we auto-switch to Picks.
    // Show the checklist card there too so it's visible immediately.
    if (type == LocationListType.saved &&
        locationListManager.savedLocations.isEmpty) {
      return true;
    }
    return false;
  }

  int get carouselLeadingCount => shouldShowProfileChecklistCard ? 1 : 0;
  bool get isBubbleModeActive => _isBubbleModeActive;
  Bubble? get activeBubble => _activeBubble;
  bool get isLoadingRecommendations =>
      locationListManager.isLoadingRecommendations ||
      locationListManager.isSearchingArea;
  bool get isMagicSearching => locationListManager.isMagicSearching;
  HeaderSearchState get headerSearchState => _headerSearchCoordinator.state;
  bool get isHeaderSearchActive => headerSearchState.isActive;
  bool get isHeaderSearchPreviewing => headerSearchState.isPreviewingMap;

  // ── Mode toggle ───────────────────────────────────────────────
  HomeMode get homeMode {
    // Derive the visible tab highlight from the actual list type so the
    // chip row stays in sync after magic search or other list switches.
    switch (locationListManager.currentListType) {
      case LocationListType.saved:
      case LocationListType.overview:
        return HomeMode.you;
      case LocationListType.recommended:
      case LocationListType.search:
        return HomeMode.explore;
      case LocationListType.bubble:
        return HomeMode.bubble;
      case LocationListType.bubbleSaved:
        return HomeMode.bubbleSaved;
    }
  }

  String? get activeBubbleName => _activeBubble?.name;

  void setHomeMode(HomeMode mode) {
    _userSelectedHomeMode = true;
    if (homeMode == mode &&
        _activeCollectionId == null &&
        !_isBubbleModeActive) {
      return;
    }
    if (mode != HomeMode.bubble && mode != HomeMode.bubbleSaved) {
      _lastNonBubbleMode = mode;
    }
    _homeMode = mode;
    _activeCollectionId = null;

    // Map the mode to LocationListType
    switch (mode) {
      case HomeMode.you:
        locationListManager.setCurrentListType(LocationListType.saved);
        break;
      case HomeMode.explore:
        locationListManager.setCurrentListType(LocationListType.recommended);
        // Warm recommendations in the background so Explore doesn't immediately
        // land on a loading state on first open.
        unawaited(_prefetchInitialRecommendationsIfReady());
        break;
      case HomeMode.bubble:
        locationListManager.setCurrentListType(LocationListType.bubble);
        break;
      case HomeMode.bubbleSaved:
        locationListManager.setCurrentListType(LocationListType.bubbleSaved);
        final bubbleId = _activeBubble?.id;
        if (bubbleId != null) {
          unawaited(
            locationListManager.fetchBubbleSavedLocations(bubbleId: bubbleId),
          );
        }
        break;
    }
    notifyListeners();
  }

  // ── Category browse ───────────────────────────────────────────
  HomeBrowseStage get homeBrowseStage => _browseStage;
  HomeCategory? get activeCategory => _activeCategory;

  /// Ordered category tiles for the landing carousel. Memoised and rebuilt
  /// when the underlying data (saved spots, area recommendations, collections)
  /// changes — [_onExternalStateChanged] clears the cache.
  List<HomeCategory> get homeCategories {
    final useServerRail = serverRailEnabled && _railCandidates != null;
    return _cachedCategories ??= HomeCategoryBuilder.build(
      savedLocations: locationListManager.savedLocations.keys.toList(),
      areaRecommendations:
          locationListManager.recommendedLocations.keys.toList(),
      vibeTagAffinity: userDataProvider.vibeTagAffinity,
      collections: _collections,
      loadCollectionLocations: (collectionId) =>
          _collectionsHelper.getLocationsForCollection(collectionId),
      railCandidates: useServerRail ? _railCandidates : null,
      loadLocationsByIds: useServerRail
          ? locationListManager.fetchLocationsByIdsInOrder
          : null,
      areaLabel: _railAreaLabel,
      bubbleAvatars: _bubbleAvatars,
    );
  }

  /// Area name for the point the rail was ranked for (e.g. 'Islington').
  String? get homeRailAreaLabel => _railAreaLabel;

  /// Drill into [category]: load its spots, drop them on the map + carousel,
  /// and switch to the focused stage.
  Future<void> openCategory(HomeCategory category) async {
    _analyticsService.track(
      eventName: 'home_category_tap',
      eventCategory: 'home',
      screenName: 'home',
      properties: {
        'kind': category.kind.name,
        'id': category.id,
        'rank': homeCategories.indexOf(category),
        'area': category.areaLabel ?? _railAreaLabel,
        'server_rail': serverRailEnabled && _railCandidates != null,
      },
    );
    _activeCategory = category;
    _browseStage = HomeBrowseStage.focused;
    // Focused stage shows richer emoji pins + the swipeable carousel.
    unawaited(mapStateProvider.setPinsDotsByDefault(false));
    notifyListeners();

    final locations = await category.resolve();
    if (_disposed) return;
    if (_activeCategory != category) return; // superseded by another tap

    await locationListManager.showLocationsOnMap(locations);
    if (locations.isNotEmpty) {
      mapStateProvider
          .setSelectedMarkerId(locations.first.locationId.toString());
      unawaited(mapStateProvider.focusOnLocations(
        locations,
        anchor: locationListManager.currentPosition,
      ));
    }
    bottomNavVisibilityProvider.showTemporarily();
    notifyListeners();
  }

  /// Whether See All should open on the user's saves rather than picks while
  /// on the category stage: follow the mode, but never open an empty list
  /// when the other one has places.
  bool get seeAllOpensSaved {
    final hasSaved = locationListManager.savedLocations.isNotEmpty;
    final hasPicks = locationListManager.recommendedLocations.isNotEmpty;
    return homeMode == HomeMode.you
        ? hasSaved || !hasPicks
        : !hasPicks && hasSaved;
  }

  /// True when See All has something to list. On the category stage the map
  /// shows a saves+picks overview that is empty until built, so [locations]
  /// alone would hide the chip.
  bool get canOpenSeeAll =>
      locations.isNotEmpty ||
      locationListManager.savedLocations.isNotEmpty ||
      locationListManager.recommendedLocations.isNotEmpty;

  /// Focus the home carousel and map on an arbitrary [locations] list (e.g.
  /// the See All filters), labelled [label] in the focused header.
  Future<void> openLocations(
    List<LocationModel> locations, {
    required String label,
  }) {
    return openCategory(
      HomeCategory(
        kind: HomeCategoryKind.source,
        id: 'see_all_filtered',
        label: label,
        count: locations.length,
        resolve: () async => locations,
      ),
    );
  }

  /// Return from the focused carousel to the category tiles.
  void closeCategory() {
    if (_browseStage == HomeBrowseStage.categories) return;
    _browseStage = HomeBrowseStage.categories;
    _activeCategory = null;
    mapStateProvider.setSelectedMarkerId(null);
    unawaited(_syncCategoryStageMap(force: true));
    notifyListeners();
  }

  /// Builds/refreshes the category-stage landing map: a curated random mix of
  /// saves + picks rendered as compact dots. No-ops when off the category stage
  /// or when the underlying data hasn't changed since the last build (which also
  /// guards against a rebuild → notify → rebuild loop).
  Future<void> _syncCategoryStageMap({bool force = false}) async {
    if (_disposed) return;
    if (_browseStage != HomeBrowseStage.categories) return;
    if (_isBubbleModeActive || _activeCollectionId != null) return;

    unawaited(mapStateProvider.setPinsDotsByDefault(true));

    final savedCount = locationListManager.savedLocations.length;
    final recCount = locationListManager.recommendedLocations.length;
    final alreadyShowingOverview =
        locationListManager.currentListType == LocationListType.overview;
    if (!force &&
        alreadyShowingOverview &&
        savedCount == _overviewSavedCount &&
        recCount == _overviewRecCount) {
      return;
    }
    _overviewSavedCount = savedCount;
    _overviewRecCount = recCount;
    await locationListManager.buildOverviewOnMap();
    if (!_overviewFramed) {
      _overviewFramed = await _frameNearestOverviewPlaces();
    }
  }

  /// Frames the camera on the overview places closest to the user, so the
  /// landing map opens on pins instead of an empty street-level view when
  /// the mix is spread across the city. Runs once per session so it never
  /// yanks the camera away from somewhere the user has panned to.
  Future<bool> _frameNearestOverviewPlaces() async {
    if (_disposed || _browseStage != HomeBrowseStage.categories) return false;
    final origin = locationListManager.currentPosition;
    final places = locationListManager.overviewLocations.keys
        .where((l) => l.lat != null && l.lng != null)
        .toList();
    if (origin == null || places.isEmpty) return false;

    final lngScale = math.cos(origin.latitude * math.pi / 180);
    double distanceSq(LocationModel l) {
      final dLat = l.lat! - origin.latitude;
      final dLng = (l.lng! - origin.longitude) * lngScale;
      return dLat * dLat + dLng * dLng;
    }

    places.sort((a, b) => distanceSq(a).compareTo(distanceSq(b)));
    await mapStateProvider.focusOnLocations(
      places.take(_overviewFramePlaceCount).toList(),
      // Clear the search header; pins also rise above their point.
      topPadding: 190,
    );
    return true;
  }

  /// The location whose pin is currently selected on the category stage, if any
  /// — drives the floating card shown above the category tiles.
  LocationModel? get selectedOverviewLocation {
    if (_browseStage != HomeBrowseStage.categories) return null;
    final markerId = mapStateProvider.selectedMarkerId;
    if (markerId == null) return null;
    final locationId = int.tryParse(markerId);
    if (locationId == null) return null;
    return locationListManager.overviewLocationById(locationId);
  }

  /// Clears the current pin selection (dismisses the category-stage floating
  /// card and returns the bloomed pin to a compact dot).
  void clearPinSelection() {
    mapStateProvider.setSelectedMarkerId(null);
  }

  Future<void> _prefetchInitialRecommendationsIfReady() {
    if (_initialRecommendationsPrefetch != null) {
      return _initialRecommendationsPrefetch!;
    }

    // Don't start a network call if we don't yet have the required inputs.
    if (SupabaseClientManager().currentUser == null) {
      return Future.value();
    }
    final position = locationListManager.currentPosition;
    if (position == null) return Future.value();

    _initialRecommendationsPrefetch = () async {
      // Avoid triggering provider notifications while widgets are building.
      if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
        await SchedulerBinding.instance.endOfFrame;
      }
      const double defaultRadiusKm = 5.0;
      await locationListManager.fetchRecommendedLocations(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: defaultRadiusKm,
      );

      final lastCenter = locationListManager.lastSearchedCenter;
      final lastRadius = locationListManager.lastSearchedRadius;
      if (lastCenter != null && lastRadius != null) {
        mapStateProvider.setLastSearchedArea(lastCenter, lastRadius);
      }
    }();

    return _initialRecommendationsPrefetch!;
  }

  Future<void> _resolveInitialDefaultListIfReady() async {
    // On the category landing stage the map shows the curated overview
    // (saves + picks), so don't auto-switch the active list to picks here. Keep
    // recommendations warming so the mix and any drill-in are ready.
    if (_browseStage == HomeBrowseStage.categories && !_userSelectedHomeMode) {
      _scheduleRecommendationsPrefetch();
      return;
    }
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

      // Always warm recommendations so Explore is ready if/when the user taps it.
      _scheduleRecommendationsPrefetch();

      final shouldUsePicks =
          locationListManager.shouldDefaultPinsToRecommendations(
        userPosition: position,
      );
      if (!shouldUsePicks) {
        _initialDefaultListResolved = true;
        return;
      }

      // Only switch to Picks after the recommendations endpoint returns, so we
      // don't immediately land the user on a loading state.
      _initialDefaultListResolved = true;
      await _prefetchInitialRecommendationsIfReady();
      if (_initialRecommendationsPrefetch == null) {
        // Recommendations couldn't be fetched (e.g. user not ready / no auth);
        // don't auto-switch away from Saved.
        return;
      }

      // Re-check: the user might have tapped another mode while we were
      // fetching recommendations.
      if (_userSelectedHomeMode ||
          _isBubbleModeActive ||
          _activeCollectionId != null ||
          locationListManager.currentListType != LocationListType.saved) {
        return;
      }

      _homeMode = HomeMode.explore;
      _lastNonBubbleMode = HomeMode.explore;
      await locationListManager
          .setCurrentListType(LocationListType.recommended);
    } finally {
      _isResolvingInitialDefaultList = false;
    }
  }

  // ── Shortlist delegates ───────────────────────────────────────
  int get shortlistCount => shortlistProvider.count;
  bool get shortlistIsNotEmpty => shortlistProvider.isNotEmpty;
  List<LocationModel> get shortlistItems => shortlistProvider.items;

  // ── Locate user ───────────────────────────────────────────────

  Future<void> locateUser() async {
    log("HomeViewModel: Locating user...");
    final position = await locationListManager.getCurrentLocation();
    if (position != null) {
      await mapStateProvider.focusOnUserLocation(position, zoom: 15.0);
    } else {
      log("HomeViewModel: Could not get user location");
    }
  }

  // ── Carousel swipe gestures ───────────────────────────────────

  /// Swipe up → add to shortlist (and save if not already saved).
  void onCarouselSwipeUp(LocationModel location) {
    log("HomeViewModel: Swipe up → shortlist: ${location.name}");
    shortlistProvider.add(location);
    // Also save it if it's not already a saved location
    locationListManager.saveLocation(location);
    notifyListeners();
  }

  /// Swipe down → save the location.
  void onCarouselSwipeDown(LocationModel location) {
    log("HomeViewModel: Swipe down → save: ${location.name}");
    locationListManager.saveLocation(location);
    notifyListeners();
  }

  // ── Init / lifecycle ──────────────────────────────────────────

  void init() {
    if (_initialized) return;
    _initialized = true;

    // Landing shows the curated overview (saves + picks as dots) rather than a
    // single list. It refreshes as saved/pick data arrives via
    // _onExternalStateChanged.
    unawaited(_syncCategoryStageMap(force: true));
    unawaited(_refreshProfileChecklistIfNeeded(force: true));
    mapStateProvider.setCarouselPageController(pageController);
    mapStateProvider.addListener(_onSelectedMarkerChanged);
    mapStateProvider.addListener(_onMapSearchAreaChanged);
    userDataProvider.addListener(_onUserDataChanged);
    _lastVibeAffinity = userDataProvider.vibeTagAffinity;
    _hydrateHomeRailFromCache();
    locationListManager.addListener(_onExternalStateChanged);
    bottomNavVisibilityProvider.addListener(_onExternalStateChanged);
    shortlistProvider.addListener(_onExternalStateChanged);

    _collectionsLibrarySub =
        CollectionsLibraryEvents.instance.changes.listen((_) {
      if (_disposed) return;
      // Avoid calling notifyListeners during an unrelated build/notify cycle.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        unawaited(loadCollections(force: true));
      });
    });

    _lastSelectedMarkerId = mapStateProvider.selectedMarkerId;
    unawaited(_prefetchInitialRecommendationsIfReady());
    unawaited(_resolveInitialDefaultListIfReady());
    unawaited(loadCollections());
    unawaited(_refreshHomeRailForGps());
  }

  void _onExternalStateChanged() {
    // Saved spots / area recommendations may have changed — rebuild the
    // category tiles on next access.
    _cachedCategories = null;
    // Always warm recommendations in the background so Explore is ready without
    // an immediate loading state when opened.
    _scheduleRecommendationsPrefetch();
    unawaited(_resolveInitialDefaultListIfReady());
    unawaited(_syncCategoryStageMap());
    unawaited(_refreshProfileChecklistIfNeeded());
    unawaited(_refreshHomeRailForGps());
    _notifyListenersSafely();
  }

  /// Taste changes re-rank the client-side vibe tiles.
  void _onUserDataChanged() {
    final affinity = userDataProvider.vibeTagAffinity;
    if (identical(affinity, _lastVibeAffinity)) return;
    _lastVibeAffinity = affinity;
    _cachedCategories = null;
    _notifyListenersSafely();
  }

  // ── Server home rail ──────────────────────────────────────────

  /// Paint the last rail from the startup snapshot until a live fetch lands.
  void _hydrateHomeRailFromCache() {
    if (!serverRailEnabled) return;
    final cached = _startupCache?.cachedHomeRail;
    if (cached == null || cached.candidates.isEmpty) return;
    _railCandidates = cached.candidates;
    _railCenter = LatLng(cached.latitude, cached.longitude);
    _railAreaLabel = cached.areaLabel;
    _cachedCategories = null;
  }

  /// First position fix, then whenever the device moves > 750 m.
  Future<void> _refreshHomeRailForGps() async {
    final gps = locationListManager.currentPosition;
    if (gps == null) return;
    final anchor = _railGpsAnchor;
    if (_railLiveFetched &&
        anchor != null &&
        _distanceMeters(gps, anchor) < _railRefetchDistanceM) {
      return;
    }
    _railGpsAnchor = gps;
    await _fetchHomeRailAt(gps);
  }

  /// "Search this area" — the rail follows the map, not just the GPS.
  void _onMapSearchAreaChanged() {
    final center = mapStateProvider.lastSearchedCenter;
    if (center == null) return;
    final seen = _lastSeenSearchCenter;
    if (seen != null &&
        seen.latitude == center.latitude &&
        seen.longitude == center.longitude) {
      return;
    }
    _lastSeenSearchCenter = center;
    final railCenter = _railCenter;
    if (_railLiveFetched &&
        railCenter != null &&
        _distanceMeters(center, railCenter) < _railRefetchDistanceM) {
      return;
    }
    unawaited(_fetchHomeRailAt(center));
  }

  Future<void> _fetchHomeRailAt(LatLng center) async {
    if (_disposed || !serverRailEnabled) return;
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return;
    if (_railFetchInFlight) {
      _railQueuedCenter = center; // latest wins
      return;
    }
    _railFetchInFlight = true;
    try {
      final results = await Future.wait<Object?>([
        supabaseService.homeRail.fetch(
          latitude: center.latitude,
          longitude: center.longitude,
        ),
        _areaNameService.lookup(center.latitude, center.longitude),
      ]);
      if (_disposed) return;
      final candidates = results[0] as List<HomeRailCandidate>;
      final areaLabel = results[1] as String?;

      _railLiveFetched = true;
      _railCenter = center;
      _railAreaLabel = areaLabel;
      // Nothing ranked here (or the call failed) → client-only rail.
      _railCandidates = candidates.isEmpty ? null : candidates;
      _cachedCategories = null;
      _notifyListenersSafely();

      if (candidates.any((c) => c.isBubble)) {
        unawaited(_loadBubbleAvatars(userId));
      }
      if (candidates.isNotEmpty) {
        _startupCache?.updateHomeRail(
          userId: userId,
          rail: HomeRailSnapshot(
            latitude: center.latitude,
            longitude: center.longitude,
            fetchedAt: DateTime.now().toUtc(),
            areaLabel: areaLabel,
            candidates: candidates,
          ),
        );
      }
    } catch (e) {
      log('HomeViewModel: home rail fetch failed: $e');
    } finally {
      _railFetchInFlight = false;
      final queued = _railQueuedCenter;
      _railQueuedCenter = null;
      if (queued != null && !_disposed) {
        unawaited(_fetchHomeRailAt(queued));
      }
    }
  }

  /// Member photos for bubble tiles — fetched once, only when a bubble tile
  /// exists (the summary query is per-bubble).
  Future<void> _loadBubbleAvatars(String userId) async {
    if (_bubbleAvatarsRequested) return;
    _bubbleAvatarsRequested = true;
    try {
      final summaries =
          await supabaseService.bubbles.getUserBubbleSummaries(userId);
      if (_disposed) return;
      _bubbleAvatars = {
        for (final summary in summaries)
          summary.id: summary.memberAvatars
              .where((url) => url.isNotEmpty)
              .toList(growable: false),
      };
      _cachedCategories = null;
      _notifyListenersSafely();
    } catch (e) {
      _bubbleAvatarsRequested = false;
      log('HomeViewModel: bubble avatars failed: $e');
    }
  }

  static double _distanceMeters(LatLng a, LatLng b) {
    const earthRadiusM = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(a.latitude * math.pi / 180) *
            math.cos(b.latitude * math.pi / 180) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadiusM * math.asin(math.sqrt(h));
  }

  Future<void> _refreshProfileChecklistIfNeeded({bool force = false}) async {
    if (_disposed) return;

    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return;

    // Saved count drives one of the checklist steps; avoid fetching until saved
    // locations have actually loaded so we don't briefly compute the wrong
    // completion state.
    if (!locationListManager.hasLoadedSavedLocations ||
        locationListManager.isLoadingSaved) {
      return;
    }

    final savedCount = locationListManager.savedLocations.length;
    final shouldFetch = force ||
        userId != _profileChecklistUserId ||
        savedCount != _profileChecklistSavedCount;
    if (!shouldFetch) return;

    _profileChecklistUserId = userId;
    _profileChecklistSavedCount = savedCount;

    if (_profileChecklistFetching) {
      _profileChecklistFetchQueued = true;
      return;
    }

    _profileChecklistFetching = true;
    try {
      final state = await _profileChecklistService.fetch(
        userId: userId,
        savedCount: savedCount,
      );
      if (_disposed) return;
      _profileChecklistState = state;
      _notifyListenersSafely();
    } catch (e) {
      log('HomeViewModel: Failed to fetch profile checklist: $e');
    } finally {
      _profileChecklistFetching = false;
      if (_profileChecklistFetchQueued) {
        _profileChecklistFetchQueued = false;
        unawaited(_refreshProfileChecklistIfNeeded(force: true));
      }
    }
  }

  void _scheduleRecommendationsPrefetch() {
    if (_disposed) return;
    if (_initialRecommendationsPrefetch != null) return;
    if (_prefetchQueued) return;
    _prefetchQueued = true;

    // Defer so we never trigger a LocationListManager notifyListeners while we're
    // inside another provider's notification/build cycle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchQueued = false;
      if (_disposed) return;
      unawaited(_prefetchInitialRecommendationsIfReady());
    });
  }

  void _notifyListenersSafely() {
    if (_disposed) return;

    // If we're in the middle of building/layout/paint, notifying immediately can
    // trip "markNeedsBuild called during build" depending on who triggered the
    // upstream provider notification. Defer to the next frame.
    final phase = SchedulerBinding.instance.schedulerPhase;
    final shouldDefer = phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (!shouldDefer) {
      notifyListeners();
      return;
    }

    if (_externalNotifyQueued) return;
    _externalNotifyQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _externalNotifyQueued = false;
      if (_disposed) return;
      notifyListeners();
    });
  }

  void _onSelectedMarkerChanged() {
    final newSelectedMarkerId = mapStateProvider.selectedMarkerId;
    if (newSelectedMarkerId != _lastSelectedMarkerId) {
      _lastSelectedMarkerId = newSelectedMarkerId;

      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 100), () {
        if (newSelectedMarkerId == null) return;
        final index = locations.indexWhere(
          (loc) => loc.locationId.toString() == newSelectedMarkerId,
        );

        final targetIndex = index == -1 ? -1 : index + carouselLeadingCount;
        if (targetIndex != -1 &&
            pageController.hasClients &&
            pageController.page?.round() != targetIndex) {
          log(
            "HomeViewModel: Scrolling carousel to index $targetIndex for marker $newSelectedMarkerId",
          );
          pageController.animateToPage(
            targetIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
    _notifyListenersSafely();
  }

  void _onHeaderSearchChanged() {
    _syncBottomNavVisibilityForSearch();
    _notifyListenersSafely();
  }

  void _onHeaderSearchFocusChanged() {
    _syncBottomNavVisibilityForSearch();
    _notifyListenersSafely();
  }

  void _syncBottomNavVisibilityForSearch() {
    final shouldLock =
        headerSearchState.isActive || headerSearchFocusNode.hasFocus;
    bottomNavVisibilityProvider.setLocked(shouldLock);
  }

  // ── Map interactions ──────────────────────────────────────────

  void onMapTap() {
    bottomNavVisibilityProvider.showTemporarily();
    // Tapping empty map on the category stage dismisses the floating card.
    if (_browseStage == HomeBrowseStage.categories &&
        mapStateProvider.selectedMarkerId != null) {
      clearPinSelection();
    }
  }

  void onCarouselScrollStart() {
    bottomNavVisibilityProvider.hide();
  }

  void onCarouselPageChanged(int index) {
    bottomNavVisibilityProvider.hide();
    if (carouselLeadingCount == 1 && index == 0) {
      // Checklist card — don't select a marker.
      return;
    }
    final locationIndex = index - carouselLeadingCount;
    if (locationIndex < 0 || locationIndex >= locations.length) return;
    final location = locations[locationIndex];
    mapStateProvider.setSelectedMarkerId(
      location.locationId.toString(),
      triggeredByCarousel: true,
    );
    _flyToSelected(location);
  }

  void onLocationSelected(LocationModel location) {
    mapStateProvider.setSelectedMarkerId(
      location.locationId.toString(),
    );
    _flyToSelected(location);
  }

  /// Zoom a selected place is brought to at least, so it leaves its cluster
  /// (clusters stop at zoom 12) and its pin is readable.
  static const double selectedFocusZoom = 14.5;

  /// Centres [location], zooming in only when the map is further out than
  /// [selectedFocusZoom].
  void _flyToSelected(LocationModel location) {
    final position = location.position;
    if (position == null) return;
    mapStateProvider.animateCamera(
      position,
      zoom: math.max(mapStateProvider.currentZoom, selectedFocusZoom),
    );
  }

  void setListType(LocationListType type) {
    locationListManager.setCurrentListType(type);
  }

  void trackNoRecommendationsInAreaShown() {
    final center = locationListManager.lastSearchedCenter ??
        locationListManager.cameraPosition?.target;
    final radiusKm = locationListManager.lastSearchedRadius;
    final camera = locationListManager.cameraPosition;

    _analyticsService.trackFeature(
      'no_recommendations_in_area_shown',
      featureName: 'recommendations',
      screenName: 'home',
      properties: <String, dynamic>{
        'list_type': locationListManager.currentListType.name,
        'vibe_tag_count': locationListManager.vibeTagIds.length,
        'cuisine_tag_count': locationListManager.cuisineTagIds.length,
        'availability_filter': locationListManager.availabilityFilter.name,
        if (center != null) 'center_lat': center.latitude,
        if (center != null) 'center_lng': center.longitude,
        if (radiusKm != null) 'radius_km': radiusKm,
        if (camera != null) 'camera_zoom': camera.zoom,
      },
    );
  }

  // ── Header search surface ─────────────────────────────────────

  Future<void> openHeaderSearch({bool showMagicSuggestions = true}) async {
    _analyticsService.trackFeature(
      'search_opened',
      featureName: 'header_search',
      screenName: 'home',
      registerTap: true,
      interactionKey: 'search_opened',
    );
    if (showMagicSuggestions) {
      _showMagicSearchSuggestions = true;
    } else {
      // Guarantee a genuinely normal search — clear any magic-mode residue
      // left over from an earlier magic search elsewhere in the app.
      _clearMagicSearchState();
    }
    notifyListeners();
    await _headerSearchCoordinator.open();
    _syncBottomNavVisibilityForSearch();
    notifyListeners();
  }

  void closeHeaderSearch({bool clearQuery = true}) {
    headerSearchFocusNode.unfocus();
    if (clearQuery) {
      headerSearchController.clear();
    }
    _headerSearchCoordinator.close();
    _showMagicSearchSuggestions = true;
    _syncBottomNavVisibilityForSearch();
    notifyListeners();
  }

  void updateHeaderSearchQuery(String query) {
    if (_isMagicSearchActive) {
      _isMagicSearchActive = false;
      notifyListeners();
    }
    _headerSearchCoordinator.updateQuery(query);
  }

  void applyHeaderSearchSuggestionQuery(String query) {
    final trimmed = query.trim();
    headerSearchController.value = headerSearchController.value.copyWith(
      text: trimmed,
      selection: TextSelection.collapsed(offset: trimmed.length),
      composing: TextRange.empty,
    );
    _headerSearchCoordinator.updateQuery(trimmed, debounce: Duration.zero);
  }

  Future<void> rememberHeaderSearchQuery(String query) async {
    await _headerSearchCoordinator.rememberQuery(query);
  }

  Future<void> submitHeaderSearch() async {
    // The round search button submits through this exact method too, so
    // whichever kind of search a query runs, both stay in lockstep.
    if (_showMagicSearchSuggestions) {
      final query = headerSearchController.text.trim();
      if (query.isEmpty) return;
      // Magic search on the home entry point never uses the in-overlay
      // place list (that list is the normal-search surface, which only
      // belongs on the second tab). Instead, close the overlay so the
      // home screen is visible again, and let the results land in the
      // home carousel via `locationListManager` — mirrors what tapping a
      // magic suggestion pill already does.
      dismissMagicSearchSuggestions();
      closeHeaderSearch(clearQuery: false);
      await submitMagicSearch(query);
      return;
    }
    await _headerSearchCoordinator.submitQuery();
  }

  Future<void> selectHeaderSearchLocation(
    LocationModel location, {
    String? query,
  }) async {
    final valueToRemember = (query ?? headerSearchState.query).trim();
    if (valueToRemember.isNotEmpty) {
      await _headerSearchCoordinator.rememberQuery(valueToRemember);
    }

    await locationListManager.focusSingleLocation(location);
    mapStateProvider.setSelectedMarkerId(location.locationId.toString());
    if (location.position != null) {
      await mapStateProvider.animateCamera(location.position!, zoom: 15.2);
    }
    closeHeaderSearch();
  }

  Future<void> startHeaderSearchPreview(LocationModel location) async {
    _selectedMarkerBeforeHeaderPreview ??= mapStateProvider.selectedMarkerId;
    _headerSearchCoordinator.beginPreview(location);
    mapStateProvider.setSelectedMarkerId(location.locationId.toString());
    mapStateProvider.pulseLocation(location.locationId);
    if (location.position != null) {
      await mapStateProvider.animateCamera(location.position!, zoom: 15.8);
    }
  }

  Future<void> endHeaderSearchPreview() async {
    final selectedMarkerId = _selectedMarkerBeforeHeaderPreview;
    _selectedMarkerBeforeHeaderPreview = null;
    _headerSearchCoordinator.endPreview();
    if (selectedMarkerId == null) {
      return;
    }

    mapStateProvider.setSelectedMarkerId(selectedMarkerId);
    LocationModel? location;
    for (final item in locations) {
      if (item.locationId.toString() == selectedMarkerId) {
        location = item;
        break;
      }
    }
    if (location?.position != null) {
      await mapStateProvider.animateCamera(location!.position!);
    }
  }

  // ── Search overlay ────────────────────────────────────────────

  void toggleSearchOverlay(bool visible) {
    if (_showSearchOverlay == visible) return;
    _showSearchOverlay = visible;
    notifyListeners();
  }

  void toggleMagicSearchSuggestions() {
    _analyticsService.registerUserInteraction(
      interactionKey: 'toggle_magic_search_suggestions',
    );
    _showMagicSearchSuggestions = !_showMagicSearchSuggestions;
    notifyListeners();
  }

  void dismissMagicSearchSuggestions() {
    if (!_showMagicSearchSuggestions) return;
    _showMagicSearchSuggestions = false;
    notifyListeners();
  }

  /// Leaves magic search mode (suggestions panel or magic results) and
  /// drops the user into the normal, type-to-search place view without
  /// closing the header search surface itself.
  void exitMagicSearchMode() {
    _analyticsService.registerUserInteraction(
      interactionKey: 'exit_magic_search_mode',
    );
    headerSearchController.clear();
    _headerSearchCoordinator.updateQuery('', debounce: Duration.zero);
    _clearMagicSearchState();
    notifyListeners();
  }

  /// Resets every bit of magic-search state — the suggestions panel flag,
  /// the "results are live" flag, and (if it's the reason the underlying
  /// list is on `search`) the home list type — so nothing lingers from a
  /// prior magic search once we want a genuinely normal search view.
  void _clearMagicSearchState() {
    _isMagicSearchActive = false;
    _showMagicSearchSuggestions = false;

    // Magic search results live on `locationListManager`, not the header
    // search sheet — restore whatever list the home screen was showing
    // before the magic search took over (Saved/Explore/Bubble, etc).
    final restoredType = switch (_homeMode) {
      HomeMode.you => LocationListType.saved,
      HomeMode.explore => LocationListType.recommended,
      HomeMode.bubble => LocationListType.bubble,
      HomeMode.bubbleSaved => LocationListType.bubbleSaved,
    };
    if (locationListManager.currentListType == LocationListType.search) {
      unawaited(locationListManager.setCurrentListType(restoredType));
    }
  }

  Future<void> submitMagicSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    log("HomeViewModel: Triggering magic search for: $trimmed");
    _analyticsService.trackFeature(
      'magic_search_submitted',
      featureName: 'magic_search',
      screenName: 'home',
      properties: <String, dynamic>{
        'query_length': trimmed.length,
      },
      registerTap: true,
      interactionKey: 'magic_search_submit',
    );

    final viewData = await mapStateProvider.getVisibleCenterAndRadius();
    final radiusKm =
        (viewData != null ? viewData['radius'] as double : null) ?? 2.0;

    await locationListManager.magicSearch(
      trimmed,
      radiusKm: radiusKm,
    );

    if (viewData != null) {
      mapStateProvider.setLastSearchedArea(
        viewData['center'] as LatLng,
        radiusKm,
      );
    }

    // Only flip into "results mode" once the search has actually finished —
    // this is what turns the header search button into a cross, so it
    // shouldn't happen the instant the query is submitted.
    _isMagicSearchActive = true;
    dismissMagicSearchSuggestions();

    if (locationListManager.error != null) {
      log("HomeViewModel: Magic search error: ${locationListManager.error}");
      _analyticsService.recordError(
        key: 'magic_search_error',
        properties: <String, dynamic>{
          'query_length': trimmed.length,
          'message': locationListManager.error!,
        },
      );
    }
  }

  Future<void> loadCollections({bool force = false}) async {
    final user = SupabaseClientManager().currentUser;
    if (user == null) return;
    if (_isLoadingCollections) return;
    if (!force && _collections.isNotEmpty) return;

    _isLoadingCollections = true;
    notifyListeners();

    try {
      final collections =
          await _collectionsHelper.getUserCollectionLibrary(user.id);
      collections.sort((a, b) {
        if (a.canEdit != b.canEdit) return a.canEdit ? -1 : 1;
        final aOwner = (a.ownerName ?? '').toLowerCase();
        final bOwner = (b.ownerName ?? '').toLowerCase();
        final ownerCmp = aOwner.compareTo(bOwner);
        if (ownerCmp != 0) return ownerCmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      _collections = collections;
    } catch (_) {
      _collections = [];
    } finally {
      _isLoadingCollections = false;
      _cachedCategories = null; // eat-list tiles depend on collections
      notifyListeners();
    }
  }

  Future<bool> showCollectionOnMap(CollectionItem collection) async {
    final collectionId = collection.collectionId;
    _activeCollectionId = collectionId;

    final shown = await locationListManager.showCollectionLocations(
      collectionId,
      () => _collectionsHelper.getLocationsForCollection(collectionId),
    );

    if (shown.isEmpty) {
      _activeCollectionId = null;
      notifyListeners();
      return false;
    }

    mapStateProvider.setSelectedMarkerId(shown.first.locationId.toString());
    await mapStateProvider.focusOnLocations(shown);
    bottomNavVisibilityProvider.showTemporarily();
    notifyListeners();
    return true;
  }

  Future<List<LocationModel>> showCollectionOnMapById(
    String collectionId, {
    bool focusCamera = false,
  }) async {
    _activeCollectionId = collectionId;

    final shown = await locationListManager.showCollectionLocations(
      collectionId,
      () => _collectionsHelper.getLocationsForCollection(collectionId),
    );

    if (shown.isEmpty) {
      _activeCollectionId = null;
      notifyListeners();
      return const [];
    }

    // Don't auto-select a marker here — callers that intend to open an overlay
    // list-view shouldn't flash the bottom carousel "mini view" first.
    mapStateProvider.setSelectedMarkerId(null);
    if (focusCamera) {
      await mapStateProvider.focusOnLocations(shown);
    }
    bottomNavVisibilityProvider.showTemporarily();
    notifyListeners();
    return shown;
  }

  // ── Just Decide (Gavel) overlay ───────────────────────────────

  void toggleJustDecideOverlay(bool visible) {
    if (_showGavelOverlay == visible) return;
    _showGavelOverlay = visible;
    notifyListeners();
  }

  void setJustDecideMinutes(double minutes) {
    _justDecideMinutes = minutes;
    notifyListeners();
  }

  Future<void> submitJustDecide(double walkingMinutes) async {
    final radiusKm = (walkingMinutes * 5.0) / 60.0;

    log("HomeViewModel: Triggering just decide for: $walkingMinutes minutes (~$radiusKm km)");

    toggleJustDecideOverlay(false);

    final currentLocation = locationListManager.currentPosition ??
        await locationListManager.getCurrentLocation();

    if (currentLocation == null) {
      log("HomeViewModel: Cannot perform just decide without location");
      return;
    }

    await locationListManager.fetchJustDecideRecommendations(
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
      radiusKm: radiusKm,
      maxResults: 5,
    );

    _justDecideLocations = locationListManager.justDecideLocations;
    _showJustDecideSwipeMode = true;
    notifyListeners();

    if (locationListManager.error != null) {
      log("HomeViewModel: Just decide error: ${locationListManager.error}");
    }
  }

  void onJustDecideSwipe(LocationModel location, bool saved) {
    log("HomeViewModel: Just decide swipe - location: ${location.name}, saved: $saved");
    if (saved) {
      locationListManager.saveLocation(location);
    }
  }

  void onJustDecideComplete() {
    log("HomeViewModel: Just decide completed");
    _justDecideLocations = [];
    _showJustDecideSwipeMode = false;
    notifyListeners();
  }

  // ── Quick Picks (new flow) ────────────────────────────────────

  /// Fetches quick-pick recommendations for the given walking budget and
  /// returns them directly to the caller. Used by the Quick Picks screens
  /// which own their own navigation state instead of going through the
  /// view-model overlay flags.
  ///
  /// Returns an empty list if we don't have a location fix yet or the API
  /// call fails — the caller can surface an error.
  Future<List<LocationModel>> requestQuickPicks(double walkingMinutes) async {
    final radiusKm = (walkingMinutes * 5.0) / 60.0;
    log("HomeViewModel: Requesting quick picks for $walkingMinutes min (~${radiusKm.toStringAsFixed(2)} km)");

    if (_isBubbleModeActive) {
      final currentLocation = locationListManager.currentPosition ??
          await locationListManager.getCurrentLocation();
      final bubbleLocations =
          List<LocationModel>.from(locationListManager.bubbleLocations.keys);

      if (bubbleLocations.isEmpty) {
        log("HomeViewModel: No bubble recommendations available for quick picks");
        return const [];
      }

      if (currentLocation == null) {
        log("HomeViewModel: No location available, using current bubble ranking without distance filtering");
        return bubbleLocations.take(10).toList();
      }

      final filteredBubbleLocations = bubbleLocations.where((location) {
        final position = location.position;
        if (position == null) return false;
        return _distanceKm(currentLocation, position) <= radiusKm;
      }).toList();

      log("HomeViewModel: Bubble quick picks filtered ${filteredBubbleLocations.length} locations within ${radiusKm.toStringAsFixed(2)} km");
      return filteredBubbleLocations.take(10).toList();
    }

    final currentLocation = locationListManager.currentPosition ??
        await locationListManager.getCurrentLocation();

    if (currentLocation == null) {
      log("HomeViewModel: Cannot fetch quick picks without location");
      return const [];
    }

    await locationListManager.fetchJustDecideRecommendations(
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
      radiusKm: radiusKm,
      maxResults: 10,
    );

    if (locationListManager.error != null) {
      log("HomeViewModel: Quick picks error: ${locationListManager.error}");
    }

    return List<LocationModel>.from(locationListManager.justDecideLocations);
  }

  double _distanceKm(LatLng from, LatLng to) {
    const earthRadiusKm = 6371.0;
    final lat1Rad = from.latitude * math.pi / 180.0;
    final lat2Rad = to.latitude * math.pi / 180.0;
    final deltaLatRad = (to.latitude - from.latitude) * math.pi / 180.0;
    final deltaLngRad = (to.longitude - from.longitude) * math.pi / 180.0;

    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLngRad / 2) *
            math.sin(deltaLngRad / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Saves a location that was liked in the quick-picks deck.
  void saveQuickPick(LocationModel location) {
    log("HomeViewModel: Quick pick liked → ${location.name} (save + shortlist)");
    shortlistProvider.add(location);
    locationListManager.saveLocation(location);
  }

  // ── Sweet Treat overlay ───────────────────────────────────────
  static const String _defaultSweetTreatQuery =
      'Places with desserts or sweets that are currently open';

  Future<void> submitDefaultSweetTreatSearch() async {
    await submitSweetTreatSearch(_defaultSweetTreatQuery);
  }

  Future<void> submitSweetTreatSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    log("HomeViewModel: Triggering sweet treat search for: $trimmed");

    final viewData = await mapStateProvider.getVisibleCenterAndRadius();
    final radiusKm =
        (viewData != null ? viewData['radius'] as double : null) ?? 2.0;

    await locationListManager.magicSearch(
      trimmed,
      radiusKm: radiusKm,
    );

    if (viewData != null) {
      mapStateProvider.setLastSearchedArea(
        viewData['center'] as LatLng,
        radiusKm,
      );
    }

    if (locationListManager.error != null) {
      log("HomeViewModel: Sweet treat search error: ${locationListManager.error}");
    }
  }

  // ── Search this area ──────────────────────────────────────────

  Future<void> searchThisArea() async {
    final viewData = await mapStateProvider.searchThisArea();

    if (viewData == null) {
      print('searchThisArea: viewData is null, cannot search');
      return;
    }

    final center = viewData['center'] as LatLng;
    final radiusKm = viewData['radius'] as double;

    if (_isMagicSearchActive &&
        locationListManager.currentListType == LocationListType.search) {
      final query = headerSearchController.text.trim();
      if (query.isNotEmpty) {
        await locationListManager.magicSearch(
          query,
          radiusKm: radiusKm,
        );
        mapStateProvider.setLastSearchedArea(center, radiusKm);
        return;
      }
    }

    if (_isBubbleModeActive &&
        _homeMode == HomeMode.bubble &&
        _activeBubble != null) {
      final didSearch = await locationListManager.searchBubbleArea(
        memberIds: _activeBubble!.memberIds,
        bubbleId: _activeBubble!.id,
        center: center,
        radiusKm: radiusKm,
      );
      if (didSearch) {
        mapStateProvider.setLastSearchedArea(center, radiusKm);
      }
      return;
    }

    final didSearch = await locationListManager.searchThisArea(
      center: center,
      radiusKm: radiusKm,
      maxResults: locationListManager.filterMaxResults,
    );

    if (didSearch) {
      mapStateProvider.setLastSearchedArea(center, radiusKm);
    }
  }

  // ── Bubble mode ───────────────────────────────────────────────

  Future<void> activateBubbleMode(Bubble chatGroup) async {
    _isBubbleModeActive = true;
    _activeBubble = chatGroup;
    if (_homeMode != HomeMode.bubble && _homeMode != HomeMode.bubbleSaved) {
      _lastNonBubbleMode = _homeMode;
    }
    _homeMode = HomeMode.bubble;
    _activeCollectionId = null;
    print('activated bubble mode for bubble: ${chatGroup.name}');

    // Clear any previously loaded bubble locations and switch the carousel to
    // the bubble list immediately so we don't show stale items while loading.
    locationListManager.clearBubbleLocations(notify: false);
    await locationListManager.setCurrentListType(LocationListType.bubble);

    // Warm the "sent to this bubble" list so the SAVED tab opens instantly.
    unawaited(
      locationListManager.fetchBubbleSavedLocations(bubbleId: chatGroup.id),
    );

    final currentLocation = locationListManager.currentPosition ??
        await locationListManager.getCurrentLocation();

    if (currentLocation == null || chatGroup.memberIds.isEmpty) {
      log("Cannot activate bubble mode: location unavailable or no members");
      notifyListeners();
      return;
    }

    await locationListManager.fetchBubbleRecommendations(
      memberIds: chatGroup.memberIds,
      bubbleId: chatGroup.id,
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
    );

    final lastCenter = locationListManager.lastSearchedCenter;
    final lastRadius = locationListManager.lastSearchedRadius;
    if (lastCenter != null && lastRadius != null) {
      mapStateProvider.setLastSearchedArea(lastCenter, lastRadius);
    }

    await locationListManager.setCurrentListType(LocationListType.bubble);

    notifyListeners();
  }

  Future<void> deactivateBubbleMode() async {
    _isBubbleModeActive = false;
    _activeBubble = null;
    final fallbackMode =
        _homeMode == HomeMode.bubble || _homeMode == HomeMode.bubbleSaved
            ? _lastNonBubbleMode
            : _homeMode;
    _homeMode = fallbackMode;

    final currentLocation = locationListManager.currentPosition ??
        await locationListManager.getCurrentLocation();

    if (fallbackMode == HomeMode.explore && currentLocation != null) {
      const double defaultRadius = 5.0;
      await locationListManager.fetchRecommendedLocations(
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        radiusKm: defaultRadius,
      );
      final lastCenter = locationListManager.lastSearchedCenter;
      final lastRadius = locationListManager.lastSearchedRadius;
      if (lastCenter != null && lastRadius != null) {
        mapStateProvider.setLastSearchedArea(lastCenter, lastRadius);
      }
    }

    switch (fallbackMode) {
      case HomeMode.you:
        await locationListManager.setCurrentListType(LocationListType.saved);
        break;
      case HomeMode.explore:
        await locationListManager.setCurrentListType(
          LocationListType.recommended,
        );
        break;
      case HomeMode.bubble:
      case HomeMode.bubbleSaved:
        _homeMode = HomeMode.you;
        _lastNonBubbleMode = HomeMode.you;
        await locationListManager.setCurrentListType(LocationListType.saved);
        break;
    }

    notifyListeners();
  }

  // ── Dispose ───────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    _headerSearchCoordinator.removeListener(_onHeaderSearchChanged);
    mapStateProvider.removeListener(_onSelectedMarkerChanged);
    mapStateProvider.removeListener(_onMapSearchAreaChanged);
    userDataProvider.removeListener(_onUserDataChanged);
    locationListManager.removeListener(_onExternalStateChanged);
    bottomNavVisibilityProvider.removeListener(_onExternalStateChanged);
    shortlistProvider.removeListener(_onExternalStateChanged);
    _collectionsLibrarySub?.cancel();
    bottomNavVisibilityProvider.setLocked(false);
    pageController.dispose();
    magicSearchController.dispose();
    headerSearchController.dispose();
    headerSearchFocusNode.removeListener(_onHeaderSearchFocusChanged);
    headerSearchFocusNode.dispose();
    _headerSearchCoordinator.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}

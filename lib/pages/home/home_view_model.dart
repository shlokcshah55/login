import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:login/utils/geo_types.dart';
import 'package:login/models/bubble.dart';
import 'package:login/models/locations.dart';
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
import 'package:login/supabase/helpers/collections.dart';
import 'package:login/supabase/service.dart';
import 'package:login/supabase/supabase_client.dart';

class HomeViewModel extends ChangeNotifier {
  final LocationListManager locationListManager;
  final MapStateProvider mapStateProvider;
  final BottomNavVisibilityProvider bottomNavVisibilityProvider;
  final ShortlistProvider shortlistProvider;
  final SupabaseService supabaseService;
  final UserDataProvider userDataProvider;
  late final HeaderSearchCoordinator _headerSearchCoordinator;
  final CollectionsHelper _collectionsHelper = CollectionsHelper();
  final AnalyticsService _analyticsService = AnalyticsService();

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

  HomeViewModel({
    required this.locationListManager,
    required this.mapStateProvider,
    required this.bottomNavVisibilityProvider,
    required this.shortlistProvider,
    required this.supabaseService,
    required this.userDataProvider,
  }) {
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
  bool get isBubbleModeActive => _isBubbleModeActive;
  Bubble? get activeBubble => _activeBubble;
  bool get isLoadingRecommendations =>
      locationListManager.isLoadingRecommendations ||
      locationListManager.isSearchingArea;
  bool get isMagicSearching => locationListManager.isMagicSearching;
  HeaderSearchState get headerSearchState => _headerSearchCoordinator.state;
  bool get isHeaderSearchActive => headerSearchState.isActive;
  bool get isHeaderSearchPreviewing => headerSearchState.isPreviewingMap;
  bool get isMagicSearchFieldFocused =>
      _isMagicSearchActive && headerSearchFocusNode.hasFocus;

  // ── Mode toggle ───────────────────────────────────────────────
  HomeMode get homeMode {
    // Derive the visible tab highlight from the actual list type so the
    // chip row stays in sync after magic search or other list switches.
    switch (locationListManager.currentListType) {
      case LocationListType.saved:
        return HomeMode.you;
      case LocationListType.recommended:
      case LocationListType.search:
        return HomeMode.explore;
      case LocationListType.bubble:
        return HomeMode.bubble;
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
    if (mode != HomeMode.bubble) {
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
    }
    notifyListeners();
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

    unawaited(
      locationListManager.setCurrentListType(LocationListType.saved),
    );
    mapStateProvider.setCarouselPageController(pageController);
    mapStateProvider.addListener(_onSelectedMarkerChanged);
    locationListManager.addListener(_onExternalStateChanged);
    bottomNavVisibilityProvider.addListener(_onExternalStateChanged);
    shortlistProvider.addListener(_onExternalStateChanged);

    _lastSelectedMarkerId = mapStateProvider.selectedMarkerId;
    unawaited(_prefetchInitialRecommendationsIfReady());
    unawaited(_resolveInitialDefaultListIfReady());
    unawaited(loadCollections());
  }

  void _onExternalStateChanged() {
    // Always warm recommendations in the background so Explore is ready without
    // an immediate loading state when opened.
    _scheduleRecommendationsPrefetch();
    unawaited(_resolveInitialDefaultListIfReady());
    _notifyListenersSafely();
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
          (loc) => loc.locationId == newSelectedMarkerId,
        );

        if (index != -1 &&
            pageController.hasClients &&
            pageController.page?.round() != index) {
          log(
            "HomeViewModel: Scrolling carousel to index $index for marker $newSelectedMarkerId",
          );
          pageController.animateToPage(
            index,
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
  }

  void onCarouselScrollStart() {
    bottomNavVisibilityProvider.hide();
  }

  void onCarouselPageChanged(int index) {
    bottomNavVisibilityProvider.hide();
    final location = locations[index];
    mapStateProvider.setSelectedMarkerId(
      location.locationId.toString(),
      triggeredByCarousel: true,
    );
    mapStateProvider.animateCamera(
      location.position!,
    );
  }

  void onLocationSelected(LocationModel location) {
    mapStateProvider.setSelectedMarkerId(
      location.locationId.toString(),
    );
    mapStateProvider.animateCamera(
      location.position!,
    );
  }

  void setListType(LocationListType type) {
    locationListManager.setCurrentListType(type);
  }

  // ── Header search surface ─────────────────────────────────────

  Future<void> openHeaderSearch() async {
    _analyticsService.trackFeature(
      'search_opened',
      featureName: 'header_search',
      screenName: 'home',
      registerTap: true,
      interactionKey: 'search_opened',
    );
    await _headerSearchCoordinator.open();
    _syncBottomNavVisibilityForSearch();
  }

  void closeHeaderSearch({bool clearQuery = true}) {
    headerSearchFocusNode.unfocus();
    if (clearQuery) {
      headerSearchController.clear();
    }
    _headerSearchCoordinator.close();
    _syncBottomNavVisibilityForSearch();
  }

  void updateHeaderSearchQuery(String query) {
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

  void toggleMagicSearch() {
    _analyticsService.registerUserInteraction(
      interactionKey: 'toggle_magic_search',
    );
    _isMagicSearchActive = !_isMagicSearchActive;
    if (_isMagicSearchActive) {
      _showMagicSearchSuggestions = true;
    } else {
      _showMagicSearchSuggestions = false;
      setHomeMode(HomeMode.you);
    }
    _syncBottomNavVisibilityForSearch();
    notifyListeners();
  }

  void dismissMagicSearchSuggestions() {
    if (!_showMagicSearchSuggestions) return;
    _showMagicSearchSuggestions = false;
    notifyListeners();
  }

  Future<void> submitMagicSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // Once the user submits a query we move into “results mode” — the
    // suggestion panel should collapse so the header stays compact.
    dismissMagicSearchSuggestions();

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
    );

    if (didSearch) {
      mapStateProvider.setLastSearchedArea(center, radiusKm);
    }
  }

  // ── Bubble mode ───────────────────────────────────────────────

  Future<void> activateBubbleMode(Bubble chatGroup) async {
    _isBubbleModeActive = true;
    _activeBubble = chatGroup;
    if (_homeMode != HomeMode.bubble) {
      _lastNonBubbleMode = _homeMode;
    }
    _homeMode = HomeMode.bubble;
    _activeCollectionId = null;
    print('activated bubble mode for bubble: ${chatGroup.name}');

    // Clear any previously loaded bubble locations and switch the carousel to
    // the bubble list immediately so we don't show stale items while loading.
    locationListManager.clearBubbleLocations(notify: false);
    await locationListManager.setCurrentListType(LocationListType.bubble);

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
        _homeMode == HomeMode.bubble ? _lastNonBubbleMode : _homeMode;
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
    locationListManager.removeListener(_onExternalStateChanged);
    bottomNavVisibilityProvider.removeListener(_onExternalStateChanged);
    shortlistProvider.removeListener(_onExternalStateChanged);
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

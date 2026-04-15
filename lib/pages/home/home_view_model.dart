import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:login/utils/geo_types.dart';
import 'package:login/controllers/home_controller.dart';
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
  late final HomeController _homeController;
  late final HeaderSearchCoordinator _headerSearchCoordinator;
  final CollectionsHelper _collectionsHelper = CollectionsHelper();

  final TextEditingController magicSearchController = TextEditingController();
  final TextEditingController headerSearchController = TextEditingController();
  final FocusNode headerSearchFocusNode = FocusNode();
  final PageController pageController = PageController(viewportFraction: 0.80);

  // ── Overlay state ─────────────────────────────────────────────
  bool _showSearchOverlay = false;
  bool _showGavelOverlay = false;
  bool _isMagicSearchActive = false;
  bool _showMagicSearchActivated = false;
  double _justDecideMinutes = 15.0;
  bool _showJustDecideSwipeMode = false;
  List<LocationModel> _justDecideLocations = [];
  List<CollectionItem> _collections = [];
  bool _isLoadingCollections = false;
  String? _activeCollectionId;

  // ── Mode toggle state ─────────────────────────────────────────
  HomeMode _homeMode = HomeMode.you;
  HomeMode _lastNonBubbleMode = HomeMode.you;

  // ── Internal state ────────────────────────────────────────────
  String? _lastSelectedMarkerId;
  Timer? _debounce;
  bool _initialized = false;
  bool _isBubbleModeActive = false;
  Bubble? _activeBubble;
  bool _initialRecommendationsFetched = false;
  String? _selectedMarkerBeforeHeaderPreview;

  HomeViewModel({
    required this.locationListManager,
    required this.mapStateProvider,
    required this.bottomNavVisibilityProvider,
    required this.shortlistProvider,
    required this.supabaseService,
    required this.userDataProvider,
  }) {
    _homeController = HomeController(
      locationListManager: locationListManager,
      mapStateProvider: mapStateProvider,
    );
    _headerSearchCoordinator = HeaderSearchCoordinator(
      repository: LiveHeaderSearchRepository(
        locationListManager: locationListManager,
        userDataProvider: userDataProvider,
        supabaseService: supabaseService,
      ),
    );
    _headerSearchCoordinator.addListener(_onHeaderSearchChanged);
    headerSearchFocusNode.addListener(_onHeaderSearchFocusChanged);
  }

  // ── Getters ───────────────────────────────────────────────────

  bool get showSearchOverlay => _showSearchOverlay;
  bool get showGavelOverlay => _showGavelOverlay;
  bool get isMagicSearchActive => _isMagicSearchActive;
  bool get showMagicSearchActivated => _showMagicSearchActivated;
  double get justDecideMinutes => _justDecideMinutes;
  bool get showJustDecideSwipeMode => _showJustDecideSwipeMode;
  List<LocationModel> get justDecideLocations => _justDecideLocations;
  List<CollectionItem> get collections => List.unmodifiable(_collections);
  bool get isLoadingCollections => _isLoadingCollections;
  String? get activeCollectionId => _activeCollectionId;
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
        // Lazy-load recommendations the first time Explore is opened.
        _maybeFetchInitialRecommendations();
        break;
      case HomeMode.bubble:
        locationListManager.setCurrentListType(LocationListType.bubble);
        break;
    }
    notifyListeners();
  }

  /// Fetches recommendations once, the first time the user enters Explore mode
  /// and a location is available. If Explore is opened before a location is
  /// known, [_onExternalStateChanged] will pick it up when the stream arrives.
  void _maybeFetchInitialRecommendations() {
    if (_initialRecommendationsFetched) return;
    if (_homeMode != HomeMode.explore) return;
    if (locationListManager.currentPosition == null) return;

    _initialRecommendationsFetched = true;
    log("HomeViewModel: Explore active, fetching initial recommendations");
    _homeController.fetchAndPlotRecommendedPins(
      locationListManager.currentPosition,
    );
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
    unawaited(loadCollections());
  }

  void _onExternalStateChanged() {
    // If the user is already in Explore mode, fetch recommendations as soon
    // as a location becomes available. In You mode we stay lazy — the
    // carousel sticks to saved locations until Explore is tapped.
    _maybeFetchInitialRecommendations();
    notifyListeners();
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
    notifyListeners();
  }

  void _onHeaderSearchChanged() {
    _syncBottomNavVisibilityForSearch();
    notifyListeners();
  }

  void _onHeaderSearchFocusChanged() {
    _syncBottomNavVisibilityForSearch();
    notifyListeners();
  }

  void _syncBottomNavVisibilityForSearch() {
    final shouldLock = headerSearchState.isActive ||
        _isMagicSearchActive ||
        headerSearchFocusNode.hasFocus;
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
    await _headerSearchCoordinator.open();
    _syncBottomNavVisibilityForSearch();
  }

  void closeHeaderSearch() {
    headerSearchFocusNode.unfocus();
    headerSearchController.clear();
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
    _isMagicSearchActive = !_isMagicSearchActive;
    if (_isMagicSearchActive) {
      _showMagicSearchActivated = true;
    } else {
      _showMagicSearchActivated = false;
      // Switch back to You mode when exiting magic search.
      setHomeMode(HomeMode.you);
    }
    _syncBottomNavVisibilityForSearch();
    notifyListeners();
  }

  void dismissMagicSearchActivated() {
    if (!_showMagicSearchActivated) return;
    _showMagicSearchActivated = false;
    notifyListeners();
  }

  Future<void> submitMagicSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    log("HomeViewModel: Triggering magic search for: $trimmed");

    await locationListManager.magicSearch(trimmed);

    if (locationListManager.error != null) {
      log("HomeViewModel: Magic search error: ${locationListManager.error}");
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
      final collections = await _collectionsHelper.getUserCollections(user.id);
      collections.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
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
    log("HomeViewModel: Quick pick saved → ${location.name}");
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

    await locationListManager.magicSearch(trimmed);

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

    if (_isBubbleModeActive &&
        _homeMode == HomeMode.bubble &&
        _activeBubble != null) {
      await locationListManager.fetchBubbleRecommendations(
        memberIds: _activeBubble!.memberIds,
        bubbleId: _activeBubble!.id,
        latitude: center.latitude,
        longitude: center.longitude,
        radiusKm: radiusKm,
      );
      mapStateProvider.setLastSearchedArea(center, radiusKm);
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

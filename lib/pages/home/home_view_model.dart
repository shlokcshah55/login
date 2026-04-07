import 'dart:async';
import 'dart:developer';

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
import 'package:login/supabase/service.dart';

class HomeViewModel extends ChangeNotifier {
  final LocationListManager locationListManager;
  final MapStateProvider mapStateProvider;
  final BottomNavVisibilityProvider bottomNavVisibilityProvider;
  final ShortlistProvider shortlistProvider;
  final SupabaseService supabaseService;
  final UserDataProvider userDataProvider;
  late final HomeController _homeController;
  late final HeaderSearchCoordinator _headerSearchCoordinator;

  final TextEditingController magicSearchController = TextEditingController();
  final TextEditingController headerSearchController = TextEditingController();
  final FocusNode headerSearchFocusNode = FocusNode();
  final PageController pageController = PageController(viewportFraction: 0.80);

  // ── Overlay state ─────────────────────────────────────────────
  bool _showSearchOverlay = false;
  bool _showGavelOverlay = false;
  bool _showSweetTreatOverlay = false;
  double _justDecideMinutes = 15.0;
  bool _showJustDecideSwipeMode = false;
  List<LocationModel> _justDecideLocations = [];

  // ── Mode toggle state ─────────────────────────────────────────
  HomeMode _homeMode = HomeMode.you;

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
  }

  // ── Getters ───────────────────────────────────────────────────

  bool get showSearchOverlay => _showSearchOverlay;
  bool get showGavelOverlay => _showGavelOverlay;
  bool get showSweetTreatOverlay => _showSweetTreatOverlay;
  double get justDecideMinutes => _justDecideMinutes;
  bool get showJustDecideSwipeMode => _showJustDecideSwipeMode;
  List<LocationModel> get justDecideLocations => _justDecideLocations;
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
  HeaderSearchState get headerSearchState => _headerSearchCoordinator.state;
  bool get isHeaderSearchActive => headerSearchState.isActive;
  bool get isHeaderSearchPreviewing => headerSearchState.isPreviewingMap;

  // ── Mode toggle ───────────────────────────────────────────────
  HomeMode get homeMode => _homeMode;

  void setHomeMode(HomeMode mode) {
    if (_homeMode == mode) return;
    _homeMode = mode;

    // Map the mode to LocationListType
    switch (mode) {
      case HomeMode.you:
        locationListManager.setCurrentListType(LocationListType.saved);
        break;
      case HomeMode.explore:
        locationListManager.setCurrentListType(LocationListType.recommended);
        break;
    }
    notifyListeners();
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

    mapStateProvider.setCarouselPageController(pageController);
    mapStateProvider.addListener(_onSelectedMarkerChanged);
    locationListManager.addListener(_onExternalStateChanged);
    bottomNavVisibilityProvider.addListener(_onExternalStateChanged);
    shortlistProvider.addListener(_onExternalStateChanged);

    _lastSelectedMarkerId = mapStateProvider.selectedMarkerId;
  }

  void _onExternalStateChanged() {
    // Fetch initial recommendations once we have a location from the stream
    if (!_initialRecommendationsFetched &&
        locationListManager.currentPosition != null) {
      _initialRecommendationsFetched = true;
      log("HomeViewModel: Location stream provided position, fetching initial recommendations");
      _homeController.fetchAndPlotRecommendedPins(
        locationListManager.currentPosition
      );
    }
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
    notifyListeners();
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
  }

  void closeHeaderSearch() {
    headerSearchFocusNode.unfocus();
    headerSearchController.clear();
    _headerSearchCoordinator.close();
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

  Future<void> submitMagicSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    log("HomeViewModel: Triggering magic search for: $trimmed");

    magicSearchController.clear();
    toggleSearchOverlay(false);

    await locationListManager.magicSearch(trimmed);

    if (locationListManager.error != null) {
      log("HomeViewModel: Magic search error: ${locationListManager.error}");
    }
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

  // ── Sweet Treat overlay ───────────────────────────────────────

  void toggleSweetTreatOverlay(bool visible) {
    if (_showSweetTreatOverlay == visible) return;
    _showSweetTreatOverlay = visible;
    notifyListeners();
  }

  Future<void> submitSweetTreatSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    log("HomeViewModel: Triggering sweet treat search for: $trimmed");

    toggleSweetTreatOverlay(false);

    await locationListManager.magicSearch(trimmed);

    if (locationListManager.error != null) {
      log("HomeViewModel: Sweet treat search error: ${locationListManager.error}");
    }
  }

  // ── Surprise Me (random vibe search) ──────────────────────────

  Future<void> submitSurpriseMe() async {
    const vibePrompts = [
      'Something fun and different near me',
      'A hidden gem I haven\'t tried',
      'Best vibes near me right now',
      'Somewhere cozy and interesting',
      'A wavy spot with great food',
    ];
    final prompt = (vibePrompts..shuffle()).first;
    log("HomeViewModel: Surprise me with: $prompt");
    await locationListManager.magicSearch(prompt);
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

    await locationListManager.searchThisArea(
      center: center,
      radiusKm: radiusKm,
      vibeTagIds: locationListManager.vibeTagIds.isNotEmpty
          ? locationListManager.vibeTagIds
          : null,
      cuisineTagIds: locationListManager.cuisineTagIds.isNotEmpty
          ? locationListManager.cuisineTagIds
          : null,
    );

    mapStateProvider.setLastSearchedArea(center, radiusKm);
  }

  // ── Bubble mode ───────────────────────────────────────────────

  Future<void> activateBubbleMode(Bubble chatGroup) async {
    _isBubbleModeActive = true;
    _activeBubble = chatGroup;
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
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
    );

    final lastCenter = locationListManager.lastSearchedCenter;
    final lastRadius = locationListManager.lastSearchedRadius;
    if (lastCenter != null && lastRadius != null) {
      mapStateProvider.setLastSearchedArea(lastCenter, lastRadius);
    }

    await locationListManager.setCurrentListType(LocationListType.recommended);

    notifyListeners();
  }

  Future<void> deactivateBubbleMode() async {
    _isBubbleModeActive = false;
    _activeBubble = null;

    final currentLocation = locationListManager.currentPosition ??
        await locationListManager.getCurrentLocation();

    if (currentLocation != null) {
      const double defaultRadius = 5.0;
      await locationListManager.fetchRecommendedLocations(
        latitude: currentLocation.latitude,
        longitude: currentLocation.longitude,
        radiusKm: defaultRadius,
        vibeTagIds: locationListManager.vibeTagIds.isNotEmpty
            ? locationListManager.vibeTagIds
            : null,
        cuisineTagIds: locationListManager.cuisineTagIds.isNotEmpty
            ? locationListManager.cuisineTagIds
            : null,
      );
      final lastCenter = locationListManager.lastSearchedCenter;
      final lastRadius = locationListManager.lastSearchedRadius;
      if (lastCenter != null && lastRadius != null) {
        mapStateProvider.setLastSearchedArea(lastCenter, lastRadius);
      }
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
    pageController.dispose();
    magicSearchController.dispose();
    headerSearchController.dispose();
    headerSearchFocusNode.dispose();
    _headerSearchCoordinator.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}

import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:login/utils/geo_types.dart';
import 'package:login/controllers/home_controller.dart';
import 'package:login/models/bubble.dart';
import 'package:login/models/locations.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/nav_bar/visibility_provider.dart';

class HomeViewModel extends ChangeNotifier {
  static const double _selectedPlaceMinZoom = 16.2;

  final LocationListManager locationListManager;
  final MapStateProvider mapStateProvider;
  final BottomNavVisibilityProvider bottomNavVisibilityProvider;
  late final HomeController _homeController;

  final TextEditingController searchController = TextEditingController();
  final PageController pageController = PageController(viewportFraction: 0.80);

  bool _showSearchOverlay = false;
  bool _showGavelOverlay = false;
  bool _showSweetTreatOverlay = false;
  double _justDecideMinutes = 15.0;
  bool _showJustDecideSwipeMode = false;
  List<LocationModel> _justDecideLocations = [];
  String? _lastSelectedMarkerId;
  Timer? _debounce;
  bool _initialized = false;
  bool _isBubbleModeActive = false;
  Bubble? _activeBubble;
  bool _initialRecommendationsFetched = false;

  HomeViewModel({
    required this.locationListManager,
    required this.mapStateProvider,
    required this.bottomNavVisibilityProvider,
  }) {
    _homeController = HomeController(
      locationListManager: locationListManager,
      mapStateProvider: mapStateProvider,
    );
  }

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

  void init() {
    if (_initialized) return;
    _initialized = true;

    mapStateProvider.setCarouselPageController(pageController);
    mapStateProvider.addListener(_onSelectedMarkerChanged);
    locationListManager.addListener(_onExternalStateChanged);
    bottomNavVisibilityProvider.addListener(_onExternalStateChanged);

    // Don't fetch recommendations immediately - wait for location stream to provide first position
    // This will be triggered in _onExternalStateChanged when currentPosition becomes available

    _lastSelectedMarkerId = mapStateProvider.selectedMarkerId;
  }

  void _onExternalStateChanged() {
    // Fetch initial recommendations once we have a location from the stream
    if (!_initialRecommendationsFetched &&
        locationListManager.currentPosition != null) {
      _initialRecommendationsFetched = true;
      log("HomeViewModel: Location stream provided position, fetching initial recommendations");
      _homeController
          .fetchAndPlotRecommendedPins(locationListManager.currentPosition);
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

  void onMapTap() {
    bottomNavVisibilityProvider.showTemporarily();
  }

  void onCarouselScrollStart() {
    bottomNavVisibilityProvider.hide();
  }

  void onCarouselPageChanged(int index) {
    bottomNavVisibilityProvider.hide();
    final location = locations[index];
    final targetZoom = mapStateProvider.currentZoom < _selectedPlaceMinZoom
        ? _selectedPlaceMinZoom
        : mapStateProvider.currentZoom;
    mapStateProvider.setSelectedMarkerId(
      location.locationId.toString(),
      triggeredByCarousel: true,
    );
    mapStateProvider.animateCamera(
      location.position!,
      zoom: targetZoom,
    );
  }

  void onLocationSelected(LocationModel location) {
    final targetZoom = mapStateProvider.currentZoom < _selectedPlaceMinZoom
        ? _selectedPlaceMinZoom
        : mapStateProvider.currentZoom;
    mapStateProvider.setSelectedMarkerId(
      location.locationId.toString(),
    );
    mapStateProvider.animateCamera(
      location.position!,
      zoom: targetZoom,
    );
  }

  void setListType(LocationListType type) {
    locationListManager.setCurrentListType(type);
  }

  void toggleSearchOverlay(bool visible) {
    print(
        '🎭 toggleSearchOverlay called with visible=$visible, current=$_showSearchOverlay');
    if (_showSearchOverlay == visible) return;
    _showSearchOverlay = visible;
    notifyListeners();
  }

  Future<void> submitMagicSearch(String query) async {
    print('✨ submitMagicSearch CALLED with query: "$query"');
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      print('❌ Query is empty after trim, aborting');
      return;
    }
    print('✅ Query trimmed: "$trimmed"');

    log("HomeViewModel: Triggering magic search for: $trimmed");

    searchController.clear();
    toggleSearchOverlay(false);

    // Perform the search
    await locationListManager.magicSearch(trimmed);

    // Check for errors after search completes
    if (locationListManager.error != null) {
      log("HomeViewModel: Magic search error: ${locationListManager.error}");
    }
  }

  void toggleJustDecideOverlay(bool visible) {
    print(
        '🎲 toggleJustDecideOverlay called with visible=$visible, current=$_showGavelOverlay');
    if (_showGavelOverlay == visible) return;
    _showGavelOverlay = visible;
    notifyListeners();
  }

  void setJustDecideMinutes(double minutes) {
    _justDecideMinutes = minutes;
    notifyListeners();
  }

  Future<void> submitJustDecide(double walkingMinutes) async {
    print('🎲 submitJustDecide CALLED with minutes: $walkingMinutes');

    // Convert minutes to km: distance_km = (minutes * 5.0) / 60.0
    final radiusKm = (walkingMinutes * 5.0) / 60.0;

    log("HomeViewModel: Triggering just decide for: $walkingMinutes minutes (~$radiusKm km)");

    // Close overlay
    toggleJustDecideOverlay(false);

    // Get current location
    final currentLocation = locationListManager.currentPosition ??
        await locationListManager.getCurrentLocation();

    if (currentLocation == null) {
      log("HomeViewModel: Cannot perform just decide without location");
      return;
    }

    // Call fetchJustDecideRecommendations
    await locationListManager.fetchJustDecideRecommendations(
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
      radiusKm: radiusKm,
      maxResults: 5,
    );

    // Set the locations and show swipe mode
    _justDecideLocations = locationListManager.justDecideLocations;
    _showJustDecideSwipeMode = true;
    notifyListeners();

    // Check for errors after fetch completes
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

  void toggleSweetTreatOverlay(bool visible) {
    print(
        '🧁 toggleSweetTreatOverlay called with visible=$visible, current=$_showSweetTreatOverlay');
    if (_showSweetTreatOverlay == visible) return;
    _showSweetTreatOverlay = visible;
    notifyListeners();
  }

  Future<void> submitSweetTreatSearch(String query) async {
    print('🧁 submitSweetTreatSearch CALLED with query: "$query"');
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      print('❌ Query is empty after trim, aborting');
      return;
    }
    print('✅ Query trimmed: "$trimmed"');

    log("HomeViewModel: Triggering sweet treat search for: $trimmed");

    toggleSweetTreatOverlay(false);

    // Perform the search (using magic search for now)
    await locationListManager.magicSearch(trimmed);

    // Check for errors after search completes
    if (locationListManager.error != null) {
      log("HomeViewModel: Sweet treat search error: ${locationListManager.error}");
    }
  }

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

    // Update the last searched area in MapStateProvider
    mapStateProvider.setLastSearchedArea(center, radiusKm);
  }

  Future<void> activateBubbleMode(Bubble chatGroup) async {
    _isBubbleModeActive = true;
    _activeBubble = chatGroup;
    print('activated bubble mode for bubble: ${chatGroup.name}');

    // Get current location
    final currentLocation = locationListManager.currentPosition ??
        await locationListManager.getCurrentLocation();

    if (currentLocation == null || chatGroup.memberIds.isEmpty) {
      log("Cannot activate bubble mode: location unavailable or no members");
      notifyListeners();
      return;
    }

    // Fetch bubble recommendations
    await locationListManager.fetchBubbleRecommendations(
      memberIds: chatGroup.memberIds,
      latitude: currentLocation.latitude,
      longitude: currentLocation.longitude,
    );

    // Update last searched area in MapStateProvider using values from locationListManager
    final lastCenter = locationListManager.lastSearchedCenter;
    final lastRadius = locationListManager.lastSearchedRadius;
    if (lastCenter != null && lastRadius != null) {
      mapStateProvider.setLastSearchedArea(lastCenter, lastRadius);
    }

    // Switch to recommended view
    await locationListManager.setCurrentListType(LocationListType.recommended);

    notifyListeners();
  }

  Future<void> deactivateBubbleMode() async {
    _isBubbleModeActive = false;
    _activeBubble = null;

    // Restore individual recommendations
    final currentLocation = locationListManager.currentPosition ??
        await locationListManager.getCurrentLocation();

    if (currentLocation != null) {
      const double defaultRadius =
          5.0; // Match default from fetchRecommendedLocations
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
      // Update last searched area in MapStateProvider using values from locationListManager
      final lastCenter = locationListManager.lastSearchedCenter;
      final lastRadius = locationListManager.lastSearchedRadius;
      if (lastCenter != null && lastRadius != null) {
        mapStateProvider.setLastSearchedArea(lastCenter, lastRadius);
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    mapStateProvider.removeListener(_onSelectedMarkerChanged);
    locationListManager.removeListener(_onExternalStateChanged);
    bottomNavVisibilityProvider.removeListener(_onExternalStateChanged);
    pageController.dispose();
    searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}

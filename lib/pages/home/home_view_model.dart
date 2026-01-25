import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/controllers/home_controller.dart';
import 'package:login/models/locations.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/nav_bar/visibility_provider.dart';

class HomeViewModel extends ChangeNotifier {
  final LocationListManager locationListManager;
  final MapStateProvider mapStateProvider;
  final BottomNavVisibilityProvider bottomNavVisibilityProvider;
  late final HomeController _homeController;

  final TextEditingController searchController = TextEditingController();
  final PageController pageController = PageController(viewportFraction: 0.80);

  bool _showSearchOverlay = false;
  MarkerId? _lastSelectedMarkerId;
  Timer? _debounce;
  bool _initialized = false;

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
  bool get bottomNavVisible => bottomNavVisibilityProvider.isVisible;
  LocationListType get currentListType => locationListManager.currentListType;
  MarkerId? get selectedMarkerId => mapStateProvider.selectedMarkerId;
  List<LocationModel> get locations =>
      locationListManager.currentItems.keys.toList();

  void init() {
    if (_initialized) return;
    _initialized = true;

    mapStateProvider.setCarouselPageController(pageController);
    mapStateProvider.addListener(_onSelectedMarkerChanged);
    locationListManager.addListener(_onExternalStateChanged);
    bottomNavVisibilityProvider.addListener(_onExternalStateChanged);

    _homeController.fetchAndPlotRecommendedPins(null);

    _lastSelectedMarkerId = mapStateProvider.selectedMarkerId;
  }

  void _onExternalStateChanged() {
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
          (loc) => loc.locationId == newSelectedMarkerId.value,
        );

        if (index != -1 &&
            pageController.hasClients &&
            pageController.page?.round() != index) {
          log(
            "HomeViewModel: Scrolling carousel to index $index for marker ${newSelectedMarkerId.value}",
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
    mapStateProvider.setSelectedMarkerId(
      MarkerId(location.locationId.toString()),
      triggeredByCarousel: true,
    );
    mapStateProvider.animateCamera(
      CameraUpdate.newLatLng(location.position!),
    );
  }

  void onLocationSelected(LocationModel location) {
    mapStateProvider.setSelectedMarkerId(
      MarkerId(location.locationId.toString()),
    );
    mapStateProvider.animateCamera(
      CameraUpdate.newLatLng(location.position!),
    );
  }

  void setListType(LocationListType type) {
    locationListManager.setCurrentListType(type);
  }

  void toggleSearchOverlay(bool visible) {
    print('🎭 toggleSearchOverlay called with visible=$visible, current=$_showSearchOverlay');
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

  Future<void> searchThisArea() async {
    final center = mapStateProvider.searchThisArea();
    final controller = await mapStateProvider.controllerFuture;
    final bounds = await controller.getVisibleRegion();
    await locationListManager.searchThisArea(
      center: center,
      bounds: bounds,
    );
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

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:login/models/locations.dart';
import 'package:login/pages/home/home_view_model.dart';
import 'package:login/pages/home/widgets/home_map_sync_gate.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/supabase/helpers/tags.dart';
import 'package:login/utils/geo_types.dart';
import 'package:login/utils/marker_clustering.dart';
import 'package:login/widgets/home/filter_category_list_popover.dart';
import 'package:login/widgets/home/tag_selection_popover.dart';
import 'package:provider/provider.dart';

class PinitMap extends StatefulWidget {
  static const double DEFAULT_LAT = 51.4988;
  static const double DEFAULT_LNG = -0.1749;

  final VoidCallback? onMapTap;
  final VoidCallback? onSearchThisArea;

  const PinitMap({super.key, this.onMapTap, this.onSearchThisArea});

  @override
  _PinitMapState createState() => _PinitMapState();
}

class _PinitMapState extends State<PinitMap> {
  bool _locationTrackingStarted = false;
  LocationListManager? _locationListManager;
  MapStateProvider? _mapStateProvider;

  // Legacy fields for PointAnnotation-based rendering (when useGeoJsonLayers is false)
  // ignore: unused_field
  bool _mapReady = false;
  // ignore: unused_field
  Map<String, MapMarkerData> _clusteredMarkers = {};
  int _lastSyncedItemCount = 0;
  String _lastSyncedItemIds = '';
  bool _syncInProgress = false;

  // GeoJSON: key of the last list handed to MapStateProvider.requestPins, so
  // unrelated notifications don't re-push an identical list.
  String _lastRequestedPinsKey = '';

  // Filter state
  Set<String> _selectedVibeTagIds = {};
  Set<String> _selectedCuisineTagIds = {};
  Set<String> _selectedDietaryTagIds = {};
  List<Map<String, dynamic>>? _vibeTags;
  List<Map<String, dynamic>>? _cuisineTags;
  List<Map<String, dynamic>>? _dietaryTags;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startLocationTracking();
    });
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tagsHelper = TagsHelper();
    final results = await Future.wait([
      tagsHelper.getVibeTags(),
      tagsHelper.getCuisineTags(),
    ]);
    if (!mounted) return;
    setState(() {
      _vibeTags = results[0];
      _cuisineTags = results[1];
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_locationListManager == null) {
      _locationListManager = context.read<LocationListManager>();
      _mapStateProvider = context.read<MapStateProvider>();
      // Pins follow the list directly rather than piggybacking on rebuilds.
      _locationListManager!.addListener(_requestPinsIfChanged);
      _requestPinsIfChanged();
    }
  }

  Future<void> _startLocationTracking() async {
    if (_locationTrackingStarted) return;
    _locationTrackingStarted = true;
    await _locationListManager?.startLocationUpdates();
  }

  void _showFilterCategoryList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterCategoryListPopover(
        hasVibeFilters: _selectedVibeTagIds.isNotEmpty,
        hasCuisineFilters: _selectedCuisineTagIds.isNotEmpty,
        onVibeSelected: () {
          if (_vibeTags != null) {
            _showFilterPopover(
              title: 'Select Vibe',
              icon: Icons.emoji_emotions_outlined,
              tags: _vibeTags!,
              selectedTagIds: _selectedVibeTagIds,
              onApply: (selected) async {
                print(
                    '🎨 [PinitMap] Vibe filter applied - selected: $selected');
                _selectedVibeTagIds = selected;
                await _applyCurrentFilters();
                print('🎨 [PinitMap] Filter application complete');
              },
            );
          }
        },
        onCuisineSelected: () {
          if (_cuisineTags != null) {
            _showFilterPopover(
              title: 'Select Cuisine',
              icon: Icons.restaurant_menu_outlined,
              tags: _cuisineTags!,
              selectedTagIds: _selectedCuisineTagIds,
              onApply: (selected) async {
                print(
                    '🍽️ [PinitMap] Cuisine filter applied - selected: $selected');
                _selectedCuisineTagIds = selected;
                await _applyCurrentFilters();
                print('🍽️ [PinitMap] Filter application complete');
              },
            );
          }
        },
      ),
    );
  }

  void _showFilterPopover({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> tags,
    required Set<String> selectedTagIds,
    required Future<void> Function(Set<String>) onApply,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagSelectionPopover(
        title: title,
        titleIcon: icon,
        tags: tags,
        initialSelectedTagIds: selectedTagIds,
        onApply: (selected) async {
          setState(() {
            // State update happens synchronously
          });
          // Then apply filters asynchronously
          await onApply(selected);
        },
      ),
    );
  }

  /// Resolves selected tag IDs to text names and calls applyFilters on the location manager.
  Future<void> _applyCurrentFilters() async {
    final vibeNames = _resolveTagNames(_selectedVibeTagIds, _vibeTags);
    final cuisineNames = _resolveTagNames(_selectedCuisineTagIds, _cuisineTags);

    print('🔍 [PinitMap] Resolved vibe names: $vibeNames');
    print('🔍 [PinitMap] Resolved cuisine names: $cuisineNames');

    await _locationListManager?.applyFilters(
      vibeTagIds: _selectedVibeTagIds.toList(),
      cuisineTagIds: _selectedCuisineTagIds.toList(),
      vibeTagNames: vibeNames,
      cuisineTagNames: cuisineNames,
    );

    if (mounted) {
      final mapState = context.read<MapStateProvider>();
      final lastCenter = _locationListManager?.lastSearchedCenter;
      final lastRadius = _locationListManager?.lastSearchedRadius;
      if (lastCenter != null && lastRadius != null) {
        mapState.setLastSearchedArea(lastCenter, lastRadius);
      }
    }
  }

  /// Looks up tag text names from the loaded tag list for a set of selected tag IDs.
  List<String> _resolveTagNames(
      Set<String> selectedIds, List<Map<String, dynamic>>? tags) {
    if (tags == null || selectedIds.isEmpty) return [];
    final names = <String>[];
    for (final tag in tags) {
      final id = (tag['tag_id'] ?? tag['id'])?.toString();
      if (id != null && selectedIds.contains(id)) {
        final text = (tag['text'] ?? tag['name'])?.toString();
        if (text != null) names.add(text);
      }
    }
    return names;
  }

  String _buildGeoJsonSyncKey(
    List<LocationModel> locations,
    Set<int> beenToLocationIds,
  ) {
    final itemIds = locations.map((location) => location.locationId).toList()
      ..sort();
    final visitedIds = itemIds
        .where((locationId) => beenToLocationIds.contains(locationId))
        .toList();

    return 'items:${itemIds.join(",")}|visited:${visitedIds.join(",")}';
  }

  /// Hands the current list to [MapStateProvider.requestPins] when it has
  /// changed. The provider serialises updates (latest wins) and holds them
  /// until the map style is ready, so this never has to retry.
  void _requestPinsIfChanged() {
    final locationListManager = _locationListManager;
    final mapStateProvider = _mapStateProvider;
    if (locationListManager == null || mapStateProvider == null) return;

    if (!shouldSyncGeoJsonPins(
      useGeoJsonLayers: mapStateProvider.useGeoJsonLayers,
      currentListType: locationListManager.currentListType,
      hasLoadedSavedLocations: locationListManager.hasLoadedSavedLocations,
    )) {
      return;
    }

    final locations = locationListManager.currentItems.keys.toList();
    final beenToLocationIds = locationListManager.beenToLocationIds;
    final key = _buildGeoJsonSyncKey(locations, beenToLocationIds);
    if (key == _lastRequestedPinsKey) return;
    _lastRequestedPinsKey = key;

    mapStateProvider.requestPins(
      locations,
      beenToLocationIds: beenToLocationIds,
    );
  }

  /// Legacy: Apply manual clustering (old approach).
  /// Only used when useGeoJsonLayers is false.
  void _applyClusteringAsync(
    Map<dynamic, MapMarkerData> currentItems,
    double dpr,
    LocationListManager locationListManager,
    MapStateProvider mapStateReader,
    MapStateProvider mapStateProvider,
  ) {
    // Skip if using GeoJSON layers
    if (mapStateProvider.useGeoJsonLayers) return;

    // Check if items actually changed to avoid redundant updates
    final currentItemIds = currentItems.keys.map((e) => e.toString()).toList()
      ..sort();
    final itemIdsKey = currentItemIds.join(',');
    if (itemIdsKey == _lastSyncedItemIds &&
        currentItems.length == _lastSyncedItemCount) {
      return;
    }

    if (_syncInProgress) return;
    _syncInProgress = true;

    print(
        'PinitMap: _applyClusteringAsync called with ${currentItems.length} items (changed)');

    Future.microtask(() async {
      try {
        if (currentItems.isEmpty) {
          if (!mounted) return;
          setState(() {
            _clusteredMarkers = {};
          });
          await _syncAnnotations(
            const {},
            mapStateProvider,
            mapStateReader,
            locationListManager,
          );
          _lastSyncedItemCount = 0;
          _lastSyncedItemIds = '';
          return;
        }

        final result = await MarkerClustering.clusterMarkers(
          locationMarkers: Map.fromEntries(
            currentItems.entries.map((e) => MapEntry(e.key, e.value)),
          ),
          devicePixelRatio: dpr,
        );

        final clusteredMarkers =
            result['markers'] as Map<dynamic, MapMarkerData>;
        print(
            'PinitMap: Clustering produced ${clusteredMarkers.length} markers');

        final Map<String, MapMarkerData> markersWithHandlers = {};
        for (final entry in clusteredMarkers.entries) {
          markersWithHandlers[entry.value.id] = entry.value;
        }

        if (mounted) {
          setState(() {
            _clusteredMarkers = markersWithHandlers;
          });
          await _syncAnnotations(markersWithHandlers, mapStateProvider,
              mapStateReader, locationListManager);
          _lastSyncedItemCount = currentItems.length;
          _lastSyncedItemIds = itemIdsKey;
        }
      } finally {
        _syncInProgress = false;
      }
    });
  }

  /// Legacy: Sync annotations using PointAnnotationManager.
  Future<void> _syncAnnotations(
    Map<String, MapMarkerData> markers,
    MapStateProvider mapStateProvider,
    MapStateProvider mapStateReader,
    LocationListManager locationListManager,
  ) async {
    final mgr = mapStateProvider.pointAnnotationManager;
    if (mgr == null) {
      print(
          'PinitMap: pointAnnotationManager is null, cannot sync annotations');
      return;
    }

    try {
      await mgr.deleteAll();

      final options = <mapbox.PointAnnotationOptions>[];
      for (final marker in markers.values) {
        if (marker.imageBytes.isEmpty) continue;
        options.add(mapbox.PointAnnotationOptions(
          geometry: marker.position.toPoint(),
          image: Uint8List.fromList(marker.imageBytes),
          iconAnchor: mapbox.IconAnchor.BOTTOM,
          iconSize: 1.0,
        ));
      }

      print('PinitMap: Creating ${options.length} annotations');

      if (options.isNotEmpty) {
        final annotations = await mgr.createMulti(options);
        print(
            'PinitMap: Successfully created ${annotations.length} annotations');

        mgr.addOnPointAnnotationClickListener(
          _AnnotationClickListener(
            markers: markers,
            annotations: annotations,
            mapStateProvider: mapStateProvider,
            mapStateReader: mapStateReader,
            locationListManager: locationListManager,
          ),
        );
      }
    } catch (e) {
      print('PinitMap: Error syncing annotations: $e');
    }
  }

  /// Handle location tap from GeoJSON layer.
  void _onLocationTapped(int locationId) {
    print('PinitMap: Location tapped: $locationId');
    final mapState = context.read<MapStateProvider>();
    final locationManager = context.read<LocationListManager>();

    mapState.setSelectedMarkerId(locationId.toString());

    // Find index in current items and animate carousel
    final index = locationManager.currentItems.keys
        .toList()
        .indexWhere((loc) => loc.locationId == locationId);

    if (index != -1) {
      mapState.animateToCarouselItem(index);
    }
  }

  /// Handle cluster tap from GeoJSON layer.
  void _onClusterTapped(LatLng center, int pointCount, double? expansionZoom) {
    print('PinitMap: Cluster tapped at $center with $pointCount points');
    final mapState = context.read<MapStateProvider>();

    // Zoom to where the cluster splits apart (small nudge past it so the
    // places separate cleanly).
    final zoom =
        expansionZoom != null ? expansionZoom + 0.5 : mapState.currentZoom + 2;
    mapState.animateCamera(center, zoom: zoom);
  }

  @override
  Widget build(BuildContext context) {
    final locationListManager = context.watch<LocationListManager>();
    final mapStateProvider = context.watch<MapStateProvider>();
    final mapStateReader = context.read<MapStateProvider>();
    final homeViewModel = context.watch<HomeViewModel>();

    final dpr = MediaQuery.of(context).devicePixelRatio;
    locationListManager.setDevicePixelRatio(dpr);

    // GeoJSON pins are driven by _requestPinsIfChanged (a list listener).
    if (!mapStateProvider.useGeoJsonLayers) {
      _applyClusteringAsync(
        locationListManager.currentItems,
        dpr,
        locationListManager,
        mapStateReader,
        mapStateProvider,
      );
    }

    final currentPosition = locationListManager.currentPosition;
    final isMagicSearchActive = homeViewModel.isMagicSearchActive;
    final hasMagicSearchQuery =
        homeViewModel.headerSearchController.text.trim().isNotEmpty;
    final supportsSearchThisArea =
        locationListManager.currentListType == LocationListType.recommended ||
            locationListManager.currentListType == LocationListType.bubble ||
            (isMagicSearchActive &&
                hasMagicSearchQuery &&
                locationListManager.currentListType == LocationListType.search);
    final isSearchingArea = locationListManager.isSearchingArea ||
        (isMagicSearchActive && locationListManager.isMagicSearching);

    final initialCenter = currentPosition ??
        const LatLng(PinitMap.DEFAULT_LAT, PinitMap.DEFAULT_LNG);
    return Stack(
      children: [
        mapbox.MapWidget(
          cameraOptions: mapbox.CameraOptions(
            center: initialCenter.toPoint(),
            zoom: 15.0,
          ),
          styleUri: "mapbox://styles/srishlok/cmlpttggl000p01rz51whgzk9",
          onMapCreated: _onMapCreated,
          // Sources and layers only need the style, not the tiles, so this
          // fires sooner than onMapLoaded.
          onStyleLoadedListener: (_) => mapStateReader.onStyleLoaded(),
          onTapListener: (mapbox.MapContentGestureContext tapContext) {
            // Handle GeoJSON layer tap events
            if (mapStateProvider.useGeoJsonLayers) {
              final point = tapContext.touchPosition;
              print('PinitMap: Map tapped at screen (${point.x}, ${point.y})');
              mapStateReader.handleMapTap(point.x, point.y);
            }
            widget.onMapTap?.call();
          },
          onCameraChangeListener: (mapbox.CameraChangedEventData event) {
            _onCameraChanged(mapStateProvider, locationListManager);
          },
        ),

        // "Search this area" button - show for proximal recommendation modes.
        // Positioned below the compact header search shell + chip row so it
        // never sits behind the top controls.
        if (supportsSearchThisArea)
          Positioned(
            top: MediaQuery.of(context).padding.top + 110,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring:
                  !mapStateProvider.showSearchThisAreaButton || isSearchingArea,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: mapStateProvider.showSearchThisAreaButton
                    ? Offset.zero
                    : const Offset(0, -0.18),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity:
                      mapStateProvider.showSearchThisAreaButton ? 1.0 : 0.0,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: pinit.PinitColors.cream,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: pinit.PinitColors.aubergine,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: pinit.PinitColors.aubergine,
                            blurRadius: 0,
                            offset: const Offset(3, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: widget.onSearchThisArea,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: isSearchingArea
                                      ? CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: pinit.PinitColors.aubergine,
                                        )
                                      : const Icon(
                                          FeatherIcons.search,
                                          size: 13,
                                          color: pinit.PinitColors.aubergine,
                                        ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isSearchingArea
                                      ? 'Searching...'
                                      : 'Search this area',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: pinit.PinitColors.aubergine,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _onMapCreated(mapbox.MapboxMap map) async {
    final mapState = context.read<MapStateProvider>();
    final locationManager = context.read<LocationListManager>();

    // Must come first: the SDK doesn't await this callback, and the style can
    // finish loading during any later await. setMapboxMap creates the layer
    // service synchronously, before its own first await.
    final mapReady = mapState.setMapboxMap(
      map,
      onLocationTapped: _onLocationTapped,
      onClusterTapped: _onClusterTapped,
    );

    unawaited(map.attribution.updateSettings(
      mapbox.AttributionSettings(enabled: false),
    ));

    // Enable location puck (blue dot)
    unawaited(map.location.updateSettings(mapbox.LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
    )));

    LatLng initialLocation = locationManager.currentPosition ??
        const LatLng(PinitMap.DEFAULT_LAT, PinitMap.DEFAULT_LNG);
    print('Setting initial location in onMapCreated: $initialLocation');
    mapState.setLastFocusedUserLocation(initialLocation);
    await mapReady;
    _mapReady = true;
  }

  Future<void> _onCameraChanged(
    MapStateProvider mapStateProvider,
    LocationListManager locationListManager,
  ) async {
    final map = mapStateProvider.mapboxMap;
    if (map == null) return;
    try {
      final state = await map.getCameraState();
      final center = LatLng.fromPoint(state.center);
      mapStateProvider.updateMapCenter(
        center,
        state.zoom,
      );
      locationListManager.setCameraPosition(CameraPositionData(
        target: center,
        zoom: state.zoom,
      ));
    } catch (_) {}
  }

  @override
  void dispose() {
    _locationListManager?.removeListener(_requestPinsIfChanged);
    if (_locationTrackingStarted) {
      _locationListManager?.stopLocationUpdates();
    }
    super.dispose();
  }
}

/// Legacy: Handles annotation tap events for PointAnnotation-based rendering.
class _AnnotationClickListener extends mapbox.OnPointAnnotationClickListener {
  final Map<String, MapMarkerData> markers;
  final List<mapbox.PointAnnotation?> annotations;
  final MapStateProvider mapStateProvider;
  final MapStateProvider mapStateReader;
  final LocationListManager locationListManager;

  _AnnotationClickListener({
    required this.markers,
    required this.annotations,
    required this.mapStateProvider,
    required this.mapStateReader,
    required this.locationListManager,
  });

  @override
  void onPointAnnotationClick(mapbox.PointAnnotation annotation) {
    final annotationIndex =
        annotations.indexWhere((a) => a?.id == annotation.id);
    if (annotationIndex < 0) return;

    final markerList = markers.values.toList();
    if (annotationIndex >= markerList.length) return;

    final tappedMarker = markerList[annotationIndex];
    final isCluster = tappedMarker.id.startsWith('cluster_');

    if (isCluster) {
      mapStateProvider.animateCamera(
        tappedMarker.position,
        zoom: mapStateProvider.currentZoom + 2,
      );
    } else {
      print("Marker tapped: ${tappedMarker.id}");
      mapStateReader.setSelectedMarkerId(tappedMarker.id);

      final index = locationListManager.currentItems.keys
          .toList()
          .indexWhere((loc) => loc.locationId.toString() == tappedMarker.id);

      if (index != -1) {
        mapStateProvider.animateToCarouselItem(index);
      }
    }
  }
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:login/models/locations.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
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
  
  // Legacy fields for PointAnnotation-based rendering (when useGeoJsonLayers is false)
  // ignore: unused_field
  bool _mapReady = false;
  // ignore: unused_field  
  Map<String, MapMarkerData> _clusteredMarkers = {};
  int _lastSyncedItemCount = 0;
  String _lastSyncedItemIds = '';
  bool _syncInProgress = false;
  
  // GeoJSON: Track last synced location IDs to avoid redundant updates
  String _lastGeoJsonSyncKey = '';

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
    _locationListManager ??= context.read<LocationListManager>();
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
                print('🎨 [PinitMap] Vibe filter applied - selected: $selected');
                _selectedVibeTagIds = selected;
                // Apply filters to location manager
                await _locationListManager?.applyFilters(
                  vibeTagIds: _selectedVibeTagIds.toList(),
                  cuisineTagIds: _selectedCuisineTagIds.toList(),
                );
                // Update MapStateProvider with the last searched area
                if (mounted) {
                  final mapState = context.read<MapStateProvider>();
                  final lastCenter = _locationListManager?.lastSearchedCenter;
                  final lastRadius = _locationListManager?.lastSearchedRadius;
                  if (lastCenter != null && lastRadius != null) {
                    mapState.setLastSearchedArea(lastCenter, lastRadius);
                  }
                }
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
                print('🍽️ [PinitMap] Cuisine filter applied - selected: $selected');
                _selectedCuisineTagIds = selected;
                // Apply filters to location manager
                await _locationListManager?.applyFilters(
                  vibeTagIds: _selectedVibeTagIds.toList(),
                  cuisineTagIds: _selectedCuisineTagIds.toList(),
                );
                // Update MapStateProvider with the last searched area
                if (mounted) {
                  final mapState = context.read<MapStateProvider>();
                  final lastCenter = _locationListManager?.lastSearchedCenter;
                  final lastRadius = _locationListManager?.lastSearchedRadius;
                  if (lastCenter != null && lastRadius != null) {
                    mapState.setLastSearchedArea(lastCenter, lastRadius);
                  }
                }
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

  /// Update locations using GeoJSON source (new approach).
  /// Mapbox handles clustering and text collision detection natively.
  void _updateGeoJsonLocations(
    Map<dynamic, MapMarkerData> currentItems,
    MapStateProvider mapStateProvider,
  ) {
    if (!mapStateProvider.useGeoJsonLayers) return;
    if (currentItems.isEmpty) {
      print('PinitMap: No items to display');
      return;
    }

    // Generate a key to detect changes
    final itemIds = currentItems.keys.map((e) {
      if (e is LocationModel) return e.locationId.toString();
      return e.toString();
    }).toList()..sort();
    final syncKey = '${itemIds.length}_${itemIds.hashCode}';
    
    if (syncKey == _lastGeoJsonSyncKey) {
      // No change, skip update
      return;
    }
    
    print('PinitMap: Updating GeoJSON with ${currentItems.length} locations');
    
    // Extract LocationModel instances
    final locations = currentItems.keys
        .whereType<LocationModel>()
        .toList();
    
    // Update via provider (which delegates to GeoJsonMapLayerService)
    // Only mark as synced if the update actually succeeded
    mapStateProvider.updateMapLocations(locations).then((success) {
      if (success) {
        _lastGeoJsonSyncKey = syncKey;
        print('PinitMap: GeoJSON sync successful, key set to $syncKey');
      } else {
        print('PinitMap: GeoJSON update skipped (service not ready), will retry on next rebuild');
      }
    });
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
    
    if (currentItems.isEmpty) {
      print('PinitMap: currentItems is empty, skipping clustering');
      return;
    }
    
    // Check if items actually changed to avoid redundant updates
    final currentItemIds = currentItems.keys.map((e) => e.toString()).toList()..sort();
    final itemIdsKey = currentItemIds.join(',');
    if (itemIdsKey == _lastSyncedItemIds && currentItems.length == _lastSyncedItemCount) {
      return;
    }
    
    if (_syncInProgress) return;
    _syncInProgress = true;
    
    print('PinitMap: _applyClusteringAsync called with ${currentItems.length} items (changed)');
    
    Future.microtask(() async {
      try {
        final result = await MarkerClustering.clusterMarkers(
          locationMarkers: Map.fromEntries(
            currentItems.entries.map((e) => MapEntry(e.key, e.value)),
          ),
          devicePixelRatio: dpr,
        );

        final clusteredMarkers = result['markers'] as Map<dynamic, MapMarkerData>;
        print('PinitMap: Clustering produced ${clusteredMarkers.length} markers');

        final Map<String, MapMarkerData> markersWithHandlers = {};
        for (final entry in clusteredMarkers.entries) {
          markersWithHandlers[entry.value.id] = entry.value;
        }

        if (mounted) {
          setState(() {
            _clusteredMarkers = markersWithHandlers;
          });
          await _syncAnnotations(markersWithHandlers, mapStateProvider, mapStateReader, locationListManager);
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
      print('PinitMap: pointAnnotationManager is null, cannot sync annotations');
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
        print('PinitMap: Successfully created ${annotations.length} annotations');

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
  void _onClusterTapped(LatLng center, int pointCount) {
    print('PinitMap: Cluster tapped at $center with $pointCount points');
    final mapState = context.read<MapStateProvider>();
    
    // Zoom in to expand the cluster
    mapState.animateCamera(center, zoom: mapState.currentZoom + 2);
  }

  @override
  Widget build(BuildContext context) {
    final locationListManager = context.watch<LocationListManager>();
    final mapStateProvider = context.watch<MapStateProvider>();
    final mapStateReader = context.read<MapStateProvider>();

    final dpr = MediaQuery.of(context).devicePixelRatio;
    locationListManager.setDevicePixelRatio(dpr);

    // Update map based on current approach
    if (mapStateProvider.useGeoJsonLayers) {
      _updateGeoJsonLocations(
        locationListManager.currentItems,
        mapStateProvider,
      );
    } else {
      _applyClusteringAsync(
        locationListManager.currentItems,
        dpr,
        locationListManager,
        mapStateReader,
        mapStateProvider,
      );
    }

    final currentPosition = locationListManager.currentPosition;
    final isRecommendedTab =
        locationListManager.currentListType == LocationListType.recommended;

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

        // "Search this area" button - only show on recommended tab.
        // Positioned below the header panel (logo + search shell + chip row)
        // so it never sits behind the You / Explore / Decide chips.
        if (mapStateProvider.showSearchThisAreaButton && isRecommendedTab)
          Positioned(
            top: MediaQuery.of(context).padding.top + 160,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      )
                    ]),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20.0),
                    onTap: () {
                      widget.onSearchThisArea?.call();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            FeatherIcons.search,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Search this area",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
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
      ],
    );
  }

  void _onMapCreated(mapbox.MapboxMap map) async {
    final mapState = context.read<MapStateProvider>();
    final locationManager = context.read<LocationListManager>();
    
    // Initialize map with callbacks for GeoJSON layer events
    await mapState.setMapboxMap(
      map,
      onLocationTapped: _onLocationTapped,
      onClusterTapped: _onClusterTapped,
    );

    // Enable location puck (blue dot)
    await map.location.updateSettings(mapbox.LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
    ));

    LatLng initialLocation = locationManager.currentPosition ??
        const LatLng(PinitMap.DEFAULT_LAT, PinitMap.DEFAULT_LNG);
    print('Setting initial location in onMapCreated: $initialLocation');
    mapState.setLastFocusedUserLocation(initialLocation);
    _mapReady = true;
    
    // Reset sync key to force an update now that the map is ready
    _lastGeoJsonSyncKey = '';
    
    // Trigger initial location update for GeoJSON mode
    if (mapState.useGeoJsonLayers && locationManager.currentItems.isNotEmpty) {
      final locations = locationManager.currentItems.keys
          .whereType<LocationModel>()
          .toList();
      final success = await mapState.updateMapLocations(locations);
      if (success) {
        // Update sync key to match current state
        final itemIds = locationManager.currentItems.keys.map((e) {
          if (e is LocationModel) return e.locationId.toString();
          return e.toString();
        }).toList()..sort();
        _lastGeoJsonSyncKey = '${itemIds.length}_${itemIds.hashCode}';
        print('PinitMap: Initial GeoJSON sync after map created, ${locations.length} locations');
      }
    }
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
      mapStateProvider.updateMapCenter(center, state.zoom);
      locationListManager.setCameraPosition(CameraPositionData(
        target: center,
        zoom: state.zoom,
      ));
    } catch (_) {}
  }

  @override
  void dispose() {
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
    final annotationIndex = annotations.indexWhere((a) => a?.id == annotation.id);
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

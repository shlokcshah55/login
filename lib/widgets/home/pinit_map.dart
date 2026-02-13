import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/utils/geo_types.dart';
import 'package:login/utils/marker_clustering.dart';
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
  bool _mapReady = false;
  Map<String, MapMarkerData> _clusteredMarkers = {};
  
  // Track last synced items to avoid redundant annotation updates
  int _lastSyncedItemCount = 0;
  String _lastSyncedItemIds = '';
  bool _syncInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startLocationTracking();
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

  void _applyClusteringAsync(
    Map<dynamic, MapMarkerData> currentItems,
    double dpr,
    LocationListManager locationListManager,
    MapStateProvider mapStateReader,
    MapStateProvider mapStateProvider,
  ) {
    if (currentItems.isEmpty) {
      print('PinitMap: currentItems is empty, skipping clustering');
      return;
    }
    
    // Check if items actually changed to avoid redundant updates
    final currentItemIds = currentItems.keys.map((e) => e.toString()).toList()..sort();
    final itemIdsKey = currentItemIds.join(',');
    if (itemIdsKey == _lastSyncedItemIds && currentItems.length == _lastSyncedItemCount) {
      // No change, skip
      return;
    }
    
    // Prevent concurrent syncs
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
          // Sync annotations to the map
          await _syncAnnotations(markersWithHandlers, mapStateProvider, mapStateReader, locationListManager);
          
          // Update tracking
          _lastSyncedItemCount = currentItems.length;
          _lastSyncedItemIds = itemIdsKey;
        }
      } finally {
        _syncInProgress = false;
      }
    });
  }

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
      // Clear existing annotations
      await mgr.deleteAll();

      // Create new annotations
      final options = <mapbox.PointAnnotationOptions>[];
      for (final marker in markers.values) {
        // Skip markers with no image data - they won't render
        if (marker.imageBytes.isEmpty) {
          continue;
        }
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

        // Set up click listener
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

  @override
  Widget build(BuildContext context) {
    final locationListManager = context.watch<LocationListManager>();
    final mapStateProvider = context.watch<MapStateProvider>();
    final mapStateReader = context.read<MapStateProvider>();

    final dpr = MediaQuery.of(context).devicePixelRatio;
    locationListManager.setDevicePixelRatio(dpr);

    // Apply clustering
    _applyClusteringAsync(
      locationListManager.currentItems,
      dpr,
      locationListManager,
      mapStateReader,
      mapStateProvider,
    );

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
          styleUri: mapbox.MapboxStyles.LIGHT,
          onMapCreated: _onMapCreated,
          onTapListener: (mapbox.MapContentGestureContext context) {
            widget.onMapTap?.call();
          },
          onCameraChangeListener: (mapbox.CameraChangedEventData event) {
            _onCameraChanged(mapStateProvider, locationListManager);
          },
        ),

        // "Search this area" button - only show on recommended tab
        if (mapStateProvider.showSearchThisAreaButton && isRecommendedTab)
          Positioned(
            top: 150,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
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

        // "My Location" button
        Positioned(
          top: 150,
          left: 20,
          child: Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30.0),
                onTap: () async {
                  print('My Location button pressed');
                  await _startLocationTracking();
                  LatLng? position = locationListManager.currentPosition;
                  position ??= await locationListManager.getCurrentLocation();
                  if (position != null) {
                    await mapStateReader.focusOnUserLocation(position, zoom: 15.0);
                    print('Focused on position: $position');
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unable to get your location. Please ensure GPS is enabled and try again.'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Icon(
                    FeatherIcons.crosshair,
                    color: Theme.of(context).primaryColor,
                    size: 24,
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
    await mapState.setMapboxMap(map);

    // Enable location puck (blue dot)
    await map.location.updateSettings(mapbox.LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
    ));

    final locationManager = context.read<LocationListManager>();
    LatLng initialLocation = locationManager.currentPosition ??
        const LatLng(PinitMap.DEFAULT_LAT, PinitMap.DEFAULT_LNG);
    print('Setting initial location in onMapCreated: $initialLocation');
    mapState.setLastFocusedUserLocation(initialLocation);
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

/// Handles annotation tap events and maps them back to marker IDs.
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
    // Find which marker was tapped by matching annotation index
    final annotationIndex = annotations.indexWhere((a) => a?.id == annotation.id);
    if (annotationIndex < 0) return;

    final markerList = markers.values.toList();
    if (annotationIndex >= markerList.length) return;

    final tappedMarker = markerList[annotationIndex];
    final isCluster = tappedMarker.id.startsWith('cluster_');

    if (isCluster) {
      // Zoom in on cluster
      mapStateProvider.animateCamera(
        tappedMarker.position,
        zoom: mapStateProvider.currentZoom + 2,
      );
    } else {
      // Handle individual marker tap
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
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
  String? _mapStyle;
  bool _locationTrackingStarted = false;
  Map<String, Marker> _clusteredMarkers = {};
  LocationListManager? _locationListManager;

  // Caching to prevent unnecessary reclustering
  String? _lastClusterHash;

  // Debounce clustering during rapid zoom/pan
  bool _isClusteringInProgress = false;
  DateTime? _lastClusterTime;
  static const _clusterDebounceMs = 150; // Minimum ms between cluster updates

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    // Start GPS tracking automatically
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
    print('[MapDebug] Starting location tracking...');
    print('_locationListManager: $_locationListManager');
    await _locationListManager?.startLocationUpdates();
  }

  Future<void> _loadMapStyle() async {
    final String style =
        await rootBundle.loadString('lib/assets/map_style.json');
    if (mounted) {
      setState(() {
        _mapStyle = style;
      });
    }
  }

  String _getClusteringCacheKey(
    Map<dynamic, Marker> items,
    double zoom,
  ) {
    // Round zoom to 0.5 increments (less sensitive for smoother experience)
    final roundedZoom = (zoom * 2).round() / 2;
    return '${items.length}_${items.keys.map((l) => l.locationId).join(',')}_$roundedZoom';
  }

  void _applyClusteringAsync(
    Map<dynamic, Marker> currentItems,
    double dpr,
    LocationListManager locationListManager,
    MapStateProvider mapStateReader,
    MapStateProvider mapStateProvider,
    double currentZoom,
    LatLng? viewportCenter,
  ) {
    // Debounce: skip if already clustering or too soon after last cluster
    if (_isClusteringInProgress) return;

    final now = DateTime.now();
    if (_lastClusterTime != null) {
      final msSinceLastCluster =
          now.difference(_lastClusterTime!).inMilliseconds;
      if (msSinceLastCluster < _clusterDebounceMs) {
        // Schedule a delayed recluster instead of blocking
        Future.delayed(
            Duration(milliseconds: _clusterDebounceMs - msSinceLastCluster),
            () {
          if (mounted) {
            _applyClusteringAsync(
              currentItems,
              dpr,
              locationListManager,
              mapStateReader,
              mapStateProvider,
              currentZoom,
              viewportCenter,
            );
          }
        });
        return;
      }
    }

    _isClusteringInProgress = true;
    _lastClusterTime = now;

    // Apply clustering in the next frame to avoid blocking the build
    Future.microtask(() async {
      try {
        final result = await MarkerClustering.clusterMarkers(
          locationMarkers: Map.fromEntries(
            currentItems.entries.map((e) => MapEntry(e.key, e.value)),
          ),
          devicePixelRatio: dpr,
          zoom: currentZoom,
          viewportCenter:
              viewportCenter, // Pass for accurate latitude-based calculation
        );

        final clusteredMarkers = result['markers'] as Map<dynamic, Marker>;

        // Add onTap handlers to all markers
        final Map<String, Marker> markersWithHandlers = {};
        for (final entry in clusteredMarkers.entries) {
          final originalMarker = entry.value;
          final isCluster =
              originalMarker.markerId.value.startsWith('cluster_');

          markersWithHandlers[originalMarker.markerId.value] =
              originalMarker.copyWith(
            onTapParam: () {
              if (isCluster) {
                // Zoom in on cluster with smooth animation
                mapStateProvider.animateCamera(
                  CameraUpdate.newLatLngZoom(originalMarker.position,
                      mapStateProvider.currentZoom + 2),
                );
              } else {
                // Handle individual marker tap
                print("Marker tapped: ${originalMarker.markerId.value}");
                mapStateReader.setSelectedMarkerId(originalMarker.markerId);

                final index = locationListManager.currentItems.keys
                    .toList()
                    .indexWhere((loc) =>
                        loc.locationId.toString() ==
                        originalMarker.markerId.value);

                if (index != -1) {
                  mapStateProvider.animateToCarouselItem(index);
                }
              }
            },
            infoWindowParam: const InfoWindow(title: ""),
          );
        }

        if (mounted) {
          setState(() {
            _clusteredMarkers = markersWithHandlers;
          });
        }
      } finally {
        _isClusteringInProgress = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to providers needed for map display
    final locationListManager = context.watch<LocationListManager>();
    final mapStateProvider = context
        .watch<MapStateProvider>(); // Watch for polyline/selection changes
    final mapStateReader =
        context.read<MapStateProvider>(); // Use read for onTap callback

    // Set device pixel ratio for high-quality marker rendering
    final dpr = MediaQuery.of(context).devicePixelRatio;
    locationListManager.setDevicePixelRatio(dpr);

    // Get current zoom level and viewport center
    final currentZoom = mapStateProvider.currentZoom;
    final viewportCenter = mapStateProvider.currentVisibleCenter;

    // Check if we need to recluster
    final currentItems = locationListManager.currentItems;
    final cacheKey = _getClusteringCacheKey(currentItems, currentZoom);
    final shouldRecluster = _lastClusterHash != cacheKey;

    // Apply clustering only if needed (debounced for smoothness)
    if (shouldRecluster && !_isClusteringInProgress) {
      _lastClusterHash = cacheKey;
      _applyClusteringAsync(
        currentItems,
        dpr,
        locationListManager,
        mapStateReader,
        mapStateProvider,
        currentZoom,
        viewportCenter,
      );
    }

    // Use clustered markers
    final Set<Marker> markers = _clusteredMarkers.values.toSet();

    // Get current position from LocationListManager
    final currentPosition = locationListManager.currentPosition;

    // Get the current list type from location list manager
    final isRecommendedTab =
        locationListManager.currentListType == LocationListType.recommended;

    return Stack(
      children: [
        GoogleMap(
          style: _mapStyle,
          mapToolbarEnabled: false,
          myLocationEnabled: true,
          myLocationButtonEnabled: false, // We add our own button
          compassEnabled: false,
          zoomControlsEnabled: false,
          initialCameraPosition: CameraPosition(
            // Use current position from LocationListManager for initial target
            target: currentPosition ??
                const LatLng(PinitMap.DEFAULT_LAT, PinitMap.DEFAULT_LNG),
            zoom: 15,
          ),
          onMapCreated: (controller) {
            // Set the controller in the MapStateProvider
            final mapState = context.read<MapStateProvider>();
            mapState.setMapController(controller);

            // Initialize the lastFocusedUserLocation with the current position
            // or the initial camera position if no current position is available
            final locationManager = context.read<LocationListManager>();
            LatLng initialLocation = locationManager.currentPosition ??
                LatLng(PinitMap.DEFAULT_LAT, PinitMap.DEFAULT_LNG);

            print('Setting initial location in onMapCreated: $initialLocation');
            mapState.setLastFocusedUserLocation(initialLocation);
          },
          onTap: (LatLng position) {
            // Call the callback when map is tapped
            widget.onMapTap?.call();
          },
          onCameraMove: (CameraPosition position) {
            // Update the map center in MapStateProvider when camera moves
            mapStateProvider.updateMapCenter(position);
            locationListManager.setCameraPosition(position);
          },
          onCameraIdle: () async {
            // Trigger rebuild to recluster when user stops zooming
            if (mounted) {
              setState(() {});
            }

            // Get viewport bounds and trigger name selection
            final controller = mapStateProvider.mapController;
            if (controller != null) {
              try {
                final bounds = await controller.getVisibleRegion();
                final center = mapStateProvider.currentVisibleCenter;
                final zoom = mapStateProvider.currentZoom;

                await locationListManager.onMapViewportChanged(
                  bounds: bounds,
                  center: center,
                  zoom: zoom,
                );
              } catch (e) {
                print('Error updating viewport bounds: $e');
              }
            }
          },
          markers: markers,
          // Get polylines from MapStateProvider
          polylines: mapStateProvider.polylines,
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

        // "My Location" button - always show at the top left
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
                  print('Current position from stream: $position');

                  // If no position yet, fetch it directly via the manager.
                  position ??= await locationListManager.getCurrentLocation();

                  if (position != null) {
                    await mapStateReader.focusOnUserLocation(position,
                        zoom: 15.0);
                    print('Focused on position: $position');
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Unable to get your location. Please ensure GPS is enabled and try again.'),
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

  @override
  void dispose() {
    // Note: Don't stop location tracking here.
    // LocationService is a singleton that should keep running.
    // Location tracking is managed at the app level.
    super.dispose();
  }
}

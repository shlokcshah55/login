import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:login/utils/geo_types.dart';
import 'package:login/models/markers.dart';
import 'package:login/models/proximal_models.dart';
import 'package:login/services/recommendations_api.dart';
import 'package:login/widgets/feedback/app_feedback.dart';

class MapScreenSearchArea extends StatefulWidget {
  final String currentUserId;
  final Map<int, LatLng> locationCoordinates;

  const MapScreenSearchArea({
    super.key,
    required this.currentUserId,
    required this.locationCoordinates,
  });

  @override
  State<MapScreenSearchArea> createState() => _MapScreenSearchAreaState();
}

class _MapScreenSearchAreaState extends State<MapScreenSearchArea> {
  final RecommendationsApi _api = RecommendationsApi();
  mapbox.MapboxMap? _mapController;
  mapbox.PointAnnotationManager? _annotationManager;
  LatLng? _currentCenter;
  LatLng? _lastSearchedCenter;
  bool _areaChanged = false;
  bool _isSearching = false;

  List<Recommendation> _recommendations = [];
  List<MapMarkerData> _markerData = [];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        mapbox.MapWidget(
          styleUri: mapbox.MapboxStyles.LIGHT,
          cameraOptions: mapbox.CameraOptions(
            center: const LatLng(37.773972, -122.431297).toPoint(),
            zoom: 14,
          ),
          onMapCreated: (controller) async {
            _mapController = controller;
            await controller.attribution.updateSettings(
              mapbox.AttributionSettings(enabled: false),
            );
            _annotationManager =
                await controller.annotations.createPointAnnotationManager();
          },
          onCameraChangeListener: (mapbox.CameraChangedEventData data) {
            _areaChanged = true;
          },
          onMapIdleListener: (mapbox.MapIdleEventData data) {
            if (!mounted) return;
            setState(() {});
          },
        ),
        Positioned(
          top: 150,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _areaChanged ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_areaChanged || _isSearching,
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
                      onTap: _isSearching ? null : _searchThisArea,
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
                              child: _isSearching
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
                              _isSearching
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
      ],
    );
  }

  Future<void> _searchThisArea() async {
    final controller = _mapController;
    if (controller == null) return;

    final cameraState = await controller.getCameraState();
    final centerPoint = cameraState.center;
    final center = LatLng.fromPoint(centerPoint);

    final bounds = await controller.coordinateBoundsForCamera(
      mapbox.CameraOptions(
        center: centerPoint,
        zoom: cameraState.zoom,
        bearing: cameraState.bearing,
        pitch: cameraState.pitch,
      ),
    );
    final latLngBounds = LatLngBounds.fromCoordinateBounds(bounds);
    final radiusKm = radiusKmFromVisibleRegion(latLngBounds, center);

    setState(() => _isSearching = true);
    try {
      final response = await _api.fetchProximal(
        userId: widget.currentUserId,
        latitude: center.latitude,
        longitude: center.longitude,
        radiusKm: radiusKm,
      );

      // print the markers being created
      for (var rec in response.recommendations) {
        print('Recommendation: ${rec.name}, Location ID: ${rec.locationId}');
      }

      final markers = await _buildMarkers(response.recommendations);
      if (!mounted) return;

      setState(() {
        _recommendations = response.recommendations;
        _markerData = markers;
        _lastSearchedCenter = center;
        _areaChanged = false;
      });
      _syncAnnotations();
    } catch (e) {
      if (!mounted) return;
      await AppFeedback.showError(
        context,
        title: 'Search failed',
        message: 'Please try again in a moment.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<List<MapMarkerData>> _buildMarkers(
    List<Recommendation> recommendations,
  ) async {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final List<MapMarkerData> markers = [];

    for (final rec in recommendations) {
      final position = widget.locationCoordinates[rec.locationId];
      if (position == null) {
        continue;
      }

      final imageBytes = await PinitMarkers.createPinitMarker(
        name: rec.name,
        devicePixelRatio: dpr,
        rating: rec.rating,
        fallbackSeed: rec.locationId,
      );

      markers.add(
        MapMarkerData(
          id: rec.locationId.toString(),
          position: position,
          imageBytes: imageBytes,
          title: rec.name,
          snippet: rec.vicinity ?? '',
        ),
      );
    }

    return markers;
  }

  Future<void> _syncAnnotations() async {
    final manager = _annotationManager;
    if (manager == null) return;
    await manager.deleteAll();
    for (final m in _markerData) {
      final bytes = Uint8List.fromList(m.imageBytes);
      await manager.create(
        mapbox.PointAnnotationOptions(
          geometry: m.position.toPoint(),
          image: bytes,
          iconSize: 1.0,
        ),
      );
    }
  }

  static double radiusKmFromVisibleRegion(
    LatLngBounds bounds,
    LatLng center,
  ) {
    final double distanceKm = _haversineKm(
      center.latitude,
      center.longitude,
      bounds.northeast.latitude,
      bounds.northeast.longitude,
    );
    return distanceKm.clamp(0.5, 10.0);
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180);
}

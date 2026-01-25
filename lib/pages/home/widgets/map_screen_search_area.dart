import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/markers.dart';
import 'package:login/models/proximal_models.dart';
import 'package:login/services/recommendations_api.dart';

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
  GoogleMapController? _mapController;
  CameraPosition? _cameraPosition;
  LatLng? _lastSearchedCenter;
  bool _areaChanged = false;
  bool _isSearching = false;

  List<Recommendation> _recommendations = [];
  Set<Marker> _markers = {};

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(37.773972, -122.431297),
            zoom: 14,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
          },
          onCameraMove: (position) {
            _cameraPosition = position;
            _areaChanged = true;
          },
          onCameraIdle: () {
            if (!mounted) return;
            setState(() {});
          },
          markers: _markers,
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
                child: ElevatedButton(
                  onPressed: _isSearching ? null : _searchThisArea,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Search this area'),
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

    final center = _cameraPosition?.target ??
        await controller.getLatLng(
          const ScreenCoordinate(x: 0, y: 0),
        );
    final bounds = await controller.getVisibleRegion();
    final radiusKm = radiusKmFromVisibleRegion(bounds, center);

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
        _markers = markers;
        _lastSearchedCenter = center;
        _areaChanged = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<Set<Marker>> _buildMarkers(
    List<Recommendation> recommendations,
  ) async {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final Set<Marker> markers = {};

    for (final rec in recommendations) {
      final position = widget.locationCoordinates[rec.locationId];
      if (position == null) {
        continue;
      }

      final icon = await PinitMarkers.createPinitMarker(
        emoji: '📍',
        name: rec.name,
        devicePixelRatio: dpr,
      );

      markers.add(
        Marker(
          markerId: MarkerId(rec.locationId.toString()),
          position: position,
          icon: icon,
          infoWindow: InfoWindow(
            title: rec.name,
            snippet: rec.vicinity ?? '',
          ),
        ),
      );
    }

    return markers;
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

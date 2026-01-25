import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/markers.dart';

class MarkerCluster {
  final LatLng center;
  final List<LocationModel> locations;
  final int count;

  MarkerCluster({
    required this.center,
    required this.locations,
  }) : count = locations.length;
}

class MarkerClustering {
  /// Clusters markers based on distance
  static Future<Map<String, dynamic>> clusterMarkers({
    required Map<LocationModel, Marker> locationMarkers,
    required double devicePixelRatio,
    double zoom = 15.0,
  }) async {
    // Dynamic clustering distance based on zoom
    // At zoom 10: ~1km, zoom 15: ~80m, zoom 18: ~20m
    double clusterDistance = 1000 / math.pow(2, zoom - 10); // meters
    if (clusterDistance < 20) clusterDistance = 20;

    final List<LocationModel> locations = locationMarkers.keys.toList();
    final List<MarkerCluster> clusters = [];
    final Set<int> clusteredIndices = {};
    final Map<LocationModel, Marker> unclustered = {};

    // Group nearby markers into clusters
    for (int i = 0; i < locations.length; i++) {
      if (clusteredIndices.contains(i)) continue;

      final location = locations[i];
      if (location.lat == null || location.lng == null) continue;

      final List<LocationModel> clusterLocations = [location];
      clusteredIndices.add(i);

      // Find nearby markers to cluster with
      for (int j = i + 1; j < locations.length; j++) {
        if (clusteredIndices.contains(j)) continue;

        final other = locations[j];
        if (other.lat == null || other.lng == null) continue;

        final distance = _calculateDistance(
          location.lat!,
          location.lng!,
          other.lat!,
          other.lng!,
        ) * 1000; // convert km to meters

        if (distance <= clusterDistance) {
          clusterLocations.add(other);
          clusteredIndices.add(j);
        }
      }

      // If we have multiple locations in this cluster, create a cluster marker
      if (clusterLocations.length > 1) {
        final center = _calculateCenter(clusterLocations);
        clusters.add(MarkerCluster(
          center: center,
          locations: clusterLocations,
        ));
      } else {
        // Single marker, keep it as is
        unclustered[location] = locationMarkers[location]!;
      }
    }

    // Create cluster markers
    final Map<LocationModel, Marker> clusterMarkers = {};
    for (final cluster in clusters) {
      final clusterMarker = await _createClusterMarker(
        cluster: cluster,
        devicePixelRatio: devicePixelRatio,
      );

      // Use first location as the key for the cluster
      clusterMarkers[cluster.locations.first] = clusterMarker;
    }

    // Combine cluster markers with unclustered individual markers
    final allMarkers = {...unclustered, ...clusterMarkers};

    return {
      'markers': allMarkers,
      'clusters': clusters,
    };
  }

  static double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371; // km
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180);

  static LatLng _calculateCenter(List<LocationModel> locations) {
    double totalLat = 0;
    double totalLng = 0;
    int count = 0;

    for (final location in locations) {
      if (location.lat != null && location.lng != null) {
        totalLat += location.lat!;
        totalLng += location.lng!;
        count++;
      }
    }

    return LatLng(totalLat / count, totalLng / count);
  }

  static Future<Marker> _createClusterMarker({
    required MarkerCluster cluster,
    required double devicePixelRatio,
  }) async {
    final icon = await PinitMarkers.createClusterMarker(
      count: cluster.count,
      devicePixelRatio: devicePixelRatio,
    );

    return Marker(
      markerId: MarkerId(
          'cluster_${cluster.center.latitude}_${cluster.center.longitude}'),
      position: cluster.center,
      icon: icon,
      anchor: const Offset(0.5, 0.5), // Center anchor for cluster
      infoWindow: InfoWindow(
        title: '${cluster.count} locations',
        snippet: 'Tap to zoom in',
      ),
    );
  }
}

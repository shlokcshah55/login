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
    // Calculate clustering distance based on visual marker size
    // At higher zoom levels, we want markers to be closer before clustering
    // At lower zoom levels, cluster more aggressively

    // Convert visual pixels to meters on the ground at current zoom
    // Formula: metersPerPixel = 156543.03392 * cos(latitude) / 2^zoom
    // Using average latitude of ~51.5 (London), cos(51.5°) ≈ 0.625
    // At zoom 15: ~3 meters per pixel
    // At zoom 18: ~0.4 meters per pixel
    // At zoom 20: ~0.1 meters per pixel

    final double metersPerPixel = 156543.03392 * 0.625 / math.pow(2, zoom);

    // Base marker size for clustering calculation
    // Use smaller value at high zooms to allow more separation
    double markerVisualWidth;
    if (zoom >= 18) {
      markerVisualWidth = 20; // Very tight at high zoom - only cluster if nearly overlapping
    } else if (zoom >= 16) {
      markerVisualWidth = 30; // Tighter clustering at medium-high zoom
    } else if (zoom >= 14) {
      markerVisualWidth = 40; // Standard clustering
    } else {
      markerVisualWidth = 60; // More aggressive clustering at low zoom
    }

    // Convert to meters
    double clusterDistance = metersPerPixel * markerVisualWidth;

    // Much lower minimum distance to allow unclustering at high zoom
    // At zoom 18+, we want to see individual pins even if close
    double minDistance;
    if (zoom >= 18) {
      minDistance = 5; // 5 meters minimum at high zoom
    } else if (zoom >= 16) {
      minDistance = 10; // 10 meters at medium zoom
    } else {
      minDistance = 20; // 20 meters at lower zooms
    }
    
    if (clusterDistance < minDistance) clusterDistance = minDistance;

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

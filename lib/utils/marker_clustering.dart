import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:login/utils/geo_types.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/markers.dart';

/// Represents a cluster of multiple locations
class MarkerCluster {
  final LatLng center;
  final List<LocationModel> locations;
  final int count;
  final String id; // Unique stable ID for the cluster

  MarkerCluster({
    required this.center,
    required this.locations,
    required this.id,
  }) : count = locations.length;
}

/// Result of clustering operation - includes both markers and metadata
class ClusteringResult {
  final Map<LocationModel, MapMarkerData> markers;
  final List<MarkerCluster> clusters;
  final Set<int> unclusteredLocationIds;

  ClusteringResult({
    required this.markers,
    required this.clusters,
    required this.unclusteredLocationIds,
  });
}

/// High-performance marker clustering using grid-based spatial hashing
/// Time complexity: O(N) average case vs O(N²) for naive approach
class MarkerClustering {
  // Cache for clustering results to avoid recalculation
  static String? _lastCacheKey;
  static ClusteringResult? _cachedResult;

  /// Clusters markers based on distance using grid-based spatial hashing
  ///
  /// This is O(N) average case complexity using spatial grid partitioning
  /// instead of O(N²) pairwise distance calculation.
  static Future<Map<String, dynamic>> clusterMarkers({
    required Map<LocationModel, MapMarkerData> locationMarkers,
    required double devicePixelRatio,
    double zoom = 15.0,
    LatLng?
        viewportCenter, // Optional: for accurate meters-per-pixel calculation
    LatLngBounds? viewportBounds, // Optional: for viewport culling
  }) async {
    if (locationMarkers.isEmpty) {
      return {
        'markers': <LocationModel, MapMarkerData>{},
        'clusters': <MarkerCluster>[],
        'unclusteredIds': <int>{},
      };
    }

    // Generate cache key
    final cacheKey = _generateCacheKey(locationMarkers, zoom);

    // Return cached result if available
    if (_lastCacheKey == cacheKey && _cachedResult != null) {
      return {
        'markers': _cachedResult!.markers,
        'clusters': _cachedResult!.clusters,
        'unclusteredIds': _cachedResult!.unclusteredLocationIds,
      };
    }

    // Calculate clustering distance based on zoom and actual viewport latitude
    final clusterDistanceMeters = _calculateClusterDistance(
      zoom: zoom,
      centerLatitude: viewportCenter?.latitude,
    );

    // Optional: Filter to viewport bounds for performance
    Map<LocationModel, MapMarkerData> locationsToCluster = locationMarkers;
    if (viewportBounds != null) {
      locationsToCluster = _filterToViewport(locationMarkers, viewportBounds);
      // If viewport filtering removed everything, use all locations
      if (locationsToCluster.isEmpty) {
        locationsToCluster = locationMarkers;
      }
    }

    // Use grid-based clustering (O(N) average case)
    final result = await _gridBasedClustering(
      locationMarkers: locationsToCluster,
      clusterDistanceMeters: clusterDistanceMeters,
      devicePixelRatio: devicePixelRatio,
    );

    // Cache the result
    _lastCacheKey = cacheKey;
    _cachedResult = result;

    return {
      'markers': result.markers,
      'clusters': result.clusters,
      'unclusteredIds': result.unclusteredLocationIds,
    };
  }

  /// Clears the clustering cache (call when locations change significantly)
  static void clearCache() {
    _lastCacheKey = null;
    _cachedResult = null;
  }

  /// Get unclustered location IDs without re-running full clustering
  /// Useful for name display selection
  static Set<int> getUnclusteredLocationIds() {
    return _cachedResult?.unclusteredLocationIds ?? {};
  }

  /// Check if a specific location is clustered
  static bool isLocationClustered(int locationId) {
    if (_cachedResult == null) return false;
    return !_cachedResult!.unclusteredLocationIds.contains(locationId);
  }

  // ============ Private Implementation ============

  /// Generate a stable cache key for clustering results
  static String _generateCacheKey(
    Map<LocationModel, MapMarkerData> locationMarkers,
    double zoom,
  ) {
    // Round zoom to 0.5 increments (less sensitive than 0.25)
    final roundedZoom = (zoom * 2).round() / 2;

    // Use sorted location IDs for stable key
    final sortedIds = locationMarkers.keys.map((l) => l.locationId).toList()
      ..sort();

    return '${sortedIds.length}_${sortedIds.hashCode}_$roundedZoom';
  }

  /// Calculate cluster distance in meters based on zoom level
  /// Uses actual latitude for accurate projection
  static double _calculateClusterDistance({
    required double zoom,
    double? centerLatitude,
  }) {
    // Use provided latitude or default to mid-latitude (45°)
    final latitude = centerLatitude ?? 45.0;
    final cosLatitude = math.cos(_degToRad(latitude.abs().clamp(0.0, 85.0)));

    // Meters per pixel at this zoom and latitude
    // Formula: metersPerPixel = 156543.03392 * cos(latitude) / 2^zoom
    final double metersPerPixel =
        156543.03392 * cosLatitude / math.pow(2, zoom);

    // Marker visual width varies by zoom (pixels)
    // At high zoom: smaller cluster radius (more individual pins)
    // At low zoom: larger cluster radius (more aggressive clustering)
    double markerVisualWidth;
    if (zoom >= 18) {
      markerVisualWidth = 18; // Very tight - only cluster if nearly overlapping
    } else if (zoom >= 16) {
      markerVisualWidth = 28; // Tight clustering
    } else if (zoom >= 14) {
      markerVisualWidth = 38; // Standard clustering
    } else if (zoom >= 12) {
      markerVisualWidth = 50; // Moderate clustering
    } else {
      markerVisualWidth = 65; // Aggressive clustering at low zoom
    }

    // Convert to meters
    double clusterDistance = metersPerPixel * markerVisualWidth;

    // Minimum distance thresholds by zoom
    double minDistance;
    if (zoom >= 18) {
      minDistance = 4; // 4 meters at street level
    } else if (zoom >= 16) {
      minDistance = 8;
    } else if (zoom >= 14) {
      minDistance = 15;
    } else {
      minDistance = 25;
    }

    return math.max(clusterDistance, minDistance);
  }

  /// Filter locations to only those within viewport bounds
  static Map<LocationModel, MapMarkerData> _filterToViewport(
    Map<LocationModel, MapMarkerData> locations,
    LatLngBounds bounds,
  ) {
    // Add small padding to bounds to include edge markers
    final paddedBounds = _expandBounds(bounds, 0.1); // 10% padding

    return Map.fromEntries(
      locations.entries.where((entry) {
        final loc = entry.key;
        if (loc.lat == null || loc.lng == null) return false;
        return _isInBounds(loc.lat!, loc.lng!, paddedBounds);
      }),
    );
  }

  static LatLngBounds _expandBounds(LatLngBounds bounds, double factor) {
    final latDiff =
        (bounds.northeast.latitude - bounds.southwest.latitude) * factor;
    final lngDiff =
        (bounds.northeast.longitude - bounds.southwest.longitude) * factor;

    return LatLngBounds(
      southwest: LatLng(
        bounds.southwest.latitude - latDiff,
        bounds.southwest.longitude - lngDiff,
      ),
      northeast: LatLng(
        bounds.northeast.latitude + latDiff,
        bounds.northeast.longitude + lngDiff,
      ),
    );
  }

  static bool _isInBounds(double lat, double lng, LatLngBounds bounds) {
    final inLat =
        lat >= bounds.southwest.latitude && lat <= bounds.northeast.latitude;

    // Handle date line crossing
    final west = bounds.southwest.longitude;
    final east = bounds.northeast.longitude;
    final inLng = west <= east
        ? (lng >= west && lng <= east)
        : (lng >= west || lng <= east);

    return inLat && inLng;
  }

  /// Grid-based clustering algorithm - O(N) average case
  ///
  /// Divides the map into a grid where each cell is clusterDistance-sized.
  /// Only checks neighbors in adjacent cells, avoiding O(N²) pairwise checks.
  static Future<ClusteringResult> _gridBasedClustering({
    required Map<LocationModel, MapMarkerData> locationMarkers,
    required double clusterDistanceMeters,
    required double devicePixelRatio,
  }) async {
    final locations = locationMarkers.keys.toList();

    if (locations.isEmpty) {
      return ClusteringResult(
        markers: {},
        clusters: [],
        unclusteredLocationIds: {},
      );
    }

    // Calculate grid cell size in degrees (approximate)
    // 1 degree latitude ≈ 111,000 meters
    // 1 degree longitude varies with latitude, but we use average
    final cellSizeDegrees = clusterDistanceMeters / 111000.0;

    // Build spatial grid: cell key -> list of location indices
    final Map<String, List<int>> grid = {};

    for (int i = 0; i < locations.length; i++) {
      final loc = locations[i];
      if (loc.lat == null || loc.lng == null) continue;

      final cellKey = _getCellKey(loc.lat!, loc.lng!, cellSizeDegrees);
      grid.putIfAbsent(cellKey, () => []).add(i);
    }

    // Track which locations have been assigned to a cluster
    final Set<int> assignedIndices = {};
    final List<MarkerCluster> clusters = [];
    final Map<LocationModel, MapMarkerData> unclustered = {};
    final Set<int> unclusteredIds = {};

    // Process each location
    for (int i = 0; i < locations.length; i++) {
      if (assignedIndices.contains(i)) continue;

      final location = locations[i];
      if (location.lat == null || location.lng == null) continue;

      // Find all nearby locations using grid neighbors
      final nearbyIndices = _findNearbyInGrid(
        grid: grid,
        lat: location.lat!,
        lng: location.lng!,
        cellSizeDegrees: cellSizeDegrees,
        locations: locations,
        clusterDistanceMeters: clusterDistanceMeters,
        excludeIndices: assignedIndices,
        currentIndex: i,
      );

      if (nearbyIndices.length > 1) {
        // Create a cluster
        final clusterLocations =
            nearbyIndices.map((idx) => locations[idx]).toList();
        final center = _calculateCenter(clusterLocations);

        // Generate stable cluster ID based on sorted location IDs
        final sortedIds = nearbyIndices
            .map((idx) => locations[idx].locationId)
            .toList()
          ..sort();
        final clusterId = 'cluster_${sortedIds.first}_${sortedIds.length}';

        clusters.add(MarkerCluster(
          center: center,
          locations: clusterLocations,
          id: clusterId,
        ));

        // Mark all as assigned
        assignedIndices.addAll(nearbyIndices);
      } else {
        // Single marker - not clustered, add to unclustered list
        // We'll regenerate these with labels below
        unclusteredIds.add(location.locationId);
        assignedIndices.add(i);
      }
    }

    // Regenerate unclustered markers WITH labels showing
    // This ensures individual pins always have their names visible
    final List<LocationModel> unclusteredLocations = locations
        .where((loc) => unclusteredIds.contains(loc.locationId))
        .toList();

    for (final location in unclusteredLocations) {
      // Create marker with label visible (showText: true)
      final marker =
          await location.toMarker(devicePixelRatio, shouldShowName: true);
      if (marker != null) {
        unclustered[location] = marker;
      }
    }

    // Create cluster markers
    final Map<LocationModel, MapMarkerData> allMarkers = {...unclustered};

    for (final cluster in clusters) {
      final clusterMarker = await _createClusterMarker(
        cluster: cluster,
        devicePixelRatio: devicePixelRatio,
      );
      // Use first location as the key for the cluster
      allMarkers[cluster.locations.first] = clusterMarker;
    }

    return ClusteringResult(
      markers: allMarkers,
      clusters: clusters,
      unclusteredLocationIds: unclusteredIds,
    );
  }

  /// Get grid cell key for a coordinate
  static String _getCellKey(double lat, double lng, double cellSize) {
    final cellX = (lng / cellSize).floor();
    final cellY = (lat / cellSize).floor();
    return '$cellX,$cellY';
  }

  /// Find all locations near a point using grid-based lookup
  /// Only checks current cell and 8 adjacent cells (O(1) cells, O(k) locations per cell)
  static List<int> _findNearbyInGrid({
    required Map<String, List<int>> grid,
    required double lat,
    required double lng,
    required double cellSizeDegrees,
    required List<LocationModel> locations,
    required double clusterDistanceMeters,
    required Set<int> excludeIndices,
    required int currentIndex,
  }) {
    final List<int> nearby = [currentIndex];

    final centerCellX = (lng / cellSizeDegrees).floor();
    final centerCellY = (lat / cellSizeDegrees).floor();

    // Check current cell and all 8 neighbors
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        final cellKey = '${centerCellX + dx},${centerCellY + dy}';
        final cellLocations = grid[cellKey];
        if (cellLocations == null) continue;

        for (final idx in cellLocations) {
          if (idx == currentIndex) continue;
          if (excludeIndices.contains(idx)) continue;

          final other = locations[idx];
          if (other.lat == null || other.lng == null) continue;

          final distanceMeters =
              _haversineMeters(lat, lng, other.lat!, other.lng!);

          if (distanceMeters <= clusterDistanceMeters) {
            nearby.add(idx);
          }
        }
      }
    }

    return nearby;
  }

  /// Haversine formula returning distance in meters
  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadiusMeters = 6371000;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180);

  /// Calculate centroid of a list of locations
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

    if (count == 0) return const LatLng(0, 0);
    return LatLng(totalLat / count, totalLng / count);
  }

  /// Create a marker for a cluster
  static Future<MapMarkerData> _createClusterMarker({
    required MarkerCluster cluster,
    required double devicePixelRatio,
  }) async {
    final imageBytes = await PinitMarkers.createClusterMarker(
      count: cluster.count,
      devicePixelRatio: devicePixelRatio,
    );

    return MapMarkerData(
      id: cluster.id,
      position: cluster.center,
      imageBytes: imageBytes,
      title: '${cluster.count} locations',
    );
  }
}

import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart' show Color;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:login/models/locations.dart';
import 'package:login/models/markers.dart';
import 'package:login/utils/geo_types.dart';

/// Configuration for the GeoJSON map layers.
/// 
/// Allows customization of clustering behavior, icon sizes, and styling.
class GeoJsonLayerConfig {
  /// Source ID for the GeoJSON data
  final String sourceId;
  
  /// Whether to enable Mapbox native clustering
  final bool enableClustering;
  
  /// Clustering radius in pixels
  final int clusterRadius;
  
  /// Maximum zoom level at which clustering is applied
  final int clusterMaxZoom;
  
  /// Base icon size (will be adjusted for devicePixelRatio)
  final double iconSize;
  
  /// Text size for location names
  final double textSize;
  
  /// Whether to show text labels on pins
  final bool showTextLabels;
  
  /// Whether to allow text overlap (false enables collision detection)
  final bool allowTextOverlap;
  
  /// Whether to allow icon overlap
  final bool allowIconOverlap;

  const GeoJsonLayerConfig({
    this.sourceId = 'pinit-locations',
    this.enableClustering = true,
    this.clusterRadius = 30,
    this.clusterMaxZoom = 14,
    this.iconSize = 1.0,
    this.textSize = 11.0,
    this.showTextLabels = true,
    this.allowTextOverlap = false,
    this.allowIconOverlap = false,
  });
}

/// Callback type for location tap events
typedef OnLocationTapped = void Function(int locationId);

/// Callback type for cluster tap events
typedef OnClusterTapped = void Function(LatLng center, int pointCount);

/// Service for managing GeoJSON-based map layers with native Mapbox clustering.
/// 
/// This service replaces the manual PNG-rendering + PointAnnotation approach
/// with Mapbox's native GeoJSON source and Symbol layers, providing:
/// 
/// - **Native clustering**: Mapbox handles clustering automatically
/// - **Text collision detection**: Labels automatically hide when overlapping
/// - **Better performance**: No custom bitmap rendering per marker
/// - **Dynamic styling**: Change colors/sizes without re-rendering
/// 
/// ## Usage
/// 
/// ```dart
/// final service = GeoJsonMapLayerService(
///   mapboxMap: map,
///   config: const GeoJsonLayerConfig(),
///   onLocationTapped: (id) => print('Location $id tapped'),
///   onClusterTapped: (center, count) => print('Cluster with $count items'),
/// );
/// 
/// await service.initialize();
/// await service.updateLocations(locations);
/// ```
class GeoJsonMapLayerService {
  final mapbox.MapboxMap _map;
  final GeoJsonLayerConfig config;
  final OnLocationTapped? onLocationTapped;
  final OnClusterTapped? onClusterTapped;

  bool _isInitialized = false;
  String? _selectedLocationId;

  // Layer IDs
  static const String _clusterCircleLayerId = 'pinit-cluster-circles';
  static const String _clusterCountLayerId = 'pinit-cluster-count';
  static const String _unclusteredIconLayerId = 'pinit-unclustered-icons';
  static const String _unclusteredTextLayerId = 'pinit-unclustered-text';

  // Track registered emoji icons to avoid re-registering
  final Set<String> _registeredIconIds = {};
  
  // Icon ID prefixes
  static const String _iconPrefix = 'pinit-icon-';
  static const String _clusterIconPrefix = 'pinit-cluster-';

  GeoJsonMapLayerService({
    required mapbox.MapboxMap mapboxMap,
    this.config = const GeoJsonLayerConfig(),
    this.onLocationTapped,
    this.onClusterTapped,
  }) : _map = mapboxMap;

  /// Whether the service has been initialized
  bool get isInitialized => _isInitialized;

  /// The currently selected location ID
  String? get selectedLocationId => _selectedLocationId;

  /// Initialize the GeoJSON source and symbol layers.
  /// 
  /// Must be called after the map style has loaded.
  Future<void> initialize() async {
    if (_isInitialized) {
      log('GeoJsonMapLayerService: Already initialized');
      return;
    }

    try {
      // 1. Create the GeoJSON source with clustering
      await _createGeoJsonSource();

      // 2. Add a fallback icon (will be replaced by emoji-specific icons)
      await _addFallbackIcon();

      // 3. Add layers (order matters - clusters first, then individual points)
      await _addClusterLayers();
      await _addUnclusteredLayers();

      // 4. Set up click handlers
      await _setupClickHandlers();

      _isInitialized = true;
      log('GeoJsonMapLayerService: Initialized successfully');
    } catch (e, stack) {
      log('GeoJsonMapLayerService: Initialization failed: $e\n$stack');
      rethrow;
    }
  }

  /// Update the locations displayed on the map.
  /// 
  /// Converts [locations] to GeoJSON and updates the source.
  /// Mapbox will automatically handle clustering.
  Future<void> updateLocations(List<LocationModel> locations) async {
    if (!_isInitialized) {
      log('GeoJsonMapLayerService: Not initialized, cannot update locations');
      return;
    }

    try {
      // Register icons for all unique emoji+color combinations (both regular and cluster)
      await _registerEmojiIcons(locations);
      await _registerClusterIcons(locations);

      final geoJson = _locationsToGeoJson(locations);
      final geoJsonString = jsonEncode(geoJson);
      
      await _map.style.setStyleSourceProperty(
        config.sourceId,
        'data',
        geoJsonString,
      );
      
      log('GeoJsonMapLayerService: Updated ${locations.length} locations');
    } catch (e) {
      log('GeoJsonMapLayerService: Failed to update locations: $e');
      rethrow;
    }
  }

  /// Set the selected location (for highlighting).
  /// 
  /// Pass null to clear selection.
  void setSelectedLocation(String? locationId) {
    if (_selectedLocationId != locationId) {
      _selectedLocationId = locationId;
      // Note: To implement visual selection, you'd use feature-state
      // or filter the layer to show a different icon for selected items
      log('GeoJsonMapLayerService: Selected location: $locationId');
    }
  }

  /// Clean up resources when the service is no longer needed.
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      // Remove layers (reverse order of addition)
      await _safeRemoveLayer(_unclusteredTextLayerId);
      await _safeRemoveLayer(_unclusteredIconLayerId);
      await _safeRemoveLayer(_clusterCountLayerId);
      await _safeRemoveLayer(_clusterCircleLayerId);

      // Remove source
      await _map.style.removeStyleSource(config.sourceId);

      // Remove all registered icons
      for (final iconId in _registeredIconIds) {
        try {
          await _map.style.removeStyleImage(iconId);
        } catch (_) {
          // Icon may not exist
        }
      }
      _registeredIconIds.clear();

      _isInitialized = false;
      log('GeoJsonMapLayerService: Disposed');
    } catch (e) {
      log('GeoJsonMapLayerService: Error during dispose: $e');
    }
  }

  // ============ Private Implementation ============

  /// Create the GeoJSON source with clustering configuration.
  Future<void> _createGeoJsonSource() async {
    final emptyGeoJson = jsonEncode({
      'type': 'FeatureCollection',
      'features': <Map<String, dynamic>>[],
    });

    // Using raw properties since mapbox_maps_flutter may not expose all options
    // clusterProperties pass representative emoji/color to clusters for badge rendering
    await _map.style.addStyleSource(
      config.sourceId,
      jsonEncode({
        'type': 'geojson',
        'data': jsonDecode(emptyGeoJson),
        'cluster': config.enableClustering,
        'clusterRadius': config.clusterRadius,
        'clusterMaxZoom': config.clusterMaxZoom,
        // Pass first emoji and color to clusters for representative pin rendering
        'clusterProperties': {
          // Use 'any' aggregation to get a representative emoji (not perfect "best", but works)
          'clusterEmoji': [['coalesce', ['accumulated'], ['get', 'emoji']], ['get', 'emoji']],
          'clusterColorHex': [['coalesce', ['accumulated'], ['get', 'colorHex']], ['get', 'colorHex']],
        },
      }),
    );

    log('GeoJsonMapLayerService: GeoJSON source created with clustering=${config.enableClustering}');
  }

  /// Add a fallback icon for locations without a registered emoji icon.
  Future<void> _addFallbackIcon() async {
    const fallbackIconId = '${_iconPrefix}fallback';
    if (_registeredIconIds.contains(fallbackIconId)) return;

    final iconBytes = await PinitMarkers.createPinitMarker(
      emoji: '📍',
      name: '',
      devicePixelRatio: 3.0,
      showText: false,
    );

    final image = mapbox.MbxImage(
      width: 90, // estimated from 22 * 3 + padding + shadow
      height: 90,
      data: iconBytes,
    );

    await _map.style.addStyleImage(
      fallbackIconId,
      3.0, // devicePixelRatio
      image,
      false, // SDF
      [], // Stretch X
      [], // Stretch Y
      null, // Content
    );

    _registeredIconIds.add(fallbackIconId);
    log('GeoJsonMapLayerService: Fallback icon added');
  }

  /// Register icons for all unique emoji+color combinations in the locations.
  Future<void> _registerEmojiIcons(List<LocationModel> locations) async {
    // Collect unique emoji+color combinations
    final iconKeys = <String>{};
    final iconData = <String, ({String emoji, Color color})>{};

    for (final location in locations) {
      final emoji = location.emoji ?? '📍';
      final color = PinitMarkerPalette.forCuisine(
        location.cuisine,
        location.types,
      );
      final colorHex = color.value.toRadixString(16).substring(2).toUpperCase();
      final iconId = '$_iconPrefix$emoji-$colorHex';

      if (!_registeredIconIds.contains(iconId)) {
        iconKeys.add(iconId);
        iconData[iconId] = (emoji: emoji, color: color);
      }
    }

    if (iconKeys.isEmpty) return;

    log('GeoJsonMapLayerService: Registering ${iconKeys.length} new emoji icons');

    // Register each new icon
    for (final iconId in iconKeys) {
      final data = iconData[iconId]!;
      try {
        final iconBytes = await PinitMarkers.createPinitMarker(
          emoji: data.emoji,
          name: '',
          devicePixelRatio: 3.0,
          surfaceColor: data.color,
          showText: false,
        );

        final image = mapbox.MbxImage(
          width: 90, // estimated dimensions
          height: 90,
          data: iconBytes,
        );

        await _map.style.addStyleImage(
          iconId,
          3.0, // devicePixelRatio
          image,
          false, // SDF
          [], // Stretch X
          [], // Stretch Y
          null, // Content
        );

        _registeredIconIds.add(iconId);
      } catch (e) {
        log('GeoJsonMapLayerService: Failed to register icon $iconId: $e');
      }
    }
  }

  /// Register cluster icons with stacked effect for unique emoji+color combinations.
  /// Creates icons for different cluster size buckets (small, medium, large).
  Future<void> _registerClusterIcons(List<LocationModel> locations) async {
    // Collect unique emoji+color combinations
    final iconData = <String, ({String emoji, Color color})>{};

    for (final location in locations) {
      final emoji = location.emoji ?? '📍';
      final color = PinitMarkerPalette.forCuisine(
        location.cuisine,
        location.types,
      );
      final colorHex = color.value.toRadixString(16).substring(2).toUpperCase();
      final baseKey = '$emoji-$colorHex';

      if (!iconData.containsKey(baseKey)) {
        iconData[baseKey] = (emoji: emoji, color: color);
      }
    }

    if (iconData.isEmpty) return;

    // Create cluster icons for stack counts: 1, 2, 3 (visual depth levels)
    // Mapbox will select based on point_count via step expression
    final stackLevels = [
      (name: 'small', stackCount: 1),   // 2-4 points: 1 stacked circle
      (name: 'medium', stackCount: 2),  // 5-9 points: 2 stacked circles
      (name: 'large', stackCount: 3),   // 10+ points: 3 stacked circles
    ];

    int registered = 0;
    for (final entry in iconData.entries) {
      final data = entry.value;

      for (final level in stackLevels) {
        final iconId = '$_clusterIconPrefix${entry.key}-${level.name}';
        if (_registeredIconIds.contains(iconId)) continue;

        try {
          // Use stacked cluster pin (NO badge - badge rendered by text layer)
          final iconBytes = await PinitMarkers.createClusterPinWithBadge(
            emoji: data.emoji,
            remainingCount: level.stackCount,
            devicePixelRatio: 3.0,
            surfaceColor: data.color,
          );

          final image = mapbox.MbxImage(
            width: 120, // Larger to accommodate stacked circles
            height: 120,
            data: iconBytes,
          );

          await _map.style.addStyleImage(
            iconId,
            3.0, // devicePixelRatio
            image,
            false, // SDF
            [], // Stretch X
            [], // Stretch Y
            null, // Content
          );

          _registeredIconIds.add(iconId);
          registered++;
        } catch (e) {
          log('GeoJsonMapLayerService: Failed to register cluster icon $iconId: $e');
        }
      }
    }

    if (registered > 0) {
      log('GeoJsonMapLayerService: Registered $registered cluster icons');
    }
  }

  /// Add cluster layers with stacked effect and badge.
  /// Clusters show as pins with stacked circles behind + "+N" badge.
  Future<void> _addClusterLayers() async {
    // Cluster pin icon layer - shows stacked circles with representative emoji
    await _map.style.addStyleLayer(
      jsonEncode({
        'id': _clusterCircleLayerId, // Reusing ID for backward compat
        'type': 'symbol',
        'source': config.sourceId,
        'filter': ['has', 'point_count'],
        'layout': {
          // Select cluster icon based on count bucket (small/medium/large)
          'icon-image': [
            'step',
            ['get', 'point_count'],
            // Default for count 2-4 (small bucket)
            ['concat', '$_clusterIconPrefix', ['get', 'clusterEmoji'], '-', ['get', 'clusterColorHex'], '-small'],
            5,
            // Count 5-9 (medium bucket)
            ['concat', '$_clusterIconPrefix', ['get', 'clusterEmoji'], '-', ['get', 'clusterColorHex'], '-medium'],
            10,
            // Count 10+ (large bucket)
            ['concat', '$_clusterIconPrefix', ['get', 'clusterEmoji'], '-', ['get', 'clusterColorHex'], '-large'],
          ],
          'icon-size': config.iconSize,
          'icon-anchor': 'center',
          'icon-allow-overlap': true, // Clusters should always show
        },
      }),
      null,
    );

    // Small badge overlay showing "+N" count
    // Positioned at top-right of the cluster pin
    await _map.style.addStyleLayer(
      jsonEncode({
        'id': _clusterCountLayerId,
        'type': 'symbol',
        'source': config.sourceId,
        'filter': ['has', 'point_count'],
        'layout': {
          // Format as "+N" badge
          'text-field': [
            'concat',
            '+',
            ['case',
              ['>', ['get', 'point_count'], 99], '99',
              // Show remaining count (total - 1, since one pin is "shown")
              ['to-string', ['-', ['get', 'point_count'], 1]],
            ],
          ],
          'text-font': ['Open Sans Bold', 'Arial Unicode MS Bold'],
          'text-size': 9,
          'text-anchor': 'center',
          // Position badge at top-right of pin
          'text-offset': [0.8, -0.9],
          'text-allow-overlap': true,
        },
        'paint': {
          'text-color': '#ffffff',
          // Dark purple badge background via halo
          'text-halo-color': 'rgba(66, 20, 61, 0.85)',
          'text-halo-width': 4,
          'text-halo-blur': 0,
        },
      }),
      null,
    );

    log('GeoJsonMapLayerService: Cluster layers added (badge style)');
  }

  /// Add layers for individual (unclustered) points.
  Future<void> _addUnclusteredLayers() async {
    // Combined icon + text layer for unclustered points
    // Having both in the same layer ensures proper collision detection
    final layoutProps = <String, dynamic>{
      // Dynamic icon selection: 'pinit-icon-{emoji}-{colorHex}'
      // Falls back to 'pinit-icon-fallback' if icon not found
      'icon-image': [
        'coalesce',
        ['concat', '$_iconPrefix', ['get', 'emoji'], '-', ['get', 'colorHex']],
        '${_iconPrefix}fallback',
      ],
      'icon-size': config.iconSize,
      'icon-anchor': 'center',
      'icon-allow-overlap': config.allowIconOverlap,
      // Visual priority based on saved count
      'symbol-sort-key': ['get', 'savedCount'],
    };

    // Add text properties if enabled
    if (config.showTextLabels) {
      layoutProps.addAll({
        'text-field': ['get', 'name'],
        'text-font': ['Open Sans Semibold', 'Arial Unicode MS Bold'],
        'text-size': config.textSize,
        'text-anchor': 'left',
        'text-offset': [2.0, 0], // Offset from icon center in ems
        'text-max-width': 8, // Max width in ems
        'text-allow-overlap': config.allowTextOverlap,
        'text-optional': true, // Hide text on collision, keep icon
        'icon-text-fit': 'none', // Don't resize icon to fit text
      });
    }

    await _map.style.addStyleLayer(
      jsonEncode({
        'id': _unclusteredIconLayerId,
        'type': 'symbol',
        'source': config.sourceId,
        'filter': ['!', ['has', 'point_count']],
        'layout': layoutProps,
        'paint': config.showTextLabels
            ? {
                'text-color': '#1A1A2E',
                'text-halo-color': '#ffffff',
                'text-halo-width': 1.5,
              }
            : <String, dynamic>{},
      }),
      null,
    );

    log('GeoJsonMapLayerService: Unclustered layer added (combined icon+text)');
  }

  /// Set up tap handlers for clusters and individual locations.
  Future<void> _setupClickHandlers() async {
    // Note: Click handling for GeoJSON layers requires querying features at tap location.
    // This is done via the onTapListener in the MapWidget, which calls queryRenderedFeatures.
    // The actual tap handling is delegated to callbacks passed during construction.
    // 
    // For now, we rely on the map widget's tap listener to call our query methods.
    // This service exposes queryFeaturesAtPoint for the map widget to use.
    
    log('GeoJsonMapLayerService: Click handlers configured (via queryFeaturesAtPoint)');
  }

  /// Query features at a screen point and dispatch to appropriate callback.
  /// 
  /// This should be called from the map widget's tap listener.
  Future<void> handleTapAtPoint(double x, double y) async {
    // Tap tolerance in screen pixels (helps with finger taps)
    const double tapTolerance = 22.0;
    
    try {
      log('GeoJsonMapLayerService: Querying features at ($x, $y)');
      
      // Create a bounding box around the tap point for better hit detection
      final screenBox = mapbox.ScreenBox(
        min: mapbox.ScreenCoordinate(x: x - tapTolerance, y: y - tapTolerance),
        max: mapbox.ScreenCoordinate(x: x + tapTolerance, y: y + tapTolerance),
      );

      // Query for clusters first (they should take priority)
      final clusterFeatures = await _map.queryRenderedFeatures(
        mapbox.RenderedQueryGeometry.fromScreenBox(screenBox),
        mapbox.RenderedQueryOptions(
          layerIds: [_clusterCircleLayerId],
        ),
      );

      log('GeoJsonMapLayerService: Found ${clusterFeatures.length} cluster features');

      if (clusterFeatures.isNotEmpty) {
        final feature = clusterFeatures.first;
        if (feature != null) {
          final featureData = feature.queriedFeature.feature;
          
          // Convert feature to Map<String, dynamic> (may be Map<String?, Object?>)
          final Map<String, dynamic> featureJson = _convertToStringDynamicMap(featureData);
          
          final geometry = featureJson['geometry'];
          if (geometry is Map) {
            final geoMap = _convertToStringDynamicMap(geometry);
            if (geoMap['type'] == 'Point') {
              final coords = geoMap['coordinates'] as List?;
              if (coords != null && coords.length >= 2) {
                final lng = (coords[0] as num).toDouble();
                final lat = (coords[1] as num).toDouble();
                final center = LatLng(lat, lng);
                
                final properties = featureJson['properties'];
                final propsMap = properties is Map ? _convertToStringDynamicMap(properties) : <String, dynamic>{};
                final pointCount = propsMap['point_count'] as int? ?? 0;
                
                log('GeoJsonMapLayerService: Cluster tapped with $pointCount points');
                onClusterTapped?.call(center, pointCount);
                return;
              }
            }
          }
        }
      }

      // Query for individual (unclustered) points
      final pointFeatures = await _map.queryRenderedFeatures(
        mapbox.RenderedQueryGeometry.fromScreenBox(screenBox),
        mapbox.RenderedQueryOptions(
          layerIds: [_unclusteredIconLayerId],
        ),
      );

      log('GeoJsonMapLayerService: Found ${pointFeatures.length} point features');

      if (pointFeatures.isNotEmpty) {
        final feature = pointFeatures.first;
        if (feature != null) {
          final featureData = feature.queriedFeature.feature;
          
          // Convert feature to Map<String, dynamic>
          final Map<String, dynamic> featureJson = _convertToStringDynamicMap(featureData);
          
          final properties = featureJson['properties'];
          final propsMap = properties is Map ? _convertToStringDynamicMap(properties) : <String, dynamic>{};
          log('GeoJsonMapLayerService: Point properties: $propsMap');
          
          final locationId = propsMap['locationId'];
          if (locationId != null) {
            log('GeoJsonMapLayerService: Location tapped: $locationId');
            onLocationTapped?.call(locationId as int);
            return;
          }
        }
      }
      
      log('GeoJsonMapLayerService: No features found at tap location');
    } catch (e, stack) {
      log('GeoJsonMapLayerService: Error querying features: $e\n$stack');
    }
  }

  /// Convert LocationModel list to GeoJSON FeatureCollection.
  Map<String, dynamic> _locationsToGeoJson(List<LocationModel> locations) {
    final features = <Map<String, dynamic>>[];

    for (final location in locations) {
      if (location.lat == null || location.lng == null) continue;

      // Determine color based on cuisine/type
      final color = PinitMarkerPalette.forCuisine(
        location.cuisine,
        location.types,
      );

      // Store colorHex without '#' for icon lookup
      final colorHex = color.value.toRadixString(16).substring(2).toUpperCase();

      features.add({
        'type': 'Feature',
        'properties': {
          'locationId': location.locationId,
          'name': location.name,
          'emoji': location.emoji ?? '📍',
          'cuisine': location.cuisine,
          'types': location.types,
          'rating': location.rating,
          'savedCount': location.savedCount ?? 0,
          'priceLevel': location.priceLevel,
          // Color as hex string (no '#') for icon-image expression
          'colorHex': colorHex,
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [location.lng, location.lat], // GeoJSON is [lng, lat]
        },
      });
    }

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  /// Safely remove a layer, ignoring errors if it doesn't exist.
  Future<void> _safeRemoveLayer(String layerId) async {
    try {
      await _map.style.removeStyleLayer(layerId);
    } catch (_) {
      // Layer may not exist
    }
  }

  /// Convert a Map with nullable keys to Map<String, dynamic>.
  /// Handles Map<String?, Object?> from Mapbox SDK.
  Map<String, dynamic> _convertToStringDynamicMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key?.toString() ?? '', value));
    }
    return <String, dynamic>{};
  }
}

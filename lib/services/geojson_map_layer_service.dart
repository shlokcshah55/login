import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color, Curves;
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

  /// Clustering radius in screen pixels.
  ///
  /// Higher values make clustering more eager once the user is zoomed out
  /// enough for clustering to be active.
  final int clusterRadius;

  /// Maximum zoom level at which clustering is applied.
  ///
  /// Above this zoom, pins always stay individual even if they are close.
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

  /// Switch visible markers to compact dots once the viewport gets dense.
  final int denseMarkerThreshold;

  const GeoJsonLayerConfig({
    this.sourceId = 'pinit-locations',
    this.enableClustering = true,
    this.clusterRadius = 34,
    this.clusterMaxZoom = 12,
    this.iconSize = 1.0,
    this.textSize = 11.0,
    this.showTextLabels = true,
    this.allowTextOverlap = false,
    this.allowIconOverlap = true,
    this.denseMarkerThreshold = 15,
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
  List<LocationModel>? _pendingLocations;
  List<LocationModel> _currentLocations = const [];
  Set<int> _beenToLocationIds = const <int>{};
  Set<int> _compactLocationIds = const <int>{};
  Set<int> _presentationVisibleLocationIds = const <int>{};
  Set<int> _presentationExpandedLocationIds = const <int>{};
  bool _presentationDefaultsVisibleToCompact = false;
  ui.Rect? _usableScreenRect;
  final Map<int, double> _compactFadeByLocationId = {};
  final Map<int, int> _bouncePhaseByLocationId = {};
  final Map<int, double> _bounceScaleByLocationId = {};
  final Map<int, Timer> _bounceTimersByLocationId = {};
  final Set<int> _pendingRecentSaveIds = {};
  Timer? _compactFadeTimer;
  bool _sourceUpdateInFlight = false;
  bool _sourceUpdateQueued = false;

  // Layer IDs
  static const String _clusterCircleLayerId = 'pinit-cluster-circles';
  static const String _compactDotLayerId = 'pinit-compact-dots';
  static const String _unclusteredIconLayerId = 'pinit-unclustered-icons';
  static const String _unclusteredTextLayerId = 'pinit-unclustered-text';
  static const String _compactDotIconId = '${_iconPrefix}compact-dot';
  static const String _compactDotBeenToIconId =
      '${_iconPrefix}compact-dot-been-to';

  // Track registered emoji icons to avoid re-registering
  final Set<String> _registeredIconIds = {};

  // Icon ID prefixes
  static const String _iconPrefix = 'pinit-icon-';
  static const String _clusterIconPrefix = 'pinit-cluster-';
  static const Duration _bounceDuration = Duration(milliseconds: 1120);
  static const Duration _bounceFrameInterval = Duration(milliseconds: 16);
  static const Duration _compactFadeDuration = Duration(milliseconds: 220);
  static const Duration _compactFadeFrameInterval = Duration(milliseconds: 16);
  static const List<double> _bounceScaleStops = [1.0, 1.45, 1.0, 1.18, 1.0];
  static const List<int> _clusterIconPointCounts = [2, 3, 4, 5];
  static const int _segmentRows = 2;
  static const int _segmentColumns = 3;
  static const int _segmentDenseEnterThreshold = 3;
  static const int _segmentDenseExitThreshold = 2;
  static const int _segmentExpandedPinCount = 2;
  static const int _segmentStickyPinCount = 3;
  static const double _criticalOverlapEnterRatio = 0.50;
  static const double _criticalOverlapExitRatio = 0.38;
  static const double _criticalOverlapStickyRatio = 0.72;
  static const double _viewportVerticalOverscanFactor = 0.18;
  static const double _viewportMinVerticalOverscan = 44.0;
  static const double _densePinWidth = 52.0;
  static const double _densePinHeight = 58.0;
  static const double _denseSelectedPinWidth = 82.0;
  static const double _denseSelectedPinHeight = 90.0;

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
  /// Any locations that arrived before initialization will be flushed after setup completes.
  Future<void> initialize() async {
    if (_isInitialized) {
      log('GeoJsonMapLayerService: Already initialized');
      return;
    }

    try {
      // 1. Create the GeoJSON source with clustering
      await _createGeoJsonSource();

      // 2. Add fallback assets used by the marker layer
      await _addFallbackIcon();
      await _addCompactDotIcons();

      // 3. Add layers (order matters - clusters first, then individual points)
      await _addClusterLayers();
      await _addUnclusteredLayers();

      // 4. Set up click handlers
      await _setupClickHandlers();

      _isInitialized = true;
      log('GeoJsonMapLayerService: Initialized successfully');

      // Flush any locations that arrived before initialization completed
      if (_pendingLocations != null) {
        log('GeoJsonMapLayerService: Flushing ${_pendingLocations!.length} buffered locations');
        final pending = _pendingLocations!;
        _pendingLocations = null;
        await _applyLocations(
          pending,
          beenToLocationIds: _beenToLocationIds,
        );
      }
    } catch (e, stack) {
      log('GeoJsonMapLayerService: Initialization failed: $e\n$stack');
      rethrow;
    }
  }

  /// Update the locations displayed on the map.
  ///
  /// If initialization hasn't completed yet, locations are buffered and will be
  /// applied once initialize() completes. Otherwise, updates are applied immediately.
  /// Mapbox will automatically handle clustering.
  Future<void> updateLocations(
    List<LocationModel> locations, {
    Set<int> beenToLocationIds = const <int>{},
  }) async {
    if (!_isInitialized) {
      log('GeoJsonMapLayerService: Buffering ${locations.length} locations until initialized');
      _pendingLocations = locations;
      _beenToLocationIds = Set<int>.from(beenToLocationIds);
      return;
    }

    await _applyLocations(
      locations,
      beenToLocationIds: beenToLocationIds,
    );
  }

  /// Apply locations to the map immediately.
  ///
  /// Registers icons and updates the GeoJSON source with the provided locations.
  /// Should only be called after initialize() completes.
  Future<void> _applyLocations(
    List<LocationModel> locations, {
    Set<int> beenToLocationIds = const <int>{},
  }) async {
    try {
      _currentLocations = List<LocationModel>.from(locations);
      _beenToLocationIds = Set<int>.from(beenToLocationIds);
      _pruneBounceStateForCurrentLocations();

      // Register icons for all unique emoji+color combinations (both regular and cluster)
      await _registerEmojiIcons(locations);
      await _registerClusterIcons(locations);
      await _refreshViewportPresentation(
        isInteracting: false,
        updateSource: false,
      );
      await _updateSourceData();
      _flushPendingRecentSaveBounces();

      log('GeoJsonMapLayerService: Applied ${locations.length} locations');
    } catch (e) {
      log('GeoJsonMapLayerService: Failed to apply locations: $e');
      rethrow;
    }
  }

  /// Set the selected location (for highlighting).
  ///
  /// Pass null to clear selection.
  void setSelectedLocation(String? locationId) {
    if (_selectedLocationId != locationId) {
      _selectedLocationId = locationId;
      log('GeoJsonMapLayerService: Selected location: $locationId');
      if (_isInitialized) {
        unawaited(_registerEmojiIcons(_currentLocations));
        unawaited(_updateSourceData());
      }
    }
  }

  /// Triggers a springy save bounce for a location that is currently visible.
  ///
  /// If the location is not in the active source data yet, the request is
  /// queued and replayed after the next location update that contains it.
  void markLocationAsRecentlySaved(int locationId) {
    final isVisible = _currentLocations.any(
      (location) => location.locationId == locationId,
    );

    if (!_isInitialized || !isVisible) {
      _pendingRecentSaveIds.add(locationId);
      return;
    }

    _pendingRecentSaveIds.remove(locationId);
    _bounceTimersByLocationId[locationId]?.cancel();

    final stopwatch = Stopwatch()..start();
    _bouncePhaseByLocationId[locationId] = 1;
    _bounceScaleByLocationId[locationId] = 1.0;
    unawaited(_updateSourceData());

    _bounceTimersByLocationId[locationId] = Timer.periodic(
      _bounceFrameInterval,
      (timer) {
        final progress =
            (stopwatch.elapsedMilliseconds / _bounceDuration.inMilliseconds)
                .clamp(0.0, 1.0);

        if (progress >= 1.0) {
          timer.cancel();
          _bounceTimersByLocationId.remove(locationId);
          _bouncePhaseByLocationId[locationId] = 0;
          _bounceScaleByLocationId[locationId] = 1.0;
          unawaited(_updateSourceData());
          return;
        }

        _bouncePhaseByLocationId[locationId] =
            _bouncePhaseForProgress(progress);
        _bounceScaleByLocationId[locationId] =
            _bounceScaleForProgress(progress);
        unawaited(_updateSourceData());
      },
    );
  }

  void pulseLocation(int locationId) {
    markLocationAsRecentlySaved(locationId);
  }

  Future<void> updateViewportPresentation({
    LatLngBounds? visibleBounds,
    ui.Rect? usableScreenRect,
    required bool isInteracting,
  }) async {
    if (usableScreenRect != null) {
      _usableScreenRect = usableScreenRect;
    }
    await _refreshViewportPresentation(
      visibleBounds: visibleBounds,
      usableScreenRect: usableScreenRect,
      isInteracting: isInteracting,
      updateSource: true,
    );
  }

  /// Clean up resources when the service is no longer needed.
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      for (final timer in _bounceTimersByLocationId.values) {
        timer.cancel();
      }
      _bounceTimersByLocationId.clear();
      _bouncePhaseByLocationId.clear();
      _bounceScaleByLocationId.clear();
      _pendingRecentSaveIds.clear();
      _compactFadeTimer?.cancel();
      _compactFadeTimer = null;
      _compactFadeByLocationId.clear();
      _compactLocationIds = const <int>{};
      _beenToLocationIds = const <int>{};
      _presentationVisibleLocationIds = const <int>{};
      _presentationExpandedLocationIds = const <int>{};
      _presentationDefaultsVisibleToCompact = false;
      _usableScreenRect = null;

      // Remove layers (reverse order of addition)
      await _safeRemoveLayer(_unclusteredTextLayerId);
      await _safeRemoveLayer(_unclusteredIconLayerId);
      await _safeRemoveLayer(_compactDotLayerId);
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

    final source = <String, dynamic>{
      'type': 'geojson',
      'data': jsonDecode(emptyGeoJson),
      'cluster': config.enableClustering,
    };

    if (config.enableClustering) {
      source.addAll({
        'clusterRadius': config.clusterRadius,
        'clusterMaxZoom': config.clusterMaxZoom,
        'clusterProperties': {
          'clusterVisualKey': [
            [
              'coalesce',
              ['accumulated'],
              ['get', 'markerVisualKey']
            ],
            ['get', 'markerVisualKey']
          ],
          'clusterColorHex': [
            [
              'coalesce',
              ['accumulated'],
              ['get', 'colorHex']
            ],
            ['get', 'colorHex']
          ],
          'clusterBeenToCount': [
            [
              '+',
              ['accumulated'],
              ['get', 'beenToClusterFlag']
            ],
            ['get', 'beenToClusterFlag']
          ],
        },
      });
    }

    await _map.style.addStyleSource(
      config.sourceId,
      jsonEncode(source),
    );

    log('GeoJsonMapLayerService: GeoJSON source created with clustering=${config.enableClustering}');
  }

  /// Add a fallback icon for locations without a registered emoji icon.
  Future<void> _addFallbackIcon() async {
    const fallbackIconId = '${_iconPrefix}fallback';
    if (_registeredIconIds.contains(fallbackIconId)) return;

    final iconBytes = await PinitMarkers.createPinitMarker(
      name: '',
      devicePixelRatio: 3.0,
      showText: false,
      fallbackSeed: 0,
    );

    final image = await _createMapboxImage(iconBytes);

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

  Future<void> _addCompactDotIcons() async {
    final compactDotIcons = <({String id, bool hasBeenTo})>[
      (id: _compactDotIconId, hasBeenTo: false),
      (id: _compactDotBeenToIconId, hasBeenTo: true),
    ];

    for (final compactDotIcon in compactDotIcons) {
      if (_registeredIconIds.contains(compactDotIcon.id)) continue;

      final iconBytes = await PinitMarkers.createCompactMapDot(
        devicePixelRatio: 3.0,
        hasBeenTo: compactDotIcon.hasBeenTo,
      );
      final image = await _createMapboxImage(iconBytes);

      await _map.style.addStyleImage(
        compactDotIcon.id,
        3.0,
        image,
        false,
        [],
        [],
        null,
      );

      _registeredIconIds.add(compactDotIcon.id);
    }

    log('GeoJsonMapLayerService: Compact dot icons added');
  }

  /// Register icons for all unique marker-visual/color combinations in the locations.
  Future<void> _registerEmojiIcons(List<LocationModel> locations) async {
    final iconKeys = <String>{};
    final iconData = <String,
        ({
      String? emoji,
      double? rating,
      bool selected,
      double wavyScore,
      double bossmanScore,
      int savedCount,
      double matchScore,
      String? badgeType,
      List<double>? vibeVector,
      int fallbackSeed,
    })>{};

    for (final location in locations) {
      final iconId = '$_iconPrefix${_buildLocationIconKey(location)}';

      if (!_registeredIconIds.contains(iconId)) {
        iconKeys.add(iconId);
        iconData[iconId] = (
          emoji: location.emoji,
          rating: location.rating,
          selected: _selectedLocationId == location.locationId.toString(),
          wavyScore: location.vibe?.wavyScore ?? 0.0,
          bossmanScore: location.vibe?.bossmanScore ?? 0.0,
          savedCount: location.savedCount ?? 0,
          matchScore: location.matchScore ?? 0.0,
          badgeType: location.markerBadgeType,
          vibeVector: location.vibeVector,
          fallbackSeed: location.locationId,
        );
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
          selected: data.selected,
          showText: false,
          wavyScore: data.wavyScore,
          bossmanScore: data.bossmanScore,
          savedCount: data.savedCount,
          matchScore: data.matchScore,
          badgeType: data.badgeType,
          rating: data.rating,
          vibeVector: data.vibeVector,
          fallbackSeed: data.fallbackSeed,
        );

        final image = await _createMapboxImage(iconBytes);

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

  /// Register cluster icons for unique marker-visual/color combinations.
  Future<void> _registerClusterIcons(List<LocationModel> locations) async {
    if (!config.enableClustering) return;

    // Collect unique visual+color combinations
    final iconData = <String,
        ({
      String visualKey,
      String? emoji,
      double? rating,
      List<double>? vibeVector,
      int fallbackSeed,
      String? cuisine,
      String? types,
      double wavyScore,
      double bossmanScore,
      int savedCount
    })>{};

    for (final location in locations) {
      final shadowStyle = PinitMarkers.markerShadowStyle(
        rating: location.rating,
        wavyScore: location.vibe?.wavyScore ?? 0.0,
        bossmanScore: location.vibe?.bossmanScore ?? 0.0,
        savedCount: location.savedCount ?? 0,
        cuisine: location.cuisine,
        types: location.types,
      );
      final colorHex = _colorHex(shadowStyle.color);
      final visualKey = PinitMarkers.markerVisualKey(
        emoji: location.emoji,
        vibeVector: location.vibeVector,
        fallbackSeed: location.locationId,
      );
      final baseKey = '$visualKey-$colorHex';

      if (!iconData.containsKey(baseKey)) {
        iconData[baseKey] = (
          visualKey: visualKey,
          emoji: location.emoji,
          rating: location.rating,
          vibeVector: location.vibeVector,
          fallbackSeed: location.locationId,
          cuisine: location.cuisine,
          types: location.types,
          wavyScore: location.vibe?.wavyScore ?? 0.0,
          bossmanScore: location.vibe?.bossmanScore ?? 0.0,
          savedCount: location.savedCount ?? 0,
        );
      }
    }

    if (iconData.isEmpty) return;

    int registered = 0;
    for (final entry in iconData.entries) {
      final data = entry.value;
      for (final pointCount in _clusterIconPointCounts) {
        for (final hasBeenTo in const [false, true]) {
          final visitedKey = hasBeenTo ? 'been' : 'default';
          final iconId =
              '$_clusterIconPrefix${entry.key}-$visitedKey-${_clusterOverflowTierKey(pointCount)}';
          if (_registeredIconIds.contains(iconId)) continue;

          try {
            final iconBytes = await PinitMarkers.createClusterPinWithBadge(
              emoji: data.emoji,
              pointCount: pointCount,
              avatarColors: [],
              rating: data.rating,
              cuisine: data.cuisine,
              types: data.types,
              wavyScore: data.wavyScore,
              bossmanScore: data.bossmanScore,
              savedCount: data.savedCount,
              vibeVector: data.vibeVector,
              fallbackSeed: data.fallbackSeed,
              hasBeenTo: hasBeenTo,
            );

            final image = await _createMapboxImage(iconBytes);

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
    }

    if (registered > 0) {
      log('GeoJsonMapLayerService: Registered $registered cluster icons');
    }
  }

  /// Add the cluster layer.
  Future<void> _addClusterLayers() async {
    if (!config.enableClustering) return;

    await _map.style.addStyleLayer(
      jsonEncode({
        'id': _clusterCircleLayerId, // Reusing ID for backward compat
        'type': 'symbol',
        'source': config.sourceId,
        'filter': ['has', 'point_count'],
        'layout': {
          'icon-image': [
            'concat',
            '$_clusterIconPrefix',
            ['get', 'clusterVisualKey'],
            '-',
            ['get', 'clusterColorHex'],
            '-',
            [
              'case',
              [
                '>',
                [
                  'coalesce',
                  ['get', 'clusterBeenToCount'],
                  0
                ],
                0
              ],
              'been',
              'default',
            ],
            '-',
            [
              'step',
              ['get', 'point_count'],
              'dots0',
              3,
              'dots1',
              4,
              'dots2',
              5,
              'dots3',
            ],
          ],
          'icon-size': config.iconSize,
          'icon-anchor': 'center',
          'icon-allow-overlap': true, // Clusters should always show
        },
        'paint': <String, dynamic>{},
      }),
      null,
    );

    log('GeoJsonMapLayerService: Cluster layer added (visited-aware overflow dots)');
  }

  /// Add layers for individual (unclustered) points.
  Future<void> _addUnclusteredLayers() async {
    await _map.style.addStyleLayer(
      jsonEncode({
        'id': _compactDotLayerId,
        'type': 'symbol',
        'source': config.sourceId,
        'filter': [
          'all',
          [
            '!',
            ['has', 'point_count']
          ],
        ],
        'layout': {
          'icon-image': [
            'case',
            [
              'coalesce',
              ['get', 'isBeenTo'],
              false
            ],
            _compactDotBeenToIconId,
            _compactDotIconId,
          ],
          'icon-size': [
            '*',
            config.iconSize,
            [
              'coalesce',
              ['get', 'bounceScale'],
              1.0,
            ],
          ],
          'icon-anchor': 'center',
          'icon-allow-overlap': true,
          'symbol-sort-key': ['get', 'savedCount'],
        },
        'paint': {
          'icon-opacity': ['get', 'compactOpacity'],
        },
      }),
      null,
    );

    final layoutProps = <String, dynamic>{
      // Full pins always render in a dedicated upper layer so they sit above dots.
      'icon-image': [
        'coalesce',
        [
          'concat',
          '$_iconPrefix',
          ['get', 'iconKey']
        ],
        '${_iconPrefix}fallback',
      ],
      'icon-size': [
        '*',
        config.iconSize,
        [
          'coalesce',
          ['get', 'bounceScale'],
          [
            'match',
            [
              'coalesce',
              ['get', 'bouncePhase'],
              0
            ],
            1,
            1.45,
            2,
            1.0,
            3,
            1.18,
            1.0,
          ],
        ],
      ],
      'icon-anchor': 'center',
      'icon-allow-overlap': config.allowIconOverlap,
      // Focused carousel pin should render above the rest.
      'symbol-sort-key': ['get', 'symbolSortKey'],
    };

    // Add text properties if enabled
    if (config.showTextLabels) {
      layoutProps.addAll({
        'text-field': _buildTextFieldExpression(),
        'text-font': ['Open Sans Semibold', 'Arial Unicode MS Bold'],
        'text-size': config.textSize,
        'text-anchor': 'left',
        'text-offset': [2.1, 0.1],
        'text-max-width': 10,
        'text-line-height': 1.05,
        'text-allow-overlap': config.allowTextOverlap,
        'text-optional': true, // Hide text on collision, keep icon
      });
    }

    await _map.style.addStyleLayer(
      jsonEncode({
        'id': _unclusteredIconLayerId,
        'type': 'symbol',
        'source': config.sourceId,
        'filter': [
          'all',
          [
            '!',
            ['has', 'point_count']
          ]
        ],
        'layout': layoutProps,
        'paint': config.showTextLabels
            ? {
                'icon-opacity': ['get', 'pinOpacity'],
                'text-opacity': ['get', 'labelOpacity'],
                'text-color': '#1A1A2E',
                'text-halo-color': '#ffffff',
                'text-halo-width': 1.75,
              }
            : {
                'icon-opacity': ['get', 'pinOpacity'],
              },
      }),
      null,
    );

    log('GeoJsonMapLayerService: Unclustered layers added (dots below pins)');
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

      if (config.enableClustering) {
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
            final Map<String, dynamic> featureJson =
                _convertToStringDynamicMap(featureData);

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
                  final propsMap = properties is Map
                      ? _convertToStringDynamicMap(properties)
                      : <String, dynamic>{};
                  final pointCount = propsMap['point_count'] as int? ?? 0;

                  log('GeoJsonMapLayerService: Cluster tapped with $pointCount points');
                  onClusterTapped?.call(center, pointCount);
                  return;
                }
              }
            }
          }
        }
      }

      // Query for individual (unclustered) points
      final pointFeatures = await _map.queryRenderedFeatures(
        mapbox.RenderedQueryGeometry.fromScreenBox(screenBox),
        mapbox.RenderedQueryOptions(
          layerIds: [_unclusteredIconLayerId, _compactDotLayerId],
        ),
      );

      log('GeoJsonMapLayerService: Found ${pointFeatures.length} point features');

      if (pointFeatures.isNotEmpty) {
        final feature = pointFeatures.first;
        if (feature != null) {
          final featureData = feature.queriedFeature.feature;

          // Convert feature to Map<String, dynamic>
          final Map<String, dynamic> featureJson =
              _convertToStringDynamicMap(featureData);

          final properties = featureJson['properties'];
          final propsMap = properties is Map
              ? _convertToStringDynamicMap(properties)
              : <String, dynamic>{};
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

      final shadowStyle = PinitMarkers.markerShadowStyle(
        rating: location.rating,
        wavyScore: location.vibe?.wavyScore ?? 0.0,
        bossmanScore: location.vibe?.bossmanScore ?? 0.0,
        savedCount: location.savedCount ?? 0,
        matchScore: location.matchScore ?? 0.0,
        badgeType: location.markerBadgeType,
        cuisine: location.cuisine,
        types: location.types,
      );

      // Store colorHex without '#' for icon lookup
      final colorHex = _colorHex(shadowStyle.color);
      final markerVisualKey = PinitMarkers.markerVisualKey(
        emoji: location.emoji,
        vibeVector: location.vibeVector,
        fallbackSeed: location.locationId,
      );
      final displayName = _sanitizeMapLabel(location.name);
      final infoSubtitle = _buildInfoSubtitle(location);
      final openStatusLabel = _openStatusLabel(location.openNow);
      final hasInfoLine = infoSubtitle.isNotEmpty || openStatusLabel.isNotEmpty;
      final locationId = location.locationId;
      final isBeenTo = _beenToLocationIds.contains(locationId);
      final isSelected = _selectedLocationId == locationId.toString();
      final compactBlend = _compactBlendForLocation(
        locationId,
        isSelected: isSelected,
      );

      features.add({
        'type': 'Feature',
        'properties': {
          'locationId': locationId,
          'name': displayName,
          'emoji': location.emoji,
          'markerVisualKey': markerVisualKey,
          'cuisine': location.cuisine,
          'types': location.types,
          'rating': location.rating,
          'savedCount': location.savedCount ?? 0,
          'isBeenTo': isBeenTo,
          'beenToClusterFlag': isBeenTo ? 1 : 0,
          'priceLevel': location.priceLevel,
          'openNow': location.openNow,
          'topVibeTag': location.topVibeTagLabel,
          'badgeType': location.markerBadgeType,
          'infoSubtitle': infoSubtitle,
          'openStatusLabel': openStatusLabel,
          'hasInfoLine': hasInfoLine,
          'bouncePhase': _bouncePhaseByLocationId[locationId] ?? 0,
          'bounceScale': _bounceScaleByLocationId[locationId] ?? 1.0,
          'useCompactMarker': compactBlend >= 0.5,
          'compactOpacity': compactBlend,
          'pinOpacity': 1.0 - compactBlend,
          'labelOpacity': 1.0 - compactBlend,
          'iconKey': _buildLocationIconKey(location),
          'symbolSortKey': isSelected ? 100000 : (location.savedCount ?? 0),
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

  void _pruneBounceStateForCurrentLocations() {
    final locationIds =
        _currentLocations.map((location) => location.locationId).toSet();

    final timersToCancel = _bounceTimersByLocationId.keys
        .where((locationId) => !locationIds.contains(locationId))
        .toList();

    for (final locationId in timersToCancel) {
      _bounceTimersByLocationId.remove(locationId)?.cancel();
      _bouncePhaseByLocationId.remove(locationId);
      _bounceScaleByLocationId.remove(locationId);
    }
  }

  void _flushPendingRecentSaveBounces() {
    final visibleIds =
        _currentLocations.map((location) => location.locationId).toSet();
    final readyIds = _pendingRecentSaveIds
        .where((locationId) => visibleIds.contains(locationId))
        .toList();

    for (final locationId in readyIds) {
      markLocationAsRecentlySaved(locationId);
    }
  }

  Future<void> _updateSourceData() async {
    if (!_isInitialized) return;

    if (_sourceUpdateInFlight) {
      _sourceUpdateQueued = true;
      return;
    }

    _sourceUpdateInFlight = true;
    try {
      do {
        _sourceUpdateQueued = false;
        final geoJsonString =
            jsonEncode(_locationsToGeoJson(_currentLocations));
        await _map.style.setStyleSourceProperty(
          config.sourceId,
          'data',
          geoJsonString,
        );
      } while (_sourceUpdateQueued);
    } finally {
      _sourceUpdateInFlight = false;
    }
  }

  List<Object> _buildTextFieldExpression() {
    return [
      'case',
      ['get', 'hasInfoLine'],
      [
        'format',
        ['get', 'name'],
        {
          'font-scale': 1.0,
          'text-font': [
            'literal',
            ['Open Sans Semibold', 'Arial Unicode MS Bold']
          ],
        },
        '\n',
        {},
        [
          'coalesce',
          ['get', 'infoSubtitle'],
          ''
        ],
        {
          'font-scale': 0.82,
          'text-font': [
            'literal',
            ['Open Sans Regular', 'Arial Unicode MS Regular']
          ],
          'text-color': '#707785',
        },
        [
          'case',
          [
            'all',
            [
              '!=',
              [
                'coalesce',
                ['get', 'infoSubtitle'],
                ''
              ],
              ''
            ],
            [
              '!=',
              [
                'coalesce',
                ['get', 'openStatusLabel'],
                ''
              ],
              ''
            ],
          ],
          ' · ',
          '',
        ],
        {
          'font-scale': 0.82,
          'text-font': [
            'literal',
            ['Open Sans Regular', 'Arial Unicode MS Regular']
          ],
          'text-color': '#707785',
        },
        [
          'case',
          [
            '!=',
            [
              'coalesce',
              ['get', 'openStatusLabel'],
              ''
            ],
            ''
          ],
          '●',
          '',
        ],
        {
          'font-scale': 0.80,
          'text-color': [
            'case',
            [
              '==',
              ['get', 'openNow'],
              true
            ],
            '#34C759',
            '#FF3B30',
          ],
        },
        [
          'case',
          [
            '!=',
            [
              'coalesce',
              ['get', 'openStatusLabel'],
              ''
            ],
            ''
          ],
          [
            'concat',
            ' ',
            ['get', 'openStatusLabel']
          ],
          '',
        ],
        {
          'font-scale': 0.82,
          'text-font': [
            'literal',
            ['Open Sans Regular', 'Arial Unicode MS Regular']
          ],
          'text-color': '#707785',
        },
      ],
      [
        'format',
        ['get', 'name'],
        {
          'font-scale': 1.0,
          'text-font': [
            'literal',
            ['Open Sans Semibold', 'Arial Unicode MS Bold']
          ],
        },
      ],
    ];
  }

  Future<void> _refreshViewportPresentation({
    LatLngBounds? visibleBounds,
    ui.Rect? usableScreenRect,
    required bool isInteracting,
    required bool updateSource,
  }) async {
    final visibleLocationIds = <int>{};
    final screenPositionsByLocationId = <int, ui.Offset>{};
    final effectiveUsableScreenRect = usableScreenRect ?? _usableScreenRect;
    final evaluationScreenRect = effectiveUsableScreenRect == null
        ? null
        : _expandScreenRect(effectiveUsableScreenRect);

    if (evaluationScreenRect != null) {
      final visibleLocations = _currentLocations
          .where((location) => location.lat != null && location.lng != null)
          .toList(growable: false);

      final screenPoints = await Future.wait(
        visibleLocations.map((location) async {
          final point = await _map.pixelForCoordinate(
            mapbox.Point(
              coordinates: mapbox.Position(location.lng!, location.lat!),
            ),
          );
          return (locationId: location.locationId, point: point);
        }),
      );

      for (final item in screenPoints) {
        final offset = ui.Offset(item.point.x, item.point.y);
        if (evaluationScreenRect.contains(offset)) {
          visibleLocationIds.add(item.locationId);
          screenPositionsByLocationId[item.locationId] = offset;
        }
      }
    } else {
      final bounds = visibleBounds ?? await _getVisibleBounds();
      if (bounds == null) return;

      for (final location in _currentLocations) {
        final lat = location.lat;
        final lng = location.lng;
        if (lat == null || lng == null) continue;
        if (_isLocationInBounds(lat, lng, bounds)) {
          visibleLocationIds.add(location.locationId);
        }
      }
    }

    final nextCompactLocationIds = <int>{};
    final nextExpandedLocationIds = <int>{};
    final locationsBySegment = <int, List<LocationModel>>{};
    final fallbackBounds = screenPositionsByLocationId.isEmpty
        ? (visibleBounds ?? await _getVisibleBounds())
        : null;

    for (final location in _currentLocations) {
      final lat = location.lat;
      final lng = location.lng;
      if (lat == null || lng == null) continue;
      if (!visibleLocationIds.contains(location.locationId)) continue;

      int segmentIndex;
      if (screenPositionsByLocationId.isNotEmpty &&
          evaluationScreenRect != null) {
        final offset = screenPositionsByLocationId[location.locationId];
        if (offset == null) continue;
        segmentIndex = _segmentIndexForScreenOffset(
          offset: offset,
          usableScreenRect: evaluationScreenRect,
        );
      } else {
        final bounds = fallbackBounds;
        if (bounds == null) continue;
        segmentIndex = _segmentIndexForLocation(
          lat: lat,
          lng: lng,
          bounds: bounds,
        );
      }

      locationsBySegment.putIfAbsent(segmentIndex, () => []).add(location);
    }

    for (final entry in locationsBySegment.entries) {
      final segmentLocations = entry.value;
      final hadCompactMarkers = segmentLocations.any(
        (location) => _compactLocationIds.contains(location.locationId),
      );
      final isDenseSegment =
          segmentLocations.length > _segmentDenseEnterThreshold ||
              (hadCompactMarkers &&
                  segmentLocations.length > _segmentDenseExitThreshold);
      if (!isDenseSegment && screenPositionsByLocationId.isEmpty) {
        continue;
      }

      final sortedLocations = List<LocationModel>.from(segmentLocations)
        ..sort(_compareLocationsForDenseDisplay);
      final visiblePinIds = <int>{};
      final keptPinRects = <ui.Rect>[];
      final stickyLocations = isInteracting
          ? sortedLocations
              .where(
                (location) =>
                    _selectedLocationId == location.locationId.toString() ||
                    !_compactLocationIds.contains(location.locationId),
              )
              .toList(growable: false)
          : const <LocationModel>[];

      for (final location in stickyLocations) {
        _tryKeepExpandedLocation(
          location: location,
          isDenseSegment: isDenseSegment,
          screenPositionsByLocationId: screenPositionsByLocationId,
          visiblePinIds: visiblePinIds,
          keptPinRects: keptPinRects,
          stickyMode: isInteracting,
        );
      }

      final shouldPromoteNewPins = !isInteracting || visiblePinIds.isEmpty;
      if (shouldPromoteNewPins) {
        for (final location in sortedLocations) {
          _tryKeepExpandedLocation(
            location: location,
            isDenseSegment: isDenseSegment,
            screenPositionsByLocationId: screenPositionsByLocationId,
            visiblePinIds: visiblePinIds,
            keptPinRects: keptPinRects,
            stickyMode: false,
          );
        }
      }

      for (final location in segmentLocations) {
        final locationId = location.locationId;
        if (visiblePinIds.contains(locationId)) {
          nextExpandedLocationIds.add(locationId);
        }
        if (_selectedLocationId == locationId.toString()) continue;
        if (!visiblePinIds.contains(locationId)) {
          nextCompactLocationIds.add(locationId);
        }
      }
    }

    final presentationStateChanged =
        !_setsEqual(_presentationVisibleLocationIds, visibleLocationIds) ||
            !_setsEqual(
              _presentationExpandedLocationIds,
              nextExpandedLocationIds,
            ) ||
            _presentationDefaultsVisibleToCompact != isInteracting;

    _presentationVisibleLocationIds = visibleLocationIds;
    _presentationExpandedLocationIds = nextExpandedLocationIds;
    _presentationDefaultsVisibleToCompact = isInteracting;

    if (_setsEqual(_compactLocationIds, nextCompactLocationIds)) {
      if (presentationStateChanged && updateSource) {
        await _updateSourceData();
      }
      return;
    }

    await _transitionCompactMarkers(
      nextCompactLocationIds,
      updateSource: updateSource,
    );
  }

  void _tryKeepExpandedLocation({
    required LocationModel location,
    required bool isDenseSegment,
    required Map<int, ui.Offset> screenPositionsByLocationId,
    required Set<int> visiblePinIds,
    required List<ui.Rect> keptPinRects,
    required bool stickyMode,
  }) {
    final locationId = location.locationId;
    if (visiblePinIds.contains(locationId)) {
      return;
    }

    final isSelected = _selectedLocationId == locationId.toString();
    final maxPinsInSegment =
        stickyMode ? _segmentStickyPinCount : _segmentExpandedPinCount;
    final canAddAnotherPin =
        isSelected || visiblePinIds.length < maxPinsInSegment;
    if (!canAddAnotherPin) {
      return;
    }

    final wasCompact = _compactLocationIds.contains(locationId);
    final screenOffset = screenPositionsByLocationId[locationId];
    final pinRect = screenOffset == null
        ? null
        : _pinScreenRectForLocation(
            center: screenOffset,
            isSelected: isSelected,
          );

    final overlapsExistingPin = pinRect != null &&
        keptPinRects.any((existingRect) => existingRect.overlaps(pinRect));
    final maxOverlapRatio = pinRect == null
        ? 0.0
        : keptPinRects.fold<double>(
            0.0,
            (maxRatio, existingRect) =>
                math.max(maxRatio, _overlapRatio(existingRect, pinRect)),
          );
    final overlapLimit = stickyMode
        ? _criticalOverlapStickyRatio
        : (wasCompact ? _criticalOverlapExitRatio : _criticalOverlapEnterRatio);
    final hasCriticalOverlap = maxOverlapRatio >= overlapLimit;
    final shouldKeepPin = isSelected ||
        (stickyMode
            ? !hasCriticalOverlap
            : (isDenseSegment ? !overlapsExistingPin : !hasCriticalOverlap));

    if (!shouldKeepPin) {
      return;
    }

    visiblePinIds.add(locationId);
    if (pinRect != null) {
      keptPinRects.add(pinRect);
    }
  }

  Future<void> _transitionCompactMarkers(
    Set<int> nextCompactLocationIds, {
    required bool updateSource,
  }) async {
    final previousCompactLocationIds = Set<int>.from(_compactLocationIds);
    if (_setsEqual(previousCompactLocationIds, nextCompactLocationIds)) {
      return;
    }

    _compactFadeTimer?.cancel();
    _compactFadeTimer = null;

    if (!updateSource) {
      _compactLocationIds = nextCompactLocationIds;
      _compactFadeByLocationId.clear();
      return;
    }

    final affectedLocationIds = <int>{
      ...previousCompactLocationIds,
      ...nextCompactLocationIds,
      ..._compactFadeByLocationId.keys,
    };

    final startBlendByLocationId = <int, double>{
      for (final locationId in affectedLocationIds)
        locationId: _compactFadeByLocationId[locationId] ??
            (previousCompactLocationIds.contains(locationId) ? 1.0 : 0.0),
    };
    final endBlendByLocationId = <int, double>{
      for (final locationId in affectedLocationIds)
        locationId: nextCompactLocationIds.contains(locationId) ? 1.0 : 0.0,
    };

    _compactLocationIds = nextCompactLocationIds;

    final stopwatch = Stopwatch()..start();
    _compactFadeTimer = Timer.periodic(
      _compactFadeFrameInterval,
      (timer) {
        final progress = (stopwatch.elapsedMilliseconds /
                _compactFadeDuration.inMilliseconds)
            .clamp(0.0, 1.0);
        final easedProgress = Curves.easeOutCubic.transform(progress);

        for (final locationId in affectedLocationIds) {
          final start = startBlendByLocationId[locationId] ?? 0.0;
          final end = endBlendByLocationId[locationId] ?? 0.0;
          final blend = ui.lerpDouble(start, end, easedProgress) ?? end;
          _compactFadeByLocationId[locationId] = blend;
        }

        unawaited(_updateSourceData());

        if (progress >= 1.0) {
          timer.cancel();
          _compactFadeTimer = null;
          _compactFadeByLocationId
            ..removeWhere((locationId, _) {
              final endBlend = endBlendByLocationId[locationId] ?? 0.0;
              return endBlend <= 0.0;
            })
            ..updateAll(
                (locationId, _) => endBlendByLocationId[locationId] ?? 0.0);
          unawaited(_updateSourceData());
        }
      },
    );
  }

  double _compactBlendForLocation(
    int locationId, {
    required bool isSelected,
  }) {
    if (isSelected) return 0.0;
    final isPresentationExpanded =
        _presentationExpandedLocationIds.contains(locationId);
    if (isPresentationExpanded) {
      return _compactFadeByLocationId[locationId] ?? 0.0;
    }
    final shouldDefaultToCompact = _presentationDefaultsVisibleToCompact &&
        _presentationVisibleLocationIds.contains(locationId);
    if (shouldDefaultToCompact) {
      return _compactFadeByLocationId[locationId] ?? 1.0;
    }
    return _compactFadeByLocationId[locationId] ??
        (_compactLocationIds.contains(locationId) ? 1.0 : 0.0);
  }

  Future<LatLngBounds?> _getVisibleBounds() async {
    try {
      final state = await _map.getCameraState();
      final bounds = await _map.coordinateBoundsForCamera(
        mapbox.CameraOptions(
          center: state.center,
          zoom: state.zoom,
          bearing: state.bearing,
          pitch: state.pitch,
        ),
      );
      return LatLngBounds.fromCoordinateBounds(bounds);
    } catch (_) {
      return null;
    }
  }

  bool _isLocationInBounds(double lat, double lng, LatLngBounds bounds) {
    final inLat =
        lat >= bounds.southwest.latitude && lat <= bounds.northeast.latitude;
    final west = bounds.southwest.longitude;
    final east = bounds.northeast.longitude;
    final inLng = west <= east
        ? (lng >= west && lng <= east)
        : (lng >= west || lng <= east);

    return inLat && inLng;
  }

  bool _setsEqual(Set<int> a, Set<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final value in a) {
      if (!b.contains(value)) return false;
    }
    return true;
  }

  int _segmentIndexForLocation({
    required double lat,
    required double lng,
    required LatLngBounds bounds,
  }) {
    final latSpan = bounds.northeast.latitude - bounds.southwest.latitude;
    final rowHeight = latSpan <= 0 ? 1.0 : latSpan / _segmentRows;
    final rawRow = ((lat - bounds.southwest.latitude) / rowHeight)
        .floor()
        .clamp(0, _segmentRows - 1);

    final west = bounds.southwest.longitude;
    final east = bounds.northeast.longitude;
    final lngSpan = _longitudeSpan(west, east);
    final columnWidth = lngSpan <= 0 ? 1.0 : lngSpan / _segmentColumns;
    final relativeLng = _relativeLongitude(lng, west);
    final rawColumn =
        (relativeLng / columnWidth).floor().clamp(0, _segmentColumns - 1);

    return rawRow * _segmentColumns + rawColumn;
  }

  int _segmentIndexForScreenOffset({
    required ui.Offset offset,
    required ui.Rect usableScreenRect,
  }) {
    final columnWidth = usableScreenRect.width <= 0
        ? 1.0
        : usableScreenRect.width / _segmentColumns;
    final rowHeight = usableScreenRect.height <= 0
        ? 1.0
        : usableScreenRect.height / _segmentRows;

    final rawColumn = ((offset.dx - usableScreenRect.left) / columnWidth)
        .floor()
        .clamp(0, _segmentColumns - 1);
    final rawRow = ((offset.dy - usableScreenRect.top) / rowHeight)
        .floor()
        .clamp(0, _segmentRows - 1);

    return rawRow * _segmentColumns + rawColumn;
  }

  ui.Rect _expandScreenRect(ui.Rect rect) {
    final verticalInset = math.max(
      _viewportMinVerticalOverscan,
      rect.height * _viewportVerticalOverscanFactor,
    );
    return ui.Rect.fromLTRB(
      rect.left,
      rect.top - verticalInset,
      rect.right,
      rect.bottom + verticalInset,
    );
  }

  double _longitudeSpan(double west, double east) {
    return west <= east ? (east - west) : (360 - west + east);
  }

  double _relativeLongitude(double lng, double west) {
    final delta = lng - west;
    return delta >= 0 ? delta : delta + 360;
  }

  ui.Rect _pinScreenRectForLocation({
    required ui.Offset center,
    required bool isSelected,
  }) {
    final width = isSelected ? _denseSelectedPinWidth : _densePinWidth;
    final height = isSelected ? _denseSelectedPinHeight : _densePinHeight;
    return ui.Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );
  }

  double _overlapRatio(ui.Rect a, ui.Rect b) {
    final intersection = a.intersect(b);
    if (intersection.isEmpty) return 0.0;

    final intersectionArea = intersection.width * intersection.height;
    final baseArea = math.min(a.width * a.height, b.width * b.height);
    if (baseArea <= 0) return 0.0;

    return intersectionArea / baseArea;
  }

  int _compareLocationsForDenseDisplay(LocationModel a, LocationModel b) {
    final aSelected = _selectedLocationId == a.locationId.toString();
    final bSelected = _selectedLocationId == b.locationId.toString();
    if (aSelected != bSelected) {
      return aSelected ? -1 : 1;
    }

    final matchCompare = (b.matchScore ?? 0.0).compareTo(a.matchScore ?? 0.0);
    if (matchCompare != 0) return matchCompare;

    final savedCompare = (b.savedCount ?? 0).compareTo(a.savedCount ?? 0);
    if (savedCompare != 0) return savedCompare;

    final ratingCompare = (b.rating ?? 0.0).compareTo(a.rating ?? 0.0);
    if (ratingCompare != 0) return ratingCompare;

    return a.locationId.compareTo(b.locationId);
  }

  String _buildLocationIconKey(LocationModel location) {
    final shadowStyle = PinitMarkers.markerShadowStyle(
      rating: location.rating,
      wavyScore: location.vibe?.wavyScore ?? 0.0,
      bossmanScore: location.vibe?.bossmanScore ?? 0.0,
      savedCount: location.savedCount ?? 0,
      matchScore: location.matchScore ?? 0.0,
      badgeType: location.markerBadgeType,
      cuisine: location.cuisine,
      types: location.types,
    );
    final visualKey = PinitMarkers.markerVisualKey(
      emoji: location.emoji,
      vibeVector: location.vibeVector,
      fallbackSeed: location.locationId,
    );
    final selected = _selectedLocationId == location.locationId.toString();
    final colorHex = _colorHex(shadowStyle.color);
    final badgeType = location.markerBadgeType ?? 'none';
    final wavyScore = ((location.vibe?.wavyScore ?? 0.0) * 100).round();
    final bossmanScore = ((location.vibe?.bossmanScore ?? 0.0) * 100).round();
    final matchScore = ((location.matchScore ?? 0.0) * 100).round();
    final savedCount = location.savedCount ?? 0;

    return '${visualKey}-${shadowStyle.key}-$colorHex-$badgeType-s$savedCount-w$wavyScore-b$bossmanScore-m$matchScore-sel${selected ? 1 : 0}';
  }

  String _buildInfoSubtitle(LocationModel location) {
    final parts = <String>[];

    if (location.rating != null) {
      parts.add('★${location.rating!.toStringAsFixed(1)}');
    }

    final priceLabel = _priceLevelLabel(location.priceLevel);
    if (priceLabel != null) {
      parts.add(priceLabel);
    }

    final topVibeTag = location.topVibeTagLabel;
    if (topVibeTag != null && topVibeTag.isNotEmpty) {
      parts.add(topVibeTag);
    }

    return parts.join(' · ');
  }

  String? _priceLevelLabel(int? priceLevel) {
    if (priceLevel == null || priceLevel <= 0) return null;
    final clampedLevel = priceLevel.clamp(1, 4).toInt();
    return List.filled(clampedLevel, r'$').join();
  }

  String _openStatusLabel(bool? openNow) {
    if (openNow == null) return '';
    return openNow ? 'Open' : 'Closed';
  }

  String _sanitizeMapLabel(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return '';

    final normalized = trimmed.toLowerCase();
    if (normalized == 'none' || normalized == 'null') {
      return '';
    }

    return trimmed;
  }

  String _colorHex(Color color) {
    return color
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2)
        .toUpperCase();
  }

  String _clusterOverflowTierKey(int pointCount) {
    if (pointCount <= 2) return 'dots0';
    if (pointCount == 3) return 'dots1';
    if (pointCount == 4) return 'dots2';
    return 'dots3';
  }

  Future<mapbox.MbxImage> _createMapboxImage(Uint8List pngBytes) async {
    final codec = await ui.instantiateImageCodec(pngBytes);
    final frame = await codec.getNextFrame();

    try {
      return mapbox.MbxImage(
        width: frame.image.width,
        height: frame.image.height,
        data: pngBytes,
      );
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  }

  int _bouncePhaseForProgress(double progress) {
    final phaseIndex = (progress * 4).floor().clamp(0, 3);
    switch (phaseIndex) {
      case 0:
        return 1;
      case 1:
        return 2;
      case 2:
        return 3;
      default:
        return 0;
    }
  }

  double _bounceScaleForProgress(double progress) {
    final scaled = (progress * 4).clamp(0.0, 4.0);
    final lowerIndex = scaled.floor().clamp(0, _bounceScaleStops.length - 2);
    final upperIndex = (lowerIndex + 1).clamp(0, _bounceScaleStops.length - 1);
    final localT = Curves.easeOut.transform(scaled - lowerIndex);

    return _bounceScaleStops[lowerIndex] +
        (_bounceScaleStops[upperIndex] - _bounceScaleStops[lowerIndex]) *
            localT;
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color, Curves, debugPrint;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:login/models/locations.dart';
import 'package:login/models/markers.dart';
import 'package:login/models/proximal_models.dart' show FriendSave;
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/utils/friend_avatar_loader.dart';
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
  final int clusterRadius;

  /// Maximum zoom level at which clustering is applied.
  ///
  /// Above this zoom, places are never merged into count bubbles; density is
  /// handled by pins collapsing into dots instead.
  final int clusterMaxZoom;

  /// Base icon size (will be adjusted for devicePixelRatio)
  final double iconSize;

  /// Text size for location names
  final double textSize;

  /// Whether to show text labels on pins
  final bool showTextLabels;

  /// Whether to allow text overlap (false enables collision detection)
  final bool allowTextOverlap;

  const GeoJsonLayerConfig({
    this.sourceId = 'pinit-locations',
    this.enableClustering = true,
    this.clusterRadius = 50,
    this.clusterMaxZoom = 12,
    this.iconSize = 1.0,
    this.textSize = 12.0,
    this.showTextLabels = true,
    this.allowTextOverlap = false,
  });
}

/// Callback type for location tap events
typedef OnLocationTapped = void Function(int locationId);

/// Callback type for cluster tap events. [expansionZoom] is the zoom at which
/// the cluster splits apart, when Mapbox could resolve it.
typedef OnClusterTapped = void Function(
  LatLng center,
  int pointCount,
  double? expansionZoom,
);

/// Service for managing GeoJSON-based map layers with native Mapbox clustering.
///
/// Every place is drawn in three tiers, all decided by Mapbox itself:
///
/// - **Count clusters** (zoomed far out): nearby places merge into a numbered
///   cream bubble. Tapping one zooms to exactly where it splits.
/// - **Dots**: every unclustered place always has a small dot. Dots never take
///   part in collision, so they can't hide anything.
/// - **Pins + name labels**: drawn above the dots with collision enabled and
///   ranked by importance. Where a pin doesn't fit, Mapbox hides it (pin and
///   label together), leaving the dot underneath.
///
/// The selected place is drawn in its own top layer so it always shows, with
/// an enlarged pin and a details line.
///
/// ## Usage
///
/// ```dart
/// final service = GeoJsonMapLayerService(
///   mapboxMap: map,
///   config: const GeoJsonLayerConfig(),
///   onLocationTapped: (id) => print('Location $id tapped'),
///   onClusterTapped: (center, count, zoom) => print('Cluster with $count'),
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
  // In-flight setup shared by concurrent callers. Without it, a second
  // caller hits "source already exists" and its cleanup tears down the
  // source/layers the first caller just built, leaving no pins.
  Future<void>? _initializing;
  String? _selectedLocationId;
  List<LocationModel>? _pendingLocations;
  List<LocationModel> _currentLocations = const [];
  Set<int> _beenToLocationIds = const <int>{};

  /// When true (category/overview stage), pins get extra collision padding so
  /// only a sparse set of labelled pins shows and the rest stay as dots.
  bool _dotsByDefault = false;
  final Map<int, double> _bounceScaleByLocationId = {};
  final Map<int, Timer> _bounceTimersByLocationId = {};
  final Set<int> _pendingRecentSaveIds = {};
  bool _sourceUpdateInFlight = false;
  bool _sourceUpdateQueued = false;

  // Layer IDs (bottom → top)
  static const String _clusterShadowLayerId = 'pinit-cluster-shadow';
  static const String _clusterCircleLayerId = 'pinit-cluster-circles';
  static const String _clusterCountLayerId = 'pinit-cluster-count';
  static const String _compactDotLayerId = 'pinit-compact-dots';
  static const String _unclusteredIconLayerId = 'pinit-unclustered-icons';
  static const String _selectedPinLayerId = 'pinit-selected-pin';

  // Track registered emoji icons to avoid re-registering
  final Set<String> _registeredIconIds = {};

  // Icon ID prefixes
  static const String _iconPrefix = 'pinit-icon-';
  static const String _fallbackIconId = '${_iconPrefix}fallback';
  static const String _selectedIconSuffix = '-sel';
  static const Duration _bounceDuration = Duration(milliseconds: 1120);
  static const Duration _bounceFrameInterval = Duration(milliseconds: 16);
  static const List<double> _bounceScaleStops = [1.0, 1.45, 1.0, 1.18, 1.0];

  /// Extra collision padding around pins (screen px). Bigger padding means
  /// fewer pins win a spot; the losers render as dots.
  static const double _focusedPinPadding = 2.0;
  static const double _overviewPinPadding = 28.0;

  /// Zoom at which unselected pin labels gain the rating/price/open line.
  static const double _detailLabelZoom = 16.0;

  /// Pin images carry a 3px hard shadow below the tail tip; nudge the icon
  /// down by that much so the tip lands exactly on the location.
  static const double _pinTipShadowOffset = 3.0;

  // Label offsets in ems (text-size 12), measured from the tail tip to just
  // beside the pin bubble. Selected pins are 1.4× larger.
  static const List<double> _labelOffsetLeft = [2.0, -1.95];
  static const List<double> _selectedLabelOffsetLeft = [2.6, -2.6];

  static const List<String> _labelFontBold = [
    'DIN Pro Medium',
    'Arial Unicode MS Regular',
  ];
  static const List<String> _labelFontRegular = [
    'DIN Pro Regular',
    'Arial Unicode MS Regular',
  ];

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

  /// Initialize the GeoJSON source and layers.
  ///
  /// Must be called after the map style has loaded.
  /// Any locations that arrived before initialization will be flushed after setup completes.
  Future<void> initialize() {
    if (_isInitialized) {
      log('GeoJsonMapLayerService: Already initialized');
      return Future.value();
    }
    return _initializing ??=
        _initialize().whenComplete(() => _initializing = null);
  }

  Future<void> _initialize() async {
    try {
      await _createGeoJsonSource();
      await _addFallbackIcon();

      // Order matters: later layers draw on top and win collision placement.
      await _addClusterLayers();
      await _addCompactDotLayer();
      await _addPinLayer();
      await _addSelectedPinLayer();

      _isInitialized = true;
      log('GeoJsonMapLayerService: Initialized successfully');

      await _applyPinPadding();
      await _applySelectionFilters();

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
      // `log` doesn't reach the device console; make setup failures visible.
      debugPrint('GeoJsonMapLayerService: Initialization failed: $e\n$stack');
      // Undo partial setup so the next location sync can retry from scratch
      // instead of failing on the already-added source.
      await _removeStyleObjects();
      rethrow;
    }
  }

  /// Update the locations displayed on the map.
  ///
  /// If initialization hasn't completed yet, locations are buffered and will be
  /// applied once initialize() completes. Otherwise, updates are applied immediately.
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

  Future<void> _applyLocations(
    List<LocationModel> locations, {
    Set<int> beenToLocationIds = const <int>{},
  }) async {
    try {
      // Register icons before publishing the list: bounce timers and selection
      // changes push _currentLocations at any time, and pins whose image isn't
      // registered yet would render with the fallback icon.
      await _registerEmojiIcons(locations);
      await _registerSelectedIcon(locations);

      _currentLocations = List<LocationModel>.from(locations);
      _beenToLocationIds = Set<int>.from(beenToLocationIds);
      _pruneBounceStateForCurrentLocations();

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
  /// Pass null to clear selection. Only the two layer filters change — the
  /// source data is left alone so the rest of the map doesn't re-place.
  void setSelectedLocation(String? locationId) {
    if (_selectedLocationId == locationId) return;
    _selectedLocationId = locationId;
    log('GeoJsonMapLayerService: Selected location: $locationId');
    if (_isInitialized) {
      unawaited(() async {
        await _registerSelectedIcon();
        await _applySelectionFilters();
      }());
    }
  }

  /// Toggle "dots by default" presentation (category/overview stage). When
  /// enabled, pins claim a much larger collision area so only a sparse set of
  /// labelled pins shows; everything else stays a dot.
  Future<void> setDotsByDefault(bool value) async {
    if (_dotsByDefault == value) return;
    _dotsByDefault = value;
    if (_isInitialized) {
      await _applyPinPadding();
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
          _bounceScaleByLocationId[locationId] = 1.0;
          unawaited(_updateSourceData());
          return;
        }

        _bounceScaleByLocationId[locationId] =
            _bounceScaleForProgress(progress);
        unawaited(_updateSourceData());
      },
    );
  }

  void pulseLocation(int locationId) {
    markLocationAsRecentlySaved(locationId);
  }

  /// The map reloaded its style, which drops every source, layer and image we
  /// added. Forget them so the next [initialize] rebuilds from scratch.
  void resetForNewStyle() {
    _isInitialized = false;
    _registeredIconIds.clear();
    log('GeoJsonMapLayerService: Style reloaded; layers will be rebuilt');
  }

  /// Stop all activity without touching the style — used when the map this
  /// service drew on has been replaced.
  void detach() {
    for (final timer in _bounceTimersByLocationId.values) {
      timer.cancel();
    }
    _bounceTimersByLocationId.clear();
    _isInitialized = false;
  }

  /// Clean up resources when the service is no longer needed.
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      for (final timer in _bounceTimersByLocationId.values) {
        timer.cancel();
      }
      _bounceTimersByLocationId.clear();
      _bounceScaleByLocationId.clear();
      _pendingRecentSaveIds.clear();
      _beenToLocationIds = const <int>{};

      await _removeStyleObjects();

      _isInitialized = false;
      log('GeoJsonMapLayerService: Disposed');
    } catch (e) {
      log('GeoJsonMapLayerService: Error during dispose: $e');
    }
  }

  // ============ Private Implementation ============

  /// Removes every layer, the source and all icons this service added.
  Future<void> _removeStyleObjects() async {
    // Reverse order of addition
    for (final layerId in const [
      _selectedPinLayerId,
      _unclusteredIconLayerId,
      _compactDotLayerId,
      _clusterCountLayerId,
      _clusterCircleLayerId,
      _clusterShadowLayerId,
    ]) {
      await _safeRemoveLayer(layerId);
    }

    try {
      await _map.style.removeStyleSource(config.sourceId);
    } catch (_) {
      // Source may not exist
    }

    for (final iconId in _registeredIconIds) {
      try {
        await _map.style.removeStyleImage(iconId);
      } catch (_) {
        // Icon may not exist
      }
    }
    _registeredIconIds.clear();
  }

  Future<void> _createGeoJsonSource() async {
    final source = <String, dynamic>{
      'type': 'geojson',
      'data': {
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      },
      'cluster': config.enableClustering,
    };

    if (config.enableClustering) {
      source.addAll({
        'clusterRadius': config.clusterRadius,
        'clusterMaxZoom': config.clusterMaxZoom,
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
    if (_registeredIconIds.contains(_fallbackIconId)) return;

    final iconBytes = await PinitMarkers.createPinitMarker(
      name: '',
      devicePixelRatio: 3.0,
      showText: false,
      fallbackSeed: 0,
    );
    await _addIcon(_fallbackIconId, iconBytes);
    log('GeoJsonMapLayerService: Fallback icon added');
  }

  /// Register pin icons for all unique marker-visual combinations.
  Future<void> _registerEmojiIcons(List<LocationModel> locations) async {
    final pending = <String, LocationModel>{};
    for (final location in locations) {
      final iconId = '$_iconPrefix${_buildLocationIconKey(location)}';
      if (!_registeredIconIds.contains(iconId)) {
        pending.putIfAbsent(iconId, () => location);
      }
    }

    if (pending.isEmpty) return;

    log('GeoJsonMapLayerService: Registering ${pending.length} new emoji icons');

    // In parallel: each icon may wait on friend-avatar downloads.
    await Future.wait(pending.entries.map(
      (entry) => _registerPinIcon(entry.key, entry.value, selected: false),
    ));
  }

  /// Register the enlarged icon variant for the currently selected location.
  Future<void> _registerSelectedIcon([List<LocationModel>? locations]) async {
    final selectedId = _selectedLocationId;
    if (selectedId == null) return;

    for (final location in locations ?? _currentLocations) {
      if (location.locationId.toString() != selectedId) continue;
      final iconId =
          '$_iconPrefix${_buildLocationIconKey(location)}$_selectedIconSuffix';
      if (!_registeredIconIds.contains(iconId)) {
        await _registerPinIcon(iconId, location, selected: true);
      }
      return;
    }
  }

  Future<void> _registerPinIcon(
    String iconId,
    LocationModel location, {
    required bool selected,
  }) async {
    try {
      // Mapbox style images are static bitmaps so friend avatars must be
      // rasterised into the icon at registration time.
      final friendSaves = location.friendSaves;
      List<ui.Image?> friendAvatarImages = const [];
      List<String> friendInitials = const [];
      String friendAvatarKey = '';
      if (friendSaves.isNotEmpty) {
        final List<FriendSave> shown = friendSaves.take(3).toList();
        friendAvatarImages = await FriendAvatarLoader.loadAll(
          shown.map((f) => f.friendProfileImageUrl),
        );
        friendInitials = shown.map((f) => f.friendName).toList();
        friendAvatarKey =
            shown.map((f) => f.friendProfileImageUrl ?? f.friendId).join('|');
      }

      final iconBytes = await PinitMarkers.createPinitMarker(
        emoji: location.emoji,
        name: '',
        devicePixelRatio: 3.0,
        selected: selected,
        showText: false,
        wavyScore: location.vibe?.wavyScore ?? 0.0,
        bossmanScore: location.vibe?.bossmanScore ?? 0.0,
        savedCount: location.savedCount ?? 0,
        matchScore: location.matchScore ?? 0.0,
        badgeType: location.markerBadgeType,
        rating: location.rating,
        vibeVector: location.vibeVector,
        fallbackSeed: location.locationId,
        friendAvatarImages: friendAvatarImages,
        friendInitials: friendInitials,
        friendAvatarCacheKey: friendAvatarKey,
        totalFriendCount: friendSaves.length,
      );

      await _addIcon(iconId, iconBytes);
    } catch (e) {
      log('GeoJsonMapLayerService: Failed to register icon $iconId: $e');
    }
  }

  Future<void> _addIcon(String iconId, Uint8List pngBytes) async {
    final image = await _createMapboxImage(pngBytes);
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
  }

  /// Count clusters: a cream bubble with a hard aubergine offset shadow and
  /// the number of places inside.
  Future<void> _addClusterLayers() async {
    if (!config.enableClustering) return;

    final clusterFilter = ['has', 'point_count'];
    final radius = [
      'step',
      ['get', 'point_count'],
      15,
      10,
      18,
      50,
      22,
    ];

    await _map.style.addStyleLayer(
      jsonEncode({
        'id': _clusterShadowLayerId,
        'type': 'circle',
        'source': config.sourceId,
        'filter': clusterFilter,
        'paint': {
          'circle-color': _hex(pinit.PinitColors.aubergine),
          'circle-radius': radius,
          'circle-translate': [2.5, 2.5],
        },
      }),
      null,
    );

    await _map.style.addStyleLayer(
      jsonEncode({
        'id': _clusterCircleLayerId,
        'type': 'circle',
        'source': config.sourceId,
        'filter': clusterFilter,
        'paint': {
          'circle-color': _hex(pinit.PinitColors.cream),
          'circle-radius': radius,
          'circle-stroke-color': _hex(pinit.PinitColors.aubergine),
          'circle-stroke-width': 1.5,
        },
      }),
      null,
    );

    await _map.style.addStyleLayer(
      jsonEncode({
        'id': _clusterCountLayerId,
        'type': 'symbol',
        'source': config.sourceId,
        'filter': clusterFilter,
        'layout': {
          'text-field': ['get', 'point_count_abbreviated'],
          'text-font': _labelFontBold,
          'text-size': 13,
          'text-allow-overlap': true,
          'text-ignore-placement': true,
        },
        'paint': {
          'text-color': _hex(pinit.PinitColors.aubergine),
        },
      }),
      null,
    );

    log('GeoJsonMapLayerService: Cluster layers added');
  }

  /// Dots sit under every unclustered place. Circle layers never take part in
  /// symbol collision, so a dot always shows wherever its pin was dropped.
  Future<void> _addCompactDotLayer() async {
    final isBeenTo = [
      'coalesce',
      ['get', 'isBeenTo'],
      false
    ];
    final bounceScale = [
      'coalesce',
      ['get', 'bounceScale'],
      1.0
    ];
    await _map.style.addStyleLayer(
      jsonEncode({
        'id': _compactDotLayerId,
        'type': 'circle',
        'source': config.sourceId,
        'filter': _unclusteredFilter,
        'paint': {
          'circle-color': [
            'case',
            isBeenTo,
            _hex(pinit.PinitColors.warning),
            _hex(pinit.PinitColors.aubergine),
          ],
          // `zoom` must be the input of a top-level interpolate, so the save
          // bounce multiplier goes inside each stop.
          'circle-radius': [
            'interpolate',
            ['linear'],
            ['zoom'],
            11,
            ['*', 3.0, bounceScale],
            16,
            ['*', 4.5, bounceScale],
          ],
          // Soft dots keep dense areas calm; been-to dots stay a touch
          // stronger so they remain findable.
          'circle-opacity': [
            'case',
            isBeenTo,
            0.6,
            0.4,
          ],
          'circle-stroke-color': _hex(pinit.PinitColors.cream),
          'circle-stroke-width': 1.0,
          'circle-stroke-opacity': 0.5,
        },
      }),
      null,
    );
  }

  /// Full pins with name labels. Collision is on, so Mapbox keeps the most
  /// important pins (lowest sort key) and hides the rest — pin and label
  /// together — leaving the dot below visible.
  Future<void> _addPinLayer() async {
    final layout = <String, dynamic>{
      ..._pinIconLayout(),
      'icon-allow-overlap': false,
      'icon-ignore-placement': false,
      'icon-padding': _focusedPinPadding,
      'symbol-sort-key': ['get', 'priority'],
    };

    if (config.showTextLabels) {
      layout.addAll({
        'text-field': [
          'step',
          ['zoom'],
          _nameLabelExpression(),
          _detailLabelZoom,
          _detailLabelExpression(),
        ],
        'text-font': _labelFontBold,
        'text-size': config.textSize,
        'text-max-width': 9,
        'text-line-height': 1.1,
        'text-justify': 'auto',
        'text-allow-overlap': config.allowTextOverlap,
        // Pin and label appear or disappear together — never a bare pin.
        'text-optional': false,
        'icon-optional': false,
      });
    }

    await _addLabelledSymbolLayer(
      id: _unclusteredIconLayerId,
      filter: _pinFilterExcluding(null),
      layout: layout,
      labelOffsetLeft: _labelOffsetLeft,
    );

    log('GeoJsonMapLayerService: Pin layer added');
  }

  /// The selected pin lives in its own top layer: placed first, always shown,
  /// larger icon and a two-line label with details.
  Future<void> _addSelectedPinLayer() async {
    final layout = <String, dynamic>{
      ..._pinIconLayout(iconSuffix: _selectedIconSuffix),
      'icon-allow-overlap': true,
      'icon-ignore-placement': false,
    };

    if (config.showTextLabels) {
      layout.addAll({
        'text-field': _detailLabelExpression(),
        'text-font': _labelFontBold,
        'text-size': config.textSize + 1,
        'text-max-width': 10,
        'text-line-height': 1.1,
        'text-justify': 'auto',
        'text-allow-overlap': true,
        'text-optional': true,
      });
    }

    await _addLabelledSymbolLayer(
      id: _selectedPinLayerId,
      filter: _selectedPinFilter(null),
      layout: layout,
      labelOffsetLeft: _selectedLabelOffsetLeft,
    );
  }

  /// Adds a pin symbol layer whose label sits beside the pin bubble and may
  /// flip left/right/below before being dropped. Falls back to a fixed
  /// right-hand label if the SDK rejects `text-variable-anchor-offset`.
  Future<void> _addLabelledSymbolLayer({
    required String id,
    required List<Object> filter,
    required Map<String, dynamic> layout,
    required List<double> labelOffsetLeft,
  }) async {
    Map<String, dynamic> layerJson(Map<String, dynamic> layout) => {
          'id': id,
          'type': 'symbol',
          'source': config.sourceId,
          'filter': filter,
          'layout': layout,
          'paint': {
            'text-color': _hex(pinit.PinitColors.aubergine),
            'text-halo-color': _hex(pinit.PinitColors.cream),
            'text-halo-width': 1.6,
            'text-halo-blur': 0.4,
          },
        };

    if (!config.showTextLabels) {
      await _map.style.addStyleLayer(jsonEncode(layerJson(layout)), null);
      return;
    }

    final dx = labelOffsetLeft[0];
    final dy = labelOffsetLeft[1];
    try {
      await _map.style.addStyleLayer(
        jsonEncode(layerJson({
          ...layout,
          'text-variable-anchor-offset': [
            'left',
            [dx, dy],
            'right',
            [-dx, dy],
            'top',
            [0, 0.6],
          ],
        })),
        null,
      );
    } catch (e) {
      debugPrint(
          'GeoJsonMapLayerService: variable label anchors unsupported ($e); using fixed anchor');
      await _map.style.addStyleLayer(
        jsonEncode(layerJson({
          ...layout,
          'text-anchor': 'left',
          'text-offset': [dx, dy],
        })),
        null,
      );
    }
  }

  Map<String, dynamic> _pinIconLayout({String iconSuffix = ''}) {
    return {
      'icon-image': [
        'coalesce',
        [
          'image',
          [
            'concat',
            _iconPrefix,
            ['get', 'iconKey'],
            iconSuffix,
          ],
        ],
        ['image', _fallbackIconId],
      ],
      'icon-size': [
        '*',
        config.iconSize,
        [
          'coalesce',
          ['get', 'bounceScale'],
          1.0
        ],
      ],
      // Tail tip on the location (the image carries a hard shadow below it).
      'icon-anchor': 'bottom',
      'icon-offset': [0, _pinTipShadowOffset],
    };
  }

  static const List<Object> _unclusteredFilter = [
    '!',
    ['has', 'point_count']
  ];

  List<Object> _pinFilterExcluding(int? selectedId) => [
        'all',
        _unclusteredFilter,
        [
          '!=',
          ['get', 'locationId'],
          selectedId ?? -1
        ],
      ];

  List<Object> _selectedPinFilter(int? selectedId) => [
        'all',
        _unclusteredFilter,
        [
          '==',
          ['get', 'locationId'],
          selectedId ?? -1
        ],
      ];

  Future<void> _applySelectionFilters() async {
    if (!_isInitialized) return;
    final selectedId = int.tryParse(_selectedLocationId ?? '');
    try {
      await _map.style.setStyleLayerProperty(
        _selectedPinLayerId,
        'filter',
        jsonEncode(_selectedPinFilter(selectedId)),
      );
      await _map.style.setStyleLayerProperty(
        _unclusteredIconLayerId,
        'filter',
        jsonEncode(_pinFilterExcluding(selectedId)),
      );
    } catch (e) {
      debugPrint(
          'GeoJsonMapLayerService: Failed to update selection filters: $e');
    }
  }

  Future<void> _applyPinPadding() async {
    if (!_isInitialized) return;
    try {
      await _map.style.setStyleLayerProperty(
        _unclusteredIconLayerId,
        'icon-padding',
        _dotsByDefault ? _overviewPinPadding : _focusedPinPadding,
      );
    } catch (e) {
      debugPrint('GeoJsonMapLayerService: Failed to update pin padding: $e');
    }
  }

  /// Query features at a screen point and dispatch to appropriate callback.
  ///
  /// This should be called from the map widget's tap listener.
  Future<void> handleTapAtPoint(double x, double y) async {
    // Tap tolerance in screen pixels (helps with finger taps)
    const double tapTolerance = 22.0;

    try {
      final screenBox = mapbox.ScreenBox(
        min: mapbox.ScreenCoordinate(x: x - tapTolerance, y: y - tapTolerance),
        max: mapbox.ScreenCoordinate(x: x + tapTolerance, y: y + tapTolerance),
      );

      Future<List<mapbox.QueriedRenderedFeature?>> query(String layerId) {
        return _map.queryRenderedFeatures(
          mapbox.RenderedQueryGeometry.fromScreenBox(screenBox),
          mapbox.RenderedQueryOptions(layerIds: [layerId]),
        );
      }

      // Pins win over clusters, clusters over bare dots.
      for (final layerId in [_selectedPinLayerId, _unclusteredIconLayerId]) {
        if (_dispatchLocationTap(await query(layerId))) return;
      }

      if (config.enableClustering &&
          await _dispatchClusterTap(await query(_clusterCircleLayerId))) {
        return;
      }

      if (_dispatchLocationTap(await query(_compactDotLayerId))) return;

      log('GeoJsonMapLayerService: No features found at tap location');
    } catch (e, stack) {
      log('GeoJsonMapLayerService: Error querying features: $e\n$stack');
    }
  }

  bool _dispatchLocationTap(List<mapbox.QueriedRenderedFeature?> features) {
    for (final feature in features) {
      if (feature == null) continue;
      final props = _featureProperties(feature.queriedFeature.feature);
      final locationId = props['locationId'];
      if (locationId is num) {
        log('GeoJsonMapLayerService: Location tapped: $locationId');
        onLocationTapped?.call(locationId.toInt());
        return true;
      }
    }
    return false;
  }

  Future<bool> _dispatchClusterTap(
    List<mapbox.QueriedRenderedFeature?> features,
  ) async {
    for (final feature in features) {
      if (feature == null) continue;
      final rawFeature = feature.queriedFeature.feature;
      final featureJson = _convertToStringDynamicMap(rawFeature);
      final geometry = _convertToStringDynamicMap(featureJson['geometry']);
      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2) continue;

      final center = LatLng(
        (coords[1] as num).toDouble(),
        (coords[0] as num).toDouble(),
      );
      final pointCount =
          (_featureProperties(rawFeature)['point_count'] as num?)?.toInt() ?? 0;

      double? expansionZoom;
      try {
        final result = await _map.getGeoJsonClusterExpansionZoom(
          config.sourceId,
          rawFeature,
        );
        expansionZoom = double.tryParse(result.value ?? '');
      } catch (e) {
        log('GeoJsonMapLayerService: Cluster expansion zoom unavailable: $e');
      }

      log('GeoJsonMapLayerService: Cluster tapped with $pointCount points');
      onClusterTapped?.call(center, pointCount, expansionZoom);
      return true;
    }
    return false;
  }

  Map<String, dynamic> _featureProperties(Map<String?, Object?> feature) {
    final properties = _convertToStringDynamicMap(feature)['properties'];
    return _convertToStringDynamicMap(properties);
  }

  /// Convert LocationModel list to GeoJSON FeatureCollection.
  Map<String, dynamic> _locationsToGeoJson(List<LocationModel> locations) {
    final features = <Map<String, dynamic>>[];

    for (final location in locations) {
      if (location.lat == null || location.lng == null) continue;

      final locationId = location.locationId;
      final infoSubtitle = _buildInfoSubtitle(location);
      final openStatusLabel = _openStatusLabel(location.openNow);

      features.add({
        'type': 'Feature',
        'properties': {
          'locationId': locationId,
          'name': _sanitizeMapLabel(location.name),
          'savedCount': location.savedCount ?? 0,
          'isBeenTo': _beenToLocationIds.contains(locationId),
          'openNow': location.openNow,
          'infoSubtitle': infoSubtitle,
          'openStatusLabel': openStatusLabel,
          'hasInfoLine': infoSubtitle.isNotEmpty || openStatusLabel.isNotEmpty,
          'bounceScale': _bounceScaleByLocationId[locationId] ?? 1.0,
          'iconKey': _buildLocationIconKey(location),
          'priority': _placementPriority(location),
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

  /// Mapbox places lower `symbol-sort-key` values first, so the most relevant
  /// places get the most negative key and win label space.
  double _placementPriority(LocationModel location) {
    final score = (location.matchScore ?? 0.0) * 1000 +
        location.friendSaves.length * 200 +
        (location.savedCount ?? 0).clamp(0, 100) * 10 +
        (location.rating ?? 0.0);
    return -score;
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

  List<Object> _nameLabelExpression() {
    return [
      'format',
      ['get', 'name'],
      <String, Object>{},
    ];
  }

  /// Name, then a muted "★4.5 · $$ · vibe · ● Open" line when there is one.
  List<Object> _detailLabelExpression() {
    final muted = _hex(pinit.PinitColors.mute);
    final detailStyle = {
      'font-scale': 0.84,
      'text-font': [
        'literal',
        _labelFontRegular,
      ],
      'text-color': muted,
    };
    final hasSubtitle = [
      '!=',
      [
        'coalesce',
        ['get', 'infoSubtitle'],
        ''
      ],
      ''
    ];
    final hasOpenStatus = [
      '!=',
      [
        'coalesce',
        ['get', 'openStatusLabel'],
        ''
      ],
      ''
    ];

    return [
      'case',
      ['get', 'hasInfoLine'],
      [
        'format',
        ['get', 'name'],
        <String, Object>{},
        '\n',
        <String, Object>{},
        [
          'coalesce',
          ['get', 'infoSubtitle'],
          ''
        ],
        detailStyle,
        [
          'case',
          ['all', hasSubtitle, hasOpenStatus],
          ' · ',
          '',
        ],
        detailStyle,
        ['case', hasOpenStatus, '● ', ''],
        {
          'font-scale': 0.7,
          'text-color': [
            'case',
            [
              '==',
              ['get', 'openNow'],
              true
            ],
            _hex(pinit.PinitColors.teal),
            _hex(pinit.PinitColors.accent),
          ],
        },
        [
          'coalesce',
          ['get', 'openStatusLabel'],
          ''
        ],
        detailStyle,
      ],
      _nameLabelExpression(),
    ];
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
    final colorHex = _colorHex(shadowStyle.color);
    final badgeType = location.markerBadgeType ?? 'none';
    final wavyScore = ((location.vibe?.wavyScore ?? 0.0) * 100).round();
    final bossmanScore = ((location.vibe?.bossmanScore ?? 0.0) * 100).round();
    final matchScore = ((location.matchScore ?? 0.0) * 100).round();
    final savedCount = location.savedCount ?? 0;

    // Friend-saves signature: distinct (avatar URLs, total count) tuples
    // need their own icon so the avatar stack actually appears on the map.
    // Without this, two locations differing only by friend attribution
    // collapse to one cached icon and lose their avatars.
    final friendSig = location.friendSaves.isEmpty
        ? 'fn0'
        : 'fn${location.friendSaves.length}_${location.friendSaves.take(3).map((f) => f.friendProfileImageUrl ?? f.friendId).join("|").hashCode}';

    return '$visualKey-${shadowStyle.key}-$colorHex-$badgeType-s$savedCount-w$wavyScore-b$bossmanScore-m$matchScore-$friendSig';
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

  String _hex(Color color) => '#${_colorHex(color)}';

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

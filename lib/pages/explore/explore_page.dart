import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/explore/explore_view_model.dart';
import 'package:login/pages/explore/widgets/explore_tile_sheet.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/services/geojson_map_layer_service.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:provider/provider.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  mapbox.MapboxMap? _mapController;
  GeoJsonMapLayerService? _geoJsonService;
  ExploreViewModel? _viewModel;

  @override
  void dispose() {
    _viewModel?.dispose();
    _geoJsonService?.dispose();
    super.dispose();
  }

  Future<void> _onMapCreated(mapbox.MapboxMap controller) async {
    _mapController = controller;

    final userId = context.read<UserDataProvider>().userId ?? '';

    // Initialize GeoJSON layer service for proper clustering and emoji pins
    _geoJsonService = GeoJsonMapLayerService(
      mapboxMap: controller,
      onLocationTapped: _onLocationTapped,
      onClusterTapped: _onClusterTapped,
    );

    // Set up tap handler on the map
    controller.setOnMapTapListener((mapbox.MapContentGestureContext gestureCtx) {
      final point = gestureCtx.point;
      _geoJsonService?.handleTapAtPoint(
        point.coordinates.lng.toDouble(),
        point.coordinates.lat.toDouble(),
      );
    });

    await _geoJsonService!.initialize();

    setState(() {
      _viewModel = ExploreViewModel(
        currentUserId: userId,
        mapController: _mapController,
      );

      // Listen for location changes → update map pins
      _viewModel!.addListener(_onViewModelChanged);
    });
  }

  void _onViewModelChanged() {
    final locations = _viewModel?.locations ?? [];
    _geoJsonService?.updateLocations(locations);
  }

  void _onLocationTapped(int locationId) {
    // TODO: scroll bottom sheet to tile
  }

  void _onClusterTapped(dynamic center, int pointCount) {
    if (_mapController != null && center != null) {
      _mapController!.flyTo(
        mapbox.CameraOptions(
          center: mapbox.Point(
              coordinates: mapbox.Position(center.longitude, center.latitude)),
          zoom: 15.0,
        ),
        mapbox.MapAnimationOptions(duration: 500),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──
          mapbox.MapWidget(
            styleUri: mapbox.MapboxStyles.LIGHT,
            cameraOptions: mapbox.CameraOptions(
              center: mapbox.Point(
                  coordinates: mapbox.Position(-122.431297, 37.773972)),
              zoom: 12,
            ),
            onMapCreated: _onMapCreated,
          ),

          if (_viewModel != null)
            ChangeNotifierProvider.value(
              value: _viewModel!,
              child: Stack(
                children: [
                  // ── Search bar + chips ──
                  const _ExploreSearchOverlay(),
                  // ── "Search this area" button ──
                  const _SearchThisAreaButton(),
                  // ── Bottom tile sheet ──
                  const ExploreTileSheet(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Glassmorphic search bar + filter chips
// ─────────────────────────────────────────────────────────────

class _ExploreSearchOverlay extends StatelessWidget {
  const _ExploreSearchOverlay();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExploreViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Column(
        children: [
          // ── Search bar ──
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.06),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: viewModel.searchController,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Explore a city, neighborhood...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    prefixIcon:
                        Icon(Icons.search, color: isDark ? Colors.white38 : Colors.grey),
                    suffixIcon: viewModel.isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : viewModel.searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: isDark ? Colors.white38 : Colors.grey),
                                onPressed: () {
                                  viewModel.searchController.clear();
                                  viewModel.hideSuggestions();
                                },
                              )
                            : null,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          // ── Category chips ──
          const SizedBox(height: 10),
          const _FilterChipRow(),

          // ── Autocomplete dropdown ──
          if (viewModel.showSuggestions && viewModel.suggestions.isNotEmpty)
            _buildSuggestionsDropdown(context, viewModel, isDark),
        ],
      ),
    );
  }

  Widget _buildSuggestionsDropdown(
      BuildContext context, ExploreViewModel viewModel, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 280),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: viewModel.suggestions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
              ),
              itemBuilder: (context, index) {
                final suggestion = viewModel.suggestions[index];
                final featureIcon = _featureIcon(suggestion.featureType);

                return ListTile(
                  leading: Text(featureIcon, style: const TextStyle(fontSize: 20)),
                  title: Text(
                    suggestion.name,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: suggestion.subtitle.isNotEmpty
                      ? Text(
                          suggestion.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        )
                      : null,
                  onTap: () => viewModel.onSuggestionSelected(suggestion),
                  dense: true,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _featureIcon(String? featureType) {
    switch (featureType) {
      case 'country':
        return '🌍';
      case 'region':
      case 'district':
        return '🗺️';
      case 'place':
        return '🏙️';
      case 'locality':
      case 'neighborhood':
        return '🏘️';
      case 'address':
        return '📮';
      case 'poi':
        return '📍';
      default:
        return '📍';
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  Filter chip row — horizontal scrollable
// ─────────────────────────────────────────────────────────────

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow();

  static const _filters = [
    _FilterDef('🍕', 'Pizza', 'cuisine', 'pizza'),
    _FilterDef('🍣', 'Sushi', 'cuisine', 'sushi'),
    _FilterDef('☕', 'Coffee', 'cuisine', 'coffee'),
    _FilterDef('🍰', 'Dessert', 'cuisine', 'dessert'),
    _FilterDef('🌙', 'Late Night', 'vibe', 'late_night'),
    _FilterDef('🥂', 'Date Night', 'vibe', 'romantic'),
    _FilterDef('🎵', 'Live Music', 'vibe', 'live_music'),
    _FilterDef('🏡', 'Outdoor', 'vibe', 'outdoor_dining'),
  ];

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExploreViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final f = _filters[index];
          final isActive = f.type == 'vibe'
              ? viewModel.activeVibeTagIds.contains(f.id)
              : viewModel.activeCuisineTagIds.contains(f.id);

          return _FilterChipWidget(
            emoji: f.emoji,
            label: f.label,
            isActive: isActive,
            isDark: isDark,
            onTap: () {
              if (f.type == 'vibe') {
                viewModel.toggleVibeFilter(f.id);
              } else {
                viewModel.toggleCuisineFilter(f.id);
              }
            },
          );
        },
      ),
    );
  }
}

class _FilterDef {
  final String emoji;
  final String label;
  final String type; // 'vibe' or 'cuisine'
  final String id;

  const _FilterDef(this.emoji, this.label, this.type, this.id);
}

class _FilterChipWidget extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChipWidget({
    required this.emoji,
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF6C5CE7).withValues(alpha: 0.85)
              : isDark
                  ? Colors.black.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? const Color(0xFF6C5CE7)
                : isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? Colors.white
                    : isDark
                        ? Colors.white70
                        : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  "Search this area" floating button
// ─────────────────────────────────────────────────────────────

class _SearchThisAreaButton extends StatelessWidget {
  const _SearchThisAreaButton();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExploreViewModel>();
    if (!viewModel.showSearchThisArea) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 110,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () async {
            final controller = viewModel.mapController;
            if (controller == null) return;

            final cameraState = await controller.getCameraState();
            final center = cameraState.center;
            final coords = center.coordinates;
            viewModel.searchThisArea(
              coords.lat.toDouble(),
              coords.lng.toDouble(),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded,
                        size: 16, color: Color(0xFF6C5CE7)),
                    const SizedBox(width: 6),
                    Text(
                      'Search this area',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

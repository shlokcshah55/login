import 'dart:async'; // Import for Timer
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Import for TickerProvider
import 'package:login/controllers/home_controller.dart';
import 'package:login/providers/device_location_provider.dart';
import 'package:login/providers/location_list_manager.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/themes/app_colors.dart'; // Import for theme colors
import 'package:login/themes/app_dimensions.dart'; // Import for dimensions
import 'package:login/themes/app_typography.dart'; // Import for typography
import 'package:login/widgets/LocationCarousel/filter_bar.dart';
import 'package:login/widgets/LocationCarousel/location_carousel.dart';
import 'package:login/widgets/pinit_map.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final HomeController homeController_;
  late final UserDataProvider userDataProvider_;
  late final LocationListManager locationListManager_;
  late final DeviceLocationProvider deviceLocationProvider_;
  late final MapStateProvider mapStateProvider_;

  bool showSearchOverlay = false;
  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController(viewportFraction: 0.80);
  MarkerId? _lastSelectedMarkerId;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    log("HomePage initState: Initializing providers and controller.");

    userDataProvider_ = context.read<UserDataProvider>();
    locationListManager_ = context.read<LocationListManager>();
    deviceLocationProvider_ = context.read<DeviceLocationProvider>();
    mapStateProvider_ = context.read<MapStateProvider>();

    homeController_ = HomeController(
      locationListManager: locationListManager_,
      mapStateProvider: mapStateProvider_,
      deviceLocationProvider: deviceLocationProvider_,
    );
    log("HomeController initialized");

    homeController_.fetchAndPlotRecommendedPins(null);
    deviceLocationProvider_.startLocationUpdates();

    SchedulerBinding.instance.addPostFrameCallback((_) {
      mapStateProvider_.addListener(_onSelectedMarkerChanged);
      _lastSelectedMarkerId = mapStateProvider_.selectedMarkerId;
    });
  }

  void _onSelectedMarkerChanged() {
    final newSelectedMarkerId = mapStateProvider_.selectedMarkerId;
    if (newSelectedMarkerId != _lastSelectedMarkerId) {
      _lastSelectedMarkerId = newSelectedMarkerId;

      // Debounce the scroll action
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 100), () {
        if (mounted && newSelectedMarkerId != null) {
          final locations = locationListManager_.currentItems.keys.toList();
          final index = locations
              .indexWhere((loc) => loc.locationId == newSelectedMarkerId.value);

          if (index != -1 &&
              _pageController.hasClients &&
              _pageController.page?.round() != index) {
            log("HomePage: Scrolling carousel to index $index for marker ${newSelectedMarkerId.value}");
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    log("HomePage dispose: Stopping location updates and disposing controllers.");
    deviceLocationProvider_.stopLocationUpdates();
    mapStateProvider_.removeListener(_onSelectedMarkerChanged);
    _pageController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locations =
        context.watch<LocationListManager>().currentItems.keys.toList();

    return Stack(
      children: [
        // Main UI
        Column(
          children: [
            _buildSearchBar(theme), // New search bar replacing header
            FilterBar(
              currentListType: locationListManager_.currentListType,
              onListTypeChanged: locationListManager_.setCurrentListType,
            ),
            Expanded(
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: CustomGoogleMap(),
                  ),
                  _buildMagicSearchButton(theme),
                ],
              ),
            ),
          ],
        ),

        // Carousel positioned higher above bottom bar
        Positioned(
          bottom:
              110, // Lift it higher above the floating navigation bar (which has 24px margin)
          left: 0,
          right: 0,
          child: LocationCarousel(
            pageController: _pageController,
            locations: locations,
          ),
        ),

        // Search Overlay
        if (showSearchOverlay) _buildSearchOverlay(theme),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(              padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSpacing.medium,
        bottom: AppSpacing.medium,
        left: AppSpacing.medium,
        right: AppSpacing.medium,
      ),
      color: theme.scaffoldBackgroundColor,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.radiusLarge,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 5,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),              Icon(
              Icons.search,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                onTap: () {
                  setState(() {
                    showSearchOverlay = true;
                  });
                },
                decoration: InputDecoration(
                  hintText: "Search locations...",
                  hintStyle: GoogleFonts.poppins(
                    color: AppColors.textHint,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
                readOnly:
                    true, // Make it non-editable to show search overlay instead
              ),
            ),
            Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.filter_list,
                  size: 20,
                  color: AppColors.onPrimary,
                ),
                onPressed: () {
                  // Show filter options
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMagicSearchButton(ThemeData theme) {
    return Positioned(
      top: 16.0,
      right: 16.0,
      child: FloatingActionButton(
        heroTag: "magicButton",
        onPressed: () {
          setState(() {
            showSearchOverlay = true;
          });
        },
        backgroundColor: AppColors.secondary, // Using your app's secondary color
        child: const Icon(
          Icons.auto_awesome,
          size: 28.0,
          color: AppColors.onSecondary,
        ),
      ),
    );
  }

  Widget _buildSearchOverlay(ThemeData theme) {
    final locationListManagerReader = context.read<LocationListManager>();
    return GestureDetector(
      onTap: () {
        setState(() {
          showSearchOverlay = false;
        });
      },
      child: Stack(
        children: [
          // Dimmed Background
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          // Search Box with Tags
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: 200,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Field with Enter Button
                  Row(
                    children: [
                      // Search Icon
                      Icon(Icons.search,
                          color: theme.textTheme.bodyMedium?.color),
                      const SizedBox(width: 10),
                      // Search Input
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: "Your next adventure...",
                            hintStyle: TextStyle(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.5),
                            ),
                            border: InputBorder.none,
                          ),
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                          onChanged: (value) {
                            // Optionally handle live input changes
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Enter Button
                      ElevatedButton(
                        onPressed: () {
                          String query = _searchController.text.trim();
                          if (query.isNotEmpty) {
                            log("HomePage: Triggering magic search for: $query");
                            locationListManagerReader.magicSearch(query);
                            setState(() {
                              showSearchOverlay = false;
                            });
                            _searchController.clear();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8.0,
                            horizontal: 16.0,
                          ),
                        ),
                        child: Text(
                          "Enter",
                          style: GoogleFonts.poppins(
                            fontSize: 14.0,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Tags Label
                  Text(
                    "Popular Cuisines",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Scrollable Tags
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildTag("Italian 🍕", theme),
                        _buildTag("Chinese 🥡", theme),
                        _buildTag("Mexican 🌮", theme),
                        _buildTag("Indian 🍛", theme),
                        _buildTag("Japanese 🍣", theme),
                        _buildTag("French 🥖", theme),
                        _buildTag("Thai 🍜", theme),
                        _buildTag("Korean 🍲", theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(right: 12.0),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

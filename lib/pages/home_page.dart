import 'dart:async'; // Import for Timer
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Import for TickerProvider
import 'package:login/controllers/home_controller.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/providers/nav_bar/visibility_provider.dart';
import 'package:login/themes/app_colors.dart'; // Import for theme colors
import 'package:login/widgets/home/LocationCarousel/filter_bar.dart';
import 'package:login/widgets/home/LocationCarousel/location_carousel.dart';
import 'package:login/widgets/home/pinit_map.dart';
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
  late final MapStateProvider mapStateProvider_;
  late final BottomNavVisibilityProvider bottomNavProvider_;

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
    mapStateProvider_ = context.read<MapStateProvider>();
    bottomNavProvider_ = context.read<BottomNavVisibilityProvider>();

    homeController_ = HomeController(
      locationListManager: locationListManager_,
      mapStateProvider: mapStateProvider_,
    );
    log("HomeController initialized");

    homeController_.fetchAndPlotRecommendedPins(null);
    locationListManager_.startLocationUpdates();

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
    locationListManager_.stopLocationUpdates();
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

    return Scaffold( // Using Scaffold for easier SafeArea and potential AppBar/BottomNav later
      // extendBodyBehindAppBar: true, // If you want map to go under status bar fully
      body: Stack(
        children: [
          // 1. Map (fills the screen) - with tap detection via GoogleMap's onTap
          Positioned.fill(
            child: PinitMap(
              onMapTap: () {
                // Tap anywhere on the map to show bottom nav temporarily
                bottomNavProvider_.showTemporarily();
              },
            ),
          ),

          // 2. Floating Header (Search Bar + Filter Bar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildFloatingHeaderControls(theme),
          ),

          // 3. Location Carousel (positioned higher above bottom bar) - wrapped with scroll detection
          Positioned(
            bottom: 30, // Adjusted, assuming no system bottom navigation bar for now
                       // If you have a bottom nav bar, increase this value
            left: 0,
            right: 0,
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                // Hide bottom nav when user starts scrolling the carousel
                if (scrollInfo is ScrollStartNotification) {
                  bottomNavProvider_.hide();
                }
                return false; // Allow the scroll to continue
              },
              child: LocationCarousel(
                pageController: _pageController,
                locations: locations,
              ),
            ),
          ),

          // 4. Magic Search Button (positioned before overlay so overlay appears on top)
          Positioned(
            top: 80,
            right: 20,
            child: _buildMagicSearchButton(theme),
          ),

          // 5. Search Overlay (appears on top of everything)
          if (showSearchOverlay) _buildSearchOverlay(theme),
        ],
      ),
    );
  }

  Widget _buildFloatingHeaderControls(ThemeData theme) {
    // This container provides a unified background for search and filter bars
    // and handles SafeArea.
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.background.withOpacity(0.95), // More opaque at the top
            theme.colorScheme.background.withOpacity(0.85), // Slightly more transparent
            theme.colorScheme.background.withOpacity(0.0), // Fades to transparent
          ],
          stops: const [0.0, 0.7, 1.0], // Control the gradient spread
        ),
      ),
      child: SafeArea( // Ensures content is not obscured by system UI (status bar)
        bottom: false, // No safe area needed at the bottom for this header
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 15.0, bottom: 8.0), // Space above and below filter bar
              child: FilterBar(
                currentListType: locationListManager_.currentListType,
                onListTypeChanged: locationListManager_.setCurrentListType,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildMagicSearchButton(ThemeData theme) {
    return SafeArea(
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
    return Stack(
      children: [
        // Dimmed Background with tap to close
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              setState(() {
                showSearchOverlay = false;
              });
            },
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ),
        // Magic Search Popover
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with title and close button
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: AppColors.secondary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Magic Search",
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.titleLarge?.color,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                          onPressed: () {
                            setState(() {
                              showSearchOverlay = false;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Description text
                    Text(
                      "Search in natural language like 'cozy Italian place with outdoor seating' or 'best ramen near me'",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Search Input Field
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (value) {
                          String query = value.trim();
                          if (query.isNotEmpty) {
                            log("HomePage: Triggering magic search for: $query");
                            locationListManagerReader.magicSearch(query);
                            setState(() {
                              showSearchOverlay = false;
                            });
                            _searchController.clear();
                          }
                        },
                        decoration: InputDecoration(
                          hintText: "Your next adventure...",
                          hintStyle: GoogleFonts.poppins(
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          icon: Icon(
                            Icons.search,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        style: GoogleFonts.poppins(
                          color: theme.textTheme.bodyMedium?.color,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Search Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
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
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          elevation: 0,
                        ),
                        child: Text(
                          "Search",
                          style: GoogleFonts.poppins(
                            fontSize: 16.0,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
  }

}

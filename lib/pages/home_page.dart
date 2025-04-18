import 'dart:async'; // Import for Timer
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Import for TickerProvider
import 'package:login/controllers/home_controller.dart';
// import 'package:login/pages/home/carousel/cards.dart'; // Remove unused GridItemWidget import
import 'package:login/providers/device_location_provider.dart';
import 'package:login/providers/location_list_manager.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/widgets/LocationCarousel/filter_bar.dart';
import 'package:login/widgets/LocationCarousel/location_carousel.dart'; // Import the new carousel
import 'package:login/widgets/pinit_map.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Import for MarkerId

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

// Add TickerProviderStateMixin for PageController listener debouncing
class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final HomeController homeController_;
  late final UserDataProvider userDataProvider_; // Add references for new providers if needed directly
  late final LocationListManager locationListManager_;
  late final DeviceLocationProvider deviceLocationProvider_;
  late final MapStateProvider mapStateProvider_;

  bool showSearchOverlay = false;
  final TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController(); // Controller for the carousel
  MarkerId? _lastSelectedMarkerId; // Track last selected marker to avoid redundant scrolls
  Timer? _debounce; // Timer for debouncing marker selection updates

  @override
  void initState() {
    super.initState();
    log("HomePage initState: Initializing providers and controller.");

    // Use read for initialization
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

    homeController_.fetchAndPlotRecommendedPins();
    deviceLocationProvider_.startLocationUpdates();

    // Add listener for MapStateProvider's selectedMarkerId AFTER the first frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      mapStateProvider_.addListener(_onSelectedMarkerChanged);
      // Initialize last selected marker ID
      _lastSelectedMarkerId = mapStateProvider_.selectedMarkerId;
    });
  }

  // Listener method to scroll carousel when selected marker changes
  void _onSelectedMarkerChanged() {
    final newSelectedMarkerId = mapStateProvider_.selectedMarkerId;
    if (newSelectedMarkerId != _lastSelectedMarkerId) {
      _lastSelectedMarkerId = newSelectedMarkerId;

      // Debounce the scroll action
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 100), () { // Adjust delay as needed
        if (mounted && newSelectedMarkerId != null) {
          final locations = locationListManager_.currentItems.keys.toList();
          final index = locations.indexWhere((loc) => loc.id == newSelectedMarkerId.value);

          if (index != -1 && _pageController.hasClients && _pageController.page?.round() != index) {
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
    mapStateProvider_.removeListener(_onSelectedMarkerChanged); // Remove listener
    _pageController.dispose(); // Dispose PageController
    _searchController.dispose();
    _debounce?.cancel(); // Cancel any pending debounce timer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watch LocationListManager to get locations for the carousel
    final locations = context.watch<LocationListManager>().currentItems.keys.toList();

    return Stack(
      children: [
        // Main UI
        Column(
          children: [
            _buildHeader(theme),
            FilterBar(
              // Provide the current type from the manager
              currentListType: locationListManager_.currentListType,
              // Pass the manager's method directly as the callback
              onListTypeChanged: locationListManager_.setCurrentListType,
            ),
            Expanded(
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: CustomGoogleMap(),
                  ),
                  _buildMagicSearchButton(theme),
                  // Add the LocationCarousel
                  LocationCarousel(
                    pageController: _pageController,
                    locations: locations,
                  ),
                ],
              ),
            ),
          ],
        ),
        // Search Overlay
        if (showSearchOverlay) _buildSearchOverlay(theme),
      ],
    );
  }

  Widget _buildMagicSearchButton(ThemeData theme) {
    return Positioned(
      top: 16.0, // Below the header
      right: 16.0,
      child: FloatingActionButton(
        heroTag: "magicButton",
        onPressed: () {
          setState(() {
            showSearchOverlay = true;
          });
        },
        backgroundColor: theme.floatingActionButtonTheme.backgroundColor, 
        child: Icon(
          Icons.auto_awesome, // Magic icon
          size: 28.0,
          color: theme.floatingActionButtonTheme.foregroundColor, 
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      color: theme.scaffoldBackgroundColor, // Use theme background color
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16.0,
        bottom: 16.0,
        left: 16.0,
        right: 16.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome Back!',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Use UserDataProvider to get user name, listen for changes
              Consumer<UserDataProvider>(
                builder: (context, userProvider, child) {
                  return Text(
                    userProvider.userData?["name"] ?? "User", // Access name safely
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  );
                }
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              // Handle pin action
            },
            icon: Icon(
              Icons.push_pin,
              size: 28,
              color: theme.textTheme.bodyLarge?.color, // Use theme text color
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSearchOverlay(ThemeData theme) {
    // Use read here as it's triggered by user action (setState)
    final locationListManagerReader = context.read<LocationListManager>();
    return GestureDetector(
      onTap: () {
        // Close the overlay when tapping outside the search area
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
                color: theme.cardTheme.color, // Use theme card color
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
                      Icon(Icons.search, color: theme.textTheme.bodyMedium?.color),
                      const SizedBox(width: 10),
                      // Search Input
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: "Your next adventure...",
                            hintStyle: TextStyle(
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
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
                            // Use the reader instance for magic search
                            locationListManagerReader.magicSearch(query);
                            // Close overlay
                            setState(() {
                              showSearchOverlay = false;
                            });
                            _searchController.clear(); // Clear field after search
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor, // Use theme primary color
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
                          style: TextStyle(
                            fontSize: 14.0,
                            color: theme.textTheme.bodyMedium?.color, // Use theme text color
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ), // Use theme text color
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

  // Helper Method to Create a Tag
  Widget _buildTag(String label, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(right: 12.0),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: theme.cardTheme.color?.withOpacity(0.8), // Use theme card color
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ), // Use theme text color
      ),
    );
  }
}

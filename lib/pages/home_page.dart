import 'dart:developer';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/controllers/home_controller.dart';
import 'package:login/providers/device_location_provider.dart'; // Import new providers
import 'package:login/providers/location_list_manager.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/widgets/pinit_map.dart';
import 'package:provider/provider.dart';
import 'package:login/pages/carousel/cards.dart'; // Keep GridItemWidget import

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // GoogleMapController? controller; // Controller managed by MapStateProvider now
  late final HomeController homeController_;
  // late final AppStateProvider appStateProvider_; // Remove old provider reference
  late final UserDataProvider userDataProvider_; // Add references for new providers if needed directly
  late final LocationListManager locationListManager_;
  late final DeviceLocationProvider deviceLocationProvider_;
  late final MapStateProvider mapStateProvider_;

  bool showSearchOverlay = false; // State for the search overlay
  final DraggableScrollableController _draggableScrollableController = DraggableScrollableController();
  double currentDraggableSize = 0.1; // Default draggable size

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    log("HomePage initState: Initializing providers and controller.");
    // print("home_page: api key: ${dotenv.env['GOOGLE_PLACE_API_KEY']}"); // Keep if needed

    // Get providers using listen: false as we are calling methods/passing them
    userDataProvider_ = Provider.of<UserDataProvider>(context, listen: false);
    locationListManager_ = Provider.of<LocationListManager>(context, listen: false);
    deviceLocationProvider_ = Provider.of<DeviceLocationProvider>(context, listen: false);
    mapStateProvider_ = Provider.of<MapStateProvider>(context, listen: false);

    // Instantiate HomeController with the required providers
    homeController_ = HomeController(
      locationListManager: locationListManager_,
      mapStateProvider: mapStateProvider_,
      deviceLocationProvider: deviceLocationProvider_,
      // userDataProvider: userDataProvider_, // Pass if needed by controller
    );
    log("HomeController initialized");

    // Fetch initial data - recommendations and start location updates
    // Use the new method name
    homeController_.fetchAndPlotRecommendedPins();

    // Start location updates using the dedicated provider
    deviceLocationProvider_.startLocationUpdates();

    // Listener for draggable sheet size
    _draggableScrollableController.addListener(() {
      // Check if mounted before calling setState
      if (mounted) {
        setState(() {
          currentDraggableSize = _draggableScrollableController.size;
        });
      }
    }); // End of addListener callback
  }

  @override
  void dispose() {
    log("HomePage dispose: Stopping location updates.");
    // Stop location updates using the dedicated provider
    deviceLocationProvider_.stopLocationUpdates();
    _draggableScrollableController.dispose(); // Dispose controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Access the theme

    return Stack(
      children: [
        // Main UI
        Column(
          children: [
            // Welcome Header
            _buildHeader(theme),
            Expanded(
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: CustomGoogleMap(),
                  ),
                  _buildMagicSearchButton(theme),
                  _buildDraggableSheet(theme),
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

Widget _buildDraggableSheet(ThemeData theme) {
  // Listen to LocationListManager for changes in currentItems
  return Consumer<LocationListManager>(
    builder: (context, locationManager, child) {
      final locations = locationManager.currentItems.keys.toList();
      final markers = locationManager.currentItems; // Get the map of locations to markers

      return DraggableScrollableSheet(
        controller: _draggableScrollableController, // Assign controller
        initialChildSize: 0.1, // Initial height
        minChildSize: 0.1, // Minimum height
        maxChildSize: 0.5, // Maximum height
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white, // Consider using theme.cardColor or similar
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.0),
            topRight: Radius.circular(16.0),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 10.0, spreadRadius: 0.5),
          ],
        ),
        child: GridView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(8.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // Number of items per row
            crossAxisSpacing: 20.0,
            mainAxisSpacing: 20.0,
            childAspectRatio: 0.8, // Adjust height vs width ratio
          ),
          itemCount: locations.length, // Use length from listened provider
          itemBuilder: (context, index) {
            final location = locations[index];
            final marker = markers[location]; // Get the corresponding marker

            // Pass necessary data to GridItemWidget
            // It might need LocationListManager, MapStateProvider etc. or specific data points
            // For now, just passing location and size. GridItemWidget might need refactoring too.
            return GridItemWidget(
              location: location,
              // Pass providers or specific data needed by GridItemWidget
              // e.g., locationListManager: locationListManager, mapStateProvider: mapStateProvider, etc.
              screenSize: currentDraggableSize,
              // Pass marker if needed by GridItemWidget for interactions
              marker: marker,
            );
          },
        ),
      );
      },
    );
   }
  );
}


  Widget _buildSearchOverlay(ThemeData theme) {
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
                            // Use LocationListManager for magic search
                            locationListManager_.magicSearch(query);
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

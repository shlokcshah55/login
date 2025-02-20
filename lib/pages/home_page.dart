import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/controllers/home_controller.dart';
import 'package:login/providers/app_data_provider.dart';
import 'package:login/widgets/pinit_map.dart';
import 'package:provider/provider.dart';
import 'package:login/pages/carousel/cards.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? controller;
  late final HomeController homeController_;
  late final AppStateProvider appStateProvider_;
  bool showSearchOverlay = false; // State for the search overlay
  final DraggableScrollableController _draggableScrollableController = DraggableScrollableController();
  double currentDraggableSize = 10.0;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print("home_page: api key: \${dotenv.env['GOOGLE_PLACE_API_KEY']}");

    appStateProvider_ = Provider.of<AppStateProvider>(context, listen: false);
    homeController_ = HomeController(appStateProvider_);
    log("home controller initialized");
    homeController_.plotRecommendedPins();

    appStateProvider_.startLocationUpdates();

    _draggableScrollableController.addListener(() {
      setState(() {
      double currentDraggableSize = _draggableScrollableController.size;
      });
    });
  }
  @override
  void dispose() {
    appStateProvider_.stopLocationUpdates();
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
                ), // Use theme text color
              ),
              Text(
                appStateProvider_.userData["name"] ?? "User",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7), // Use theme text color
                ),
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
  AppStateProvider appStateProvider_ = Provider.of<AppStateProvider>(context, listen: true);
  return DraggableScrollableSheet(
    initialChildSize: 0.1, // Initial height as a fraction of the screen height
    minChildSize: 0.1, // Minimum height
    maxChildSize: 0.5, // Maximum height
    builder: (context, scrollController) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
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
          itemCount: appStateProvider_.currentItems.length,
          itemBuilder: (context, index) {
            final location = appStateProvider_.currentItems.keys.toList()[index];
            return GridItemWidget(
              location: location,
              appStateProvider: appStateProvider_,
              screenSize: currentDraggableSize
            );
            //return homeController_.buildGridItem(location); // Updated method
          },
        ),
      );
    },
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
                          String value = _searchController.text.trim();
                          log("Searching for: $value");
                          appStateProvider_.magicSearch(value);
                          setState(() {
                            showSearchOverlay = false;
                          });
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
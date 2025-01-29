import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/controllers/home_controller.dart';
import 'package:login/providers/app_data_provider.dart';
import 'package:login/widgets/pinit_map.dart';
import 'package:provider/provider.dart';

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
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print("home_page: api key: ${dotenv.env['GOOGLE_PLACE_API_KEY']}");

    appStateProvider_ = Provider.of<AppStateProvider>(context, listen: false);
    homeController_ = HomeController(appStateProvider_);
    log("home controller initialized");
    // homeController_.plotRecommendedPins();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main UI
        Column(
          children: [
            // Welcome Header
            _buildHeader(),
            Expanded(
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: CustomGoogleMap(),
                  ),
                  _buildMagicSearchButton(),
                  _buildDraggableSheet(),
                ],
              ),
            ),
          ],
        ),
        // Search Overlay
        if (showSearchOverlay) _buildSearchOverlay(),
      ],
    );
  }

  Widget _buildMagicSearchButton() {
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
        backgroundColor: Colors.deepPurpleAccent,
        child: const Icon(
          Icons.auto_awesome, // Magic icon
          size: 28.0,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
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
              const Text(
                'Welcome Back!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                appStateProvider_.userData["name"] ?? "User",
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
          IconButton(
            onPressed: () {
              // Handle pin action
            },
            icon: const Icon(Icons.push_pin, size: 28, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableSheet() {
    AppStateProvider appStateProvider_ = Provider.of<AppStateProvider>(context, listen: true);
    return DraggableScrollableSheet(
      initialChildSize: 0.1, // Initial height as a fraction of the screen height
      minChildSize: 0.1, // Minimum height
      maxChildSize: 0.6, // Maximum height
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
          child: ListView.builder(
            controller: scrollController,
            shrinkWrap: true, // Ensures the list only takes up the space it needs
            physics: const ClampingScrollPhysics(), // Prevents over-scrolling
            itemCount: appStateProvider_.currentItems.length,
            itemBuilder: (context, index) {
              final location = appStateProvider_.currentItems.keys.toList()[index];
              return homeController_.buildCarouselItem(location);
            },
          ),
        );
      },
    );
  }


  Widget _buildSearchOverlay() {
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
                color: Colors.grey[200],
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
                      Icon(Icons.search, color: Colors.grey[600]),
                      const SizedBox(width: 10),
                      // Search Input
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: "Your next adventure...",
                            border: InputBorder.none,
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
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8.0,
                            horizontal: 16.0,
                          ),
                        ),
                        child: const Text(
                          "Enter",
                          style: TextStyle(
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
                  const Text(
                    "Popular Cuisines",
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Scrollable Tags
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildTag("Italian 🍕"),
                        _buildTag("Chinese 🥡"),
                        _buildTag("Mexican 🌮"),
                        _buildTag("Indian 🍛"),
                        _buildTag("Japanese 🍣"),
                        _buildTag("French 🥖"),
                        _buildTag("Thai 🍜"),
                        _buildTag("Korean 🍲"),
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
  Widget _buildTag(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 12.0),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14.0,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

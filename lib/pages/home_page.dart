import 'dart:developer';
import 'dart:ui';

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

  @override
  void initState() {
    super.initState();
    print("home_page: api key: ${dotenv.env['GOOGLE_PLACE_API_KEY']}");

    appStateProvider_ = Provider.of<AppStateProvider>(context, listen: false);
    homeController_ = HomeController(appStateProvider_);
    log("home controller initialized");
    homeController_.plotRecommendedPins();
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
                  // Google Map
                  const Positioned.fill(
                    child: CustomGoogleMap(),
                  ),
                  // Floating Button on Map
                  Positioned(
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
                  ),
                  // Draggable Carousel
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
    return Stack(
      children: [
        // Blurred Background
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ),
        // Search Widget
        Center(
          child: Container(
            padding: const EdgeInsets.all(16.0),
            margin: const EdgeInsets.symmetric(horizontal: 32.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10.0, spreadRadius: 0.5),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Search Location",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 16.0),
                TextField(
                  decoration: InputDecoration(
                    hintText: "Enter a location...",
                    prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    // Handle search input
                  },
                ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      showSearchOverlay = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text(
                    "Close",
                    style: TextStyle(fontSize: 16.0, color: Colors.white),
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

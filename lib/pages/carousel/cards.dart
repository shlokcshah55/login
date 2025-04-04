import 'dart:developer';
import 'dart:math' hide log; // Hide log from dart:math
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/location_model.dart';
import 'package:login/providers/device_location_provider.dart'; 
import 'package:login/providers/location_list_manager.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart'; 


class GridItemWidget extends StatefulWidget {
  final LocationModel location;
  final double screenSize;
  final Marker? marker; // Add marker for info window interaction

  // Remove appStateProvider, add required providers
  const GridItemWidget({
    Key? key,
    required this.location,
    required this.screenSize,
    this.marker, // Make marker optional
    // We will access providers via context inside the state
  }) : super(key: key);

  @override
  _GridItemWidgetState createState() => _GridItemWidgetState();
}

class _GridItemWidgetState extends State<GridItemWidget> {
  bool isFlipped = false;

  // Access providers via context within methods
  late final LocationListManager locationListManager;
  late final MapStateProvider mapStateProvider;
  late final DeviceLocationProvider deviceLocationProvider;
  // Instantiate GooglePlacesService - consider injecting via Provider if used elsewhere
  final GooglePlacesService googlePlacesService = GooglePlacesService();


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize providers here, where context is available safely
    locationListManager = Provider.of<LocationListManager>(context, listen: false);
    mapStateProvider = Provider.of<MapStateProvider>(context, listen: false);
    deviceLocationProvider = Provider.of<DeviceLocationProvider>(context, listen: false);
  }


  void _flipCard() async {
    final currentPosition = deviceLocationProvider.currentPosition; // Get current position

    // Check if position is available before flipping
    if (currentPosition == null || widget.location.position == null) {
       log("Cannot flip card: Missing current or location position.");
       // Optionally show a message to the user
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("Cannot show route, location unknown.")),
       );
       return;
    }

    setState(() {
      isFlipped = !isFlipped;
    });

    if (isFlipped) {
      _adjustCameraToFit(currentPosition, widget.location.position!);
      _drawRoute(currentPosition, widget.location.position!); // Corrected method name
    } else {
      mapStateProvider.clearPolylines(); // Use MapStateProvider
      // Focus back on user location if available
      mapStateProvider.focusOnUserLocation(currentPosition);
    }
  }

  void _handleTap() async {
     log("GridItem tapped: ${widget.location.name}");
     // Animate camera using MapStateProvider
     if (widget.location.position != null) {
       await mapStateProvider.animateCamera(
         CameraUpdate.newLatLng(widget.location.position!),
       );
       // Showing marker info window might need direct controller access or a new MapStateProvider method
       final controller = mapStateProvider.mapController;
       // Use the marker passed via the constructor
       final marker = widget.marker;
       if (controller != null && marker != null) {
          log("Showing info window for marker: ${marker.markerId.value}");
          controller.showMarkerInfoWindow(marker.markerId);
       } else {
          log("Cannot show info window: Controller or marker is null.");
       }
     } else {
        log("Cannot animate camera: Location position is null.");
     }
  }


  @override
  Widget build(BuildContext context) {
    // Use InkWell for tap effect and GestureDetector for long press
    return InkWell(
       key: ValueKey(widget.location.id), // Use a stable key
       onTap: _handleTap,
       child: GestureDetector(
         onLongPress: _flipCard,
         child: AnimatedSwitcher(
           duration: const Duration(milliseconds: 500),
           transitionBuilder: (Widget child, Animation<double> animation) {
             // Use a more robust flip animation like in HomeController example
             final rotate = Tween(begin: pi, end: 0.0).animate(animation);
             return AnimatedBuilder(
               animation: rotate,
               child: child,
               builder: (context, animatedChild) {
                 final isFront = animatedChild?.key == const ValueKey(false);
                 final rotationValue = isFront ? rotate.value : (pi - rotate.value);
                 return Transform(
                   transform: Matrix4.identity()
                     ..setEntry(3, 2, 0.001) // Perspective
                     ..rotateY(rotationValue),
                   alignment: Alignment.center,
                   child: animatedChild,
                 );
               },
             );
           },
           // Pass keys to children for AnimatedSwitcher to work correctly
           child: isFlipped ? _buildBackSide() : _buildFrontSide(),
         ),
       ),
    );
  }

  /// Builds the front side of the card
  Widget _buildFrontSide() {
    return Container(
      key: const ValueKey(false), // Key for front side
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        color: Colors.white,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 5.0, spreadRadius: 0.5),
        ],
      ),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.location.photoReference != null
              ? Image.network(
                  'https://maps.googleapis.com/maps/api/place/photo'
                  '?maxwidth=1600&photoreference=${widget.location.photoReference}'
                  '&key=${dotenv.env['GOOGLE_PLACE_API_KEY']}',
                  fit: BoxFit.cover,
                  height: 80,
                  width: double.infinity,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('$error');
                    return Container(
                      height: 80,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                    );
                  },
                )
              : Container(
                  height: 80,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: const Icon(Icons.restaurant, size: 40, color: Colors.grey),
                ),
          const SizedBox(height: 8.0),
          Text(
            widget.location.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              const Icon(Icons.star, size: 10, color: Colors.amber),
              Text(widget.location.rating?.toString() ?? 'N/A', style: const TextStyle(fontSize: 10)),
              const Spacer(),
              Text(
                widget.location.cuisine ?? 'Cuisine',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the back side of the card
  /// Builds the back side of the card
  Widget _buildBackSide() {
    final currentPosition = deviceLocationProvider.currentPosition; // Get current position for FutureBuilder

    return Container(
      key: const ValueKey(true), // Key for back side
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        color: Colors.blueGrey[50],
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 5.0, spreadRadius: 0.5),
        ],
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Walking Distance
          // Use the locally available currentPosition
          currentPosition != null ? FutureBuilder<String>(
            // Use the instantiated service
            future: googlePlacesService.getWalkingDuration(
              originLatLng: currentPosition,
              destinationPlaceId: widget.location.id,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_walk, size: 14, color: Colors.black54),
                    SizedBox(width: 6),
                    Text("..", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                );
              } else if (snapshot.hasError || !snapshot.hasData) {
                return const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_walk, size: 14, color: Colors.black54),
                    SizedBox(width: 6),
                    Text("?", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                );
              } else {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_walk, size: 14, color: Colors.black54),
                    const SizedBox(width: 6),
                    Text(
                      "${snapshot.data}",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              }
            },
          ) : const Row( // Placeholder if current location is null
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Icon(Icons.directions_walk, size: 14, color: Colors.black54),
                 SizedBox(width: 6),
                 Text("...", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
          const SizedBox(height: 8),

          // How many people saved it (Data comes from widget.location)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
              const SizedBox(width: 6),
              Text(
                "${widget.location.savedCount}",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 6),
              Text(
                widget.location.rating?.toString() ?? 'N/A',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Adjusts the camera using MapStateProvider
  void _adjustCameraToFit(LatLng userLocation, LatLng targetLocation) {
     mapStateProvider.focusOnBounds(userLocation, targetLocation); // Use provider method
  }

  // Remove the commented out _adjustCameraToFit method
/*
// void _adjustCameraToFit(LatLng userLocation, LatLng targetLocation) async {
//   if (widget.appStateProvider.mapController == null) return;

//   // Get screen size
//   final screenHeight = MediaQuery.of(context).size.height;
//   print(screenHeight);
//   // Get the height of the draggable sheet (percentage of screen height)
//   double draggableSheetHeightRatio = widget.screenSize.clamp(0.1, 0.5); // Between 0.1 and 0.5

//   // Calculate the visible map ratio
//   double visibleMapRatio = 1.0 - draggableSheetHeightRatio; // Remaining portion of the screen used for the map

//   // Compute the new bounds to ensure both locations are visible
//   LatLngBounds targetBounds = LatLngBounds(
//     southwest: LatLng(
//       min(userLocation.latitude, targetLocation.latitude),
//       min(userLocation.longitude, targetLocation.longitude),
//     ),
//     northeast: LatLng(
//       max(userLocation.latitude, targetLocation.latitude),
//       max(userLocation.longitude, targetLocation.longitude),
//     ),
//   );

//   // Base padding
//   double basePadding = 100;

//   // Adjust padding dynamically based on visible map area
//   double adjustedPadding = basePadding / visibleMapRatio; // If less of the map is visible, increase padding
//   log(adjustedPadding);
//   // Ensure padding stays within reasonable limits
//   double finalPadding = adjustedPadding.clamp(50, 300); // Prevent too much zoom-in or zoom-out

//   // Animate camera update with dynamic padding
//   widget.appStateProvider.mapController.animateCamera(
//     CameraUpdate.newLatLngBounds(targetBounds, finalPadding),
//   );
// }
*/ // Terminate comment correctly
//   if (widget.appStateProvider.mapController == null) return;

//   // Get screen size
//   final screenHeight = MediaQuery.of(context).size.height;
//   print(screenHeight);
//   // Get the height of the draggable sheet (percentage of screen height)
//   double draggableSheetHeightRatio = widget.screenSize.clamp(0.1, 0.5); // Between 0.1 and 0.5
  
//   // Calculate the visible map ratio
//   double visibleMapRatio = 1.0 - draggableSheetHeightRatio; // Remaining portion of the screen used for the map

//   // Compute the new bounds to ensure both locations are visible
//   LatLngBounds targetBounds = LatLngBounds(
//     southwest: LatLng(
//       min(userLocation.latitude, targetLocation.latitude),
//       min(userLocation.longitude, targetLocation.longitude),
//     ),
//     northeast: LatLng(
//       max(userLocation.latitude, targetLocation.latitude),
//       max(userLocation.longitude, targetLocation.longitude),
//     ),
//   );

//   // Base padding
//   double basePadding = 100;

//   // Adjust padding dynamically based on visible map area
//   double adjustedPadding = basePadding / visibleMapRatio; // If less of the map is visible, increase padding
//   log(adjustedPadding);
//   // Ensure padding stays within reasonable limits
//   double finalPadding = adjustedPadding.clamp(50, 300); // Prevent too much zoom-in or zoom-out

//   // Animate camera update with dynamic padding
//   widget.appStateProvider.mapController.animateCamera(
//     CameraUpdate.newLatLngBounds(targetBounds, finalPadding),
//   );
// }




  /// Draws a polyline route using MapStateProvider
  void _drawRoute(LatLng start, LatLng end) {
    final polyline = Polyline(
      polylineId: const PolylineId("dotted_route"), // Consider a more unique ID if needed
      points: [start, end],
      color: Colors.blue,
      width: 4,
      patterns: [PatternItem.dot, PatternItem.gap(10)], // Can be const now
    );

    mapStateProvider.setPolyline(polyline); // Use provider method
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/location_model.dart';
import 'package:login/providers/app_data_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class GridItemWidget extends StatefulWidget {
  final LocationModel location;
  final AppStateProvider appStateProvider;
  final double screenSize;

  const GridItemWidget({Key? key, required this.location, required this.appStateProvider, required this.screenSize})
      : super(key: key);

  @override
  _GridItemWidgetState createState() => _GridItemWidgetState();
}

class _GridItemWidgetState extends State<GridItemWidget> {
  bool isFlipped = false;

  void _flipCard() async {
    setState(() {
      isFlipped = !isFlipped;
    });

    if (isFlipped) {
      _adjustCameraToFit(widget.appStateProvider.currentPosition!, widget.location.position!);
      _drawRoute(widget.appStateProvider.currentPosition!, widget.location.position!);
    } else {
      widget.appStateProvider.removePolyline();
      widget.appStateProvider.focusOnUserLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _flipCard,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final rotate = Tween(begin: pi, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotate,
            child: child,
            builder: (context, child) {
              return Transform(
                transform: Matrix4.rotationY(rotate.value),
                alignment: Alignment.center,
                child: child,
              );
            },
          );
        },
        child: isFlipped ? _buildBackSide() : _buildFrontSide(),
      ),
    );
  }

  /// Builds the front side of the card
  Widget _buildFrontSide() {
    return Container(
      key: const ValueKey(false), // Ensure key is non-null
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
  Widget _buildBackSide() {
    return Container(
      key: const ValueKey(true), // Ensure key is non-null
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
          FutureBuilder<String>(
            future: GooglePlacesService().getWalkingDuration(
              originLatLng: widget.appStateProvider.currentPosition,
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
          ),
          const SizedBox(height: 8),

          // How many people saved it
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

 // Adjusts the camera to fit both the user's location and the target location
  void _adjustCameraToFit(LatLng userLocation, LatLng targetLocation) {

    double southWestLat = min(userLocation.latitude, targetLocation.latitude);
    double southWestLng = min(userLocation.longitude, targetLocation.longitude);
    double northeastLat = max(userLocation.latitude, targetLocation.latitude);
    double northeastLng = max(userLocation.longitude, targetLocation.longitude);
    
    double deltaLat = (northeastLat - southWestLat);
    double finalSouthWestLat = southWestLat - deltaLat;
    widget.appStateProvider.mapController.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            finalSouthWestLat,
            southWestLng
         ),
          northeast: LatLng(
            northeastLat,
            northeastLng
          ),
        ),
        100
      ),
    );
  }


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




  /// Draws a polyline route between two points with a dotted effect
  void _drawRoute(LatLng start, LatLng end) {
    final polyline = Polyline(
      polylineId: const PolylineId("dotted_route"),
      points: [start, end],
      color: Colors.blue,
      width: 4,
      patterns: [PatternItem.dot, PatternItem.gap(10)],
    );

    widget.appStateProvider.setPolyline(polyline);
  }
}

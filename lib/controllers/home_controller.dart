import 'dart:developer'; // Added for logging
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/locations.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:flutter/material.dart';
import 'dart:math' hide log; // Hide log from dart:math

class HomeController {
  // Keep references to the providers needed
  final LocationListManager locationListManager;
  final MapStateProvider mapStateProvider;
  // UserDataProvider might be needed if actions depend on user state
  // final UserDataProvider userDataProvider;

  // Service can be kept or injected if needed elsewhere
  final GooglePlacesService googlePlacesService = GooglePlacesService();

  // Constructor accepting the required providers
  HomeController({
    required this.locationListManager,
    required this.mapStateProvider,
    // required this.userDataProvider,
  });

  /// Fetches the user's current location using LocationListManager
  /// and potentially updates the map focus.
  Future<void> getUserLocationAndFocus() async {
    LatLng? position = await locationListManager.getCurrentLocation();
    if (position != null) {
      // Optionally focus the map on the user's location
      await mapStateProvider.focusOnUserLocation(position);
    } else {
      log("HomeController: Could not get user location.");
      // Handle cases where location couldn't be fetched (e.g., show message)
    }
  }

  /// Fetches recommended pins using the LocationListManager.
  /// Requires current location.
  Future<void> fetchAndPlotRecommendedPins(LatLng? location) async {
    const double defaultRadius = 5.0; // Match default from fetchRecommendedLocations

    if (location == null) {
      // Get device GPS location
      LatLng? currentLocation = locationListManager.currentPosition ??
          await locationListManager.getCurrentLocation();

      if (currentLocation != null) {
        await locationListManager.fetchRecommendedLocations(
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
          radiusKm: defaultRadius,
          vibeTagIds: locationListManager.vibeTagIds.isNotEmpty
              ? locationListManager.vibeTagIds
              : null,
          cuisineTagIds: locationListManager.cuisineTagIds.isNotEmpty
              ? locationListManager.cuisineTagIds
              : null,
        );
        // Update last searched area in MapStateProvider using values from locationListManager
        final lastCenter = locationListManager.lastSearchedCenter;
        final lastRadius = locationListManager.lastSearchedRadius;
        if (lastCenter != null && lastRadius != null) {
          mapStateProvider.setLastSearchedArea(lastCenter, lastRadius);
        }
        // Set the carousel items to recommended
        locationListManager.setCurrentListType(LocationListType.recommended);
      } else {
        log("HomeController: Cannot fetch recommendations without current location.");
        // Handle error - maybe show a message to the user
      }
    } else {
      await locationListManager.fetchRecommendedLocations(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusKm: defaultRadius,
        vibeTagIds: locationListManager.vibeTagIds.isNotEmpty
            ? locationListManager.vibeTagIds
            : null,
        cuisineTagIds: locationListManager.cuisineTagIds.isNotEmpty
            ? locationListManager.cuisineTagIds
            : null,
      );
      // Update last searched area in MapStateProvider using values from locationListManager
      final lastCenter = locationListManager.lastSearchedCenter;
      final lastRadius = locationListManager.lastSearchedRadius;
      if (lastCenter != null && lastRadius != null) {
        mapStateProvider.setLastSearchedArea(lastCenter, lastRadius);
      }
      locationListManager.setCurrentListType(LocationListType.recommended);
    }
  }

  // buildCarouselItem seems obsolete as HomePage uses GridItemWidget directly. Removing it.

  /// Builds the grid item for the draggable sheet.
  /// Note: This logic was moved mostly into HomePage's _buildGridItem.
  /// This controller method might become redundant or simplified.
  /// Keeping structure for reference, but likely needs removal/refactoring based on HomePage usage.
  Widget buildGridItem(BuildContext context, LocationModel location) {
    // Access providers via context if this becomes part of a widget,
    // otherwise use the injected providers.
    // final locationListManager = context.read<LocationListManager>();
    // final mapStateProvider = context.read<MapStateProvider>();
    // final deviceLocationProvider = context.read<DeviceLocationProvider>();

    ValueNotifier<bool> isFlipped = ValueNotifier(false);

    return GestureDetector(
      onLongPress: () async {
        isFlipped.value = !isFlipped.value;
        final currentPosition = locationListManager.currentPosition;

        if (isFlipped.value && currentPosition != null) {
          _adjustCameraToFit(currentPosition, location.position!);
          _drawRoute(currentPosition, location.position!);
        } else {
          mapStateProvider.clearPolylines(); // Use MapStateProvider
        }
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: isFlipped,
        builder: (context, flipped, child) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              final rotate = Tween(begin: pi, end: 0.0).animate(animation);
              return AnimatedBuilder(
                animation: rotate,
                child: child,
                builder: (context, child) {
                  // Ensure child key is checked correctly
                  final isFront = child?.key == const ValueKey(false);
                  final rotationValue = isFront
                      ? rotate.value
                      : (pi - rotate.value); // Adjust rotation for back

                  // Prevent interaction during flip
                  return IgnorePointer(
                    ignoring: animation.status == AnimationStatus.forward ||
                        animation.status == AnimationStatus.reverse,
                    child: Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // Perspective
                        ..rotateY(rotationValue),
                      alignment: Alignment.center,
                      child: child,
                    ),
                  );
                },
              );
            },
            // Use location.locationId for a stable key
            child: InkWell(
              key: ValueKey<bool>(
                  flipped), // Key is important for AnimatedSwitcher
              onTap: () async {
                // Animate camera using MapStateProvider
                await mapStateProvider.animateCamera(
                  CameraUpdate.newLatLng(location.position!),
                );
                // Showing marker info window might need direct controller access or a new MapStateProvider method
                final controller = mapStateProvider.mapController;
                final marker = locationListManager.currentItems[location];
                if (controller != null && marker != null) {
                  controller.showMarkerInfoWindow(marker.markerId);
                }
              },
              child: flipped
                  ? _buildBackSide(context, location)
                  : _buildFrontSide(location), // Pass context if needed
            ),
          );
        },
      ),
    );
  }

  Widget _buildFrontSide(LocationModel location) {
    // This seems mostly UI logic, could live entirely in the widget itself (HomePage)
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
          location.photoReference != null
              ? Image.network(
                  location.photoReference!,
                  fit: BoxFit.cover,
                  height: 80,
                  width: double.infinity,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    log("Error loading image for ${location.name}: $error");
                    return Container(
                      height: 80,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(FeatherIcons.image,
                          size: 50, color: Colors.grey),
                    );
                  },
                )
              : Container(
                  height: 80,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: const Icon(FeatherIcons.mapPin,
                      size: 40, color: Colors.grey),
                ),
          const SizedBox(height: 8.0),
          Text(
            location.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              const Icon(FeatherIcons.star, size: 10, color: Colors.amber),
              Text(location.rating?.toString() ?? 'N/A',
                  style: const TextStyle(fontSize: 10)),
              const Spacer(),
              Text(
                location.cuisine ?? 'Cuisine',
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

  Widget _buildBackSide(BuildContext context, LocationModel location) {
    // This seems mostly UI logic, could live entirely in the widget itself (HomePage)
    // Access providers if needed for data like currentPosition
    final currentPosition = locationListManager.currentPosition;

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
          // Walking Distance (Using FutureBuilder)
          // Ensure currentPosition is available before building
          currentPosition != null
              ? FutureBuilder<String>(
                  // Pass the current position from the provider
                  future: googlePlacesService.getWalkingDuration(
                    originLatLng: currentPosition,
                    destinationPlaceId: location.locationId.toString(),
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(FeatherIcons.navigation,
                              size: 14, color: Colors.black54),
                          SizedBox(width: 6),
                          Text("..",
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      );
                    } else if (snapshot.hasError || !snapshot.hasData) {
                      return const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(FeatherIcons.navigation,
                              size: 14, color: Colors.black54),
                          SizedBox(width: 6),
                          Text("?",
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      );
                    } else {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(FeatherIcons.navigation,
                              size: 14, color: Colors.black54),
                          const SizedBox(width: 6),
                          Text(
                            "${snapshot.data}",
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      );
                    }
                  },
                )
              : const Row(
                  // Placeholder if current location is null
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_walk,
                        size: 14, color: Colors.black54),
                    SizedBox(width: 6),
                    Text("...",
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
          const SizedBox(height: 8),

          // How many people saved it (location.savedCount comes from the model)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(FeatherIcons.heart, size: 14, color: Colors.redAccent),
              const SizedBox(width: 6),
              Text(
                "${location.savedCount ?? 0}",
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(FeatherIcons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 6),
              Text(
                location.rating?.toString() ?? 'N/A',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Adjusts camera using MapStateProvider
  void _adjustCameraToFit(LatLng currentLocation, LatLng targetLocation) {
    mapStateProvider.focusOnBounds(
        currentLocation, targetLocation); // Use provider method
  }

  /// Draws route using MapStateProvider
  void _drawRoute(LatLng start, LatLng end) async {
    // TODO: Consider fetching actual route points from a directions service
    // For now, just draws a straight dotted line
    List<LatLng> polylinePoints = [start, end];

    final polyline = Polyline(
      polylineId:
          const PolylineId('dotted_route'), // Use a constant or unique ID
      points: polylinePoints,
      color: Colors.blue,
      width: 4,
      // Remove const because PatternItem.gap is not a const constructor
      patterns: [PatternItem.dot, PatternItem.gap(10)],
    );

    mapStateProvider.setPolyline(polyline); // Use provider method
  }

// buildGridItem method from before is now largely handled within HomePage.
// Keeping the old commented code for reference during cleanup might be useful,
// but it should eventually be removed.
/*
//   Widget buildGridItem(LocationModel location) {
//   return InkWell(
//     onTap: () async {
//       // Handle tap action
//       await appStateProvider.mapController.animateCamera(
//         CameraUpdate.newLatLng(location.position!),
//       );
//       appStateProvider.mapController.showMarkerInfoWindow(
//         appStateProvider.currentItems[location]!.markerId,
//       );
//     },
//     child: Container(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12.0),
//         color: Colors.white,
//         boxShadow: const [
//           BoxShadow(color: Colors.black26, blurRadius: 5.0, spreadRadius: 0.5),
//         ],
//       ),
//       padding: const EdgeInsets.all(8.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Display image or placeholder
//           location.photoReference != null
//               ? Image.network(
//                   'https://maps.googleapis.com/maps/api/place/photo'
//                   '?maxwidth=1600&photoreference=${location.photoReference}'
//                   '&key=${dotenv.env['GOOGLE_PLACE_API_KEY']}',
//                   fit: BoxFit.cover,
//                   height: 80,
//                   width: double.infinity,
//                   loadingBuilder: (context, child, progress) {
//                     if (progress == null) return child;
//                     return const Center(child: CircularProgressIndicator());
//                   },
//                   errorBuilder: (context, error, stackTrace) {
//                     return Container(
//                       height: 80,
//                       width: double.infinity,
//                       color: Colors.grey[300],
//                       child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
//                     );
//                   },
//                 )
//               : Container(
//                   height: 80,
//                   width: double.infinity,
//                   color: Colors.grey[300],
//                   child: const Icon(Icons.restaurant, size: 40, color: Colors.grey),
//                 ),
//           const SizedBox(height: 8.0),
//           // Restaurant Name
//           Text(
//             location.name,
//             style: const TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.bold,
//             ),
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//           ),
//           // Rating and Cuisine
//           Row(
//             children: [
//               const Icon(Icons.star, size: 10, color: Colors.amber),
//               Text(
//                 location.rating?.toString() ?? 'N/A',
//                 style: const TextStyle(fontSize: 10),
//               ),
//               const Spacer(),
//               Text(
//                 location.cuisine ?? 'Cuisine',
//                 style: const TextStyle(fontSize: 10, color: Colors.grey),
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ],
//           ),
//         ],
//       ),
//     ),
//   );
// }
*/ // Terminate the comment correctly
}

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/location_model.dart';
import 'package:login/providers/app_data_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:login/widgets/carousel_tile.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeController {
  final AppStateProvider appStateProvider;
  final GooglePlacesService googlePlacesService = GooglePlacesService();
  late GoogleMapController mapController = appStateProvider.mapController; 

  HomeController(this.appStateProvider);

  Future<void> getUserLocation() async {
    PermissionStatus permission = await Permission.locationWhenInUse.request();
    if (permission == PermissionStatus.granted) {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      appStateProvider.updateCurrentPosition(
        LatLng(position.latitude, position.longitude),
      );
    }
  }
  



  Future<void> plotRecommendedPins() async {
    // stock recommendation data
    var recommendations = await googlePlacesService.fetchNearbyPlaces(
      latitude: 50.819788,
      longitude: -0.122921,
      placeType: "restaurant",
    );

    appStateProvider.addRecommendedLocations(recommendations);
    // Set the carousel items 
    appStateProvider.setCurrentItems('recommended');
  }

  CarouselTile buildCarouselItem(LocationModel location) {
    return CarouselTile(
      item: location,
      preference: location.preference,
      onRemove: () {
        appStateProvider.removeLocation(location);
      },
      onSave: () {
        appStateProvider.saveLocation(location);  
        appStateProvider.removeLocation(location);
      },
      onTap: () async {
        // Handle tap action
        await appStateProvider.controllerFuture;
        appStateProvider.mapController.animateCamera(
          CameraUpdate.newLatLng(location.position!),
        );
        appStateProvider.mapController.showMarkerInfoWindow(appStateProvider.currentItems[location]!.markerId);
      },
    );
  }

  Widget buildGridItem(LocationModel location) {
    ValueNotifier<bool> isFlipped = ValueNotifier(false);

    return GestureDetector(
      onLongPress: () async {
        isFlipped.value = !isFlipped.value;

        if (isFlipped.value) {
          _adjustCameraToFit(appStateProvider.currentPosition!, location.position!);
          _drawRoute(appStateProvider.currentPosition!, location.position!);
        } else {
          appStateProvider.removePolyline();
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
                  final isFront = (child != null && child.key is ValueKey<bool>) ? (child.key as ValueKey<bool>).value : false;
                  return Transform(
                    transform: Matrix4.rotationY(isFront ? rotate.value : -rotate.value),
                    alignment: Alignment.center,
                    child: child,
                  );
                },
              );
            },
          child: InkWell(
            key: ValueKey(flipped), // Key is important for AnimatedSwitcher
            onTap: () async {
              // Keep original tap functionality
              await appStateProvider.mapController.animateCamera(
                CameraUpdate.newLatLng(location.position!),
              );
              appStateProvider.mapController.showMarkerInfoWindow(
                appStateProvider.currentItems[location]!.markerId,
              );
            },
            child: flipped ? _buildBackSide(location) : _buildFrontSide(location),
          ),
        );
      },
    ),
  );
} 

Widget _buildFrontSide(LocationModel location) {
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
        location.photoReference != null
            ? Image.network(
                'https://maps.googleapis.com/maps/api/place/photo'
                '?maxwidth=1600&photoreference=${location.photoReference}'
                '&key=${dotenv.env['GOOGLE_PLACE_API_KEY']}',
                fit: BoxFit.cover,
                height: 80,
                width: double.infinity,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
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
          location.name,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Row(
          children: [
            const Icon(Icons.star, size: 10, color: Colors.amber),
            Text(location.rating?.toString() ?? 'N/A', style: const TextStyle(fontSize: 10)),
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

Widget _buildBackSide(LocationModel location) {
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
        // Walking Distance (Using FutureBuilder)
        FutureBuilder<String>(
          future: googlePlacesService.getWalkingDuration(
            originLatLng: appStateProvider.currentPosition,
            destinationPlaceId: location.id,
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
              "${location.savedCount}",
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
              location.rating?.toString() ?? 'N/A',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    ),
  );
}

void _adjustCameraToFit(LatLng currentLocation, LatLng targetLocation) {
  appStateProvider.mapController.animateCamera(
    CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(
          min(currentLocation.latitude, targetLocation.latitude),
          min(currentLocation.longitude, targetLocation.longitude), 
        ), 
        northeast: LatLng(
          max(currentLocation.latitude, targetLocation.latitude),
          max(currentLocation.longitude, targetLocation.longitude)
        ),
      ),
      100,
      ),
    );
}

void _drawRoute(LatLng start, LatLng end) async {
  List<LatLng> polylinePoints = [start, end];

  final polyline = Polyline(
    polylineId: const PolylineId('dotted_route'),
    points: polylinePoints,
    color: Colors.blue,
    width: 4,
    patterns: [PatternItem.dot, PatternItem.gap(10)],);

  appStateProvider.setPolyline(polyline);
}


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


}

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/location_model.dart';
import 'package:login/providers/app_data_provider.dart';
import 'package:login/services/google_place_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  return InkWell(
    onTap: () async {
      // Handle tap action
      await appStateProvider.mapController.animateCamera(
        CameraUpdate.newLatLng(location.position!),
      );
      appStateProvider.mapController.showMarkerInfoWindow(
        appStateProvider.currentItems[location]!.markerId,
      );
    },
    child: Container(
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
          // Display image or placeholder
          location.photoReference != null
              ? Image.network(
                  'https://maps.googleapis.com/maps/api/place/photo'
                  '?maxwidth=400&photoreference=${location.photoReference}'
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
          // Restaurant Name
          Text(
            location.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Rating and Cuisine
          Row(
            children: [
              const Icon(Icons.star, size: 14, color: Colors.amber),
              Text(
                location.rating?.toString() ?? 'N/A',
                style: const TextStyle(fontSize: 12),
              ),
              const Spacer(),
              Text(
                location.cuisine ?? 'Cuisine',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}


}

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/location_model.dart';
import 'package:login/providers/app_data_provider.dart';
import 'package:login/services/google_place_service.dart';

import 'package:geolocator/geolocator.dart';
import 'package:login/widgets/CarouselTile.dart';
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

  Future<void> plotKnownPins() async {
    for (var location in appStateProvider.savedLocations) {
      appStateProvider.addMarker(location);
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

    for (var location in recommendations) {
      appStateProvider.addMarker(location);
    }
  }

  CarouselTile buildCarouselItem(LocationModel location) {
    return CarouselTile(
      item: location,
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
        for (Marker marker in appStateProvider.markers) {
          if (marker.markerId.value == location.id) {
            appStateProvider.mapController.showMarkerInfoWindow(marker.markerId);
            break;
          }
        }
      },
    );
  }

}

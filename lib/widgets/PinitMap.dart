import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/assets/constants.dart';
import 'package:login/providers/app_data_provider.dart';
import 'package:provider/provider.dart';

class CustomGoogleMap extends StatelessWidget {
  static const double DEFAULT_LAT = 51.4988;
  static const double DEFAULT_LNG = -0.1749;
  
  final String mapStyle;

  const CustomGoogleMap({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);

    return GoogleMap(
      style: MAPSTYLE,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      zoomControlsEnabled: false,
      initialCameraPosition: CameraPosition(
        target: appStateProvider.currentPosition ?? const LatLng(DEFAULT_LAT, DEFAULT_LNG),  // Default to Imperial 
        zoom: 15,
      ),
      onMapCreated: (controller) {
        appStateProvider.setMapController(controller);
      },
      markers: appStateProvider.markers,
    );
  }
}

/// Extension to copy a Marker with new values
/// When we make custom markers this gonna develop much more 
extension MarkerCopyWith on Marker {
    Marker copyWith({
      BitmapDescriptor? iconParam,
      LatLng? positionParam,
      String? titleParam,
      String? snippetParam,
    }) {
      return Marker(
        markerId: this.markerId,
        position: positionParam ?? this.position,
        icon: iconParam ?? this.icon,
        infoWindow: InfoWindow(
          title: titleParam ?? this.infoWindow.title,
          snippet: snippetParam ?? this.infoWindow.snippet,
        ),
        onTap: this.onTap,
      );
    }
  }
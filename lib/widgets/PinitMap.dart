import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/providers/app_data_provider.dart';
import 'package:provider/provider.dart';

class CustomGoogleMap extends StatelessWidget {
  final String mapStyle;
  final LatLng? currentPosition;
  final Set<Marker> markers;
  final Function(GoogleMapController) onMapCreated;

  const CustomGoogleMap({
    super.key,
    required this.mapStyle,
    required this.currentPosition,
    required this.markers,
    required this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);

    return GoogleMap(
      style: mapStyle,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      zoomControlsEnabled: false,
      initialCameraPosition: CameraPosition(
        target: currentPosition ?? const LatLng(51.4988, -0.1749),  // Default to Imperial 
        zoom: 15,
      ),
      onMapCreated: (controller) {
        appStateProvider.setMapController(controller);
      },
      markers: markers,
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
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/assets/constants.dart';
// import 'package:login/providers/app_data_provider.dart'; // Remove old
import 'package:login/providers/device_location_provider.dart'; // Add new
import 'package:login/providers/location_list_manager.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:provider/provider.dart';

class CustomGoogleMap extends StatefulWidget {
  static const double DEFAULT_LAT = 51.4988;
  static const double DEFAULT_LNG = -0.1749;

  const CustomGoogleMap({super.key});

  @override
  _CustomGoogleMapState createState() => _CustomGoogleMapState();
}

class _CustomGoogleMapState extends State<CustomGoogleMap> {
  BitmapDescriptor? _customMarkerIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomMarker(); // Load custom marker icon
  }

  Future<void> _loadCustomMarker() async {
    print('doing');
    final BitmapDescriptor bitmapDescriptor = await _getCustomMarker('lib/assets/pinitIcon.png');
    print('fdsfok');
    setState(() {
      _customMarkerIcon = bitmapDescriptor;
    });
  }

  /// Convert an asset image to a BitmapDescriptor
  Future<BitmapDescriptor> _getCustomMarker(String assetPath) async {
    print('doingfdsf');
    final ByteData data = await rootBundle.load(assetPath);
    print(data);
    final Uint8List bytes = data.buffer.asUint8List();

    final ui.Codec codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: 30, // Adjust this width to make it smaller
  );

  final ui.FrameInfo frameInfo = await codec.getNextFrame();
  final ByteData? resizedData = await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(resizedData!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    // Listen to providers needed for map display
    final locationListManager = context.watch<LocationListManager>();
    final deviceLocationProvider = context.watch<DeviceLocationProvider>();
    final mapStateProvider = context.watch<MapStateProvider>(); // Watch for polyline/selection changes
    final mapStateReader = context.read<MapStateProvider>(); // Use read for onTap callback

    // Create markers with onTap handlers
    final Set<Marker> markers = locationListManager.currentItems.entries.map((entry) {
      final location = entry.key; // LocationModel
      final originalMarker = entry.value; // Original Marker

      // Create a new marker with the onTap handler
      return originalMarker.copyWith(
        onTapParam: () {
          print("Marker tapped: ${originalMarker.markerId.value}"); // Debug log
          mapStateReader.setSelectedMarkerId(originalMarker.markerId);
        },
      );
    }).toSet();


    // Get current position from DeviceLocationProvider
    final currentPosition = deviceLocationProvider.currentPosition;

    // Add user's current location marker if available
    if (currentPosition != null && _customMarkerIcon != null) {
      // print('Adding current location marker'); // Keep for debugging if needed
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentPosition,
          icon: _customMarkerIcon!, // Use the custom marker icon
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    return GoogleMap(
      style: MAPSTYLE,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false, // We add our own marker
      compassEnabled: false,
      zoomControlsEnabled: false,
      initialCameraPosition: CameraPosition(
        // Use current position from DeviceLocationProvider for initial target
        target: currentPosition ?? const LatLng(CustomGoogleMap.DEFAULT_LAT, CustomGoogleMap.DEFAULT_LNG),
        zoom: 15,
      ),
      onMapCreated: (controller) {
        // Set the controller in the MapStateProvider
        // Use context.read as this is a one-time action
        context.read<MapStateProvider>().setMapController(controller);
      },
      markers: markers,
      // Get polylines from MapStateProvider
      polylines: mapStateProvider.polylines,
    );
  }
}

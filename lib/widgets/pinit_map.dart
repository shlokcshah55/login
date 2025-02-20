import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/assets/constants.dart';
import 'package:login/providers/app_data_provider.dart';
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
    final appStateProvider = Provider.of<AppStateProvider>(context, listen: true);
    final Set<Marker> markers = {...appStateProvider.currentItems.values.toSet()};

    if (appStateProvider.currentPosition != null && _customMarkerIcon != null) {
      print('here');
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: appStateProvider.currentPosition!,
          icon: _customMarkerIcon!, // Use the custom marker icon
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    return GoogleMap(
      style: MAPSTYLE,
      mapToolbarEnabled: false,
      myLocationButtonEnabled: false,
      compassEnabled: false,
      zoomControlsEnabled: false,
      initialCameraPosition: CameraPosition(
        target: appStateProvider.currentPosition ?? const LatLng(CustomGoogleMap.DEFAULT_LAT, CustomGoogleMap.DEFAULT_LNG),
        zoom: 15,
      ),
      onMapCreated: (controller) {
        appStateProvider.setMapController(controller);
      },
      markers: markers,
      polylines: appStateProvider.polylines,
    );
  }
}

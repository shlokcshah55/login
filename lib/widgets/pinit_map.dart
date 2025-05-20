import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/assets/constants.dart';
import 'package:login/controllers/home_controller.dart';
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
    final BitmapDescriptor bitmapDescriptor =
        await _getCustomMarker('lib/assets/pinitIcon.png');
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
    final ByteData? resizedData =
        await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(resizedData!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    // Listen to providers needed for map display
    final locationListManager = context.watch<LocationListManager>();
    final deviceLocationProvider = context.watch<DeviceLocationProvider>();
    final mapStateProvider = context
        .watch<MapStateProvider>(); // Watch for polyline/selection changes
    final mapStateReader =
        context.read<MapStateProvider>(); // Use read for onTap callback

    // Create markers with onTap handlers
    final Set<Marker> markers =
        locationListManager.currentItems.entries.map((entry) {
      final originalMarker = entry.value; // Original Marker

      // Create a new marker with the onTap handler and no info window
      return originalMarker.copyWith(
        onTapParam: () {
          print("Marker tapped: ${originalMarker.markerId.value}"); // Debug log
          mapStateReader.setSelectedMarkerId(originalMarker.markerId);

          // Find the index of the location in the current items list
          final index = locationListManager.currentItems.keys
              .toList()
              .indexWhere((loc) =>
                  loc.locationId.toString() == originalMarker.markerId.value);

          if (index != -1) {
            // Animate to the corresponding item in the carousel
            mapStateProvider.animateToCarouselItem(index);
          }
        },
        infoWindowParam:
            const InfoWindow(title: ""), // Empty info window to prevent popup
      );
    }).toSet();

    // Get current position from DeviceLocationProvider
    final currentPosition = deviceLocationProvider.currentPosition;

    // Get the current list type from location list manager
    final isRecommendedTab =
        locationListManager.currentListType == LocationListType.recommended;

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

    return Stack(
      children: [
        GoogleMap(
          style: MAPSTYLE,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false, // We add our own marker
          compassEnabled: false,
          zoomControlsEnabled: false,
          initialCameraPosition: CameraPosition(
            // Use current position from DeviceLocationProvider for initial target
            target: currentPosition ??
                const LatLng(
                    CustomGoogleMap.DEFAULT_LAT, CustomGoogleMap.DEFAULT_LNG),
            zoom: 15,
          ),
          onMapCreated: (controller) {
            // Set the controller in the MapStateProvider
            final mapState = context.read<MapStateProvider>();
            mapState.setMapController(controller);

            // Initialize the lastFocusedUserLocation with the current position
            // or the initial camera position if no current position is available
            final deviceLocation = context.read<DeviceLocationProvider>();
            LatLng initialLocation = deviceLocation.currentPosition ??
                LatLng(
                    CustomGoogleMap.DEFAULT_LAT, CustomGoogleMap.DEFAULT_LNG);

            print('Setting initial location in onMapCreated: $initialLocation');
            mapState.setLastFocusedUserLocation(initialLocation);
          },
          onCameraMove: (CameraPosition position) {
            // Update the map center in MapStateProvider when camera moves
            mapStateProvider.updateMapCenter(position);
          },
          onCameraIdle: () {
            // Optional: Add any actions to perform when camera stops moving
          },
          markers: markers,
          // Get polylines from MapStateProvider
          polylines: mapStateProvider.polylines,
          
        ),

        // "Search this area" button - only show on recommended tab
        if (mapStateProvider.showSearchThisAreaButton && isRecommendedTab)
          Positioned(
            top: 16.0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      )
                    ]),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20.0),
                    onTap: () {
                      // Call searchThisArea when button is tapped
                      LatLng newCentre = mapStateReader.searchThisArea();

                      // Create a HomeController instance and use it
                      final homeController = HomeController(
                        locationListManager: locationListManager,
                        mapStateProvider: mapStateReader,
                        deviceLocationProvider: deviceLocationProvider,
                      );

                      // Use the controller to fetch recommended pins for this area
                      homeController.fetchAndPlotRecommendedPins(newCentre);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.search,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Search this area',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // "My Location" button - always show at the top left
        Positioned(
          top: 16.0,
          left: 16.0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ]
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30.0),
                onTap: () {
                  // Focus camera on user's current location
                  if (currentPosition != null) {
                    mapStateReader.focusOnUserLocation(currentPosition, zoom: 15.0);
                  } else {
                    // Try to get current position first if not available
                    deviceLocationProvider.getCurrentLocation().then((position) {
                      if (position != null) {
                        mapStateReader.focusOnUserLocation(position, zoom: 15.0);
                      }
                    });
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Icon(
                    Icons.my_location,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

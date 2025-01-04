import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/services/googlePlaceService.dart';
import 'package:login/widgets/PinitMap.dart';
import 'package:permission_handler/permission_handler.dart';


class HomePage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const HomePage({Key? key, required this.userData}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? controller;
  String _mapStyle = '';
  LatLng? _currentPosition;
  Set<Marker> markers = {};
  List<Map<String, dynamic>> carouselItems = [];
  final GooglePlacesService googlePlacesService = GooglePlacesService();

  @override
  void initState() {
    super.initState();

    print("home_page: api key: ${dotenv.env['GOOGLE_PLACE_API_KEY']}");

    // Loading map style from assets
    DefaultAssetBundle.of(context).loadString('lib/assets/map_style.json').then((string) {
      _mapStyle = string;
    }).catchError((error) {
      print(error.toString());
    });

    _getUserLocation();
    _plotKnownPins();
    googlePlacesService.fetchNearbyPlaces(latitude: 50.819788, longitude: -0.122921, placeType: "restaurant");
  }

  /// Gets the user's current location and updates the map.
  ///
  /// Requests location permission and, if granted, fetches the current position.
  /// Updates the state with the new position and animates the map camera.
  Future<void> _getUserLocation() async {
    
    PermissionStatus permission = await Permission.locationWhenInUse.request();
    if (permission == PermissionStatus.granted) {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        controller?.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 15));
      });
    }
  }

  void _plotKnownPins() async {
    List<Map<String, dynamic>> fetchedItems = [];
    setState(() {
      for (GeoPoint point in widget.userData!['saved_locations']) {
        markers.add(
          Marker(
            markerId: MarkerId(point.hashCode.toString()),
            position: LatLng(point.latitude, point.longitude),
            infoWindow: InfoWindow(
              title: 'Saved Location',
              snippet: 'Location at (${point.latitude}, ${point.longitude})',
            ),
          ),
        );
        fetchedItems.add({
          'title': 'Saved Location',
          'subtitle': 'Location at (${point.latitude}, ${point.longitude})',
        });
      }
      carouselItems = fetchedItems;
    });
  }

  // void _plotRecommendedPins() {
  //   // Implement recommended pins plotting here
  //   List<Map<String, dynamic>> fetchedItems = [];
  //   // key: AIzaSyCAAK9Qm8bMNTN8zcauCiIgdHQcYQrOjYQ
  //   setState(() {
  //     for (GeoPoint point in widget.userData!['saved_locations']) {
  //       GooglePlace googlePlace = GooglePlace(dotenv.env["GOOGLE_PLACE_API_KEY"]!);
  //       markers.add(
  //         Marker(
  //           markerId: MarkerId(point.hashCode.toString()),
  //           position: LatLng(point.latitude, point.longitude),
  //           infoWindow: InfoWindow(
  //             title: 'Saved Location',
  //             snippet: 'Location at (${point.latitude}, ${point.longitude})',
  //           ),
  //         ),
  //       );
  //       fetchedItems.add({
  //         'title': 'Saved Location',
  //         'subtitle': 'Location at (${point.latitude}, ${point.longitude})',
  //       });
  //     }
  //     carouselItems = fetchedItems;
  //   });

  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Welcome Header with Search Bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16.0,
              bottom: 16.0,
              left: 16.0,
              right: 16.0,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome Back!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.userData?["name"] ?? "User",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        // Handle pin icon press
                      },
                      icon: const Icon(
                        Icons.push_pin,
                        size: 28,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Next Destination',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onChanged: (value) {
                    // Implement search functionality here
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                // Google Map
                Positioned.fill(
                  child: 
                  CustomGoogleMap(
                      mapStyle: _mapStyle,
                      currentPosition: _currentPosition,
                      markers: markers,
                      onMapCreated: (mapController) {
                        setState(() {
                          controller = mapController;
                        });
                      },
                    ),
                  ),
                // Draggable Scrollable Carousel
                DraggableScrollableSheet(
                  initialChildSize: 0.1,
                  minChildSize: 0.1,
                  maxChildSize: 0.6,
                  builder: (BuildContext context, ScrollController scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16.0),
                          topRight: Radius.circular(16.0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10.0,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: carouselItems.length,
                        itemBuilder: (BuildContext context, int index) {
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(carouselItems[index]['title'][0]),
                            ),
                            title: Text(carouselItems[index]['title']),
                            subtitle: Text(carouselItems[index]['subtitle']),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

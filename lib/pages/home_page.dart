import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/widgets/locationSearchTextWidget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

// import 'package:logging/logging.dart';


class HomePage extends StatefulWidget {
  // final Logger logger;
  // const HomePage({Key? key, required this.logger}) : super(key: key);
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? _controller;
  String _mapStyle = '';
  int _currentIndex = 2;
  LatLng? _currentPosition;

  // Dummy data for carousel items
  final List<String> carouselItems = [
    'Item 1',
    'Item 2',
    'Item 3',
    'Item 4',
    'Item 5',
  ];

  String _searchQuery = ""; // Variable to store the search input

  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
    });
    print("Search query updated: $_searchQuery");
    // Perform actions based on the updated search query, like filtering a list
  }

  Future<void> _getUserLocation() async{
    PermissionStatus permission = await Permission.locationWhenInUse.request();
    if (permission == PermissionStatus.granted) {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _controller?.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 15),);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    //loading map style JSON from asset file
    print('Loading map style');
    DefaultAssetBundle.of(context).loadString('lib/assets/map_style.json').then((string) {
      _mapStyle = string;
    }).catchError((error) {
      // widget.logger.severe(error.toString());
      print(error.toString());
    });
    _getUserLocation();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: 
        Column(
          children: [
            // Custom header with logo and buttons
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top), // Adjust padding to account for the status bar
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Image.asset(
                        'lib/assets/pinitLogo.png',
                        height: 40,
                      ),
                    ),
                    // Button Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              // Handle "Following" button press
                            },
                            child: const Text(
                              'Following',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: TextButton(
                              onPressed: () {
                                // Handle "For you" button press
                              },
                              child: const Text(
                                'For you',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              // Handle "Your Pins" button press
                            },
                            child: const Text(
                              'Your Pins',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  // Google Map
                  Positioned.fill(
                    child: GoogleMap(
                      style: _mapStyle,
                      myLocationButtonEnabled: true,
                      compassEnabled: false,
                      zoomControlsEnabled: false,
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(51.4988, -0.1749),
                        zoom: 15,
                      ),
                      onMapCreated: (controller) {
                        setState(() {
                          _controller = controller;
                          if(_currentPosition != null) {
                            _controller?.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 15),);
                          }
                        });
                      },
                    ),
                  ),
                  // Draggable and scrollable carousel
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
                                child: Text(carouselItems[index][0]),
                              ),
                              title: Text(carouselItems[index]),
                              subtitle: Text('Subtitle for ${carouselItems[index]}'),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  
                  // Search bar
                  Positioned(
                    top: MediaQuery.of(context).padding.top,
                    left: 16.0,
                    right: 16.0,
                    child: SearchWidget(
                      onSearch: _updateSearchQuery, // Pass the callback to the SearchWidget
                    ),
                  ),
                ],
              ),
            ),
          ],
        )
    );
  }
}

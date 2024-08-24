import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  // Dummy data for carousel items
  final List<String> carouselItems = [
    'Item 1',
    'Item 2',
    'Item 3',
    'Item 4',
    'Item 5',
  ];

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
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          Positioned.fill(
            child: GoogleMap(
              style: _mapStyle,
              initialCameraPosition: const CameraPosition(
                target: LatLng(51.4988, -0.1749), // Coordinates for Imperial College London
                zoom: 15,
              ),
              onMapCreated: (controller) {
                setState(() {
                  _controller = controller;
                });
              },
            ),
          ),
          // Draggable and scrollable carousel
          DraggableScrollableSheet(
            initialChildSize: 0.1, // Initial size of the sheet
            minChildSize: 0.1,     // Minimum size to which the sheet can shrink
            maxChildSize: 0.6,     // Maximum size to which the sheet can expand
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
          // Search Bar
          Positioned(
            top: kToolbarHeight - 30, // Position it below the AppBar
            left: 16.0,
            right: 16.0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4.0,
                  ),
                ],
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Your next adventure...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
              ),
            ),
          ),
        ],
      ), 
    );
  }
}

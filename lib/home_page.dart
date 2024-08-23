import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'pages/home.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? _controller;

  // Dummy data for carousel items
  final List<String> carouselItems = [
    'Item 1',
    'Item 2',
    'Item 3',
    'Item 4',
    'Item 5',
  ];

  // Dummy screenshot for the bottom bar
  final List<Widget> bottomBarScreens = [
    const HomeScreen(),
    const Center(child: Text('Search')),
    const Center(child: Text('Notifications')),
    const Center(child: Text('Profile')),
  ];

  @override
  Widget build(BuildContext context) {
    int _selectedBottomIndex = 1;

    void _navigateBottomBar(int index) {
      setState(() {
        _selectedBottomIndex = index;
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          Positioned.fill(
            child: GoogleMap(
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
            maxChildSize: 0.4,     // Maximum size to which the sheet can expand
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
        ],
      ),
      

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottomIndex,
        onTap: _navigateBottomBar,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home, color: Colors.black), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.search, color: Colors.black), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.notifications, color: Colors.black), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person, color: Colors.black), label: ''),
        ],
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black.withOpacity(0.6),
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

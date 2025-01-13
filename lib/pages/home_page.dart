import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/controllers/home_controller.dart';
import 'package:login/providers/app_data_provider.dart';
import 'package:login/widgets/PinitMap.dart';
import 'package:provider/provider.dart';


class HomePage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const HomePage({Key? key, required this.userData}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? controller;
  late final HomeController homeController_;
  late final AppStateProvider appStateProvider_;
  String _mapStyle = '';
  

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

    appStateProvider_ = Provider.of<AppStateProvider>(context, listen: false);
    homeController_ = HomeController(appStateProvider_);
    homeController_.getUserLocation();
    // homeController_.plotKnownPins();
    homeController_.plotRecommendedPins();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Welcome Header
        _buildHeader(),
        Expanded(
          child: Stack(
            children: [
              // Google Map
              Positioned.fill(
                child: CustomGoogleMap(mapStyle: _mapStyle),
              ),
              // Draggable Carousel
              _buildDraggableSheet(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
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
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.userData?["name"] ?? "User",
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  // Handle pin action
                },
                icon: const Icon(Icons.push_pin, size: 28, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          TextField(
            decoration: InputDecoration(
              hintText: 'Next Destination',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            onChanged: (value) {
              // Implement search functionality
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.1,
      minChildSize: 0.1,
      maxChildSize: 0.6,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 10.0, spreadRadius: 0.5),
            ],
          ),
          child: ListView.builder(
            controller: scrollController,
            itemCount: appStateProvider_.recommendedLocations.length,
            itemBuilder: (context, index) {
              final location = appStateProvider_.recommendedLocations[index];
              return homeController_.buildCarouselItem(location);
            },
          ),
        );
      },
    );
  }
}


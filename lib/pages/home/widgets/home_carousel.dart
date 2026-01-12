import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/home/LocationCarousel/location_carousel.dart';

class HomeCarousel extends StatelessWidget {
  final PageController pageController;
  final List<LocationModel> locations;
  final MarkerId? selectedMarkerId;
  final bool bottomNavVisible;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onScrollStart;
  final ValueChanged<LocationModel> onLocationSelected;

  const HomeCarousel({
    Key? key,
    required this.pageController,
    required this.locations,
    required this.selectedMarkerId,
    required this.bottomNavVisible,
    required this.onPageChanged,
    required this.onScrollStart,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo is ScrollStartNotification) {
          onScrollStart();
        }
        return false;
      },
      child: LocationCarousel(
        pageController: pageController,
        locations: locations,
        selectedMarkerId: selectedMarkerId,
        bottomNavVisible: bottomNavVisible,
        onPageChanged: onPageChanged,
        onLocationSelected: onLocationSelected,
      ),
    );
  }
}

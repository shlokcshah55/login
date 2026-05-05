import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/home/LocationCarousel/location_carousel.dart';

class HomeCarousel extends StatelessWidget {
  final PageController pageController;
  final List<LocationModel> locations;
  final Widget? leadingCard;
  final double? heightOverride;
  final String? selectedMarkerId;
  final bool bottomNavVisible;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onScrollStart;
  final ValueChanged<LocationModel> onLocationSelected;
  final void Function(LocationModel location)? onSwipeUp;
  final void Function(LocationModel location)? onSwipeDown;
  final bool showFirstItemSwipeHint;
  final VoidCallback? onFirstItemSwipeHintCompleted;

  const HomeCarousel({
    Key? key,
    required this.pageController,
    required this.locations,
    this.leadingCard,
    this.heightOverride,
    required this.selectedMarkerId,
    required this.bottomNavVisible,
    required this.onPageChanged,
    required this.onScrollStart,
    required this.onLocationSelected,
    this.onSwipeUp,
    this.onSwipeDown,
    this.showFirstItemSwipeHint = false,
    this.onFirstItemSwipeHintCompleted,
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
        leadingCard: leadingCard,
        selectedMarkerId: selectedMarkerId,
        bottomNavVisible: bottomNavVisible,
        heightOverride: heightOverride,
        showFirstItemSwipeHint: showFirstItemSwipeHint,
        onPageChanged: onPageChanged,
        onLocationSelected: onLocationSelected,
        onSwipeUp: onSwipeUp,
        onSwipeDown: onSwipeDown,
        onFirstItemSwipeHintCompleted: onFirstItemSwipeHintCompleted,
      ),
    );
  }
}

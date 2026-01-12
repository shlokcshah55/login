import 'package:flutter/material.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/widgets/home/LocationCarousel/filter_bar.dart';

class HomeHeader extends StatelessWidget {
  final LocationListType currentListType;
  final ValueChanged<LocationListType> onListTypeChanged;

  const HomeHeader({
    Key? key,
    required this.currentListType,
    required this.onListTypeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.background.withOpacity(0.95),
            theme.colorScheme.background.withOpacity(0.85),
            theme.colorScheme.background.withOpacity(0.0),
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 15.0, bottom: 8.0),
              child: FilterBar(
                currentListType: currentListType,
                onListTypeChanged: onListTypeChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

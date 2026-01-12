import 'package:flutter/material.dart';
import 'package:login/widgets/home/pinit_map.dart';

class HomeMapLayer extends StatelessWidget {
  final VoidCallback onMapTap;
  final VoidCallback onSearchThisArea;

  const HomeMapLayer({
    Key? key,
    required this.onMapTap,
    required this.onSearchThisArea,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PinitMap(
      onMapTap: onMapTap,
      onSearchThisArea: onSearchThisArea,
    );
  }
}

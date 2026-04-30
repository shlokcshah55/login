import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';

import 'location_mosaic_grid.dart';
import 'pinit_colors.dart';

/// Places currently trending — displayed as an Instagram Explore-style mosaic.
class TrendingNowSection extends StatelessWidget {
  final List<LocationModel> locations;
  final String title;
  final String subtitle;
  final EdgeInsets headerPadding;
  final EdgeInsets gridPadding;

  const TrendingNowSection({
    Key? key,
    required this.locations,
    this.title = 'Popping Right Now',
    this.subtitle = 'Hot places people have saved',
    this.headerPadding = const EdgeInsets.fromLTRB(24, 0, 24, 16),
    this.gridPadding = const EdgeInsets.symmetric(horizontal: 20),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ──
        Padding(
          padding: headerPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Rova',
                  fontSize: 28,
                  fontWeight: FontWeight.w100,
                  color: PinitColors.aubergine,
                  letterSpacing: 1.9,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: PinitColors.aubergineSoft,
                ),
              ),
            ],
          ),
        ),

        // ── Mosaic grid ──
        Padding(
          padding: gridPadding,
          child: LocationMosaicGrid(locations: locations),
        ),
      ],
    );
  }
}

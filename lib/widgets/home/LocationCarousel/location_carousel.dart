import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/bottom_nav_visibility_provider.dart';
import 'package:login/providers/dynamic_nav_provider.dart';
import 'package:login/supabase_flutter/models/location_model.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer';

class LocationCarousel extends StatefulWidget {
  final PageController pageController;
  final List<LocationModel> locations;

  const LocationCarousel({
    Key? key,
    required this.pageController,
    required this.locations,
  }) : super(key: key);

  @override
  State<LocationCarousel> createState() => _LocationCarouselState();
}

class _LocationCarouselState extends State<LocationCarousel> {
  @override
  void initState() {
    super.initState();
    // Provide the PageController to the MapStateProvider on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<MapStateProvider>()
          .setCarouselPageController(widget.pageController);
    });
  }

  @override
  Widget build(BuildContext context) {
    print(
        "Building LocationCarousel with ${widget.locations.length} locations");
    final theme = Theme.of(context);
    final mapState = context.watch<MapStateProvider>();
    final bottomNavVisible = context.watch<BottomNavVisibilityProvider>().isVisible;

    if (widget.locations.isEmpty) return const SizedBox.shrink();

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuint,
      bottom: bottomNavVisible ? 90.0 : 20.0, // Position adjusts based on nav visibility
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        height: bottomNavVisible ? 160.0 : 200.0, // Expand height when nav is hidden
        padding: const EdgeInsets.symmetric(
            horizontal: 0), // Ensure no horizontal padding
        child: PageView.builder(
          controller: widget.pageController,
          itemCount: widget.locations.length,
          pageSnapping: true,
          // Add better scrolling physics
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemBuilder: (context, index) {
            final location = widget.locations[index];
            final isSelected =
                mapState.selectedMarkerId?.value == location.locationId;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuint,
              // Center-align the card with smaller margins to ensure visibility on both sides
              margin: EdgeInsets.symmetric(
                horizontal: 5.0,
                vertical: isSelected ? 0 : 10.0,
              ),
              transform: isSelected
                  ? Matrix4.identity()
                  : (Matrix4.identity()
                    ..scale(0.95)), // Subtle scale down for non-selected
              child: _buildCarouselCard(
                  context, theme, location, isSelected, mapState),
            );
          },
          onPageChanged: (index) {
            // Hide bottom nav when page changes (user scrolled)
            context.read<BottomNavVisibilityProvider>().hide();
            
            final location = widget.locations[index];
            mapState.setSelectedMarkerId(
              MarkerId(location.locationId.toString()),
              triggeredByCarousel: true,
            );
            mapState.animateCamera(
              CameraUpdate.newLatLng(location.position),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCarouselCard(
    BuildContext context,
    ThemeData theme,
    LocationModel location,
    bool isSelected,
    MapStateProvider mapState,
  ) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final dynamicNavProvider = context.read<DynamicNavProvider>();
    final bottomNavVisible = context.watch<BottomNavVisibilityProvider>().isVisible;

    return InkWell(
      onTap: () {
        log("Tapped card for: ${location.name} (ID: ${location.locationId})");
        
        // Show the bottom navigation bar temporarily
        context.read<BottomNavVisibilityProvider>().showTemporarily();

        // Show the dynamic navigation bar
        dynamicNavProvider.showDynamicNav(location);

        // Set the selected marker and animate the camera
        mapState.setSelectedMarkerId(MarkerId(location.locationId.toString()));
        mapState.animateCamera(
          CameraUpdate.newLatLng(location.position),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Increased corner radius
          side: isSelected
              ? BorderSide(
                  color: colorScheme.primary,
                  width: 3.0) // Thicker border when selected
              : BorderSide.none,
        ),
        elevation: isSelected ? 8.0 : 4.0, // Higher elevation when selected
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuint,
          height: bottomNavVisible ? 140 : 170, // Adjust card height based on nav visibility
          child: Row(
            children: [
              // --- Text Section (Left Half) ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0), // Reduced padding
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        location.name,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                          fontSize: 14, // Slightly smaller font
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6.0), // Reduced spacing
                      Row(
                        children: [
                          Icon(FeatherIcons.star,
                              size: 14,
                              color: colorScheme.secondary), // Smaller icon
                          const SizedBox(width: 2), // Reduced spacing
                          Text(
                            location.rating?.toStringAsFixed(1) ?? 'N/A',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 12, // Smaller text
                            ),
                          ),
                          const SizedBox(width: 3), // Reduced spacing
                          Flexible(
                            child: Text(
                              "(${location.userRatingsTotal?.toString() ?? '0'} reviews)",
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant
                                    .withOpacity(0.7), // Smaller text
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0), // Reduced spacing
                      if (location.priceLevel != null &&
                          location.priceLevel! > 0)
                        Text(
                          '\$' * location.priceLevel!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: theme.brightness == Brightness.dark
                                ? Colors.greenAccent
                                : Colors.green[700], // Smaller text
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6, // Reduced spacing
                          ),
                        ),
                      const SizedBox(height: 6.0), // Reduced spacing
                      if (location.cuisine != null &&
                          location.cuisine!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                              vertical: 2.0), // Reduced padding
                          decoration: BoxDecoration(
                            color:
                                colorScheme.secondaryContainer.withOpacity(0.7),
                            borderRadius:
                                BorderRadius.circular(10.0), // Smaller radius
                          ),
                          child: Text(
                            location.cuisine!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                              fontSize: 9, // Smaller text
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // --- Photo Section (Right Half) ---
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutQuint,
                width: bottomNavVisible ? 125 : 145, // Expand width when nav is hidden
                height: double.infinity,
                child: Stack(
                  children: [
                    _buildCardImage(location, theme),
                    // Gradient overlay for improved text contrast on the image if needed
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.surface.withOpacity(0.55),
                              Colors.transparent,
                              colorScheme.surface.withOpacity(0.65)
                            ],
                            stops: const [0.0, 0.5, 1.0],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    // Type indicator badge on the top-left of the image section
                    Positioned(
                      top: 6, // Reduced position
                      left: 6, // Reduced position
                      child: _buildTypeIndicator(location.preference!, theme),
                    ),
                    // Saved count badge on the top-right if applicable
                    if (location.savedCount != null && location.savedCount! > 0)
                      Positioned(
                        top: 6, // Reduced position
                        right: 6, // Reduced position
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5.0,
                              vertical: 2.0), // Smaller padding
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withOpacity(0.5),
                            borderRadius:
                                BorderRadius.circular(8.0), // Smaller radius
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FeatherIcons.bookmark,
                                  size: 10,
                                  color: colorScheme.primary), // Smaller icon
                              const SizedBox(width: 2), // Smaller spacing
                              Text(
                                location.savedCount.toString(),
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9, // Smaller text
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIndicator(LocationPreference preference, ThemeData theme) {
    IconData iconData;
    String text;
    Color bgColor;
    Color fgColor = theme.colorScheme.onPrimary; // Default foreground for primary/secondary

    switch (preference) {
      case LocationPreference.saved:
        iconData = FeatherIcons.bookmark;
        text = 'Saved';
        bgColor = theme.colorScheme.primary;
        break;
      case LocationPreference.recommended:
        iconData = FeatherIcons.star;
        text = 'Rec'; // Shortened text
        bgColor = theme.colorScheme.secondary;
        break;
      case LocationPreference.search:
        iconData = FeatherIcons.search;
        text = 'Result';
        bgColor = theme.colorScheme.tertiaryContainer;
        fgColor = theme.colorScheme.onTertiaryContainer;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 5.0, vertical: 2.0), // Reduced padding
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(5.0), // Smaller radius
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.2),
            blurRadius: 2.0, // Smaller blur
            offset: const Offset(1, 1),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 10, color: fgColor), // Smaller icon
          const SizedBox(width: 3), // Reduced spacing
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: fgColor,
              fontWeight: FontWeight.bold,
              fontSize: 8, // Smaller text
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardImage(LocationModel location, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return ClipRRect(
      child: SizedBox(
        height: double.infinity, // Fill the container height
        child: location.photoReference != null
            ? Image.network(
                'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${location.photoReference}&key=${dotenv.env['GOOGLE_PLACE_API_KEY']}',
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: colorScheme.surfaceVariant,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5, // Thinner stroke
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  log("Error loading image for ${location.name}: $error");
                  return Container(
                    color: colorScheme.surfaceVariant,
                    child: Icon(
                      FeatherIcons.mapPin,
                      size: 30, // Smaller icon
                      color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                  );
                },
              )
            : Container(
                color: colorScheme.surfaceVariant,
                child: Icon(
                  FeatherIcons.mapPin,
                  size: 30, // Smaller icon
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
              ),
      ),
    );
  }
}

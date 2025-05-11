import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/supabase_flutter/models/location_model.dart';
import 'package:login/widgets/expanded_location_card.dart';
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
      context.read<MapStateProvider>().setCarouselPageController(widget.pageController);
    });
  }

  @override
  Widget build(BuildContext context) {
    print("Building LocationCarousel with ${widget.locations.length} locations");
    final theme = Theme.of(context);
    final mapState = context.watch<MapStateProvider>();

    if (widget.locations.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 90.0, // Position above bottom navigation bar
      left: 0,
      right: 0,
      child: Container(
        height: 160.0, // Reduced height to match smaller card content
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
              margin: EdgeInsets.only(
                left: 5.0,
                right: 5.0,
                top: isSelected ? 0 : 10.0,
                bottom: isSelected ? 0 : 10.0,
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
            final location = widget.locations[index];
            mapState.setSelectedMarkerId(
              MarkerId(location.locationId.toString()),
              triggeredByCarousel: true,
            );
            if (location.position != null) {
              mapState.animateCamera(
                CameraUpdate.newLatLng(location.position!),
              );
            }
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

    return InkWell(
      onTap: () {
        log("Tapped card for: ${location.name} (ID: ${location.locationId})");
        mapState.setSelectedMarkerId(MarkerId(location.locationId.toString()));

        // Show the expanded location card
        showDialog(
          context: context,
          builder: (context) => ExpandedLocationCard(
            location: location,
            onClose: () => Navigator.of(context).pop(),
          ),
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
        child: SizedBox(
          height: 140, // Reduced height
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
                          Icon(Icons.star_rounded,
                              size: 14,
                              color: Colors.amber[700]), // Smaller icon
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
                                color: Colors.grey[600],
                                fontSize: 10, // Smaller text
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
                            color: Colors.green[700],
                            fontSize: 12, // Smaller text
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
              Container(
                width: 125, // Reduced width for the image side
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
                              Colors.black.withOpacity(0.55),
                              Colors.transparent,
                              Colors.black.withOpacity(0.65)
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
                    if (location.savedCount! > 0)
                      Positioned(
                        top: 6, // Reduced position
                        right: 6, // Reduced position
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5.0,
                              vertical: 2.0), // Smaller padding
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius:
                                BorderRadius.circular(8.0), // Smaller radius
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bookmark_rounded,
                                  size: 10,
                                  color: colorScheme.primary), // Smaller icon
                              const SizedBox(width: 2), // Smaller spacing
                              Text(
                                location.savedCount.toString(),
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
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

    switch (preference) {
      case LocationPreference.saved:
        iconData = Icons.bookmark_rounded;
        text = 'Saved';
        bgColor = theme.colorScheme.primary;
        break;
      case LocationPreference.recommended:
        iconData = Icons.star_rounded;
        text = 'Rec'; // Shortened text
        bgColor = theme.colorScheme.secondary;
        break;
      case LocationPreference.search:
        iconData = Icons.search_rounded;
        text = 'Result';
        bgColor = Colors.blueGrey;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 5.0, vertical: 2.0), // Reduced padding
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(5.0), // Smaller radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 2.0, // Smaller blur
            offset: const Offset(1, 1),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 10, color: Colors.white), // Smaller icon
          const SizedBox(width: 3), // Reduced spacing
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white,
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
                    color: Colors.grey[200],
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
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.restaurant_menu_rounded,
                      size: 30, // Smaller icon
                      color: Colors.grey[400],
                    ),
                  );
                },
              )
            : Container(
                color: Colors.grey[200],
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  size: 30, // Smaller icon
                  color: Colors.grey[400],
                ),
              ),
      ),
    );
  }
}

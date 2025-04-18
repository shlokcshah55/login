import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:login/models/location_model.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer';

class LocationCarousel extends StatelessWidget {
  final PageController pageController;
  final List<LocationModel> locations;

  const LocationCarousel({
    Key? key,
    required this.pageController,
    required this.locations,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mapState = context.watch<MapStateProvider>();

    if (locations.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 16.0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 190.0,
        child: PageView.builder(
          controller: pageController,
          itemCount: locations.length,
          pageSnapping: true,
          padEnds: true,
          itemBuilder: (context, index) {
            final location = locations[index];
            final isSelected = mapState.selectedMarkerId?.value == location.id;
            return AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: 6.0,
                vertical: isSelected ? 0 : 7.0,
              ),
              child: _buildCarouselCard(context, theme, location, isSelected, mapState),
            );
          },
          onPageChanged: (index) {
            final location = locations[index];
            mapState.setSelectedMarkerId(
              MarkerId(location.id),
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
        log("Tapped card for: ${location.name} (ID: ${location.id})");
        mapState.setSelectedMarkerId(MarkerId(location.id));
        if (location.position != null) {
          mapState.animateCamera(
            CameraUpdate.newLatLngZoom(location.position!, 15.5),
          );
        }
        int index = locations.indexWhere((loc) => loc.id == location.id);
        if (index != -1 &&
            pageController.hasClients &&
            pageController.page?.round() != index) {
          pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSelected
              ? BorderSide(color: colorScheme.primary, width: 2.5)
              : BorderSide.none,
        ),
        elevation: 4.0,
        child: SizedBox(
          height: 150, // Fixed height to prevent overflow
          child: Row(
            children: [
              // --- Text Section (Left Half) ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
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
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 16, color: Colors.amber[700]),
                          const SizedBox(width: 3),
                          Text(
                            location.rating?.toStringAsFixed(1) ?? 'N/A',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "(${location.userRatingsTotal?.toString() ?? '0'} reviews)",
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      if (location.priceLevel != null && location.priceLevel! > 0)
                        Text(
                          '\$' * location.priceLevel!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: Colors.green[700],
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      const SizedBox(height: 8.0),
                      if (location.cuisine != null && location.cuisine!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 3.0),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            location.cuisine!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                              fontSize: 10,
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
                width: 150, // Fixed width for the image side
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
                      top: 8,
                      left: 8,
                      child: _buildTypeIndicator(location.preference, theme),
                    ),
                    // Saved count badge on the top-right if applicable
                    if (location.savedCount > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6.0, vertical: 3.0),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bookmark_rounded,
                                  size: 12, color: colorScheme.primary),
                              const SizedBox(width: 3),
                              Text(
                                location.savedCount.toString(),
                                style: textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
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
        text = 'Recommended';
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
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 3.0,
            offset: const Offset(1, 1),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardImage(LocationModel location, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return ClipRRect(
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: location.photoReference != null
            ? Image.network(
                'https://maps.googleapis.com/maps/api/place/photo?maxwidth=600&photoreference=${location.photoReference}&key=${dotenv.env['GOOGLE_PLACE_API_KEY']}',
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
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
                      size: 40,
                      color: Colors.grey[400],
                    ),
                  );
                },
              )
            : Container(
                color: Colors.grey[200],
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  size: 40,
                  color: Colors.grey[400],
                ),
              ),
      ),
    );
  }
}

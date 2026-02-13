import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/utils/geo_types.dart';
import 'package:login/models/locations.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:developer';

class LocationCarousel extends StatelessWidget {
  final PageController pageController;
  final List<LocationModel> locations;
  final String? selectedMarkerId;
  final bool bottomNavVisible;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<LocationModel> onLocationSelected;

  const LocationCarousel({
    Key? key,
    required this.pageController,
    required this.locations,
    required this.selectedMarkerId,
    required this.bottomNavVisible,
    required this.onPageChanged,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (locations.isEmpty) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuint,
      height: bottomNavVisible ? 160.0 : 200.0,
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: PageView.builder(
        controller: pageController,
        itemCount: locations.length,
        pageSnapping: true,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemBuilder: (context, index) {
          final location = locations[index];
          final isSelected = selectedMarkerId == location.locationId;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuint,
            margin: EdgeInsets.symmetric(
              horizontal: 5.0,
              vertical: isSelected ? 0 : 10.0,
            ),
            transform: isSelected
                ? Matrix4.identity()
                : (Matrix4.identity()..scale(0.95)),
            child: _buildCarouselCard(
              context,
              theme,
              location,
              isSelected,
            ),
          );
        },
        onPageChanged: (index) {
          onPageChanged(index);
        },
      ),
    );
  }

  Widget _buildCarouselCard(
    BuildContext context,
    ThemeData theme,
    LocationModel location,
    bool isSelected,
  ) {
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return InkWell(
      onTap: () {
        log("Tapped card for: ${location.name} (ID: ${location.locationId})");

        onLocationSelected(location);

        // Open the expanded location card with slide-up animation
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel:
              MaterialLocalizations.of(context).modalBarrierDismissLabel,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) {
            return ExpandedLocationCard(
              location: location,
              onClose: () => Navigator.of(context).pop(),
            );
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24), // More rounded corners
          side: isSelected
              ? BorderSide(
                  color: colorScheme.primary,
                  width: 2.5) // Slightly thinner border
              : BorderSide.none,
        ),
        elevation: isSelected ? 12.0 : 6.0, // Higher elevation for more depth
        shadowColor:
            colorScheme.shadow.withValues(alpha: isSelected ? 100 : 50),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuint,
          height: bottomNavVisible ? 140 : 170,
          child: Row(
            children: [
              // --- Text Section (Left Half) ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(
                      16.0), // Increased padding for better spacing
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Location Name
                      Flexible(
                        child: Text(
                          location.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                            fontSize: 16,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 6.0),

                      // Rating Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              color: colorScheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  FeatherIcons.star,
                                  size: 12,
                                  color: colorScheme.secondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  location.rating?.toStringAsFixed(1) ?? 'N/A',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.secondary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "(${location.userRatingsTotal?.toString() ?? '0'})",
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant
                                    .withOpacity(0.7),
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0),

                      // Price and Cuisine Row
                      Row(
                        children: [
                          if (location.priceLevel != null &&
                              location.priceLevel! > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 3.0),
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Text(
                                '\$' * location.priceLevel!,
                                style: textTheme.bodySmall?.copyWith(
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.greenAccent
                                      : Colors.green[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          if (location.priceLevel != null &&
                              location.priceLevel! > 0 &&
                              location.cuisine != null &&
                              location.cuisine!.isNotEmpty)
                            const SizedBox(width: 8.0),
                          if (location.cuisine != null &&
                              location.cuisine!.isNotEmpty)
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 3.0),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer
                                      .withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: Text(
                                  location.cuisine!,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // --- Photo Section (Right Half) ---
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutQuint,
                width: bottomNavVisible
                    ? 125
                    : 145, // Expand width when nav is hidden
                height: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      _buildCardImage(location, theme),
                      // Enhanced gradient overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.surface.withOpacity(0.3),
                                Colors.transparent,
                                Colors.black.withOpacity(0.4),
                              ],
                              stops: const [0.0, 0.4, 1.0],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      // Type indicator badge with enhanced styling
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _buildTypeIndicator(location.preference!, theme),
                      ),
                      // Saved count badge with enhanced styling
                      if (location.savedCount != null &&
                          location.savedCount! > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color: colorScheme.primary.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  FeatherIcons.bookmark,
                                  size: 12,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  location.savedCount.toString(),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
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
    Color fgColor;

    switch (preference) {
      case LocationPreference.saved:
        iconData = FeatherIcons.heart;
        text = 'Saved';
        bgColor = theme.colorScheme.primary;
        fgColor = theme.colorScheme.onPrimary;
        break;
      case LocationPreference.recommended:
        iconData = FeatherIcons.award;
        text = 'Top Pick';
        bgColor = theme.colorScheme.secondary;
        fgColor = theme.colorScheme.onSecondary;
        break;
      case LocationPreference.search:
        iconData = FeatherIcons.search;
        text = 'Match';
        bgColor = theme.colorScheme.tertiaryContainer;
        fgColor = theme.colorScheme.onTertiaryContainer;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.3),
            blurRadius: 4.0,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 12, color: fgColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w600,
              fontSize: 10,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardImage(LocationModel location, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return SizedBox(
      height: double.infinity,
      width: double.infinity,
      child: location.imageUrl != null
          ? CachedNetworkImage(
              imageUrl: location.imageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.surfaceContainerHighest,
                      colorScheme.surfaceContainerHighest.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Loading...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              errorWidget: (context, url, error) {
                log("Error loading image for ${location.name}: $error");
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.errorContainer.withOpacity(0.3),
                        colorScheme.surfaceContainerHighest,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FeatherIcons.image,
                          size: 32,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No Image',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                colorScheme.onSurfaceVariant.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          : location.photoReference != null
              ? CachedNetworkImage(
                  imageUrl: location.photoReference!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.surfaceContainerHighest,
                          colorScheme.surfaceContainerHighest.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Loading...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    log("Error loading image for ${location.name}: $error");
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.errorContainer.withOpacity(0.3),
                            colorScheme.surfaceContainerHighest,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              FeatherIcons.image,
                              size: 32,
                              color:
                                  colorScheme.onSurfaceVariant.withOpacity(0.6),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No Image',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant
                                    .withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.surfaceContainerHighest,
                        colorScheme.surfaceContainerHighest.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FeatherIcons.mapPin,
                          size: 32,
                          color: colorScheme.primary.withOpacity(0.7),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Location',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                colorScheme.onSurfaceVariant.withOpacity(0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

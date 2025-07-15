import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/supabase_flutter/models/location_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Required for GOOGLE_PLACE_API_KEY
import 'dart:developer';

class LocationCard extends StatelessWidget {
  final LocationModel location;
  final bool isInitiallySaved;
  final Function(bool) onSaveToggle;

  const LocationCard({
    Key? key,
    required this.location,
    required this.isInitiallySaved,
    required this.onSaveToggle,
  }) : super(key: key);

  Widget _buildCardImage(LocationModel location, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    // Use photoReference for Google Places photos, or the first imageUrl for Supabase-stored images
    String? imageUrl;
    bool isGooglePlacePhoto = location.photoReference != null && location.photoReference!.isNotEmpty;

    if (isGooglePlacePhoto) {
      final apiKey = dotenv.env['GOOGLE_PLACE_API_KEY'];
      if (apiKey != null) {
        imageUrl =
            'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${location.photoReference}&key=\$apiKey';
      } else {
        log('GOOGLE_PLACE_API_KEY is not set in .env file');
      }
    } 
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12.0)), // Rounded corners for the top of the image
      child: SizedBox(
        height: 120, // Adjust height as needed for grid view
        width: double.infinity,
        child: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  log("Error loading image for ${location.name}: \$error");
                  return Container(
                    color: Colors.grey[200],
                    child: Icon(
                      FeatherIcons.mapPin, // Fallback icon
                      size: 30,
                      color: Colors.grey[400],
                    ),
                  );
                },
              )
            : Container(
                color: Colors.grey[200],
                child: Icon(
                  FeatherIcons.mapPin, // Fallback icon if no image URL
                  size: 30,
                  color: Colors.grey[400],
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    // No local state for currentSavedState, rely on isInitiallySaved directly for build
    // The parent widget (ProfilePage) will manage the state and rebuild LocationCard with new isInitiallySaved value.

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 3.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          _buildCardImage(location, theme),

          // Text Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.name,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4.0),
                      if (location.preference != null)
                        Text(
                          location.preference.toString(),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else if (location.cuisine != null && location.cuisine!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            location.cuisine!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 4.0),
                      Row(
                        children: [
                          Icon(FeatherIcons.star, size: 16, color: Colors.amber[700]),
                          const SizedBox(width: 4),
                          Text(
                            location.rating?.toStringAsFixed(1) ?? 'N/A',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              "(${location.userRatingsTotal?.toString() ?? '0'})",
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Save Icon - Placed at the bottom of the text section
                  Align(
                    alignment: Alignment.bottomRight,
                    child: IconButton(
                      padding: EdgeInsets.zero, // Remove default padding to make it more compact
                      constraints: const BoxConstraints(), // Remove default constraints
                      icon: Icon(
                        isInitiallySaved ? FeatherIcons.bookmark : FeatherIcons.bookmark,
                        color: isInitiallySaved ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                      onPressed: () {
                        onSaveToggle(!isInitiallySaved);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

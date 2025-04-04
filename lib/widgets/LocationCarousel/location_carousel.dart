import 'package:flutter/material.dart';
import 'package:login/models/location_model.dart';
import 'package:login/providers/location_list_manager.dart'; // Import new provider
// import 'package:login/providers/map_state_provider.dart'; // Import upcoming provider (placeholder)
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer';

Widget _buildLocationCarousel(BuildContext context, ThemeData theme) { // Pass BuildContext
  // Get locations from the LocationListManager
  // TODO: Implement filtering based on map bounds if needed. Requires MapStateProvider.
  final locationListManager = context.watch<LocationListManager>();
  final List<LocationModel> visibleLocations = locationListManager.currentItems.keys.toList();

  if (visibleLocations.isEmpty) {
    return const SizedBox.shrink(); // Hide carousel if no locations are visible
  }

  return Positioned(
    bottom: 16.0, // Adjust padding as needed
    left: 0,
    right: 0,
    child: SizedBox( // Use SizedBox for fixed height container
      height: 160.0, // Fixed height for the carousel
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: visibleLocations.length,
        itemBuilder: (context, index) {
          final location = visibleLocations[index];
          // TODO: Re-implement selection highlighting using MapStateProvider or HomePage state
          bool isSelected = false; // Placeholder

          return Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: _buildCarouselCard(context, theme, location, isSelected), // Pass context
          );
        },
      ),
    ),
  );
}

// Individual Card Widget for the Carousel
Widget _buildCarouselCard(BuildContext context, ThemeData theme, LocationModel location, bool isSelected) { // Pass context
  // final mapState = context.read<MapStateProvider>(); // Get MapStateProvider (placeholder)

  return InkWell(
    onTap: () {
      log("Tapped carousel card for: ${location.name}");
      // TODO: Update selected location state (e.g., mapState.setSelectedLocation(location.id))
      // Animate map to location.position using MapStateProvider
      if (location.position != null) {
        // mapState.animateCamera( // Use MapStateProvider method (placeholder)
        //   CameraUpdate.newLatLngZoom(location.position!, 15.0), // Adjust zoom
        // );
         log("TODO: Animate map to ${location.position}"); // Placeholder log
      }
    },
    child: Container(
      width: 250.0, // Fixed width for cards
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12.0),
        border: isSelected ? Border.all(color: theme.primaryColor, width: 2.0) : null, // Highlight selected
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8.0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          _buildCardImage(location),
          // Text Content Section
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.0),
                Row(
                  children: [
                    Icon(Icons.star, size: 14, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      location.rating?.toString() ?? 'N/A',
                      style: theme.textTheme.bodySmall,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "(${location.userRatingsTotal?.toString() ?? '0'})", // Show review count
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    Spacer(),
                    // Display cuisine or a generic type
                    Text(
                       location.cuisine ?? location.preference.toShortString(), // Fallback to preference type
                       style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                 SizedBox(height: 4.0),
                 // Optionally add distance/walking time if easily calculable
                 // Text("Approx. 10 min walk", style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildCardImage(LocationModel location) {
   return ClipRRect(
     borderRadius: BorderRadius.only(
       topLeft: Radius.circular(12.0),
       topRight: Radius.circular(12.0),
     ),
     child: location.photoReference != null
         ? Image.network(
             'https://maps.googleapis.com/maps/api/place/photo'
             '?maxwidth=400&photoreference=${location.photoReference}' // smaller width for card
             '&key=${dotenv.env['GOOGLE_PLACE_API_KEY']}',
             height: 80, // Fixed image height
             width: double.infinity,
             fit: BoxFit.cover,
             loadingBuilder: (context, child, progress) {
                 if (progress == null) return child;
                 return Container( // Ensure a widget is returned
                    height: 80,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  );
             },
             errorBuilder: (context, error, stackTrace) {
               return Container( // Ensure a widget is returned
                  height: 80,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: const Icon(Icons.restaurant, size: 40, color: Colors.grey),
                );
             },
           )
         : Container( // Placeholder if no photo
             height: 80,
             width: double.infinity,
             color: Colors.grey[300],
             child: const Icon(Icons.restaurant, size: 40, color: Colors.grey), // Use appropriate icon
           ),
   );
}

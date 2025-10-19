import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/supabase/service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/locations.dart';

class ExpandedLocationCard extends StatefulWidget {
  final LocationModel location;
  final VoidCallback onClose;

  const ExpandedLocationCard({
    Key? key,
    required this.location,
    required this.onClose,
  }) : super(key: key);

  @override
  State<ExpandedLocationCard> createState() => _ExpandedLocationCardState();
}

class _ExpandedLocationCardState extends State<ExpandedLocationCard> {
  bool _isSaved = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfLocationIsSaved();
  }

  // Check if location is already saved
  Future<void> _checkIfLocationIsSaved() async {
    final supabaseProvider =
        Provider.of<SupabaseService>(context, listen: false);

    setState(() => _isLoading = true);
    try {
      _isSaved = await supabaseProvider.locations
          .isLocationSaved(widget.location.locationId);
      setState(() {});
    } catch (e) {
      print('Error checking if location is saved: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Toggle save state
  Future<void> _toggleSave() async {
    final supabaseProvider =
        Provider.of<SupabaseService>(context, listen: false);

    setState(() => _isLoading = true);
    try {
      if (_isSaved) {
        // Unsave location
        final success = await supabaseProvider.locations
            .unsaveLocation(widget.location.locationId);
        if (success) {
          setState(() => _isSaved = false);

          // Remove from saved locations list
          await _updateLocationList(saved: false);
        }
      } else {
        // Save location
        final success = await supabaseProvider.locations
            .saveLocation(widget.location);
        if (success) {
          setState(() => _isSaved = true);

          // Add to saved locations list
          await _updateLocationList(saved: true);
        }
      }
    } catch (e) {
      print('Error toggling save state: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Update location list based on saved state
  Future<void> _updateLocationList({required bool saved}) async {
    final locationListManager =
        Provider.of<LocationListManager>(context, listen: false);

    if (saved) {
      // If we just saved a location, add it to the saved list
      // and potentially remove from current list if it was in search/recommended
      print('Adding location to saved list');
      await locationListManager.saveLocation(widget.location);
    } else {
      // If we just unsaved a location, remove it from the saved list
      print('Removing location from saved list');
      await locationListManager.removeLocation(widget.location);
      await locationListManager.fetchSavedLocations(); // Refresh saved locations
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final supabaseProvider =
        Provider.of<SupabaseService>(context, listen: false);

    return GestureDetector(
      onTap: widget.onClose, // Close when tapping outside
      child: Container(
        width: size.width,
        height: size.height * 0.8,
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping on the card
            child: Container(
              width: size.width * 0.9,
              height: size.height * 0.7,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with image
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        // Image
                        Container(
                          height: size.height * 0.25,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                          ),
                          child: widget.location.photoReference != null
                              ? Image.network(
                                  'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${widget.location.photoReference}&key=${dotenv.env['GOOGLE_PLACE_API_KEY']}',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Icon(
                                        Icons.restaurant_menu_rounded,
                                        size: 60,
                                        color: Colors.grey[400],
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Icon(
                                    Icons.restaurant_menu_rounded,
                                    size: 60,
                                    color: Colors.grey[400],
                                  ),
                                ),
                        ),
                        // Gradient overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.7),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Save button & close button at top
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            children: [
                              // Save button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: _isLoading
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            color: colorScheme.primary,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          _isSaved
                                              ? Icons.bookmark
                                              : Icons.bookmark_border,
                                          color: colorScheme.primary,
                                        ),
                                  onPressed: _isLoading ? null : _toggleSave,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Close button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                  onPressed: widget.onClose,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Location name at bottom of image
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Restaurant name with semi-transparent background
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 32, 54, 54)
                                      .withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  widget.location.name,
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    color: const Color.fromARGB(
                                        255, 252, 252, 252),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.location.cuisine != null &&
                                  widget.location.cuisine!.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer
                                        .withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    widget.location.cuisine!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Rating and Price
                          Row(
                            children: [
                              // Rating
                              if (widget.location.rating != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[700],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${widget.location.rating!.toStringAsFixed(1)} (${widget.location.userRatingsTotal ?? 0})',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(width: 12),
                              // Price level
                              if (widget.location.priceLevel != null &&
                                  widget.location.priceLevel! > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green[700],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '\$' * widget.location.priceLevel!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              // Saved count badge
                              if (widget.location.savedCount != null &&
                                  widget.location.savedCount! > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 12),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.bookmark_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${widget.location.savedCount}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Address
                          _buildInfoRow(
                            context,
                            Icons.location_on,
                            widget.location.vicinity,
                            colorScheme,
                          ),

                          // Phone
                          if (widget.location.phoneNumber != null)
                            InkWell(
                              onTap: () =>
                                  _launchPhone(widget.location.phoneNumber!),
                              child: _buildInfoRow(
                                context,
                                Icons.phone,
                                widget.location.phoneNumber!,
                                colorScheme,
                                isLink: true,
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Location on map preview
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                color: Colors.grey[300],
                                child: Stack(
                                  children: [
                                    // Map preview image - using Static Maps API
                                    Image.network(
                                      'https://maps.googleapis.com/maps/api/staticmap?center=${widget.location.lat},${widget.location.lng}&zoom=15&size=600x300&maptype=roadmap&markers=color:red%7C${widget.location.lat},${widget.location.lng}&key=${dotenv.env['GOOGLE_PLACE_API_KEY']}',
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Center(
                                          child: Icon(
                                            Icons.map,
                                            size: 60,
                                            color: Colors.grey[400],
                                          ),
                                        );
                                      },
                                    ),
                                    // Overlay button to open in maps
                                    Positioned.fill(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _openInMaps(
                                              widget.location.lat,
                                              widget.location.lng,
                                              widget.location.name),
                                          child: Container(
                                            alignment: Alignment.center,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                              decoration: BoxDecoration(
                                                color: colorScheme.primary
                                                    .withOpacity(0.8),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.directions,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Directions',
                                                    style: theme
                                                        .textTheme.labelLarge
                                                        ?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Action buttons
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildActionButton(
                                  context,
                                  Icons.share,
                                  'Share',
                                  colorScheme,
                                  () {
                                    // Implement share functionality
                                  },
                                ),
                                _buildActionButton(
                                  context,
                                  _isSaved
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  _isSaved ? 'Saved' : 'Save',
                                  colorScheme,
                                  _isLoading ? null : _toggleSave,
                                ),
                                _buildActionButton(
                                  context,
                                  Icons.list_alt,
                                  'Reviews',
                                  colorScheme,
                                  () {
                                    // Implement reviews functionality
                                  },
                                ),
                              ],
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
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String text,
    ColorScheme colorScheme, {
    bool isLink = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: isLink ? colorScheme.primary : Colors.grey[700],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isLink ? colorScheme.primary : Colors.grey[800],
                fontSize: 15,
                fontWeight: isLink ? FontWeight.w500 : FontWeight.normal,
                decoration:
                    isLink ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    ColorScheme colorScheme,
    VoidCallback? onTap,
  ) {
    final isDisabled = onTap == null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isDisabled ? Colors.grey : colorScheme.primary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isDisabled ? Colors.grey : colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _launchPhone(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  // Helper method to get platform info safely
  TargetPlatform _getPlatform() {
    return defaultTargetPlatform; // Using the imported foundation.dart
  }

  void _openInMaps(double lat, double lng, String name) async {
    final String encodedName = Uri.encodeComponent(name);
    final String googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$encodedName';
    final String appleMapsUrl =
        'https://maps.apple.com/?q=$encodedName&ll=$lat,$lng';

    // For iOS, try Apple Maps first, for others use Google Maps
    if (_getPlatform() == TargetPlatform.iOS) {
      final Uri appleMapsUri = Uri.parse(appleMapsUrl);
      if (await canLaunchUrl(appleMapsUri)) {
        await launchUrl(appleMapsUri);
      } else {
        final Uri googleMapsUri = Uri.parse(googleMapsUrl);
        if (await canLaunchUrl(googleMapsUri)) {
          await launchUrl(googleMapsUri);
        }
      }
    } else {
      final Uri googleMapsUri = Uri.parse(googleMapsUrl);
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri);
      }
    }
  }
}

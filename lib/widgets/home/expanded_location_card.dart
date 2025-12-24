import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/supabase/service.dart';
import 'package:login/models/chat_group_model.dart';
import 'package:login/providers/user_data_provider.dart';
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
            .saveLocation(widget.location.locationId);
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

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: widget.onClose, // Close when tapping outside
        child: Container(
          width: size.width,
          height: size.height,
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping on the card
              child: Container(
                width: size.width * 0.92,
                height: size.height * 0.85,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with image
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: Stack(
                      children: [
                        // Image
                        Container(
                          height: size.height * 0.3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colorScheme.primary.withOpacity(0.3),
                                colorScheme.secondary.withOpacity(0.3),
                              ],
                            ),
                          ),
                          child: widget.location.photoReference != null
                              ? Image.network(
                                  'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference=${widget.location.photoReference}&key=${dotenv.env['GOOGLE_PLACE_API_KEY']}',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Icon(
                                        Icons.restaurant,
                                        size: 80,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    );
                                  },
                                )
                              : Center(
                                  child: Icon(
                                    Icons.restaurant,
                                    size: 80,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                        ),
                        // Gradient overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.6),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.8),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // Close button at top
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              onPressed: widget.onClose,
                            ),
                          ),
                        ),
                        // Location name and details at bottom of image
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Restaurant name
                              Text(
                                widget.location.name,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              // Cuisine badge
                              if (widget.location.cuisine != null &&
                                  widget.location.cuisine!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    widget.location.cuisine!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
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
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Key Stats Row - Rating, Price, Saved Count
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                // Rating
                                if (widget.location.rating != null)
                                  Expanded(
                                    child: _buildStatItem(
                                      Icons.star_rounded,
                                      '${widget.location.rating!.toStringAsFixed(1)}',
                                      '${widget.location.userRatingsTotal ?? 0} reviews',
                                      Colors.amber[700]!,
                                    ),
                                  ),
                                if (widget.location.rating != null &&
                                    widget.location.priceLevel != null)
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.grey[300],
                                  ),
                                // Price Level
                                if (widget.location.priceLevel != null &&
                                    widget.location.priceLevel! > 0)
                                  Expanded(
                                    child: _buildStatItem(
                                      Icons.attach_money_rounded,
                                      '\$' * widget.location.priceLevel!,
                                      _getPriceLabel(
                                          widget.location.priceLevel!),
                                      Colors.green[700]!,
                                    ),
                                  ),
                                if (widget.location.priceLevel != null &&
                                    widget.location.savedCount != null)
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.grey[300],
                                  ),
                                // Saved Count
                                if (widget.location.savedCount != null &&
                                    widget.location.savedCount! > 0)
                                  Expanded(
                                    child: _buildStatItem(
                                      Icons.bookmark_rounded,
                                      '${widget.location.savedCount}',
                                      'Saves',
                                      colorScheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Location Details Section
                          Text(
                            'Details',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Address
                          _buildModernInfoRow(
                            context,
                            Icons.location_on_rounded,
                            'Address',
                            widget.location.vicinity!,
                            colorScheme.primary,
                          ),

                          // Phone
                          if (widget.location.phoneNumber != null)
                            InkWell(
                              onTap: () =>
                                  _launchPhone(widget.location.phoneNumber!),
                              child: _buildModernInfoRow(
                                context,
                                Icons.phone_rounded,
                                'Phone',
                                widget.location.phoneNumber!,
                                Colors.blue[700]!,
                                isLink: true,
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Quick Actions Card
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Directions Button
                                InkWell(
                                  onTap: () => _openInMaps(
                                      widget.location.lat!,
                                      widget.location.lng!,
                                      widget.location.name),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16)),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.directions_rounded,
                                            color: Colors.blue[700],
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Get Directions',
                                                style: theme
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[800],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Open in maps app',
                                                style: theme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.arrow_forward_ios_rounded,
                                            size: 16, color: Colors.grey[400]),
                                      ],
                                    ),
                                  ),
                                ),
                                Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Colors.grey[200]),
                                // Add to Bubble Button
                                InkWell(
                                  onTap: () => _showAddToBubbleDialog(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.purple[50],
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.group_add_rounded,
                                            color: Colors.purple[700],
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Add to Bubble',
                                                style: theme
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[800],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Share with your groups',
                                                style: theme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.arrow_forward_ios_rounded,
                                            size: 16, color: Colors.grey[400]),
                                      ],
                                    ),
                                  ),
                                ),
                                Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Colors.grey[200]),
                                // Save/Unsave Button
                                InkWell(
                                  onTap: _isLoading ? null : _toggleSave,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(16),
                                    bottomRight: Radius.circular(16),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: _isSaved
                                                ? colorScheme.primary
                                                    .withOpacity(0.1)
                                                : Colors.grey[100],
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: _isLoading
                                              ? SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: colorScheme.primary,
                                                    strokeWidth: 2.5,
                                                  ),
                                                )
                                              : Icon(
                                                  _isSaved
                                                      ? Icons.bookmark_rounded
                                                      : Icons
                                                          .bookmark_border_rounded,
                                                  color: _isSaved
                                                      ? colorScheme.primary
                                                      : Colors.grey[700],
                                                  size: 24,
                                                ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _isSaved
                                                    ? 'Saved to your list'
                                                    : 'Save this place',
                                                style: theme
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey[800],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _isSaved
                                                    ? 'Tap to remove from saves'
                                                    : 'Add to your saved places',
                                                style: theme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: Colors.grey[600],
                                                ),
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

                          const SizedBox(height: 20),

                          // Map Preview
                          
                          const SizedBox(height: 30),
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
    ),
    );
  }

  // Show dialog to select bubble to add location to
  Future<void> _showAddToBubbleDialog(BuildContext context) async {
    final supabaseService = Provider.of<SupabaseService>(context, listen: false);
    final userDataProvider = Provider.of<UserDataProvider>(context, listen: false);
    final userId = userDataProvider.supabaseUserData?.supabaseId;

    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to add to bubbles')),
        );
      }
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Fetch user's bubbles
      final bubbles = await supabaseService.bubbles.getUserBubbles(userId);
      
      if (!mounted) return;
      
      // Close loading dialog
      Navigator.pop(context);

      if (bubbles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You don\'t have any bubbles yet. Create one first!'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Show bubble selection dialog
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _buildBubbleSelectionSheet(bubbles, userId),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bubbles: $e')),
        );
      }
    }
  }

  // Build the bubble selection bottom sheet
  Widget _buildBubbleSelectionSheet(List<ChatGroupModel> bubbles, String userId) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.group_add_rounded, color: Colors.grey[700]),
                const SizedBox(width: 12),
                Text(
                  'Add to Bubble',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Select a bubble to share this location',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Bubble list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: bubbles.length,
              itemBuilder: (context, index) {
                final bubble = bubbles[index];
                return _buildBubbleItem(bubble, userId);
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // Build individual bubble item
  Widget _buildBubbleItem(ChatGroupModel bubble, String userId) {
    return InkWell(
      onTap: () => _addLocationToBubble(bubble, userId),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            // Group avatar
            CircleAvatar(
              radius: 24,
              backgroundImage: bubble.groupAvatar.isNotEmpty
                  ? NetworkImage(bubble.groupAvatar)
                  : null,
              backgroundColor: Colors.blue[100],
              child: bubble.groupAvatar.isEmpty
                  ? Icon(Icons.group, color: Colors.blue[700], size: 28)
                  : null,
            ),
            const SizedBox(width: 14),
            // Group info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bubble.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${bubble.memberCount} members · ${bubble.groupLocations.length} locations',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // Add location to selected bubble
  Future<void> _addLocationToBubble(ChatGroupModel bubble, String userId) async {
    final supabaseService = Provider.of<SupabaseService>(context, listen: false);
    
    // Close the bubble selection sheet
    Navigator.pop(context);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await supabaseService.bubbles.addLocationToBubble(
        bubbleId: bubble.id,
        locationId: widget.location.locationId,
        addedBy: userId,
        note: 'Shared from explore',
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Added to "${bubble.name}"'),
                ),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to add location to bubble'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // New stat item widget for the stats card
  Widget _buildStatItem(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Get price level description
  String _getPriceLabel(int priceLevel) {
    switch (priceLevel) {
      case 1:
        return 'Inexpensive';
      case 2:
        return 'Moderate';
      case 3:
        return 'Expensive';
      case 4:
        return 'Very Expensive';
      default:
        return '';
    }
  }

  // Modern info row with better styling
  Widget _buildModernInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String text,
    Color iconColor, {
    bool isLink = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    color: isLink ? iconColor : Colors.grey[800],
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    decoration:
                        isLink ? TextDecoration.underline : TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          if (isLink)
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey[400],
            ),
        ],
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

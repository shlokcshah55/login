import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:login/models/chat_group_model.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/supabase/service.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../models/locations.dart';

class ExpandedLocationCard extends StatefulWidget {
  const ExpandedLocationCard({
    super.key,
    required this.location,
    required this.onClose,
  });

  final LocationModel location;
  final VoidCallback onClose;

  @override
  State<ExpandedLocationCard> createState() => _ExpandedLocationCardState();
}

class _ExpandedLocationCardState extends State<ExpandedLocationCard> {
  bool _isSaved = false;
  bool _isLoading = false;

  final TextEditingController _commentController = TextEditingController();

  // Temporary mock data (replace with real models later)
  final List<_MockReview> _mockReviews = const [
    _MockReview(
      name: 'Ava R.',
      rating: 4.5,
      timeAgo: '2h ago',
      comment: 'Great atmosphere and the staff remembered our order.',
    ),
    _MockReview(
      name: 'Marcus T.',
      rating: 4.0,
      timeAgo: '1d ago',
      comment: 'Solid spot for a quick bite. Try the special.',
    ),
    _MockReview(
      name: 'Priya S.',
      rating: 5.0,
      timeAgo: '3d ago',
      comment: 'Best in the neighborhood. Loved the drinks.',
    ),
  ];

  final List<_MockActivity> _mockActivities = const [
    _MockActivity(
      title: 'Julia saved this place',
      timeAgo: '45m',
      icon: Icons.bookmark_rounded,
      color: Colors.indigo,
    ),
    _MockActivity(
      title: 'Leo left a 5-star review',
      timeAgo: '4h',
      icon: Icons.star_rounded,
      color: Colors.orange,
    ),
    _MockActivity(
      title: 'Maya shared it to a bubble',
      timeAgo: '1d',
      icon: Icons.group_rounded,
      color: Colors.teal,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkIfLocationIsSaved();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkIfLocationIsSaved() async {
    final supabase = context.read<SupabaseService>();

    setState(() => _isLoading = true);
    try {
      final saved =
          await supabase.locations.isLocationSaved(widget.location.locationId);
      if (!mounted) return;
      setState(() => _isSaved = saved);
    } catch (e) {
      debugPrint('Error checking saved state: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSave() async {
    final supabase = context.read<SupabaseService>();

    setState(() => _isLoading = true);
    try {
      final ok = _isSaved
          ? await supabase.locations.unsaveLocation(widget.location.locationId)
          : await supabase.locations.saveLocation(widget.location.locationId);

      if (!ok || !mounted) return;

      setState(() => _isSaved = !_isSaved);
      await _updateLocationList(saved: _isSaved);
    } catch (e) {
      debugPrint('Error toggling save state: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLocationList({required bool saved}) async {
    final manager = context.read<LocationListManager>();

    if (saved) {
      debugPrint('Adding location to saved list');
      await manager.saveLocation(widget.location);
    } else {
      debugPrint('Removing location from saved list');
      await manager.removeLocation(widget.location);
      await manager.fetchSavedLocations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final tags = _getDisplayTags();
    final hasCoords = widget.location.lat != null && widget.location.lng != null;
    final openNow = widget.location.openNow;

    final showWebsite =
        widget.location.openNow == true && widget.location.website != null;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: widget.onClose,
        child: Stack(
          children: [
            // Dimmed background
            Container(
              color: Colors.black.withOpacity(0.20),
              child: GestureDetector(
                onTap: () {}, // Prevent taps on sheet from closing
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: DraggableScrollableSheet(
                    initialChildSize: 0.60,
                    minChildSize: 0.55,
                    maxChildSize: 0.95,
                    snap: true,
                    snapSizes: const [0.60, 0.95],
                    builder: (context, scrollController) {
                      return NotificationListener<DraggableScrollableNotification>(
                        onNotification: (notification) {
                          if (notification.extent < 0.52) widget.onClose();
                          return true;
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.20),
                                blurRadius: 18,
                                offset: const Offset(0, -6),
                              ),
                            ],
                          ),
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(20),
                            children: [
                              _DragHandle(),
                              const SizedBox(height: 16),
                              _Header(
                                name: widget.location.name,
                                address: widget.location.vicinity ?? 'Address not available',
                                onClose: widget.onClose,
                              ),
                              const SizedBox(height: 20),

                              if (widget.location.photoReference != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: CachedNetworkImage(
                                    imageUrl: widget.location.photoReference!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: size.height * 0.25,
                                    placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) {
                                      return Center(
                                        child: Icon(
                                          Icons.restaurant,
                                          size: 80,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                              const SizedBox(height: 12),

                              Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildFloatingTag(
                                      openNow == true
                                          ? 'Open'
                                          : openNow == false
                                              ? 'Closed'
                                              : 'Hours N/A',
                                      openNow == true
                                          ? Colors.green
                                          : openNow == false
                                              ? Colors.red
                                              : Colors.grey,
                                      icon: openNow == true
                                          ? Icons.check_circle
                                          : Icons.schedule,
                                    ),
                                    if (widget.location.priceLevel != null &&
                                        widget.location.priceLevel! > 0)
                                      _buildFloatingTag(
                                        r'$' * widget.location.priceLevel!,
                                        Colors.green,
                                      ),
                                    if (widget.location.rating != null)
                                      _buildFloatingTag(
                                        '${widget.location.rating!.toStringAsFixed(1)} ⭐',
                                        Colors.orange,
                                      ),
                                    ...tags
                                        .take(2)
                                        .map(
                                          (t) => _buildFloatingTag(
                                            t,
                                            colorScheme.primary
                                                .withOpacity(0.80),
                                          ),
                                        )
                                        .toList(),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildActionBubble(
                                      icon: _isSaved
                                          ? Icons.bookmark
                                          : Icons.bookmark_border,
                                      label: _isSaved ? 'Saved' : 'Save',
                                      color: _isSaved
                                          ? colorScheme.primary
                                          : Colors.grey[700]!,
                                      onTap: _isLoading ? null : _toggleSave,
                                    ),
                                    _buildActionBubble(
                                      icon: Icons.thumb_down_outlined,
                                      label: 'Dislike',
                                      color: Colors.red[400]!,
                                      onTap: () => _dislikeLocation(context),
                                    ),
                                    _buildActionBubble(
                                      icon: Icons.group_add_rounded,
                                      label: 'Add to Bubble',
                                      color: Colors.purple[600]!,
                                      onTap: () =>
                                          _showAddToBubbleDialog(context),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                if (widget.location.photoReference != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      widget.location.photoReference!,
                                      height: size.height * 0.20,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: size.height * 0.20,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Icon(
                                          Icons.restaurant,
                                          size: 60,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                if (tags.length > 2) ...[
                                  Text(
                                    'Top Categories',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ...tags
                                      .skip(2)
                                      .take(3)
                                      .map(_buildTagWithScore),
                                  const SizedBox(height: 24),
                                ],

                                Text(
                                  'Reviews & Activity',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                ..._mockActivities
                                    .map((a) => _buildActivityItem(a, theme)),

                                const SizedBox(height: 20),

                                ..._mockReviews.map(_buildMockReviewCard),

                                const SizedBox(height: 24),

                                _buildAddReviewSection(theme, colorScheme),

                                const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Floating actions above the card
            Positioned(
              bottom: size.height * 0.60 + 8,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showWebsite && widget.location.website != null)
                    FloatingActionButton.small(
                      heroTag: 'website',
                      onPressed: () =>
                          _launchWebsite(widget.location.website!),
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.language_rounded,
                        color: colorScheme.primary,
                      ),
                    ),
                  if (showWebsite && hasCoords) const SizedBox(height: 12),
                  if (hasCoords)
                    FloatingActionButton.small(
                      heroTag: 'directions',
                      onPressed: () => _openInMaps(
                        widget.location.lat!,
                        widget.location.lng!,
                        widget.location.name,
                      ),
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.directions_rounded,
                        color: Colors.blue[700],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddReviewSection(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leave your review',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              5,
              (_) => IconButton(
                icon: Icon(
                  Icons.star_rounded,
                  color: Colors.orange[300],
                ),
                onPressed: () {},
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Share your experience...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleMockCommentSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Submit Review'),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getDisplayTags() {
    final tags = <String>{};

    void addTag(String? value) {
      if (value == null) return;
      final v = value.trim();
      if (v.isEmpty) return;
      tags.add(_formatTag(v));
    }

    addTag(widget.location.cuisinePrimary);
    addTag(widget.location.cuisine);
    addTag(widget.location.cuisineDetected);
    addTag(widget.location.priceBucket);

    final types = widget.location.types;
    if (types != null && types.trim().isNotEmpty) {
      for (final type in types.split(',')) {
        addTag(type);
      }
    }

    return tags.take(6).toList();
  }

  String _formatTag(String raw) {
    final cleaned = raw.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (cleaned.isEmpty) return cleaned;

    final words = cleaned.split(RegExp(r'\s+'));
    return words
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Widget _buildFloatingTag(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.90),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.30),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBubble({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final disabled = onTap == null;
    final effectiveColor = disabled ? Colors.grey : color;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: effectiveColor.withOpacity(0.10),
              border: Border.all(color: effectiveColor, width: 2),
            ),
            child: Icon(icon, color: effectiveColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagWithScore(String tag) {
    final score = 70 + (tag.hashCode % 26);
    final color = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tag,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                '$score%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(_MockActivity activity, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: activity.color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(activity.icon, color: activity.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.timeAgo,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockReviewCard(_MockReview review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blueGrey[100],
                child: Text(
                  review.name[0],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  review.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                review.timeAgo,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildStarRow(review.rating),
          const SizedBox(height: 8),
          Text(review.comment, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildStarRow(double rating) {
    return Row(
      children: List.generate(5, (index) {
        final starValue = index + 1;

        final IconData icon = rating >= starValue
            ? Icons.star_rounded
            : rating >= starValue - 0.5
                ? Icons.star_half_rounded
                : Icons.star_border_rounded;

        return Icon(icon, size: 16, color: Colors.orange[700]);
      }),
    );
  }

  void _handleMockCommentSubmit() {
    final message = _commentController.text.trim();
    if (message.isEmpty) return;

    _commentController.clear();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mock comment posted.')),
    );
  }

  void _dislikeLocation(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Location marked as disliked'),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _launchWebsite(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showAddToBubbleDialog(BuildContext context) async {
    final supabase = context.read<SupabaseService>();
    final userData = context.read<UserDataProvider>();
    final userId = userData.supabaseUserData?.supabaseId;

    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add to bubbles')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final bubbles = await supabase.bubbles.getUserBubbles(userId);
      if (!mounted) return;

      Navigator.pop(context); // close loading

      if (bubbles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You don\'t have any bubbles yet. Create one first!'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _buildBubbleSelectionSheet(bubbles, userId),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading bubbles: $e')),
      );
    }
  }

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
          _SheetHandle(),
          const SizedBox(height: 20),
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
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: bubbles.length,
              itemBuilder: (_, index) => _buildBubbleItem(bubbles[index], userId),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

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
            CircleAvatar(
              radius: 24,
              backgroundImage:
                  bubble.groupAvatar.isNotEmpty ? NetworkImage(bubble.groupAvatar) : null,
              backgroundColor: Colors.blue[100],
              child: bubble.groupAvatar.isEmpty
                  ? Icon(Icons.group, color: Colors.blue[700], size: 28)
                  : null,
            ),
            const SizedBox(width: 14),
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
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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

  Future<void> _addLocationToBubble(ChatGroupModel bubble, String userId) async {
    final supabase = context.read<SupabaseService>();

    Navigator.pop(context); // close sheet

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final ok = await supabase.bubbles.addLocationToBubble(
        bubbleId: bubble.id,
        locationId: widget.location.locationId,
        addedBy: userId,
        note: 'Shared from explore',
      );

      if (!mounted) return;

      Navigator.pop(context); // close loading

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Added to "${bubble.name}"')),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to add location to bubble'),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  TargetPlatform _getPlatform() => defaultTargetPlatform;

  Future<void> _openInMaps(double lat, double lng, String name) async {
    final encodedName = Uri.encodeComponent(name);

    // Note: your original "query_place_id" usage looks incorrect (it expects a Place ID).
    // Keeping your behavior while improving structure.
    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$encodedName';
    final appleMapsUrl = 'https://maps.apple.com/?q=$encodedName&ll=$lat,$lng';

    if (_getPlatform() == TargetPlatform.iOS) {
      final apple = Uri.parse(appleMapsUrl);
      if (await canLaunchUrl(apple)) {
        await launchUrl(apple);
        return;
      }
    }

    final google = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(google)) {
      await launchUrl(google);
    }
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.address,
    required this.onClose,
  });

  final String name;
  final String address;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close_rounded, color: Colors.grey[600]),
          onPressed: onClose,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

class _MockReview {
  const _MockReview({
    required this.name,
    required this.rating,
    required this.timeAgo,
    required this.comment,
  });

  final String name;
  final double rating;
  final String timeAgo;
  final String comment;
}

class _MockActivity {
  const _MockActivity({
    required this.title,
    required this.timeAgo,
    required this.icon,
    required this.color,
  });

  final String title;
  final String timeAgo;
  final IconData icon;
  final Color color;
}

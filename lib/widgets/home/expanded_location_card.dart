import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:login/models/bubble.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/supabase/service.dart';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/helpers/location_reviews.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpandedLocationCard extends StatefulWidget {
  const ExpandedLocationCard({
    Key? key,
    required this.location,
    required this.onClose,
  }) : super(key: key);

  final LocationModel location;
  final VoidCallback onClose;

  @override
  State<ExpandedLocationCard> createState() => _ExpandedLocationCardState();
}

class _ExpandedLocationCardState extends State<ExpandedLocationCard>
    with SingleTickerProviderStateMixin {
  bool _isSaved = false;
  int _currentPhotoIndex = 0;
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late final List<String> _photos;
  final LocationReviewsHelper _reviewsHelper = LocationReviewsHelper();
  final TextEditingController _reviewController = TextEditingController();
  final FocusNode _reviewFocusNode = FocusNode();
  bool _isLoadingReview = false;
  bool _isSubmittingReview = false;
  String? _reviewError;
  Map<String, dynamic>? _review;
  bool _reviewIsCurrentUser = false;
  int _selectedRating = 0;

  @override
  void initState() {
    super.initState();
    _photos = _resolvePhotoUrls();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
    _loadReview();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _reviewFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleClose() {
    _controller.reverse().then((_) => widget.onClose());
  }

  Future<void> _loadReview() async {
    if (!_isRestaurant()) {
      return;
    }

    setState(() {
      _isLoadingReview = true;
      _reviewError = null;
    });

    try {
      final userId = SupabaseClientManager().currentUser?.id;
      final locationId = widget.location.locationId;

      Map<String, dynamic>? userReview;
      if (userId != null) {
        userReview = await _reviewsHelper.getUserReview(
          locationId: locationId,
          userId: userId,
        );
      }

      if (userReview != null) {
        _review = userReview;
        _reviewIsCurrentUser = true;
      } else {
        _review = await _reviewsHelper.getLatestPublicReview(
          locationId: locationId,
        );
        _reviewIsCurrentUser = false;
      }
    } catch (e) {
      _reviewError = 'Could not load reviews.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingReview = false;
        });
      }
    }
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0 || _reviewController.text.trim().isEmpty) {
      setState(() {
        _reviewError = 'Please add a rating and a short review.';
      });
      return;
    }

    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) {
      setState(() {
        _reviewError = 'Sign in to leave a review.';
      });
      return;
    }

    setState(() {
      _isSubmittingReview = true;
      _reviewError = null;
    });

    try {
      await _reviewsHelper.createReview(
        locationId: widget.location.locationId,
        userId: userId,
        content: _reviewController.text.trim(),
        rating: _selectedRating,
        isPrivate: false,
      );
      _reviewController.clear();
      _selectedRating = 0;
      _reviewFocusNode.unfocus();
      await _loadReview();
    } catch (e) {
      setState(() {
        _reviewError = 'Could not submit review: ${_formatSupabaseError(e)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingReview = false;
        });
      }
    }
  }

  bool _isRestaurant() {
    final types = widget.location.types?.toLowerCase() ?? '';
    if (types.contains('restaurant')) return true;
    if ((widget.location.cuisine ?? '').trim().isNotEmpty) return true;
    return false;
  }

  List<String> _resolvePhotoUrls() {
    final urls = <String>[];
    final primary = widget.location.imageUrl?.trim();
    if (primary != null && primary.isNotEmpty) {
      urls.add(primary);
    }
    final fallback = widget.location.photoReference?.trim();
    if (fallback != null && fallback.isNotEmpty && fallback != primary) {
      urls.add(fallback);
    }
    return urls;
  }

  Widget _buildImagePlaceholder(ThemeData theme, {bool isError = false}) {
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceVariant,
            colorScheme.surfaceVariant.withOpacity(0.8),
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
              isError ? Icons.broken_image_outlined : Icons.photo_outlined,
              size: 42,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            const SizedBox(height: 8),
            Text(
              isError ? 'Image unavailable' : 'Loading image',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _openStatusLabel() {
    final isOpen = widget.location.openNow;
    if (isOpen == true) return 'Open';
    if (isOpen == false) return 'Closed';
    return 'Hours unknown';
  }

  Color _openStatusColor() {
    final isOpen = widget.location.openNow;
    if (isOpen == true) return Colors.green;
    if (isOpen == false) return Colors.redAccent;
    return Colors.grey;
  }

  IconData _openStatusIcon() {
    final isOpen = widget.location.openNow;
    if (isOpen == true) return Icons.check_circle;
    if (isOpen == false) return Icons.cancel;
    return Icons.schedule;
  }

  String _priceLabel() {
    final bucket = widget.location.priceBucket?.trim();
    if (bucket != null && bucket.isNotEmpty) {
      return bucket;
    }

    final level = widget.location.priceLevel;
    if (level == null) return '';

    final clamped = level.clamp(0, 4) as int;
    return '\$' * (clamped + 1);
  }

  List<String> _buildTags() {
    final tags = <String>[];

    void addTag(String? value) {
      if (value == null) return;
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      if (!tags.contains(trimmed)) {
        tags.add(trimmed);
      }
    }

    addTag(widget.location.cuisinePrimary);
    addTag(widget.location.cuisine);
    addTag(widget.location.cuisineDetected);

    final types = widget.location.types
        ?.split(',')
        .map((type) => type.replaceAll('_', ' ').trim())
        .where((type) => type.isNotEmpty)
        .toList();

    if (types != null) {
      for (final type in types) {
        if (type == 'point of interest' || type == 'establishment') {
          continue;
        }
        addTag(_titleCase(type));
        if (tags.length >= 5) break;
      }
    }

    if (widget.location.isOpenLate == true) {
      addTag('Open late');
    }
    if (widget.location.isOpenEarly == true) {
      addTag('Open early');
    }
    if (widget.location.isSundayOpen == true) {
      addTag('Sunday hours');
    }

    if (tags.isEmpty) {
      tags.add('Recommended');
    }

    return tags.take(5).toList();
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) {
      final value = count / 1000;
      final digits = count >= 10000 ? 0 : 1;
      return '${value.toStringAsFixed(digits)}k';
    }
    final value = count / 1000000;
    final digits = count >= 10000000 ? 0 : 1;
    return '${value.toStringAsFixed(digits)}m';
  }

  List<Widget> _intersperse(List<Widget> items, Widget separator) {
    if (items.length <= 1) return items;
    final spaced = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) spaced.add(separator);
      spaced.add(items[i]);
    }
    return spaced;
  }

  String _formatTimeAgo(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(parsed);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatSupabaseError(Object error) {
    if (error is PostgrestException) {
      return error.message;
    }
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _handleClose,
        child: Stack(
          children: [
            // Animated backdrop
            AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Container(
                  color: Colors.black.withOpacity(0.4 * _slideAnimation.value),
                );
              },
            ),

            // Main card sheet
            AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Transform.translate(
                    offset: Offset(0, (1 - _slideAnimation.value) * size.height * 0.3),
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                onTap: () {}, // Prevent backdrop tap
                child: DraggableScrollableSheet(
                  initialChildSize: 0.92,
                  minChildSize: 0.5,
                  maxChildSize: 0.92,
                  snap: true,
                  builder: (context, scrollController) {
                    return NotificationListener<DraggableScrollableNotification>(
                      onNotification: (notification) {
                        if (notification.extent <=
                            notification.minExtent + 0.01) {
                          _handleClose();
                        }
                        return true;
                      },
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Scrollable content
                            ListView(
                              controller: scrollController,
                              padding: EdgeInsets.zero,
                              children: [
                                // Hero image section
                                _buildHeroSection(size),
                                
                                // Main content
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildHeader(),
                                      const SizedBox(height: 20),
                                      _buildMetadata(),
                                      const SizedBox(height: 24),
                                      _buildActionButtons(),
                                      const SizedBox(height: 28),
                                      _buildTagsSection(),
                                      const SizedBox(height: 32),
                                      _buildGroupMatchSection(),
                                      const SizedBox(height: 32),
                                      _buildReviewHighlight(),
                                      const SizedBox(height: 32),
                                      _buildActivityFeed(),
                                      const SizedBox(height: 32),
                                      _buildSimilarPlaces(),
                                      const SizedBox(height: 100),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Drag handle
                            Positioned(
                              top: 12,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Floating close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: GestureDetector(
                onTap: _handleClose,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(Size size) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        // Photo carousel
        SizedBox(
          height: size.height * 0.38,
          child: _photos.isEmpty
              ? _buildImagePlaceholder(theme)
              : PageView.builder(
                  itemCount: _photos.length,
                  onPageChanged: (index) {
                    setState(() => _currentPhotoIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: _photos[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              _buildImagePlaceholder(theme),
                          errorWidget: (context, url, error) =>
                              _buildImagePlaceholder(theme, isError: true),
                        ),
                        // Bottom gradient
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),

        // Photo indicators
        if (_photos.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_photos.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPhotoIndex == index ? 24 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPhotoIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),

        // Status badges (top left)
        Positioned(
          top: 80,
          left: 16,
          child: Row(
            children: [
              _buildStatusBadge(_openStatusLabel(), _openStatusColor(),
                  _openStatusIcon()),
              if (_priceLabel().isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildStatusBadge(_priceLabel(), const Color(0xFF10B981)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String label, Color color, [IconData? icon]) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.location.name,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: Color(0xFF6B7280)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.location.vicinity ?? 'Nearby',
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetadata() {
    final chips = <Widget>[];

    if (widget.location.rating != null) {
      chips.add(
        _buildMetadataChip(
          widget.location.rating!.toStringAsFixed(1),
          Icons.star_rounded,
          const Color(0xFFF59E0B),
        ),
      );
    }

    if (widget.location.userRatingsTotal != null) {
      chips.add(
        _buildMetadataChip(
          _formatCount(widget.location.userRatingsTotal!),
          Icons.chat_bubble_outline_rounded,
          const Color(0xFF6B7280),
        ),
      );
    }

    if (widget.location.savedCount != null) {
      chips.add(
        _buildMetadataChip(
          _formatCount(widget.location.savedCount!),
          Icons.bookmark_rounded,
          const Color(0xFF6B4A8E),
        ),
      );
    }

    if (chips.isEmpty) {
      chips.add(
        _buildMetadataChip(
          'New',
          Icons.fiber_new_rounded,
          const Color(0xFF10B981),
        ),
      );
    }

    return Row(
      children: _intersperse(chips, const SizedBox(width: 12)),
    );
  }

  Widget _buildMetadataChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildPrimaryButton(
            'Add to Bubble',
            Icons.group_add_rounded,
            const Color(0xFF6B4A8E),
            onTap: () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSecondaryButton(
            _isSaved ? 'Saved' : 'Save',
            _isSaved ? Icons.bookmark : Icons.bookmark_border,
            onTap: () => setState(() => _isSaved = !_isSaved),
          ),
        ),
        const SizedBox(width: 12),
        _buildIconButton(
          Icons.share_outlined,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String label, IconData icon, Color color,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(String label, IconData icon,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF6B4A8E), size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        ),
        child: Icon(icon, color: const Color(0xFF6B4A8E), size: 20),
      ),
    );
  }

  Widget _buildTagsSection() {
    final tags = _buildTags();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vibe & Cuisine',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) => _buildTag(tag)).toList(),
        ),
      ],
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _buildGroupMatchSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6B4A8E).withOpacity(0.08),
            const Color(0xFF8B5FA8).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6B4A8E).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B4A8E).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.people_rounded,
                  color: Color(0xFF6B4A8E),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Group Match',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMemberAvatar('S', Colors.blue),
              _buildMemberAvatar('Y', Colors.purple),
              _buildMemberAvatar('A', Colors.orange, neutral: true),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Matches Shlok + You · Neutral for Alex',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAvatar(String initial, Color color, {bool neutral = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: neutral ? Colors.grey[300] : color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: neutral ? Colors.grey : color,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: neutral ? Colors.grey[700] : color,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewHighlight() {
    final reviewText = _review != null
        ? (_review![SupabaseConstants.columnContentReview]
                ?.toString()
                .trim() ??
            '')
        : (widget.location.editorialSummary?.trim() ?? '');
    final rating = _review?[SupabaseConstants.columnRatingReview] as int?;
    final createdAt = _review?[SupabaseConstants.columnCreatedAt]?.toString();
    final timestampLabel =
        createdAt != null ? _formatTimeAgo(createdAt) : null;
    final sourceLabel = _reviewIsCurrentUser ? 'Your review' : 'Community';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reviews',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingReview)
          const Center(child: CircularProgressIndicator())
        else if (reviewText.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      final isFilled =
                          rating != null ? index < rating : true;
                      return Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: isFilled
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFFDE68A),
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      sourceLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '"$reviewText"',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF78350F),
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (timestampLabel != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    timestampLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.brown[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          const Text(
            'No reviews yet. Be the first to share a quick thought!',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        if (_isRestaurant()) ...[
          const SizedBox(height: 20),
          _buildReviewComposer(),
        ],
        if (_reviewError != null) ...[
          const SizedBox(height: 12),
          Text(
            _reviewError!,
            style: const TextStyle(
              color: Color(0xFFB91C1C),
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewComposer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add your review',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final ratingValue = index + 1;
            final isSelected = ratingValue <= _selectedRating;
            return IconButton(
              onPressed: () {
                setState(() {
                  _selectedRating = ratingValue;
                });
              },
              icon: Icon(
                Icons.star_rounded,
                color: isSelected
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFFE5E7EB),
              ),
            );
          }),
        ),
        TextField(
          controller: _reviewController,
          focusNode: _reviewFocusNode,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Share what you loved...',
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmittingReview ? null : _submitReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4A8E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmittingReview
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Post Review'),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityFeed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        _buildActivityItem(
          'Julia saved this place',
          '45m ago',
          Icons.bookmark_rounded,
          const Color(0xFF6366F1),
        ),
        _buildActivityItem(
          'Leo left a 5-star review',
          '4h ago',
          Icons.star_rounded,
          const Color(0xFFF59E0B),
        ),
        _buildActivityItem(
          'Maya shared to a bubble',
          '1d ago',
          Icons.group_rounded,
          const Color(0xFF14B8A6),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
      String title, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarPlaces() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Similar Places',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (context, index) {
              return _buildSimilarPlaceCard(index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSimilarPlaceCard(int index) {
    final names = ['Dishoom', 'Hoppers', 'Tayyabs'];
    final images = [
      'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=400',
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400',
      'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=400',
    ];

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              images[index],
              height: 90,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  names[index],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 12, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    const Text(
                      '4.7',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '\$\$',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

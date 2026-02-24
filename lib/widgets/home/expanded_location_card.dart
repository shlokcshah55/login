import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:login/models/locations.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/helpers/location_reviews.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/models/markers.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────
//  Match scoring helpers
// ─────────────────────────────────────────────────────────────

class _MatchResult {
  /// 0.0–1.0 normalised match score.
  final double score;

  /// Human-friendly percentage (0–100).
  int get percent => (score * 100).round();

  /// Top vibe tags that contributed most to the match.
  final List<MapEntry<String, double>> topContributors;

  /// Dietary match ratio (0.0–1.0). null when no dietary data.
  final double? dietaryMatch;

  const _MatchResult({
    required this.score,
    this.topContributors = const [],
    this.dietaryMatch,
  });

  String get label {
    if (score >= 0.80) return 'Perfect match';
    if (score >= 0.60) return 'Great match';
    if (score >= 0.40) return 'Good match';
    if (score >= 0.20) return 'Okay match';
    return 'New vibe';
  }

  Color get color {
    if (score >= 0.80) return const Color(0xFF10B981);
    if (score >= 0.60) return const Color(0xFF3B82F6);
    if (score >= 0.40) return const Color(0xFFF59E0B);
    if (score >= 0.20) return const Color(0xFFF97316);
    return const Color(0xFF8B5CF6);
  }
}

_MatchResult _buildMatchResult({
  required double? matchScore,
  required VibeVector? locationVibe,
  required List<int>? userVibeAffinity,
  required List<int>? locationDietary,
  required List<int>? userDietary,
}) {
  // Use pre-calculated match score from LocationModel to avoid double calculation
  final score = matchScore ?? 0.0;
  
  final contributors = <MapEntry<String, double>>[];
  double? dietaryMatch;

  // Calculate contributors for display (vibe-based)
  if (locationVibe != null &&
      locationVibe.values.isNotEmpty &&
      userVibeAffinity != null &&
      userVibeAffinity.isNotEmpty) {
    final locVals = locationVibe.values;
    final int len = math.min(locVals.length, userVibeAffinity.length);

    // Find top contributors: element-wise product, sorted descending.
    for (int i = 0; i < len && i < vibeTagsByIndex.length; i++) {
      final contribution = locVals[i] * userVibeAffinity[i].toDouble();
      if (contribution > 0) {
        contributors.add(MapEntry(vibeTagsByIndex[i], contribution));
      }
    }
    contributors.sort((a, b) => b.value.compareTo(a.value));
  }

  // Calculate dietary match for display
  if (locationDietary != null &&
      locationDietary.isNotEmpty &&
      userDietary != null &&
      userDietary.isNotEmpty) {
    final int len = math.min(locationDietary.length, userDietary.length);
    int matched = 0;
    int required = 0;
    for (int i = 0; i < len; i++) {
      if (userDietary[i] == 1) {
        required++;
        if (locationDietary[i] == 1) matched++;
      }
    }
    dietaryMatch = required > 0 ? matched / required : 1.0;
  }

  return _MatchResult(
    score: score,
    topContributors: contributors.take(5).toList(),
    dietaryMatch: dietaryMatch,
  );
}

// ─────────────────────────────────────────────────────────────
//  Vibe tag display helpers
// ─────────────────────────────────────────────────────────────

const Map<String, IconData> _vibeIcons = {
  'cafe': Icons.coffee_rounded,
  'casual': Icons.weekend_rounded,
  'cozy': Icons.fireplace_rounded,
  'coffee_shop': Icons.local_cafe_rounded,
  'bar': Icons.local_bar_rounded,
  'elegant': Icons.diamond_rounded,
  'fine_dining': Icons.restaurant_rounded,
  'food_truck': Icons.local_shipping_rounded,
  'hole_in_the_wall': Icons.door_front_door_rounded,
  'late_night': Icons.nightlife_rounded,
  'live_music': Icons.music_note_rounded,
  'michelin_starred': Icons.star_rounded,
  'modern': Icons.auto_awesome_rounded,
  'fast_food': Icons.fastfood_rounded,
  'quiet': Icons.volume_off_rounded,
  'romantic': Icons.favorite_rounded,
  'sports_bar': Icons.sports_bar_rounded,
  'trendy': Icons.local_fire_department_rounded,
  'takeout_friendly': Icons.takeout_dining_rounded,
  'pub': Icons.sports_bar_rounded,
  'grocery_store': Icons.store_rounded,
  'brunch': Icons.brunch_dining_rounded,
  'outdoor_dining': Icons.deck_rounded,
  'wavy': Icons.waves_rounded,
  'bossman': Icons.storefront_rounded,
};

const Map<String, Color> _vibeColors = {
  'cafe': Color(0xFF8D6E63),
  'casual': Color(0xFF78909C),
  'cozy': Color(0xFFFF8A65),
  'coffee_shop': Color(0xFF6D4C41),
  'bar': Color(0xFF7E57C2),
  'elegant': Color(0xFFCE93D8),
  'fine_dining': Color(0xFFE91E63),
  'food_truck': Color(0xFF66BB6A),
  'hole_in_the_wall': Color(0xFFFFB74D),
  'late_night': Color(0xFF5C6BC0),
  'live_music': Color(0xFFEF5350),
  'michelin_starred': Color(0xFFFFD700),
  'modern': Color(0xFF29B6F6),
  'fast_food': Color(0xFFFFA726),
  'quiet': Color(0xFF90A4AE),
  'romantic': Color(0xFFEC407A),
  'sports_bar': Color(0xFF42A5F5),
  'trendy': Color(0xFFFF7043),
  'takeout_friendly': Color(0xFF26A69A),
  'pub': Color(0xFF8D6E63),
  'grocery_store': Color(0xFF66BB6A),
  'brunch': Color(0xFFFDD835),
  'outdoor_dining': Color(0xFF81C784),
  'wavy': Color(0xFFE040FB),
  'bossman': Color(0xFF90A4AE),
};

String _vibeDisplayName(String tag) {
  return tag
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

// ─────────────────────────────────────────────────────────────
//  ExpandedLocationCard — redesigned
// ─────────────────────────────────────────────────────────────

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
    with TickerProviderStateMixin {
  // ── State ──
  bool _isSaved = false;
  bool _isSaving = false;
  bool _isDisliking = false;
  int _currentPhotoIndex = 0;

  late AnimationController _sheetController;
  late Animation<double> _sheetSlide;

  late AnimationController _matchController;
  late Animation<double> _matchAnim;

  late final List<String> _photos;
  late final _MatchResult _match;
  late final Color _accentColor;

  // Review state
  final LocationReviewsHelper _reviewsHelper = LocationReviewsHelper();
  final TextEditingController _reviewController = TextEditingController();
  final FocusNode _reviewFocusNode = FocusNode();
  bool _isLoadingReview = false;
  bool _isSubmittingReview = false;
  String? _reviewError;
  Map<String, dynamic>? _review;
  bool _reviewIsCurrentUser = false;
  int _selectedRating = 0;

  // Similar places
  List<_SimilarPlace> _similarPlaces = [];

  @override
  void initState() {
    super.initState();
    _photos = _resolvePhotoUrls();

    // Accent colour derived from cuisine
    _accentColor = PinitMarkerPalette.forCuisine(
      widget.location.cuisine,
      widget.location.types,
    );

    // Use pre-calculated match score from LocationModel, with locally-computed contributors
    final userProvider = Provider.of<UserDataProvider>(context, listen: false);
    _match = _buildMatchResult(
      matchScore: widget.location.matchScore,
      locationVibe: widget.location.vibe,
      userVibeAffinity: userProvider.vibeTagAffinity,
      locationDietary: widget.location.dietaryRequirementVector,
      userDietary: userProvider.dietaryRequirementTagAffinity,
    );

    // Sheet entrance
    _sheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _sheetSlide = CurvedAnimation(
      parent: _sheetController,
      curve: Curves.easeOutCubic,
    );
    _sheetController.forward();

    // Match ring animation (delayed start)
    _matchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _matchAnim = CurvedAnimation(
      parent: _matchController,
      curve: Curves.easeOutCubic,
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _matchController.forward();
    });

    _loadReview();
    _checkSavedStatus();
    _findSimilarPlaces();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _reviewFocusNode.dispose();
    _sheetController.dispose();
    _matchController.dispose();
    super.dispose();
  }

  // ── Data helpers ──

  void _checkSavedStatus() {
    final mgr = Provider.of<LocationListManager>(context, listen: false);
    setState(() {
      _isSaved = mgr.isLocationSavedSync(widget.location.locationId);
    });
  }

  Future<void> _toggleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final mgr = Provider.of<LocationListManager>(context, listen: false);
      if (_isSaved) {
        final ok = await mgr.unsaveLocation(widget.location);
        if (ok && mounted) setState(() => _isSaved = false);
      } else {
        await mgr.saveLocation(widget.location);
        if (mounted) setState(() => _isSaved = true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${_isSaved ? 'unsave' : 'save'}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _dislikeLocation() async {
    if (_isDisliking) return;
    setState(() => _isDisliking = true);
    try {
      final mgr = Provider.of<LocationListManager>(context, listen: false);
      final ok = await mgr.dislikeLocation(widget.location);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hidden from recommendations')),
        );
        _handleClose();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to hide location')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDisliking = false);
    }
  }

  void _handleClose() {
    _sheetController.reverse().then((_) => widget.onClose());
  }

  /// Find similar places by computing cosine similarity between this
  /// location's vibe vector and all other locations available in the
  /// [LocationListManager].  Results are ranked by similarity and
  /// the top 8 are kept.
  void _findSimilarPlaces() {
    final thisVibe = widget.location.vibe;
    if (thisVibe == null || thisVibe.values.isEmpty) return;

    final mgr = Provider.of<LocationListManager>(context, listen: false);

    // Gather all locations the manager knows about (saved + recommended).
    final all = <LocationModel>[
      ...mgr.savedLocations.keys,
      ...mgr.recommendedLocations.keys,
    ];

    // De-dupe by locationId and exclude the current location.
    final seen = <int>{widget.location.locationId};
    final candidates = <LocationModel>[];
    for (final loc in all) {
      if (seen.contains(loc.locationId)) continue;
      seen.add(loc.locationId);
      if (loc.vibe != null && loc.vibe!.values.isNotEmpty) {
        candidates.add(loc);
      }
    }

    // Score each candidate.
    final scored = <_SimilarPlace>[];
    for (final loc in candidates) {
      final sim = _cosineSimilarity(thisVibe.values, loc.vibe!.values);
      if (sim > 0.15) {
        // Find shared top vibes for the subtitle.
        final thisTop = thisVibe.topTags(4).map((e) => e.key).toSet();
        final thatTop = loc.vibe!.topTags(4).map((e) => e.key).toSet();
        final shared = thisTop.intersection(thatTop).take(2).toList();

        scored.add(_SimilarPlace(
          location: loc,
          similarity: sim,
          sharedVibes: shared,
        ));
      }
    }

    scored.sort((a, b) => b.similarity.compareTo(a.similarity));

    if (mounted) {
      setState(() {
        _similarPlaces = scored.take(8).toList();
      });
    }
  }

  static double _cosineSimilarity(List<double> a, List<double> b) {
    final int len = math.min(a.length, b.length);
    double dot = 0, magA = 0, magB = 0;
    for (int i = 0; i < len; i++) {
      dot += a[i] * b[i];
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }
    final denom = math.sqrt(magA) * math.sqrt(magB);
    return denom > 0 ? (dot / denom).clamp(0.0, 1.0) : 0.0;
  }

  Future<void> _openInGoogleMaps() async {
    final uri = widget.location.googleMapsUri;
    if (uri != null && uri.isNotEmpty) {
      final parsed = Uri.tryParse(uri);
      if (parsed != null && await canLaunchUrl(parsed)) {
        await launchUrl(parsed, mode: LaunchMode.externalApplication);
        return;
      }
    }
    // Fallback: open coords
    if (widget.location.lat != null && widget.location.lng != null) {
      final fallback = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query='
        '${widget.location.lat},${widget.location.lng}',
      );
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWebsite() async {
    final url = widget.location.website;
    if (url != null && url.isNotEmpty) {
      final parsed = Uri.tryParse(url);
      if (parsed != null) {
        await launchUrl(parsed, mode: LaunchMode.externalApplication);
      }
    }
  }

  // ── Review logic ──

  bool _isRestaurant() {
    final types = widget.location.types?.toLowerCase() ?? '';
    if (types.contains('restaurant')) return true;
    if ((widget.location.cuisine ?? '').trim().isNotEmpty) return true;
    return false;
  }

  Future<void> _loadReview() async {
    if (!_isRestaurant()) return;
    setState(() { _isLoadingReview = true; _reviewError = null; });
    try {
      final userId = SupabaseClientManager().currentUser?.id;
      Map<String, dynamic>? userReview;
      if (userId != null) {
        userReview = await _reviewsHelper.getUserReview(
          locationId: widget.location.locationId,
          userId: userId,
        );
      }
      if (userReview != null) {
        _review = userReview;
        _reviewIsCurrentUser = true;
      } else {
        _review = await _reviewsHelper.getLatestPublicReview(
          locationId: widget.location.locationId,
        );
        _reviewIsCurrentUser = false;
      }
    } catch (_) {
      _reviewError = 'Could not load reviews.';
    } finally {
      if (mounted) setState(() => _isLoadingReview = false);
    }
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0 || _reviewController.text.trim().isEmpty) {
      setState(() => _reviewError = 'Please add a rating and a short review.');
      return;
    }
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) {
      setState(() => _reviewError = 'Sign in to leave a review.');
      return;
    }
    setState(() { _isSubmittingReview = true; _reviewError = null; });
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
        _reviewError = 'Could not submit review: ${_formatError(e)}';
      });
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  // ── Utility ──

  List<String> _resolvePhotoUrls() {
    final urls = <String>[];
    final primary = widget.location.imageUrl?.trim();
    if (primary != null && primary.isNotEmpty) urls.add(primary);
    final fallback = widget.location.photoReference?.trim();
    if (fallback != null && fallback.isNotEmpty && fallback != primary) {
      urls.add(fallback);
    }
    return urls;
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(count >= 10000 ? 0 : 1)}k';
    return '${(count / 1000000).toStringAsFixed(count >= 10000000 ? 0 : 1)}m';
  }

  String _formatError(Object e) {
    if (e is PostgrestException) return e.message;
    return e.toString();
  }

  String _openStatusLabel() {
    final o = widget.location.openNow;
    if (o == true) return 'Open now';
    if (o == false) return 'Closed';
    return 'Hours unknown';
  }

  Color _openStatusColor() {
    final o = widget.location.openNow;
    if (o == true) return const Color(0xFF10B981);
    if (o == false) return const Color(0xFFEF4444);
    return const Color(0xFF9CA3AF);
  }

  String _priceLabel() {
    final bucket = widget.location.priceBucket?.trim();
    if (bucket != null && bucket.isNotEmpty) return bucket;
    final level = widget.location.priceLevel;
    if (level == null) return '';
    return '£' * (level.clamp(0, 4) + 1);
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _handleClose,
        child: Stack(
          children: [
            // Backdrop
            AnimatedBuilder(
              animation: _sheetSlide,
              builder: (_, __) => Container(
                color: Colors.black.withOpacity(0.5 * _sheetSlide.value),
              ),
            ),

            // Sheet
            AnimatedBuilder(
              animation: _sheetSlide,
              builder: (_, child) => Align(
                alignment: Alignment.bottomCenter,
                child: Transform.translate(
                  offset: Offset(0, (1 - _sheetSlide.value) * size.height * 0.4),
                  child: child,
                ),
              ),
              child: GestureDetector(
                onTap: () {},
                child: DraggableScrollableSheet(
                  initialChildSize: 0.93,
                  minChildSize: 0.5,
                  maxChildSize: 0.93,
                  snap: true,
                  builder: (context, scrollCtrl) {
                    return NotificationListener<DraggableScrollableNotification>(
                      onNotification: (n) {
                        if (n.extent <= n.minExtent + 0.01) _handleClose();
                        return true;
                      },
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFFAF9FB),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        child: Stack(
                          children: [
                            ListView(
                              controller: scrollCtrl,
                              padding: EdgeInsets.zero,
                              children: [
                                _buildHero(size),
                                _buildMatchBanner(),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 20),
                                      _buildNameAndLocation(),
                                      const SizedBox(height: 16),
                                      _buildQuickStats(),
                                      const SizedBox(height: 20),
                                      _buildActions(),
                                      const SizedBox(height: 28),
                                      _buildVibeSection(),
                                      if (widget.location.generatedSummary != null ||
                                          widget.location.editorialSummary != null) ...[
                                        const SizedBox(height: 28),
                                        _buildAboutSection(),
                                      ],
                                      const SizedBox(height: 28),
                                      _buildDetailsGrid(),
                                      if (widget.location.recommendedDishes != null) ...[
                                        const SizedBox(height: 28),
                                        _buildRecommendedDishes(),
                                      ],
                                      const SizedBox(height: 28),
                                      _buildReviewSection(),
                                      if (_similarPlaces.isNotEmpty) ...[
                                        const SizedBox(height: 32),
                                        _buildSimilarPlaces(),
                                      ],
                                      const SizedBox(height: 120),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Drag handle
                            Positioned(
                              top: 10,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD1D5DB),
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

            // Close button
            Positioned(
              top: topPad + 12,
              right: 14,
              child: _buildCloseButton(),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  HERO IMAGE
  // ══════════════════════════════════════════════════════════════

  Widget _buildHero(Size size) {
    return Stack(
      children: [
        SizedBox(
          height: size.height * 0.34,
          child: _photos.isEmpty
              ? _buildEmptyHero()
              : PageView.builder(
                  itemCount: _photos.length,
                  onPageChanged: (i) => setState(() => _currentPhotoIndex = i),
                  itemBuilder: (_, i) => Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: _photos[i],
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _buildEmptyHero(),
                        errorWidget: (_, __, ___) => _buildEmptyHero(isError: true),
                      ),
                      // Scrim gradient — darker at top for badges, lighter at bottom
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.45),
                                Colors.black.withOpacity(0.05),
                                Colors.black.withOpacity(0.20),
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        // Photo dots
        if (_photos.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_photos.length, (i) {
                final active = i == _currentPhotoIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),

        // Badges overlay — top of hero
        Positioned(
          top: 28,
          left: 16,
          right: 60, // leave room for close button area
          child: Row(
            children: [
              _glassBadge(
                _openStatusLabel(),
                dotColor: _openStatusColor(),
              ),
              if (_priceLabel().isNotEmpty) ...[
                const SizedBox(width: 8),
                _glassBadge(_priceLabel()),
              ],
              if (widget.location.vibe != null &&
                  widget.location.vibe!.wavyScore >= 0.35) ...[
                const SizedBox(width: 8),
                _glassBadge('✨ Wavy', textColor: const Color(0xFFE040FB)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyHero({bool isError = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accentColor.withOpacity(0.15),
            _accentColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          isError ? Icons.broken_image_outlined : Icons.restaurant_rounded,
          size: 48,
          color: _accentColor.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _glassBadge(String label, {Color? dotColor, Color? textColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: textColor ?? Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  MATCH BANNER — the hero metric
  // ══════════════════════════════════════════════════════════════

  Widget _buildMatchBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      transform: Matrix4.translationValues(0, -28, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _match.color.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Animated ring
          AnimatedBuilder(
            animation: _matchAnim,
            builder: (_, __) => SizedBox(
              width: 56,
              height: 56,
              child: CustomPaint(
                painter: _MatchRingPainter(
                  progress: _matchAnim.value * _match.score,
                  color: _match.color,
                  trackColor: const Color(0xFFF3F4F6),
                  strokeWidth: 5.0,
                ),
                child: Center(
                  child: Text(
                    '${(_matchAnim.value * _match.percent).round()}%',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _match.color,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _match.label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _match.color,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _match.topContributors.isNotEmpty
                      ? 'Based on ${_match.topContributors.take(3).map((e) => _vibeDisplayName(e.key).toLowerCase()).join(', ')}'
                      : 'Save more places to improve matching',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (_match.dietaryMatch != null)
            _dietaryBadge(_match.dietaryMatch!),
        ],
      ),
    );
  }

  Widget _dietaryBadge(double ratio) {
    final ok = ratio >= 0.8;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ok
            ? const Color(0xFF10B981).withOpacity(0.10)
            : const Color(0xFFF59E0B).withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 14,
            color: ok ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 4),
          Text(
            ok ? 'Diet ✓' : 'Diet ~',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ok ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  NAME & LOCATION
  // ══════════════════════════════════════════════════════════════

  Widget _buildNameAndLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.location.name,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
        if (widget.location.vicinity != null) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _openInGoogleMaps,
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, size: 15, color: _accentColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.location.vicinity!,
                    style: TextStyle(
                      fontSize: 14,
                      color: _accentColor.withOpacity(0.8),
                      decoration: TextDecoration.underline,
                      decorationColor: _accentColor.withOpacity(0.3),
                      decorationStyle: TextDecorationStyle.dotted,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.open_in_new_rounded,
                    size: 13, color: _accentColor.withOpacity(0.5)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  QUICK STATS ROW
  // ══════════════════════════════════════════════════════════════

  Widget _buildQuickStats() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (widget.location.rating != null)
            _statChip(
              '${widget.location.rating!.toStringAsFixed(1)}',
              Icons.star_rounded,
              const Color(0xFFF59E0B),
            ),
          if (widget.location.userRatingsTotal != null)
            _statChip(
              _formatCount(widget.location.userRatingsTotal!),
              Icons.reviews_rounded,
              const Color(0xFF6B7280),
            ),
          if (widget.location.savedCount != null && widget.location.savedCount! > 0)
            _statChip(
              '${_formatCount(widget.location.savedCount!)} saves',
              Icons.bookmark_rounded,
              const Color(0xFF8B5CF6),
            ),
          if (widget.location.cuisinePrimary != null)
            _statChip(
              widget.location.cuisinePrimary!,
              Icons.restaurant_menu_rounded,
              _accentColor,
            ),
          if (widget.location.isOpenLate == true)
            _statChip('Late night', Icons.nightlife_rounded, const Color(0xFF6366F1)),
          if (widget.location.servesCocktails == true)
            _statChip('Cocktails', Icons.local_bar_rounded, const Color(0xFFEC4899)),
          if (widget.location.outdoorSeating == true)
            _statChip('Outdoor', Icons.deck_rounded, const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _statChip(String label, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  ACTIONS
  // ══════════════════════════════════════════════════════════════

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _actionButton(
            label: 'Add to Bubble',
            icon: Icons.group_add_rounded,
            filled: true,
            onTap: () {},
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _actionButton(
            label: _isSaved ? 'Saved' : 'Save',
            icon: _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            filled: false,
            isLoading: _isSaving,
            onTap: _isSaving ? null : _toggleSave,
          ),
        ),
        const SizedBox(width: 10),
        _iconAction(
          Icons.thumb_down_off_alt_rounded,
          onTap: _isDisliking ? null : _dislikeLocation,
          isLoading: _isDisliking,
        ),
        const SizedBox(width: 8),
        _iconAction(Icons.share_rounded, onTap: () {}),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required bool filled,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: filled ? _accentColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: filled ? null : Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
          boxShadow: filled
              ? [BoxShadow(color: _accentColor.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: filled ? Colors.white : _accentColor,
                ),
              )
            else
              Icon(icon, size: 19, color: filled ? Colors.white : _accentColor),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconAction(IconData icon, {VoidCallback? onTap, bool isLoading = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6B7280)),
                ),
              )
            : Icon(icon, size: 20, color: const Color(0xFF6B7280)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  VIBE SECTION — the star of the show
  // ══════════════════════════════════════════════════════════════

  Widget _buildVibeSection() {
    final vibe = widget.location.vibe;
    if (vibe == null || vibe.values.isEmpty) {
      return const SizedBox.shrink();
    }

    final topVibes = vibe.topTags(6);
    final maxVal = topVibes.isNotEmpty ? topVibes.first.value : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.waves_rounded, size: 18, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(width: 10),
            const Text(
              'Vibe Profile',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Vibe bars
        ...topVibes.map((entry) => _vibeBar(entry.key, entry.value, maxVal)),

        // Wavy / bossman callout
        if (vibe.wavyScore >= 0.35) ...[
          const SizedBox(height: 12),
          _vibeCallout(
            '✨',
            'This spot has wavy energy',
            'Novel, interesting, worth discovering',
            const Color(0xFFE040FB),
          ),
        ] else if (vibe.bossmanScore >= 0.35) ...[
          const SizedBox(height: 12),
          _vibeCallout(
            '🏪',
            'Classic bossman joint',
            'Reliable, familiar, no-frills',
            const Color(0xFF9CA3AF),
          ),
        ],
      ],
    );
  }

  Widget _vibeBar(String tag, double value, double max) {
    final color = _vibeColors[tag] ?? const Color(0xFF9CA3AF);
    final icon = _vibeIcons[tag] ?? Icons.label_rounded;
    final ratio = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _vibeDisplayName(tag),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF4B5563),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (_, constraints) {
                return Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      height: 8,
                      width: constraints.maxWidth * ratio,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.7),
                            color,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 32,
            child: Text(
              '${(value * 100).round()}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vibeCallout(String emoji, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  ABOUT SECTION
  // ══════════════════════════════════════════════════════════════

  Widget _buildAboutSection() {
    final summary = widget.location.generatedSummary ??
        widget.location.editorialSummary ??
        '';
    if (summary.trim().isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          summary,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  DETAILS GRID — all the useful info
  // ══════════════════════════════════════════════════════════════

  Widget _buildDetailsGrid() {
    final items = <_DetailItem>[];

    // Google Maps
    if (widget.location.googleMapsUri != null || widget.location.lat != null) {
      items.add(_DetailItem(
        icon: Icons.map_rounded,
        label: 'Directions',
        value: 'Open in Google Maps',
        color: const Color(0xFF4285F4),
        onTap: _openInGoogleMaps,
      ));
    }

    // Website
    if (widget.location.website != null && widget.location.website!.isNotEmpty) {
      final host = Uri.tryParse(widget.location.website!)?.host ?? 'Visit website';
      items.add(_DetailItem(
        icon: Icons.language_rounded,
        label: 'Website',
        value: host,
        color: const Color(0xFF6366F1),
        onTap: _openWebsite,
      ));
    }

    // Phone
    if (widget.location.phoneNumber != null || widget.location.internationalPhoneNumber != null) {
      final phone = widget.location.internationalPhoneNumber ?? widget.location.phoneNumber ?? '';
      items.add(_DetailItem(
        icon: Icons.phone_rounded,
        label: 'Phone',
        value: phone,
        color: const Color(0xFF10B981),
        onTap: () async {
          final uri = Uri.parse('tel:$phone');
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        },
      ));
    }

    // Opening hours
    if (widget.location.openingHoursText != null && widget.location.openingHoursText!.isNotEmpty) {
      // Find today's hours
      final now = DateTime.now();
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final todayName = weekdays[now.weekday - 1];
      final todayHours = widget.location.openingHoursText!.firstWhere(
        (h) => h.toLowerCase().contains(todayName.toLowerCase()),
        orElse: () => widget.location.openingHoursText!.first,
      );
      items.add(_DetailItem(
        icon: Icons.schedule_rounded,
        label: 'Today',
        value: todayHours.replaceFirst(RegExp(r'^[A-Za-z]+:\s*'), ''),
        color: _openStatusColor(),
      ));
    }

    // Menu
    if (widget.location.menu != null && widget.location.menu!.isNotEmpty) {
      items.add(_DetailItem(
        icon: Icons.menu_book_rounded,
        label: 'Menu',
        value: 'View menu',
        color: const Color(0xFFEC4899),
        onTap: () async {
          final uri = Uri.tryParse(widget.location.menu!);
          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
      ));
    }

    // Service booleans as compact row
    final services = <String>[];
    if (widget.location.servesBreakfast == true) services.add('Breakfast');
    if (widget.location.servesBrunch == true) services.add('Brunch');
    if (widget.location.servesLunch == true) services.add('Lunch');
    if (widget.location.servesDinner == true) services.add('Dinner');
    if (widget.location.servesCoffee == true) services.add('Coffee');
    if (widget.location.servesCocktails == true) services.add('Cocktails');
    if (widget.location.servesVegetarianFood == true) services.add('Veggie');
    if (services.isNotEmpty) {
      items.add(_DetailItem(
        icon: Icons.dining_rounded,
        label: 'Serves',
        value: services.join(' · '),
        color: const Color(0xFF6B7280),
      ));
    }

    // Amenities
    final amenities = <String>[];
    if (widget.location.goodForGroups == true) amenities.add('Groups');
    if (widget.location.goodForChildren == true) amenities.add('Kids');
    if (widget.location.outdoorSeating == true) amenities.add('Outdoor');
    if (widget.location.liveMusic == true) amenities.add('Live music');
    if (widget.location.goodForWatchingSports == true) amenities.add('Sports');
    if (amenities.isNotEmpty) {
      items.add(_DetailItem(
        icon: Icons.verified_rounded,
        label: 'Good for',
        value: amenities.join(' · '),
        color: const Color(0xFF6B7280),
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Details',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final item = entry.value;
              final isLast = entry.key == items.length - 1;
              return _detailRow(item, showDivider: !isLast);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(_DetailItem item, {bool showDivider = true}) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(item.icon, size: 17, color: item.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: item.onTap != null ? item.color : const Color(0xFF374151),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (item.onTap != null)
            Icon(Icons.chevron_right_rounded, size: 20, color: item.color.withOpacity(0.5)),
        ],
      ),
    );

    return Column(
      children: [
        item.onTap != null
            ? GestureDetector(onTap: item.onTap, child: child)
            : child,
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 62),
            child: Divider(height: 1, color: const Color(0xFFF3F4F6)),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  RECOMMENDED DISHES
  // ══════════════════════════════════════════════════════════════

  Widget _buildRecommendedDishes() {
    final raw = widget.location.recommendedDishes ?? '';
    if (raw.trim().isEmpty) return const SizedBox.shrink();

    // Parse: could be comma-separated or line-separated
    final dishes = raw
        .split(RegExp(r'[,\n]'))
        .map((d) => d.trim())
        .where((d) => d.isNotEmpty)
        .take(6)
        .toList();

    if (dishes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_dining_rounded, size: 18, color: Color(0xFFF59E0B)),
            ),
            const SizedBox(width: 10),
            const Text(
              'Recommended Dishes',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: dishes.map((dish) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🍽️', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    dish,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  REVIEW SECTION
  // ══════════════════════════════════════════════════════════════

  Widget _buildReviewSection() {
    final reviewText = _review != null
        ? (_review![SupabaseConstants.columnContentReview]?.toString().trim() ?? '')
        : '';
    final rating = _review?[SupabaseConstants.columnRatingReview] as int?;
    final createdAt = _review?[SupabaseConstants.columnCreatedAt]?.toString();
    final sourceLabel = _reviewIsCurrentUser ? 'Your review' : 'Community';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reviews',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),

        if (_isLoadingReview)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          )
        else if (reviewText.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ...List.generate(5, (i) {
                      return Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: (rating != null && i < rating)
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFE5E7EB),
                      );
                    }),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        sourceLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '"$reviewText"',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _formatTimeAgo(createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else
          Text(
            'No reviews yet — be the first!',
            style: TextStyle(fontSize: 14, color: const Color(0xFF9CA3AF)),
          ),

        if (_isRestaurant()) ...[
          const SizedBox(height: 18),
          _buildReviewComposer(),
        ],

        if (_reviewError != null) ...[
          const SizedBox(height: 10),
          Text(
            _reviewError!,
            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewComposer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leave a review',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final val = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _selectedRating = val),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.star_rounded,
                    size: 28,
                    color: val <= _selectedRating
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reviewController,
            focusNode: _reviewFocusNode,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'What did you love?',
              hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
              filled: true,
              fillColor: const Color(0xFFFAF9FB),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _accentColor.withOpacity(0.5)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isSubmittingReview ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmittingReview
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Post Review', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  SIMILAR PLACES — vibe-based recommendations
  // ══════════════════════════════════════════════════════════════

  Widget _buildSimilarPlaces() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.explore_rounded, size: 18, color: Color(0xFF6366F1)),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Similar Vibes',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Text(
              '${_similarPlaces.length} found',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 195,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _similarPlaces.length,
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              return _buildSimilarPlaceCard(_similarPlaces[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSimilarPlaceCard(_SimilarPlace similar, int index) {
    final loc = similar.location;
    final simPercent = (similar.similarity * 100).round();
    final cardColor = PinitMarkerPalette.forCuisine(loc.cuisine, loc.types);
    final imageUrl = loc.imageUrl?.trim();
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    // Determine if this place is wavy
    final isWavy = loc.vibe != null && loc.vibe!.wavyScore >= 0.35;

    return GestureDetector(
      onTap: () {
        // Close current card and open the tapped location
        // The parent screen should handle navigation via a callback.
        // For now we just close.
        _handleClose();
      },
      child: Container(
        width: 158,
        margin: EdgeInsets.only(right: index < _similarPlaces.length - 1 ? 12 : 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isWavy
                ? const Color(0xFFE040FB).withOpacity(0.20)
                : const Color(0xFFF3F4F6),
            width: isWavy ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + similarity badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: 90,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _similarImagePlaceholder(cardColor),
                          errorWidget: (_, __, ___) => _similarImagePlaceholder(cardColor),
                        )
                      : _similarImagePlaceholder(cardColor),
                ),
                // Similarity pill — top right
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$simPercent% match',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                // Wavy sparkle
                if (isWavy)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE040FB).withOpacity(0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '✨',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + emoji
                    Row(
                      children: [
                        if (loc.emoji != null && loc.emoji!.isNotEmpty) ...[
                          Text(loc.emoji!, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            loc.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Rating + cuisine row
                    Row(
                      children: [
                        if (loc.rating != null) ...[
                          const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 2),
                          Text(
                            loc.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (loc.cuisinePrimary != null)
                          Expanded(
                            child: Text(
                              loc.cuisinePrimary!,
                              style: TextStyle(
                                fontSize: 11,
                                color: cardColor,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),

                    const Spacer(),

                    // Shared vibes
                    if (similar.sharedVibes.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: similar.sharedVibes.map((tag) {
                          final color = _vibeColors[tag] ?? const Color(0xFF9CA3AF);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _vibeDisplayName(tag),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: color,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _similarImagePlaceholder(Color color) {
    return Container(
      height: 90,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.12),
            color.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          size: 28,
          color: color.withOpacity(0.3),
        ),
      ),
    );
  }

  // ── Close button ──

  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: _handleClose,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF6B7280)),
      ),
    );
  }

  // ── Utility ──

  String _formatTimeAgo(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return 'Just now';
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

// ─────────────────────────────────────────────────────────────
//  Detail item model
// ─────────────────────────────────────────────────────────────
class _DetailItem {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });
}

// ─────────────────────────────────────────────────────────────
//  Match ring painter
// ─────────────────────────────────────────────────────────────
class _MatchRingPainter extends CustomPainter {
  final double progress; // 0.0–1.0
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _MatchRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    // Track
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Arc
    if (progress > 0) {
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_MatchRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────
//  Similar place model
// ─────────────────────────────────────────────────────────────
class _SimilarPlace {
  final LocationModel location;

  /// Cosine similarity (0.0–1.0) to the source location.
  final double similarity;

  /// Vibe tags shared between both locations (for display).
  final List<String> sharedVibes;

  const _SimilarPlace({
    required this.location,
    required this.similarity,
    this.sharedVibes = const [],
  });
}
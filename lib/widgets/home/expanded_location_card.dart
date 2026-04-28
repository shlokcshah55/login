import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/markers.dart';
import 'package:login/models/video_insights.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/services/analytics_service.dart';
import 'package:login/supabase/helpers/location.dart';
import 'package:login/supabase/helpers/location_reviews.dart';
import 'package:login/supabase/helpers/video_insights_helper.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/widgets/home/been_to_review_sheet.dart';
import 'package:login/widgets/home/been_to_swipe_ranker.dart';
import 'package:login/widgets/home/expanded_card/add_to_bubble_sheet.dart';
import 'package:login/widgets/home/expanded_card/add_to_collection_sheet.dart';
import 'package:login/widgets/home/expanded_card/helpers/match_result.dart';
import 'package:login/widgets/home/expanded_card/helpers/similar_place.dart';
import 'package:login/widgets/home/expanded_card/sections/details_section.dart';
import 'package:login/widgets/home/expanded_card/sections/hero_section.dart';
import 'package:login/widgets/home/expanded_card/sections/persistent_action_dock.dart';
import 'package:login/widgets/home/expanded_card/sections/recommended_dishes_section.dart';
import 'package:login/widgets/home/expanded_card/sections/social_proof_section.dart';
import 'package:login/widgets/home/expanded_card/sections/summary_slab_section.dart';
import 'package:login/widgets/home/expanded_card/sections/tiktok_insights_section.dart';
import 'package:login/widgets/home/expanded_card/sections/why_go_section.dart';
import 'package:login/widgets/feedback/app_feedback.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bottom-sheet style expanded view of a single [LocationModel].
///
/// This widget is intentionally a thin orchestrator: each visual block
/// lives in `lib/widgets/home/expanded_card/sections/*`. The parent
/// owns the sheet animation, save/dislike state, similar-places lookup,
/// and the URL launchers — sections receive props + callbacks only.
///
/// Phase 1 of the redesign: structural extraction only — no behaviour
/// changes vs. the previous monolithic implementation.
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

class _ExpandedLocationCardState extends State<ExpandedLocationCard>
    with TickerProviderStateMixin {
  final AnalyticsService _analyticsService = AnalyticsService();

  // ── Save / dislike state ──
  bool _isSaved = false;
  bool _isSaving = false;
  bool _isDisliking = false;

  // ── Been to state ──
  bool _isBeenTo = false;
  bool _isBeenToLoading = false;
  final LocationReviewsHelper _reviewsHelper = LocationReviewsHelper();

  // ── Pinit avg rating state ──
  double? _pinitAvgRating;
  int _pinitReviewCount = 0;

  // ── Pinit reviews + friends ──
  List<Map<String, dynamic>> _pinitReviews = [];
  Set<String> _friendIds = {};

  // ── Hero photo state ──
  int _currentPhotoIndex = 0;
  List<String> _photos = const [];
  final LocationHelper _locationHelper = LocationHelper();

  // ── Sheet entrance animation ──
  late final AnimationController _sheetController;
  late final Animation<double> _sheetSlide;

  // ── Match ring animation ──
  late final AnimationController _matchController;
  late final Animation<double> _matchAnim;

  // ── Derived display data ──
  late final MatchResult _match;
  late final Color _accentColor;

  // ── Similar places ──
  List<SimilarPlace> _similarPlaces = [];
  bool _isOpeningSimilarPlace = false;

  // ── TikTok video insights (lazy-loaded) ──
  VideoInsight? _videoInsight;
  final VideoInsightsHelper _videoInsightsHelper = VideoInsightsHelper();

  @override
  void initState() {
    super.initState();
    _analyticsService.trackFeature(
      'location_card_opened',
      featureName: 'location_card',
      screenName: 'home',
      properties: <String, dynamic>{
        'location_id': widget.location.locationId,
      },
      registerTap: true,
      interactionKey: 'location_card_opened',
    );
    // Seed with whatever we already have synchronously (the storage URL
    // from the list row). The full gallery is fetched lazily below.
    final seed = widget.location.imageUrl?.trim();
    if (seed != null && seed.isNotEmpty) {
      _photos = [seed];
    }
    _loadGalleryPhotos();

    _accentColor = PinitMarkerPalette.forCuisine(
      widget.location.cuisine,
      widget.location.types,
    );

    final userProvider = Provider.of<UserDataProvider>(context, listen: false);
    _match = buildMatchResult(
      matchScore: widget.location.matchScore,
      locationVibe: widget.location.vibe,
      userVibeAffinity: userProvider.vibeTagAffinity,
      locationDietary: widget.location.dietaryRequirementVector,
      userDietary: userProvider.dietaryRequirementTagAffinity,
    );

    _sheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _sheetSlide = CurvedAnimation(
      parent: _sheetController,
      curve: Curves.easeOutCubic,
    );
    _sheetController.forward();

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

    _checkSavedStatus();
    _checkBeenToStatus();
    _fetchPinitAvgRating();
    _fetchPinitReviews();
    _fetchFriendIds();
    _findSimilarPlaces();
    _fetchVideoInsight();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _matchController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  Save / dislike
  // ─────────────────────────────────────────────────────────────

  void _checkSavedStatus() {
    final mgr = Provider.of<LocationListManager>(context, listen: false);
    setState(() {
      _isSaved = mgr.isLocationSavedSync(widget.location.locationId);
    });
  }

  void _fetchPinitAvgRating() async {
    final result = await _reviewsHelper.getLocationAvgRating(
      locationId: widget.location.locationId,
    );
    if (mounted && result != null) {
      setState(() {
        _pinitAvgRating = result.avg;
        _pinitReviewCount = result.count;
      });
    }
  }

  void _fetchPinitReviews() async {
    final reviews = await _reviewsHelper.getPublicReviewsWithProfiles(
      locationId: widget.location.locationId,
    );
    if (mounted) setState(() => _pinitReviews = reviews);
  }

  void _fetchFriendIds() async {
    final ids = await _reviewsHelper.getFriendIds();
    if (mounted) setState(() => _friendIds = ids);
  }

  void _checkBeenToStatus() async {
    final user = SupabaseClientManager().currentUser;
    if (user == null) return;
    try {
      final review = await _reviewsHelper.getUserReview(
        locationId: widget.location.locationId,
        userId: user.id,
      );
      if (!mounted || review == null) return;
      context.read<LocationListManager>().markLocationBeenTo(
            widget.location.locationId,
          );
      setState(() => _isBeenTo = true);
    } catch (_) {}
  }

  /// Submit review and add location to "Been To" collection.
  /// Collection creation/update is non-fatal; review is already saved even if collection fails.
  Future<void> _submitReviewAndAddToCollection({
    required int locationId,
    double? rating,
    String? notes,
    bool gatekeep = false,
  }) async {
    await _reviewsHelper.submitBeenTo(
      locationId: locationId,
      rating: rating,
      content: notes,
      gatekeep: gatekeep,
    );
    if (mounted) {
      context.read<LocationListManager>().markLocationBeenTo(locationId);
    }
    try {
      final collectionId = await _reviewsHelper.getOrCreateBeenToCollection();
      if (collectionId != null) {
        await _reviewsHelper.addLocationToBeenToCollection(
          collectionId: collectionId,
          locationId: locationId,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('ExpandedLocationCard: failed to add to Been To collection: $e');
      }
    }
  }

  Future<void> _onBeenToTap() async {
    if (_isBeenTo || _isBeenToLoading) return;
    final user = SupabaseClientManager().currentUser;
    if (user == null) return;
    setState(() => _isBeenToLoading = true);
    try {
      final count = await _reviewsHelper.getUserBeenToCount(userId: user.id);
      if (!mounted) return;

      if (count > 5) {
        final reviews =
            await _reviewsHelper.getUserBeenToReviews(userId: user.id);
        if (!mounted) return;
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BeenToSwipeRanker(
            newLocation: widget.location,
            existingReviews: reviews,
            onSubmitted: (rating, notes, gatekeep) async {
              await _submitReviewAndAddToCollection(
                locationId: widget.location.locationId,
                rating: rating,
                notes: notes,
                gatekeep: gatekeep,
              );
              if (mounted) setState(() => _isBeenTo = true);
            },
          ),
        );
      } else {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BeenToReviewSheet(
            locationName: widget.location.name,
            onSubmit: (rating, notes, gatekeep) async {
              await _submitReviewAndAddToCollection(
                locationId: widget.location.locationId,
                rating: rating,
                notes: notes,
                gatekeep: gatekeep,
              );
              if (mounted) setState(() => _isBeenTo = true);
            },
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBeenToLoading = false);
    }
  }

  Future<void> _toggleSave() async {
    if (_isSaving) return;
    final wasSaved = _isSaved;
    setState(() => _isSaving = true);
    try {
      final mgr = Provider.of<LocationListManager>(context, listen: false);
      if (wasSaved) {
        if (mounted) {
          setState(() => _isSaved = false);
        }
        final ok = await mgr.unsaveLocation(widget.location);
        if (!ok && mounted) {
          setState(() => _isSaved = true);
        }
      } else {
        if (mounted) {
          setState(() => _isSaved = true);
        }
        await mgr.saveLocation(widget.location);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaved = wasSaved);
        unawaited(
          AppFeedback.showError(
            context,
            title: 'Couldn’t update save',
            message: 'Failed to ${wasSaved ? 'unsave' : 'save'}.',
          ),
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
        AppFeedback.showSuccess(
          context,
          message: 'Hidden from recommendations',
          leading: const Icon(
            Icons.visibility_off_rounded,
            color: PinitColors.cream,
            size: 18,
          ),
          duration: const Duration(seconds: 2),
        );
        _handleClose();
      }
    } catch (_) {
      if (mounted) {
        unawaited(
          AppFeedback.showError(
            context,
            title: 'Couldn’t hide this',
            message: 'Failed to hide location.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDisliking = false);
    }
  }

  void _handleClose() {
    _sheetController.reverse().then((_) => widget.onClose());
  }

  Future<void> _openSimilarPlace(SimilarPlace similar) async {
    if (_isOpeningSimilarPlace) return;
    _isOpeningSimilarPlace = true;

    try {
      final navigator = Navigator.of(context, rootNavigator: true);
      final loc = similar.location;

      await _sheetController.reverse();
      widget.onClose();

      // Let the pop complete before presenting the next dialog.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (!navigator.mounted) return;

      unawaited(
        showGeneralDialog<void>(
          context: navigator.context,
          barrierDismissible: true,
          barrierLabel: MaterialLocalizations.of(navigator.context)
              .modalBarrierDismissLabel,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (ctx, _, __) => ExpandedLocationCard(
            location: loc,
            onClose: () => Navigator.of(ctx).pop(),
          ),
          transitionBuilder: (ctx, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    } finally {
      if (mounted) _isOpeningSimilarPlace = false;
    }
  }

  Future<void> _showAddToCollectionSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddToCollectionSheet(
        locationId: widget.location.locationId,
        locationName: widget.location.name,
      ),
    );
  }

  Future<void> _showAddToBubbleSheet() async {
    final sentCount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddToBubbleSheet(
        location: widget.location,
      ),
    );

    if (!mounted || sentCount == null) return;

    if (sentCount > 0) {
      AppFeedback.showSuccess(
        context,
        message: 'Sent to $sentCount ${sentCount == 1 ? 'bubble' : 'bubbles'}',
        leading: const Icon(
          Icons.send_rounded,
          color: PinitColors.cream,
          size: 18,
        ),
        duration: const Duration(seconds: 2),
      );
    } else {
      unawaited(
        AppFeedback.showError(
          context,
          title: 'Couldn’t send',
          message: 'Could not send to bubble.',
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Similar places (vibe-based)
  // ─────────────────────────────────────────────────────────────

  /// Find similar places by computing cosine similarity between this
  /// location's vibe vector and all other locations available in the
  /// [LocationListManager]. Top 8 are kept.
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
    final scored = <SimilarPlace>[];
    for (final loc in candidates) {
      final sim = _cosineSimilarity(thisVibe.values, loc.vibe!.values);
      if (sim > 0.15) {
        // Find shared top vibes for the subtitle.
        final thisTop = thisVibe.topTags(4).map((e) => e.key).toSet();
        final thatTop = loc.vibe!.topTags(4).map((e) => e.key).toSet();
        final shared = thisTop.intersection(thatTop).take(2).toList();

        scored.add(SimilarPlace(
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

  // ─────────────────────────────────────────────────────────────
  //  TikTok video insights
  // ─────────────────────────────────────────────────────────────

  /// Lazily fetch video insight data when the card opens for a
  /// TikTok/Instagram-saved location.
  Future<void> _fetchVideoInsight() async {
    final sourceUrl = widget.location.savedFrom;
    if (sourceUrl == null || sourceUrl.trim().isEmpty) return;

    final insight = await _videoInsightsHelper.getInsight(
      locationId: widget.location.locationId,
      sourceVideoUrl: sourceUrl,
    );

    if (mounted && insight != null) {
      setState(() => _videoInsight = insight);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  URL launchers
  // ─────────────────────────────────────────────────────────────

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

  /// Launches the original source URL the user pinned this location
  /// from (e.g. a TikTok video). Used by the "Saved from this TikTok"
  /// flash badge in the summary slab.
  Future<void> _openSavedFromUrl() async {
    final url = widget.location.savedFrom;
    if (url == null || url.trim().isEmpty) return;
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null) return;
    if (await canLaunchUrl(parsed)) {
      await launchUrl(parsed, mode: LaunchMode.externalApplication);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Display helpers
  // ─────────────────────────────────────────────────────────────

  /// Loads the gallery with progressive, parallel delivery. Every time a
  /// new contiguous prefix is ready we [setState] and [precacheImage]
  /// each newly-arrived URL — that warms both the in-memory ImageCache
  /// and the on-disk `CachedNetworkImage` cache so PageView swipes are
  /// instant even though the network fetches only just finished.
  Future<void> _loadGalleryPhotos() async {
    final seen = <String>{..._photos};
    try {
      final finalUrls = await _locationHelper.fetchExpandedCardPhotos(
        widget.location,
        onPartial: (partial) {
          if (!mounted || partial.isEmpty) return;
          for (final url in partial) {
            if (seen.add(url)) {
              precacheImage(CachedNetworkImageProvider(url), context);
            }
          }
          setState(() {
            _photos = partial;
            if (_currentPhotoIndex >= _photos.length) {
              _currentPhotoIndex = _photos.length - 1;
            }
          });
        },
      );
      if (!mounted || finalUrls.isEmpty) return;
      for (final url in finalUrls) {
        if (seen.add(url)) {
          precacheImage(CachedNetworkImageProvider(url), context);
        }
      }
      if (finalUrls.length != _photos.length) {
        setState(() {
          _photos = finalUrls;
          if (_currentPhotoIndex >= _photos.length) {
            _currentPhotoIndex = _photos.length - 1;
          }
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ExpandedCard] Gallery load failed: $e');
      }
    }
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
    final isWavy =
        widget.location.vibe != null && widget.location.vibe!.wavyScore >= 0.35;

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
                color: Colors.black.withValues(alpha: 0.5 * _sheetSlide.value),
              ),
            ),

            // Sheet
            AnimatedBuilder(
              animation: _sheetSlide,
              builder: (_, child) => Align(
                alignment: Alignment.bottomCenter,
                child: Transform.translate(
                  offset:
                      Offset(0, (1 - _sheetSlide.value) * size.height * 0.4),
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
                    return NotificationListener<
                        DraggableScrollableNotification>(
                      onNotification: (n) {
                        if (n.extent <= n.minExtent + 0.01) _handleClose();
                        return true;
                      },
                      child: Container(
                        decoration: const BoxDecoration(
                          color: PinitColors.cream,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        child: Stack(
                          children: [
                            _buildRestaurantBody(
                              scrollCtrl: scrollCtrl,
                              heroHeight: size.height * 0.34,
                              isWavy: isWavy,
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
                                    color: PinitColors.creamDeep,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),

                            // Persistent action dock
                            // Anchored to the bottom of the sheet so the
                            // primary actions stay visible while the
                            // editorial body scrolls behind.
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: PersistentActionDock(
                                isSaved: _isSaved,
                                isSaving: _isSaving,
                                isDisliking: _isDisliking,
                                onAddToBubble: _showAddToBubbleSheet,
                                onToggleSave: _toggleSave,
                                onAddToCollection: _showAddToCollectionSheet,
                                onDislike: _dislikeLocation,
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
              child: ExpandedCardCloseButton(onTap: _handleClose),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  Body composition (2026-04-08 redesign)
  // ─────────────────────────────────────────────────────────────

  /// Restaurant composition: hero → summary slab → editorial body
  /// (Why go / What to get / Social proof / Practicals). Action row is
  /// owned by the persistent dock and intentionally absent from the
  /// scroll body.
  Widget _buildRestaurantBody({
    required ScrollController scrollCtrl,
    required double heroHeight,
    required bool isWavy,
  }) {
    // Bottom inset reserves space for the persistent dock so the final
    // section remains fully readable above it. Dock chrome height plus
    // safe-area inset plus a little breathing room.
    final dockBottomInset = MediaQuery.of(context).padding.bottom +
        PersistentActionDock.dockHeight +
        24;

    return ListView(
      controller: scrollCtrl,
      padding: EdgeInsets.zero,
      children: [
        HeroSection(
          height: heroHeight,
          photos: _photos,
          currentPhotoIndex: _currentPhotoIndex,
          onPhotoChanged: (i) => setState(() => _currentPhotoIndex = i),
          accentColor: _accentColor,
          openStatusLabel: _openStatusLabel(),
          openStatusColor: _openStatusColor(),
          priceLabel: _priceLabel(),
          isWavy: isWavy,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Layer 2 — summary slab (page backbone).
              SummarySlabSection(
                location: widget.location,
                match: _match,
                matchAnim: _matchAnim,
                onAddressTap: _openInGoogleMaps,
                onSavedFromTap: _openSavedFromUrl,
                isBeenTo: _isBeenTo,
                isBeenToLoading: _isBeenToLoading,
                onBeenTo: _onBeenToTap,
                pinitAvgRating: _pinitAvgRating,
                pinitReviewCount: _pinitReviewCount,
                creatorHandle: _videoInsight?.creatorHandle,
              ),

              // Layer 2b — TikTok insights (only for social-video saves)
              if (_videoInsight != null) ...[
                const SizedBox(height: 28),
                TikTokInsightsSection(
                  insight: _videoInsight!,
                  videoExtras: widget.location.videoExtras,
                ),
              ],

              // Layer 3 — editorial body.
              const SizedBox(height: 32),

              DetailsSection(
                location: widget.location,
                onOpenInMaps: _openInGoogleMaps,
                onOpenWebsite: _openWebsite,
              ),
              const SizedBox(height: 32),

              WhyGoSection(
                generatedSummary: widget.location.generatedSummary,
                editorialSummary: widget.location.editorialSummary,
                vibe: widget.location.vibe,
              ),
              if (widget.location.recommendedDishes != null) ...[
                const SizedBox(height: 32),
                RecommendedDishesSection(
                  recommendedDishes: widget.location.recommendedDishes,
                ),
              ],
              const SizedBox(height: 32),
              SocialProofSection(
                location: widget.location,
                similarPlaces: _similarPlaces,
                onSimilarPlaceTap: _openSimilarPlace,
                pinitReviews: _pinitReviews,
                friendIds: _friendIds,
              ),
              SizedBox(height: dockBottomInset),
            ],
          ),
        ),
      ],
    );
  }
}

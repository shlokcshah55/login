import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/markers.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/widgets/home/expanded_card/add_to_collection_sheet.dart';
import 'package:login/widgets/home/expanded_card/helpers/match_result.dart';
import 'package:login/widgets/home/expanded_card/helpers/similar_place.dart';
import 'package:login/widgets/home/expanded_card/sections/about_section.dart';
import 'package:login/widgets/home/expanded_card/sections/actions_section.dart';
import 'package:login/widgets/home/expanded_card/sections/details_section.dart';
import 'package:login/widgets/home/expanded_card/sections/hero_section.dart';
import 'package:login/widgets/home/expanded_card/sections/match_banner_section.dart';
import 'package:login/widgets/home/expanded_card/sections/name_location_section.dart';
import 'package:login/widgets/home/expanded_card/sections/persistent_action_dock.dart';
import 'package:login/widgets/home/expanded_card/sections/quick_stats_section.dart';
import 'package:login/widgets/home/expanded_card/sections/recommended_dishes_section.dart';
import 'package:login/widgets/home/expanded_card/sections/review_section.dart';
import 'package:login/widgets/home/expanded_card/sections/saved_from_badge.dart';
import 'package:login/widgets/home/expanded_card/sections/similar_places_section.dart';
import 'package:login/widgets/home/expanded_card/sections/social_proof_section.dart';
import 'package:login/widgets/home/expanded_card/sections/summary_slab_section.dart';
import 'package:login/widgets/home/expanded_card/sections/vibe_section.dart';
import 'package:login/widgets/home/expanded_card/sections/why_go_section.dart';
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
  // ── Save / dislike state ──
  bool _isSaved = false;
  bool _isSaving = false;
  bool _isDisliking = false;

  // ── Hero photo state ──
  int _currentPhotoIndex = 0;
  late final List<String> _photos;

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

  @override
  void initState() {
    super.initState();
    _photos = _resolvePhotoUrls();

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
    _findSimilarPlaces();
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

  /// Heuristic for whether to apply the 2026-04-08 restaurant-only
  /// structural redesign. Mirrors the same check used inside
  /// [ReviewSection] so the gating stays consistent across the card.
  bool _isRestaurant() {
    final types = widget.location.types?.toLowerCase() ?? '';
    if (types.contains('restaurant')) return true;
    if ((widget.location.cuisine ?? '').trim().isNotEmpty) return true;
    return false;
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;
    final isWavy = widget.location.vibe != null &&
        widget.location.vibe!.wavyScore >= 0.35;
    final isRestaurant = _isRestaurant();

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
                color: Colors.black
                    .withValues(alpha: 0.5 * _sheetSlide.value),
              ),
            ),

            // Sheet
            AnimatedBuilder(
              animation: _sheetSlide,
              builder: (_, child) => Align(
                alignment: Alignment.bottomCenter,
                child: Transform.translate(
                  offset: Offset(
                      0, (1 - _sheetSlide.value) * size.height * 0.4),
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
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(28)),
                        ),
                        child: Stack(
                          children: [
                            isRestaurant
                                ? _buildRestaurantBody(
                                    scrollCtrl: scrollCtrl,
                                    heroHeight: size.height * 0.34,
                                    isWavy: isWavy,
                                  )
                                : _buildLegacyBody(
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

                            // Persistent action dock — restaurant-only.
                            // Anchored to the bottom of the sheet so the
                            // primary actions stay visible while the
                            // editorial body scrolls behind.
                            if (isRestaurant)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: PersistentActionDock(
                                  isSaved: _isSaved,
                                  isSaving: _isSaving,
                                  isDisliking: _isDisliking,
                                  onAddToBubble: () {},
                                  onToggleSave: _toggleSave,
                                  onAddToCollection:
                                      _showAddToCollectionSheet,
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
              ),

              // Layer 3 — editorial body.
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
                onSimilarPlaceTap: (_) => _handleClose(),
              ),
              const SizedBox(height: 32),
              DetailsSection(
                location: widget.location,
                onOpenInMaps: _openInGoogleMaps,
                onOpenWebsite: _openWebsite,
              ),
              SizedBox(height: dockBottomInset),
            ],
          ),
        ),
      ],
    );
  }

  /// Legacy composition for non-restaurant locations. The 2026-04-08
  /// redesign is intentionally restaurant-only — other place types
  /// continue to use the previous structure unchanged.
  Widget _buildLegacyBody({
    required ScrollController scrollCtrl,
    required double heroHeight,
    required bool isWavy,
  }) {
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
        MatchBannerSection(
          match: _match,
          matchAnim: _matchAnim,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Provenance — "Saved from this TikTok" flash badge.
              // Mirrors the placement used in SummarySlabSection so the
              // signal is consistent across both card compositions.
              if ((widget.location.savedMethod ?? '').toLowerCase() ==
                      'tiktok' &&
                  (widget.location.savedFrom ?? '').trim().isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: SavedFromBadge(
                    savedMethod: widget.location.savedMethod,
                    sourceUrl: widget.location.savedFrom,
                    onTap: _openSavedFromUrl,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              NameLocationSection(
                name: widget.location.name,
                vicinity: widget.location.vicinity,
                onAddressTap: _openInGoogleMaps,
              ),
              const SizedBox(height: 16),
              QuickStatsSection(location: widget.location),
              const SizedBox(height: 20),
              ActionsSection(
                isSaved: _isSaved,
                isSaving: _isSaving,
                isDisliking: _isDisliking,
                onAddToBubble: () {},
                onToggleSave: _toggleSave,
                onDislike: _dislikeLocation,
                onShare: () {},
                onAddToCollection: _showAddToCollectionSheet,
              ),
              if (widget.location.generatedSummary != null ||
                  widget.location.editorialSummary != null) ...[
                const SizedBox(height: 28),
                AboutSection(
                  generatedSummary: widget.location.generatedSummary,
                  editorialSummary: widget.location.editorialSummary,
                ),
              ],
              const SizedBox(height: 28),
              VibeSection(vibe: widget.location.vibe),
              if (widget.location.recommendedDishes != null) ...[
                const SizedBox(height: 28),
                RecommendedDishesSection(
                  recommendedDishes: widget.location.recommendedDishes,
                ),
              ],
              const SizedBox(height: 28),
              ReviewSection(location: widget.location),
              const SizedBox(height: 28),
              DetailsSection(
                location: widget.location,
                onOpenInMaps: _openInGoogleMaps,
                onOpenWebsite: _openWebsite,
              ),
              if (_similarPlaces.isNotEmpty) ...[
                const SizedBox(height: 32),
                SimilarPlacesSection(
                  similarPlaces: _similarPlaces,
                  onPlaceTap: (_) => _handleClose(),
                ),
              ],
              const SizedBox(height: 120),
            ],
          ),
        ),
      ],
    );
  }
}

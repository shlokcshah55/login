import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/social_review_models.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/pages/social_review/widgets/social_place_search_sheet.dart';
import 'package:login/providers/social_review_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/services/spotlight_wizard_seen_service.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/widgets/home/location_list_card.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the compact places sheet for one shared TikTok/Reel.
Future<void> showSocialPostPlacesSheet(
  BuildContext context, {
  required String postId,
  String source = 'notification',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SocialPostPlacesSheet(postId: postId, source: source),
  );
}

/// Compact review of the places found in one shared TikTok/Reel: a link to
/// the post, then each place as a restaurant card with its match score.
/// Swipe a card left to remove a wrong place; tick to save an unsure one;
/// add more places from search.
class SocialPostPlacesSheet extends StatefulWidget {
  const SocialPostPlacesSheet({
    super.key,
    required this.postId,
    this.source = 'notification',
    this.onOpenOriginal,
    this.placeSearcher,
    this.shouldShowSwipeHint,
    this.markSwipeHintSeen,
    this.undoWindow = const Duration(seconds: 4),
  });

  final String postId;
  final String source;

  /// Test seams. Production opens the post externally, searches Google
  /// Places, and stores the hint flag per user in shared preferences.
  final Future<void> Function(SocialPostReviewItem item)? onOpenOriginal;
  final SocialPlaceSearcher? placeSearcher;
  final Future<bool> Function()? shouldShowSwipeHint;
  final Future<void> Function()? markSwipeHintSeen;

  /// How long a swiped-away place can be restored before the removal is
  /// committed.
  final Duration undoWindow;

  @override
  State<SocialPostPlacesSheet> createState() => _SocialPostPlacesSheetState();
}

class _SocialPostPlacesSheetState extends State<SocialPostPlacesSheet>
    with SingleTickerProviderStateMixin {
  static final _hintService =
      _SwipeHintSeen(SpotlightWizardSeenService('social_places_swipe_hint'));

  late final SocialReviewProvider _provider;
  late final AnimationController _hint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  bool _requestedRefresh = false;
  bool _trackedShown = false;
  bool _hintChecked = false;
  bool _userTouched = false;

  /// Places swiped away whose removal hasn't been committed yet.
  final Map<String, SocialPostPlace> _pendingRemovals = {};

  /// Every place swiped away (and not undone); kept hidden while the
  /// provider catches up with the discard.
  final Set<String> _hiddenIds = {};
  SocialPostPlace? _undoPlace;
  Timer? _undoTimer;

  final Set<String> _savingIds = {};
  bool _showSearch = false;
  bool _adding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _provider = context.read<SocialReviewProvider>();
  }

  @override
  void dispose() {
    _undoTimer?.cancel();
    _commitAllRemovals();
    _hint.dispose();
    super.dispose();
  }

  // ── Loading ─────────────────────────────────────────────────

  void _onItemAvailable(SocialPostReviewItem? item) {
    if (item == null) {
      if (!_provider.hasLoaded && !_provider.isLoading && !_requestedRefresh) {
        _requestedRefresh = true;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => unawaited(_provider.refresh()));
      }
      return;
    }
    if (!_trackedShown) {
      _trackedShown = true;
      _provider.trackPostShown(item, source: widget.source);
    }
    if (!_hintChecked && _visiblePlaces(item).isNotEmpty) {
      _hintChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybePlayHint());
    }
  }

  // ── Swipe hint ──────────────────────────────────────────────

  Future<void> _maybePlayHint() async {
    final shouldShow =
        await (widget.shouldShowSwipeHint ?? _hintService.shouldShow)();
    if (!shouldShow || !mounted) return;
    final markSeen = widget.markSwipeHintSeen ?? _hintService.markSeen;
    if (MediaQuery.disableAnimationsOf(context)) {
      await markSeen();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted || _userTouched) return;
    await markSeen();
    if (!mounted || _userTouched) return;
    try {
      await _hint.forward(from: 0).orCancel;
    } on TickerCanceled {
      // Disposed or interrupted mid-hint.
    }
  }

  void _onUserTouch() {
    if (_userTouched) return;
    _userTouched = true;
    if (_hint.isAnimating) {
      _hint.stop();
      _hint.value = 0;
    }
  }

  // ── Actions ─────────────────────────────────────────────────

  Future<void> _openPost(SocialPostReviewItem item) async {
    final override = widget.onOpenOriginal;
    if (override != null) {
      await override(item);
      return;
    }
    final uri = Uri.tryParse(item.openUrl);
    if (uri == null || !uri.hasScheme) return;
    _provider.trackOpenedOriginalPost(item);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _remove(SocialPostPlace place) {
    // Commit any earlier pending removal before starting a new undo window.
    _undoTimer?.cancel();
    _commitAllRemovals();
    setState(() {
      _pendingRemovals[place.id] = place;
      _hiddenIds.add(place.id);
      _undoPlace = place;
    });
    _undoTimer = Timer(widget.undoWindow, () {
      _commitAllRemovals();
      if (mounted) setState(() => _undoPlace = null);
    });
  }

  void _undo() {
    final place = _undoPlace;
    if (place == null) return;
    _undoTimer?.cancel();
    setState(() {
      _pendingRemovals.remove(place.id);
      _hiddenIds.remove(place.id);
      _undoPlace = null;
    });
  }

  void _commitAllRemovals() {
    if (_pendingRemovals.isEmpty) return;
    final places = _pendingRemovals.values.toList(growable: false);
    _pendingRemovals.clear();
    unawaited(_discardAll(places));
  }

  Future<void> _discardAll(List<SocialPostPlace> places) async {
    for (final place in places) {
      final item = _provider.itemByPostId(widget.postId);
      if (item == null) return;
      await _provider.discardPlace(item, place);
    }
  }

  Future<void> _save(SocialPostReviewItem item, SocialPostPlace place) async {
    if (_savingIds.contains(place.id)) return;
    setState(() {
      _savingIds.add(place.id);
      _error = null;
    });
    final ok = await _provider.savePlace(item, place);
    if (!mounted) return;
    setState(() {
      _savingIds.remove(place.id);
      if (!ok) _error = 'Couldn’t save ${place.name}';
    });
  }

  Future<void> _add(SocialPostReviewItem item, LocationModel picked) async {
    if (_adding) return;
    setState(() {
      _adding = true;
      _error = null;
    });
    final ok = await _provider.addManualPlace(item, picked);
    if (!mounted) return;
    setState(() {
      _adding = false;
      if (ok) {
        _showSearch = false;
      } else {
        _error = 'Couldn’t add ${picked.name}';
      }
    });
  }

  // ── Helpers ─────────────────────────────────────────────────

  List<SocialPostPlace> _visiblePlaces(SocialPostReviewItem item) {
    return item.places
        .where((place) =>
            item.placeActions[place.id] != SocialPlaceAction.discarded &&
            !_hiddenIds.contains(place.id))
        .toList(growable: false)
      ..sort(
        (a, b) => (b.confidenceScore ?? 0).compareTo(a.confidenceScore ?? 0),
      );
  }

  static bool _isSaved(SocialPostReviewItem item, SocialPostPlace place) {
    final action = item.placeActions[place.id];
    return action == SocialPlaceAction.saved ||
        action == SocialPlaceAction.corrected ||
        action == SocialPlaceAction.manualAdded;
  }

  double _matchScore(LocationModel location) {
    final precomputed = location.matchScore;
    if (precomputed != null && precomputed > 0) {
      return precomputed.clamp(0.0, 1.0);
    }
    final UserDataProvider user;
    try {
      user = context.read<UserDataProvider>();
    } on ProviderNotFoundException {
      return 0;
    }
    return LocationModel.calculateMatchScore(
      userVibeAffinity: user.vibeTagAffinity,
      userDietaryAffinity: user.dietaryRequirementTagAffinity,
      locationVibeVector: location.vibeVector,
      locationDietaryVector: location.dietaryRequirementVector,
    ).clamp(0.0, 1.0);
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SocialReviewProvider>();
    final item = provider.itemByPostId(widget.postId);
    _onItemAvailable(item);

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        decoration: const BoxDecoration(
          color: pinit.PinitColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _DragHandle(),
              Flexible(
                child: item == null
                    ? _MissingOrLoading(loading: !provider.hasLoaded)
                    : _buildContent(provider, item),
              ),
              if (_undoPlace case final removed?)
                _UndoBar(name: removed.name, onUndo: _undo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    SocialReviewProvider provider,
    SocialPostReviewItem item,
  ) {
    final places = _visiblePlaces(item);
    return Listener(
      onPointerDown: (_) => _onUserTouch(),
      child: ListView(
        shrinkWrap: true,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          _PostLinkHeader(
            item: item,
            onTap: () => unawaited(_openPost(item)),
          ),
          const SizedBox(height: 20),
          if (item.isProcessing)
            const _InfoLine(
              icon: FeatherIcons.loader,
              text: 'Still reading this post…',
            )
          else ...[
            Text(
              places.isEmpty
                  ? 'No places from this ${item.platformLabel}'
                  : places.length == 1
                      ? '1 place from this ${item.platformLabel}'
                      : '${places.length} places from this ${item.platformLabel}',
              style: AppTypography.brand(
                fontSize: 22,
                // Rova ships a single weight; heavier weights are synthesised
                // and smear the letterforms.
                fontWeight: FontWeight.w400,
                letterSpacing: 0.8,
                color: pinit.PinitColors.aubergine,
              ),
            ),
            if (places.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Swipe left to remove a wrong one.',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: pinit.PinitColors.mute,
                ),
              ),
            ],
            const SizedBox(height: 14),
            for (final (index, place) in places.indexed)
              _buildRow(provider, item, place, hint: index == 0),
          ],
          if (_error case final error?) ...[
            _InfoLine(icon: FeatherIcons.alertCircle, text: error),
            const SizedBox(height: 8),
          ],
          if (!item.isProcessing) _buildAddSection(item),
        ],
      ),
    );
  }

  Widget _buildRow(
    SocialReviewProvider provider,
    SocialPostReviewItem item,
    SocialPostPlace place, {
    required bool hint,
  }) {
    final saved = _isSaved(item, place);
    final locationId = item.savedLocationIds[place.id] ?? place.locationId;
    final location =
        locationId == null ? null : provider.locationsById[locationId];
    final saveButton = saved
        ? null
        : _SaveTick(
            busy: _savingIds.contains(place.id),
            onTap: () => unawaited(_save(item, place)),
          );

    final Widget card;
    if (location != null) {
      final score = _matchScore(location);
      card = LocationListCard(
        location: location,
        sourceLabel: saved ? 'SAVED' : 'NOT SAVED',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (score > 0) _MatchPill(score: score),
            if (saveButton != null) ...[
              const SizedBox(width: 6),
              saveButton,
            ],
          ],
        ),
      );
    } else {
      card = _UnresolvedPlaceCard(
          place: place, saved: saved, trailing: saveButton);
    }

    return Dismissible(
      key: ValueKey('social-place:${place.id}'),
      direction: DismissDirection.endToStart,
      background: const _BinBackground(),
      onDismissed: (_) => _remove(place),
      child: hint ? _SwipeHint(animation: _hint, child: card) : card,
    );
  }

  Widget _buildAddSection(SocialPostReviewItem item) {
    if (_adding) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: pinit.PinitColors.aubergine,
            ),
          ),
        ),
      );
    }
    if (!_showSearch) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _showSearch = true),
          style: TextButton.styleFrom(
            foregroundColor: pinit.PinitColors.aubergine,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          ),
          icon: const Icon(FeatherIcons.plus, size: 16),
          label: Text(
            'ADD A RESTAURANT',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        SocialPlaceSearchPanel(
          autofocus: true,
          searcher: widget.placeSearcher,
          onSelected: (place) => unawaited(_add(item, place)),
        ),
      ],
    );
  }
}

/// Reads and writes the once-per-user hint flag.
class _SwipeHintSeen {
  const _SwipeHintSeen(this._service);

  final SpotlightWizardSeenService _service;

  Future<bool> shouldShow() => _service.shouldShowNow();
  Future<void> markSeen() => _service.markCompleted();
}

// ── Pieces ──────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: pinit.PinitColors.mute.withValues(alpha: .32),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _PostLinkHeader extends StatelessWidget {
  const _PostLinkHeader({required this.item, required this.onTap});

  final SocialPostReviewItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final handle = item.creatorHandle?.trim();
    final description = [item.caption, item.title]
        .map((value) => value?.trim())
        .firstWhere((value) => value != null && value.isNotEmpty,
            orElse: () => null);
    final thumbnail = item.thumbnailUrl;

    return Material(
      color: pinit.PinitColors.creamSunk,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const ValueKey('social-post-link'),
        borderRadius: BorderRadius.circular(14),
        onTap: item.openUrl.trim().isEmpty ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 64,
                  child: thumbnail == null || thumbnail.isEmpty
                      ? const _ThumbFallback()
                      : Image.network(
                          thumbnail,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _ThumbFallback(),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        item.platformLabel.toUpperCase(),
                        if (handle != null && handle.isNotEmpty) '@$handle',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                        color: pinit.PinitColors.aubergine,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          height: 1.3,
                          color: pinit.PinitColors.aubergineSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                FeatherIcons.externalLink,
                size: 18,
                color: pinit.PinitColors.aubergine,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: pinit.PinitColors.creamDeep,
      alignment: Alignment.center,
      child: const Icon(
        FeatherIcons.film,
        size: 18,
        color: pinit.PinitColors.mute,
      ),
    );
  }
}

/// Red bin shown behind a card while it's swiped (or during the hint).
class _BinBackground extends StatelessWidget {
  const _BinBackground({this.binOpacity = 1});

  final double binOpacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Matches the card's own bottom margin so the red sits behind it.
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(right: 24),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: pinit.PinitColors.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Opacity(
        opacity: binOpacity,
        child: const Icon(
          FeatherIcons.trash2,
          key: ValueKey('social-place-bin'),
          color: pinit.PinitColors.cream,
          size: 22,
        ),
      ),
    );
  }
}

/// First-open hint: nudges the card left to reveal the red bin, flashes the
/// bin twice, then bounces the card back.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  static const double _reveal = 72;

  static final Animatable<double> _offset = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: -_reveal)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 25,
    ),
    TweenSequenceItem(tween: ConstantTween(-_reveal), weight: 35),
    TweenSequenceItem(
      tween: Tween(begin: -_reveal, end: 0.0)
          .chain(CurveTween(curve: Curves.elasticOut)),
      weight: 40,
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        if (t == 0 || t == 1) return child!;
        final dx = _offset.transform(t);
        // Two flashes while the card holds open (t 0.25–0.6).
        final hold = ((t - .25) / .35).clamp(0.0, 1.0);
        final binOpacity = hold == 0 || hold == 1
            ? 1.0
            : .35 + .65 * (0.5 + 0.5 * math.cos(hold * 4 * math.pi));
        return Stack(
          children: [
            Positioned.fill(child: _BinBackground(binOpacity: binOpacity)),
            Transform.translate(offset: Offset(dx, 0), child: child),
          ],
        );
      },
    );
  }
}

class _MatchPill extends StatelessWidget {
  const _MatchPill({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pinit.PinitColors.aubergine,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${(score * 100).round()}% MATCH',
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: .6,
          color: pinit.PinitColors.cream,
        ),
      ),
    );
  }
}

class _SaveTick extends StatelessWidget {
  const _SaveTick({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Save place',
      child: GestureDetector(
        key: const ValueKey('social-place-save'),
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: pinit.PinitColors.aubergine, width: 1.5),
          ),
          child: busy
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: pinit.PinitColors.aubergine,
                  ),
                )
              : const Icon(
                  FeatherIcons.check,
                  size: 15,
                  color: pinit.PinitColors.aubergine,
                ),
        ),
      ),
    );
  }
}

/// Card for a candidate that hasn't been matched to a Pinit location yet.
class _UnresolvedPlaceCard extends StatelessWidget {
  const _UnresolvedPlaceCard({
    required this.place,
    required this.saved,
    this.trailing,
  });

  final SocialPostPlace place;
  final bool saved;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final area = [place.candidateArea, place.address]
        .map((value) => value?.trim())
        .firstWhere((value) => value != null && value.isNotEmpty,
            orElse: () => null);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: pinit.PinitColors.cream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pinit.PinitColors.aubergine, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: pinit.PinitColors.aubergine,
            blurRadius: 0,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saved ? 'SAVED' : 'NOT SAVED',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: pinit.PinitColors.mute,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: pinit.PinitColors.aubergine,
                  ),
                ),
                if (area != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    area,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: pinit.PinitColors.mute,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _UndoBar extends StatelessWidget {
  const _UndoBar({required this.name, required this.onUndo});

  final String name;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: pinit.PinitColors.aubergine,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Removed $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: pinit.PinitColors.cream,
              ),
            ),
          ),
          TextButton(
            onPressed: onUndo,
            style: TextButton.styleFrom(
              foregroundColor: pinit.PinitColors.cream,
            ),
            child: Text(
              'UNDO',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: pinit.PinitColors.mute),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: pinit.PinitColors.aubergineSoft,
            ),
          ),
        ),
      ],
    );
  }
}

class _MissingOrLoading extends StatelessWidget {
  const _MissingOrLoading({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: pinit.PinitColors.aubergine,
                ),
              )
            : const _InfoLine(
                icon: FeatherIcons.alertCircle,
                text: 'We couldn’t find this post any more.',
              ),
      ),
    );
  }
}

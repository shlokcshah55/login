import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/models/social_review_models.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/pages/social_review/social_review_place_item.dart';
import 'package:login/pages/social_review/widgets/social_place_search_sheet.dart';
import 'package:login/providers/social_review_provider.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/utils/social_video_link.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Context-rich review screen for one shared TikTok or Instagram Reel.
class SocialPostReviewPage extends StatefulWidget {
  const SocialPostReviewPage({
    super.key,
    required this.postId,
    this.source = 'inbox',
    this.onOpenOriginal,
    this.placeSearcher,
  });

  final String postId;
  final String source;

  /// Test/embedding seams. Production uses the external URL launcher and
  /// Google Places-backed search.
  final Future<void> Function(SocialPostReviewItem item)? onOpenOriginal;
  final SocialPlaceSearcher? placeSearcher;

  @override
  State<SocialPostReviewPage> createState() => _SocialPostReviewPageState();
}

class _SocialPostReviewPageState extends State<SocialPostReviewPage> {
  bool _requestedRefresh = false;
  bool _trackedShown = false;
  bool _submitting = false;
  final Set<String> _selectedCandidateIds = <String>{};
  LocationModel? _searchedPlace;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterFirstFrame());
  }

  void _afterFirstFrame() {
    if (!mounted) return;
    final provider = context.read<SocialReviewProvider>();
    final item = provider.itemByPostId(widget.postId);
    if (item == null) {
      if (!provider.hasLoaded && !_requestedRefresh) {
        _requestedRefresh = true;
        unawaited(provider.refresh());
      }
      return;
    }
    _seedSelection(item);
    if (!_trackedShown) {
      _trackedShown = true;
      provider.trackPostShown(item, source: widget.source);
    }
  }

  void _seedSelection(SocialPostReviewItem item) {
    if (_selectedCandidateIds.isNotEmpty || item.places.isEmpty) return;
    final candidates = _rankedCandidates(item);
    final preferred = candidates.where(
      (place) =>
          item.pendingReviewPlaces.any((pending) => pending.id == place.id),
    );
    _selectedCandidateIds.add(
      (preferred.isNotEmpty ? preferred.first : candidates.first).id,
    );
  }

  List<SocialPostPlace> _rankedCandidates(SocialPostReviewItem item) {
    return item.places.toList(growable: false)
      ..sort(
        (a, b) => (b.confidenceScore ?? 0).compareTo(a.confidenceScore ?? 0),
      );
  }

  Future<void> _openPost(SocialPostReviewItem item) async {
    final override = widget.onOpenOriginal;
    if (override != null) {
      await override(item);
      return;
    }
    final uri = Uri.tryParse(item.openUrl);
    if (uri == null || !uri.hasScheme) return;
    context.read<SocialReviewProvider>().trackOpenedOriginalPost(item);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _confirm(SocialPostReviewItem item) async {
    if (_submitting) return;
    final selected = _rankedCandidates(item)
        .where((place) => _selectedCandidateIds.contains(place.id))
        .toList(growable: false);
    final selectionCount = selected.length + (_searchedPlace == null ? 0 : 1);
    if (selectionCount == 0) return;

    setState(() => _submitting = true);
    final provider = context.read<SocialReviewProvider>();
    final ok = await provider.confirmPlaces(
      item,
      selectedPlaces: selected,
      additionalPlace: _searchedPlace,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    _showMessage(
      ok
          ? selectionCount == 1
              ? 'Restaurant confirmed'
              : '$selectionCount restaurants confirmed'
          : 'Couldn’t save every restaurant',
      isError: !ok,
    );
  }

  Future<void> _dismiss(SocialPostReviewItem item) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await context.read<SocialReviewProvider>().dismissPost(item);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (mounted) _showMessage('Post dismissed');
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError ? pinit.PinitColors.accent : pinit.PinitColors.aubergine,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SocialReviewProvider>();
    final item = provider.itemByPostId(widget.postId);
    if (item != null) _seedSelection(item);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: pinit.PinitColors.cream,
      body: SafeArea(
        child: item == null
            ? _MissingOrLoading(
                loading: !provider.hasLoaded,
                onBack: () => Navigator.of(context).pop(),
              )
            : _buildReview(provider, item),
      ),
    );
  }

  Widget _buildReview(
    SocialReviewProvider provider,
    SocialPostReviewItem item,
  ) {
    final projection = SocialReviewPostItem(
      review: item,
      locationsById: provider.locationsById,
    );
    final actionable =
        projection.state == SocialPostWorkflowState.needsChecking ||
            projection.state == SocialPostWorkflowState.failed;

    return Column(
      children: [
        _PageHeader(onBack: () => Navigator.of(context).pop()),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 6, 16, actionable ? 28 : 36),
            children: [
              _PostHero(item: item, onOpen: () => unawaited(_openPost(item))),
              if (!actionable) ...[
                const SizedBox(height: 14),
                _StatusPanel(item: projection),
              ],
              const SizedBox(height: 22),
              _InsightsSection(
                item: item,
                locationsById: provider.locationsById,
              ),
              if (item.places.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionHeading(title: 'Suggested restaurants'),
                const SizedBox(height: 11),
                for (final candidate in _rankedCandidates(item)) ...[
                  _CandidateCard(
                    place: candidate,
                    selected: _selectedCandidateIds.contains(candidate.id),
                    readOnly: !actionable,
                    onTap: () {
                      if (!actionable) return;
                      setState(() {
                        if (!_selectedCandidateIds.add(candidate.id)) {
                          _selectedCandidateIds.remove(candidate.id);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              if (actionable) ...[
                const SizedBox(height: 16),
                const _SectionHeading(title: 'Search for a different place'),
                const SizedBox(height: 11),
                SocialPlaceSearchPanel(
                  searcher: widget.placeSearcher,
                  onSelected: (place) => setState(() => _searchedPlace = place),
                ),
                if (_searchedPlace case final searched?) ...[
                  const SizedBox(height: 10),
                  _SelectedSearchPlace(
                    place: searched,
                    onClear: () => setState(() => _searchedPlace = null),
                  ),
                ],
              ],
            ],
          ),
        ),
        if (actionable)
          _ReviewActionBar(
            submitting: _submitting,
            selectionCount:
                _selectedCandidateIds.length + (_searchedPlace == null ? 0 : 1),
            onConfirm: () => unawaited(_confirm(item)),
            onDismiss: () => unawaited(_dismiss(item)),
          ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(
              FeatherIcons.chevronLeft,
              color: pinit.PinitColors.aubergine,
            ),
          ),
          Expanded(
            child: Text(
              'Review shared post',
              style: AppTypography.brand(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: pinit.PinitColors.aubergine,
                letterSpacing: .9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostHero extends StatelessWidget {
  const _PostHero({required this.item, required this.onOpen});

  final SocialPostReviewItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: pinit.PinitColors.creamDeep),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroArtwork(item: item),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      item.platformType == SocialVideoPlatform.instagram
                          ? FeatherIcons.instagram
                          : FeatherIcons.music,
                      size: 13,
                      color: pinit.PinitColors.aubergineSoft,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.platformLabel,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: pinit.PinitColors.aubergineSoft,
                        letterSpacing: .35,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.creatorHandle?.trim().isNotEmpty == true
                      ? '@${item.creatorHandle!.trim()}'
                      : '${item.platformLabel} creator',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: pinit.PinitColors.aubergine,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.caption?.trim().isNotEmpty == true
                      ? item.caption!.trim()
                      : item.title?.trim().isNotEmpty == true
                          ? item.title!.trim()
                          : 'Shared post',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: pinit.PinitColors.aubergineSoft,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 11),
                OutlinedButton.icon(
                  onPressed: item.openUrl.trim().isEmpty ? null : onOpen,
                  icon: const Icon(FeatherIcons.externalLink, size: 14),
                  label: const Text('Open original'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: pinit.PinitColors.aubergine,
                    side: const BorderSide(
                      color: pinit.PinitColors.creamDeep,
                    ),
                    backgroundColor: pinit.PinitColors.cream,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                    textStyle: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroArtwork extends StatelessWidget {
  const _HeroArtwork({required this.item});

  final SocialPostReviewItem item;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            pinit.PinitColors.cream,
            pinit.PinitColors.creamDeep,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: pinit.PinitColors.aubergine,
            shape: BoxShape.circle,
          ),
          child: Icon(
            item.platformType == SocialVideoPlatform.instagram
                ? FeatherIcons.instagram
                : FeatherIcons.music,
            color: pinit.PinitColors.cream,
            size: 20,
          ),
        ),
      ),
    );
    final imageUrl = item.thumbnailUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 92,
        height: 132,
        child: imageUrl == null || imageUrl.isEmpty
            ? fallback
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.item});

  final SocialReviewPostItem item;

  @override
  Widget build(BuildContext context) {
    final (title, icon, background, foreground) = switch (item.state) {
      SocialPostWorkflowState.processing => (
          'Still processing',
          FeatherIcons.clock,
          const Color(0xFFF0E7EF),
          pinit.PinitColors.aubergineSoft,
        ),
      SocialPostWorkflowState.needsChecking => (
          'Your check is needed',
          FeatherIcons.alertCircle,
          const Color(0xFFFFF5DB),
          const Color(0xFF805A08),
        ),
      SocialPostWorkflowState.failed => (
          'Pinit couldn’t finish',
          FeatherIcons.alertTriangle,
          const Color(0xFFFBE9E5),
          const Color(0xFF92392F),
        ),
      SocialPostWorkflowState.resolved => (
          'Restaurant confirmed',
          FeatherIcons.checkCircle,
          const Color(0xFFE4F4F1),
          const Color(0xFF176F66),
        ),
      SocialPostWorkflowState.dismissed => (
          'Post dismissed',
          FeatherIcons.xCircle,
          pinit.PinitColors.creamSunk,
          pinit.PinitColors.mute,
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.statusExplanation,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: pinit.PinitColors.aubergineSoft,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsSection extends StatelessWidget {
  const _InsightsSection({
    required this.item,
    required this.locationsById,
  });

  final SocialPostReviewItem item;
  final Map<int, LocationModel> locationsById;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[];

    void add(String? value) {
      final normalized = value?.trim();
      if (normalized == null ||
          normalized.isEmpty ||
          chips.any((chip) => chip.toLowerCase() == normalized.toLowerCase())) {
        return;
      }
      chips.add(normalized);
    }

    for (final vibe in item.topVibes) {
      add(_humanize(vibe));
    }
    for (final place in item.places) {
      for (final dish in place.keyDishNames) {
        add(dish);
      }
      for (final vibe in place.vibeSignalNames) {
        add(_humanize(vibe));
      }
      add(place.candidateArea);
      final id = item.savedLocationIds[place.id] ?? place.locationId;
      final location = id == null ? null : locationsById[id];
      add(location?.displayCuisine);
      if (location?.priceLevel case final price? when price > 0) {
        add('£' * price.clamp(1, 4).toInt());
      }
    }
    final notes = item.places
        .map((place) => place.creatorNotes)
        .whereType<String>()
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(title: 'What Pinit found'),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in chips.take(6)) _ContextChip(label: chip),
            ],
          ),
        ],
        if (notes != null) ...[
          const SizedBox(height: 11),
          _ContextNote(
            icon: FeatherIcons.messageCircle,
            label: 'Creator note',
            value: notes,
          ),
        ],
        if (chips.isEmpty && notes == null) ...[
          const SizedBox(height: 11),
          const _ContextNote(
            icon: FeatherIcons.info,
            label: 'Limited context',
            value:
                'No cuisine, dish or vibe details were available, but you can still identify the place below.',
          ),
        ],
      ],
    );
  }

  static String _humanize(String value) {
    return value
        .split(RegExp(r'[_ ]+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.brand(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: pinit.PinitColors.aubergine,
        letterSpacing: .7,
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: pinit.PinitColors.creamDeep),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: pinit.PinitColors.aubergineSoft,
        ),
      ),
    );
  }
}

class _ContextNote extends StatelessWidget {
  const _ContextNote({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: pinit.PinitColors.aubergineSoft),
          const SizedBox(width: 9),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: pinit.PinitColors.aubergineSoft,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: '$label · ',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatefulWidget {
  const _CandidateCard({
    required this.place,
    required this.selected,
    required this.readOnly,
    required this.onTap,
  });

  final SocialPostPlace place;
  final bool selected;
  final bool readOnly;
  final VoidCallback onTap;

  @override
  State<_CandidateCard> createState() => _CandidateCardState();
}

class _CandidateCardState extends State<_CandidateCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final detail = place.address?.trim().isNotEmpty == true
        ? place.address!.trim()
        : place.candidateArea?.trim();
    return AnimatedScale(
      scale: _pressed ? .985 : 1,
      duration: const Duration(milliseconds: 130),
      child: Material(
        color:
            widget.selected ? const Color(0xFFF5EAF3) : pinit.PinitColors.cream,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: widget.readOnly ? null : widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: widget.selected
                    ? pinit.PinitColors.aubergineSoft
                    : pinit.PinitColors.creamDeep,
                width: widget.selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.readOnly) ...[
                  Container(
                    width: 21,
                    height: 21,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.selected
                          ? pinit.PinitColors.aubergine
                          : Colors.transparent,
                      border: Border.all(
                        color: widget.selected
                            ? pinit.PinitColors.aubergine
                            : pinit.PinitColors.mute,
                        width: 1.4,
                      ),
                    ),
                    child: widget.selected
                        ? const Icon(
                            FeatherIcons.check,
                            size: 12,
                            color: pinit.PinitColors.cream,
                          )
                        : null,
                  ),
                  const SizedBox(width: 11),
                ] else ...[
                  const Icon(
                    FeatherIcons.mapPin,
                    size: 18,
                    color: pinit.PinitColors.aubergineSoft,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: pinit.PinitColors.aubergine,
                              ),
                            ),
                          ),
                          if (place.confidenceScore != null)
                            _ConfidencePill(score: place.confidenceScore!),
                        ],
                      ),
                      if (detail != null && detail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: pinit.PinitColors.mute,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (place.keyDishNames.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final dish in place.keyDishNames.take(3))
                              _MicroChip(label: dish),
                          ],
                        ),
                      ],
                      if (place.specialOfferLabels.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              FeatherIcons.tag,
                              size: 12,
                              color: pinit.PinitColors.aubergineSoft,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                place.specialOfferLabels.first,
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: pinit.PinitColors.aubergineSoft,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfidencePill extends StatelessWidget {
  const _ConfidencePill({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${(score * 100).round()}% match',
        style: GoogleFonts.dmSans(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: pinit.PinitColors.aubergineSoft,
        ),
      ),
    );
  }
}

class _MicroChip extends StatelessWidget {
  const _MicroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: pinit.PinitColors.aubergineSoft,
        ),
      ),
    );
  }
}

class _SelectedSearchPlace extends StatelessWidget {
  const _SelectedSearchPlace({required this.place, required this.onClear});

  final LocationModel place;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE4F4F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB9DDD7)),
      ),
      child: Row(
        children: [
          const Icon(
            FeatherIcons.checkCircle,
            size: 18,
            color: Color(0xFF176F66),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Use ${place.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: pinit.PinitColors.aubergine,
                  ),
                ),
                if (place.vicinity?.trim().isNotEmpty == true)
                  Text(
                    place.vicinity!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: pinit.PinitColors.mute,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear selected place',
            onPressed: onClear,
            icon: const Icon(
              FeatherIcons.x,
              size: 17,
              color: pinit.PinitColors.aubergineSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewActionBar extends StatelessWidget {
  const _ReviewActionBar({
    required this.submitting,
    required this.selectionCount,
    required this.onConfirm,
    required this.onDismiss,
  });

  final bool submitting;
  final int selectionCount;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
      decoration: BoxDecoration(
        color: pinit.PinitColors.cream,
        border: const Border(
          top: BorderSide(color: pinit.PinitColors.creamDeep),
        ),
        boxShadow: pinit.PinitColors.elevatedShadow,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            TextButton(
              onPressed: submitting ? null : onDismiss,
              style: TextButton.styleFrom(
                foregroundColor: pinit.PinitColors.mute,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                textStyle: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('Dismiss post'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: !submitting && selectionCount > 0 ? onConfirm : null,
                style: FilledButton.styleFrom(
                  backgroundColor: pinit.PinitColors.aubergine,
                  foregroundColor: pinit.PinitColors.cream,
                  disabledBackgroundColor: pinit.PinitColors.creamDeep,
                  disabledForegroundColor: pinit.PinitColors.mute,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: pinit.PinitColors.cream,
                        ),
                      )
                    : Text(
                        selectionCount > 1
                            ? 'Confirm $selectionCount restaurants'
                            : 'Confirm restaurant',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingOrLoading extends StatelessWidget {
  const _MissingOrLoading({required this.loading, required this.onBack});

  final bool loading;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: pinit.PinitColors.aubergine),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              FeatherIcons.inbox,
              size: 42,
              color: pinit.PinitColors.mute,
            ),
            const SizedBox(height: 14),
            Text(
              'This shared post is no longer available',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: pinit.PinitColors.aubergine,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onBack,
              style: FilledButton.styleFrom(
                backgroundColor: pinit.PinitColors.aubergine,
              ),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

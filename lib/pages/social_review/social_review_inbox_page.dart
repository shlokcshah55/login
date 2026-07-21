import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/social_review_models.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/pages/social_review/social_post_review_page.dart';
import 'package:login/pages/social_review/social_review_place_item.dart';
import 'package:login/providers/social_review_provider.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/utils/social_video_link.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Post-first history and recovery surface for shared TikToks and Reels.
class SocialReviewInboxPage extends StatefulWidget {
  const SocialReviewInboxPage({
    super.key,
    this.onOpenPost,
    this.initialFilter,
  });

  /// Test/embedding seam. Production callers open [SocialPostReviewPage].
  final ValueChanged<SocialPostReviewItem>? onOpenPost;
  final SocialReviewInboxFilter? initialFilter;

  @override
  State<SocialReviewInboxPage> createState() => _SocialReviewInboxPageState();
}

class _SocialReviewInboxPageState extends State<SocialReviewInboxPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  SocialReviewInboxFilter? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  SocialReviewInboxFilter _effectiveFilter(
    List<SocialReviewPostItem> items,
  ) {
    if (_selectedFilter != null) return _selectedFilter!;
    if (items.any((item) =>
        item.state == SocialPostWorkflowState.needsChecking ||
        item.state == SocialPostWorkflowState.failed)) {
      return SocialReviewInboxFilter.needsChecking;
    }
    if (items.any((item) => item.state == SocialPostWorkflowState.processing)) {
      return SocialReviewInboxFilter.processing;
    }
    if (items.any((item) => item.state == SocialPostWorkflowState.resolved)) {
      return SocialReviewInboxFilter.recentlySaved;
    }
    return SocialReviewInboxFilter.all;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pinit.PinitColors.cream,
      body: SafeArea(
        child: Consumer<SocialReviewProvider>(
          builder: (context, provider, _) {
            final items = provider.items
                .map(
                  (review) => SocialReviewPostItem(
                    review: review,
                    locationsById: provider.locationsById,
                  ),
                )
                .toList(growable: false);
            final filter = _effectiveFilter(items);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(onBack: () => Navigator.of(context).pop()),
                _SearchField(
                  controller: _searchController,
                  query: _query,
                  onChanged: (value) => setState(() => _query = value),
                  onClear: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
                _FilterBar(
                  selected: filter,
                  attentionCount: items
                      .where((item) =>
                          item.state == SocialPostWorkflowState.needsChecking ||
                          item.state == SocialPostWorkflowState.failed)
                      .length,
                  processingCount: items
                      .where((item) =>
                          item.state == SocialPostWorkflowState.processing)
                      .length,
                  onSelected: (value) =>
                      setState(() => _selectedFilter = value),
                ),
                const SizedBox(height: 10),
                Expanded(child: _buildBody(provider, items, filter)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    SocialReviewProvider provider,
    List<SocialReviewPostItem> items,
    SocialReviewInboxFilter filter,
  ) {
    if (provider.isLoading && !provider.hasLoaded) {
      return const _LoadingList();
    }
    if (provider.error != null && items.isEmpty) {
      return _ErrorView(onRetry: provider.refresh);
    }

    final visible = visibleSocialReviewPosts(
      items,
      filter: filter,
      query: _query,
    );
    if (visible.isEmpty) {
      return _EmptyView(filter: filter, hasQuery: _query.trim().isNotEmpty);
    }

    return RefreshIndicator(
      color: pinit.PinitColors.aubergine,
      backgroundColor: pinit.PinitColors.cream,
      onRefresh: provider.refresh,
      child: ListView.builder(
        key: ValueKey('${filter.name}:${_query.trim().toLowerCase()}'),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 32),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final item = visible[index];
          return _SharedPostCard(
            key: ValueKey('social-post:${item.id}'),
            item: item,
            onOpen: () => _openReview(item.review),
            onOpenOriginal: item.review.openUrl.trim().isEmpty
                ? null
                : () => unawaited(_openOriginal(item.review)),
            onDismiss: item.state == SocialPostWorkflowState.needsChecking ||
                    item.state == SocialPostWorkflowState.failed
                ? () => unawaited(_dismiss(item.review))
                : null,
          );
        },
      ),
    );
  }

  void _openReview(SocialPostReviewItem item) {
    final override = widget.onOpenPost;
    if (override != null) {
      override(item);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SocialPostReviewPage(
          postId: item.postId,
          source: 'inbox',
        ),
      ),
    );
  }

  Future<void> _openOriginal(SocialPostReviewItem item) async {
    final uri = Uri.tryParse(item.openUrl);
    if (uri == null || !uri.hasScheme) return;
    context.read<SocialReviewProvider>().trackOpenedOriginalPost(item);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _dismiss(SocialPostReviewItem item) async {
    await context.read<SocialReviewProvider>().dismissPost(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Post dismissed'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: pinit.PinitColors.aubergine,
        ),
      );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoundIconButton(
            icon: FeatherIcons.chevronLeft,
            semanticLabel: 'Back',
            onTap: onBack,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shared saves',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.brand(
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    color: pinit.PinitColors.aubergine,
                    letterSpacing: .6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'See what Pinit found and finish anything uncertain.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: pinit.PinitColors.mute,
                    height: 1.35,
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: pinit.PinitColors.creamSunk,
        shape: CircleBorder(
          side: BorderSide(color: pinit.PinitColors.creamDeep),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              size: 19,
              color: pinit.PinitColors.aubergine,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        cursorColor: pinit.PinitColors.aubergine,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: pinit.PinitColors.aubergine,
        ),
        decoration: InputDecoration(
          hintText: 'Search posts, creators or places',
          hintStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: pinit.PinitColors.mute,
          ),
          prefixIcon: const Icon(
            FeatherIcons.search,
            size: 19,
            color: pinit.PinitColors.aubergineSoft,
          ),
          suffixIcon: query.trim().isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(
                    FeatherIcons.x,
                    size: 18,
                    color: pinit.PinitColors.aubergineSoft,
                  ),
                ),
          filled: true,
          fillColor: pinit.PinitColors.creamSunk,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: pinit.PinitColors.creamDeep,
              width: 1.3,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: pinit.PinitColors.aubergine,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.attentionCount,
    required this.processingCount,
    required this.onSelected,
  });

  final SocialReviewInboxFilter selected;
  final int attentionCount;
  final int processingCount;
  final ValueChanged<SocialReviewInboxFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _FilterChip(
            label: 'Needs checking',
            count: attentionCount,
            selected: selected == SocialReviewInboxFilter.needsChecking,
            onTap: () => onSelected(SocialReviewInboxFilter.needsChecking),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Processing',
            count: processingCount,
            selected: selected == SocialReviewInboxFilter.processing,
            onTap: () => onSelected(SocialReviewInboxFilter.processing),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Recently saved',
            selected: selected == SocialReviewInboxFilter.recentlySaved,
            onTap: () => onSelected(SocialReviewInboxFilter.recentlySaved),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'All',
            selected: selected == SocialReviewInboxFilter.all,
            onTap: () => onSelected(SocialReviewInboxFilter.all),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? pinit.PinitColors.aubergine
                : pinit.PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? pinit.PinitColors.aubergine
                  : pinit.PinitColors.creamDeep,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? pinit.PinitColors.cream
                      : pinit.PinitColors.aubergine,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? pinit.PinitColors.cream.withValues(alpha: .18)
                        : pinit.PinitColors.cream,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: selected
                          ? pinit.PinitColors.cream
                          : pinit.PinitColors.aubergine,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedPostCard extends StatefulWidget {
  const _SharedPostCard({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onOpenOriginal,
    required this.onDismiss,
  });

  final SocialReviewPostItem item;
  final VoidCallback onOpen;
  final VoidCallback? onOpenOriginal;
  final VoidCallback? onDismiss;

  @override
  State<_SharedPostCard> createState() => _SharedPostCardState();
}

class _SharedPostCardState extends State<_SharedPostCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final candidate = item.bestCandidate;
    final resolvedId = candidate == null
        ? null
        : item.review.savedLocationIds[candidate.id] ?? candidate.locationId;
    final location = resolvedId == null ? null : item.locationsById[resolvedId];
    final artwork = item.review.thumbnailUrl?.trim().isNotEmpty == true
        ? item.review.thumbnailUrl
        : location?.imageUrl;

    return AnimatedScale(
      scale: _pressed ? .985 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: pinit.PinitColors.cream,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: pinit.PinitColors.creamDeep,
            width: 1.2,
          ),
          boxShadow: pinit.PinitColors.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onOpen,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PostArtwork(
                        imageUrl: artwork,
                        platform: item.review.platformType,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _PlatformLabel(review: item.review),
                                const Spacer(),
                                _StatusBadge(state: item.state),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.review.creatorHandle?.trim().isNotEmpty ==
                                      true
                                  ? '@${item.review.creatorHandle!.trim()}'
                                  : '${item.review.platformLabel} creator',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: pinit.PinitColors.aubergineSoft,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.summary,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: pinit.PinitColors.aubergine,
                                height: 1.28,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  _WhyRow(item: item),
                  if (candidate != null) ...[
                    const SizedBox(height: 12),
                    _CandidateSummary(
                      candidate: candidate,
                      locationName: location?.name,
                    ),
                  ],
                  if (item.insightChips.isNotEmpty) ...[
                    const SizedBox(height: 11),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final chip in item.insightChips)
                          _InsightChip(label: chip),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (widget.onOpenOriginal != null)
                        _SecondaryAction(
                          icon: FeatherIcons.externalLink,
                          label: 'Open post',
                          onTap: widget.onOpenOriginal!,
                        ),
                      if (widget.onOpenOriginal != null &&
                          item.primaryActionLabel != null)
                        const SizedBox(width: 8),
                      if (item.primaryActionLabel != null)
                        Expanded(
                          child: _PrimaryAction(
                            label: item.primaryActionLabel!,
                            onTap: widget.onOpen,
                          ),
                        ),
                      if (widget.onDismiss != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Dismiss post',
                          onPressed: widget.onDismiss,
                          icon: const Icon(
                            FeatherIcons.x,
                            size: 18,
                            color: pinit.PinitColors.mute,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PostArtwork extends StatelessWidget {
  const _PostArtwork({required this.imageUrl, required this.platform});

  final String? imageUrl;
  final SocialVideoPlatform platform;

  @override
  Widget build(BuildContext context) {
    final fallback = _ArtworkFallback(platform: platform);
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        width: 78,
        height: 96,
        child: imageUrl == null || imageUrl!.trim().isEmpty
            ? fallback
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.platform});

  final SocialVideoPlatform platform;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            pinit.PinitColors.creamSunk,
            pinit.PinitColors.creamDeep,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: pinit.PinitColors.aubergine,
            shape: BoxShape.circle,
          ),
          child: Icon(
            platform == SocialVideoPlatform.instagram
                ? FeatherIcons.instagram
                : FeatherIcons.music,
            color: pinit.PinitColors.cream,
            size: 19,
          ),
        ),
      ),
    );
  }
}

class _PlatformLabel extends StatelessWidget {
  const _PlatformLabel({required this.review});

  final SocialPostReviewItem review;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          review.platformType == SocialVideoPlatform.instagram
              ? FeatherIcons.instagram
              : FeatherIcons.music,
          size: 12,
          color: pinit.PinitColors.aubergineSoft,
        ),
        const SizedBox(width: 5),
        Text(
          review.platformLabel,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: pinit.PinitColors.aubergineSoft,
            letterSpacing: .4,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final SocialPostWorkflowState state;

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground, icon) = switch (state) {
      SocialPostWorkflowState.processing => (
          'Processing',
          const Color(0xFFF0E7EF),
          pinit.PinitColors.aubergineSoft,
          FeatherIcons.clock,
        ),
      SocialPostWorkflowState.needsChecking => (
          'Needs checking',
          const Color(0xFFFFF0CC),
          const Color(0xFF805A08),
          FeatherIcons.alertCircle,
        ),
      SocialPostWorkflowState.failed => (
          'Couldn’t finish',
          const Color(0xFFFBE6E2),
          const Color(0xFF9A3025),
          FeatherIcons.alertTriangle,
        ),
      SocialPostWorkflowState.resolved => (
          'Resolved',
          const Color(0xFFDFF3EF),
          const Color(0xFF176F66),
          FeatherIcons.checkCircle,
        ),
      SocialPostWorkflowState.dismissed => (
          'Dismissed',
          pinit.PinitColors.creamSunk,
          pinit.PinitColors.mute,
          FeatherIcons.xCircle,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhyRow extends StatelessWidget {
  const _WhyRow({required this.item});

  final SocialReviewPostItem item;

  @override
  Widget build(BuildContext context) {
    final isActionable = item.state == SocialPostWorkflowState.needsChecking ||
        item.state == SocialPostWorkflowState.failed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: isActionable
            ? const Color(0xFFFFF8E8)
            : pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isActionable ? FeatherIcons.info : FeatherIcons.activity,
            size: 14,
            color: isActionable
                ? const Color(0xFF805A08)
                : pinit.PinitColors.aubergineSoft,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.statusExplanation,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: pinit.PinitColors.aubergineSoft,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateSummary extends StatelessWidget {
  const _CandidateSummary({
    required this.candidate,
    required this.locationName,
  });

  final SocialPostPlace candidate;
  final String? locationName;

  @override
  Widget build(BuildContext context) {
    final name = locationName?.trim().isNotEmpty == true
        ? locationName!.trim()
        : candidate.name;
    final area = candidate.address?.trim().isNotEmpty == true
        ? candidate.address!.trim()
        : candidate.candidateArea?.trim();
    final confidence = candidate.confidenceScore;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pinit.PinitColors.creamDeep),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: pinit.PinitColors.cream,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              FeatherIcons.mapPin,
              size: 15,
              color: pinit.PinitColors.aubergine,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: pinit.PinitColors.aubergine,
                  ),
                ),
                if (area != null && area.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    area,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: pinit.PinitColors.mute,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (confidence != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: pinit.PinitColors.cream,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${(confidence * 100).round()}% match',
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: pinit.PinitColors.aubergineSoft,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InsightChip extends StatelessWidget {
  const _InsightChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: pinit.PinitColors.aubergineSoft,
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: pinit.PinitColors.aubergine,
        side: const BorderSide(color: pinit.PinitColors.creamDeep),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        visualDensity: VisualDensity.compact,
        textStyle: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: pinit.PinitColors.aubergine,
        foregroundColor: pinit.PinitColors.cream,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        visualDensity: VisualDensity.compact,
        textStyle: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      child: Text(label),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        height: 260,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: pinit.PinitColors.creamSunk,
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.filter, required this.hasQuery});

  final SocialReviewInboxFilter filter;
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final title = hasQuery
        ? 'No matching shared posts'
        : switch (filter) {
            SocialReviewInboxFilter.needsChecking => 'Nothing needs checking',
            SocialReviewInboxFilter.processing => 'Nothing is processing',
            SocialReviewInboxFilter.recentlySaved => 'No recent social saves',
            SocialReviewInboxFilter.all => 'No shared posts yet',
          };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              FeatherIcons.inbox,
              size: 38,
              color: pinit.PinitColors.mute,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: pinit.PinitColors.aubergine,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            FeatherIcons.alertCircle,
            size: 38,
            color: pinit.PinitColors.mute,
          ),
          const SizedBox(height: 14),
          Text(
            'Couldn’t load shared posts',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: pinit.PinitColors.aubergine,
            ),
          ),
          const SizedBox(height: 12),
          _PrimaryAction(
            label: 'Retry',
            onTap: () => unawaited(onRetry()),
          ),
        ],
      ),
    );
  }
}

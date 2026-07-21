import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/social_review_models.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/pages/social_review/social_post_review_page.dart';
import 'package:login/pages/social_review/social_review_place_item.dart';
import 'package:login/providers/social_review_provider.dart';
import 'package:login/utils/social_video_link.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-screen, snap-scrolling feed of shared TikToks and Reels — one post per
/// screen, TikTok-style.
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
  SocialReviewInboxFilter? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
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
      backgroundColor: pinit.PinitColors.aubergine,
      body: Consumer<SocialReviewProvider>(
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
          return Stack(
            children: [
              Positioned.fill(child: _buildFeed(provider, items, filter)),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: _TopControls(
                    selected: filter,
                    attentionCount: items
                        .where((item) =>
                            item.state ==
                                SocialPostWorkflowState.needsChecking ||
                            item.state == SocialPostWorkflowState.failed)
                        .length,
                    processingCount: items
                        .where((item) =>
                            item.state == SocialPostWorkflowState.processing)
                        .length,
                    onBack: () => Navigator.of(context).pop(),
                    onRefresh: () => unawaited(provider.refresh()),
                    onSelected: (value) =>
                        setState(() => _selectedFilter = value),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeed(
    SocialReviewProvider provider,
    List<SocialReviewPostItem> items,
    SocialReviewInboxFilter filter,
  ) {
    if (provider.isLoading && !provider.hasLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: pinit.PinitColors.cream),
      );
    }
    if (provider.error != null && items.isEmpty) {
      return _ErrorView(onRetry: provider.refresh);
    }

    final visible = visibleSocialReviewPosts(
      items,
      filter: filter,
      query: '',
    );
    if (visible.isEmpty) {
      return _EmptyView(filter: filter);
    }

    return PageView.builder(
      key: ValueKey('feed:${filter.name}'),
      scrollDirection: Axis.vertical,
      physics: const _SnappyPagePhysics(),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final item = visible[index];
        return _SharedPostPage(
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

/// Firmer snap than the default so a short flick still lands on one post.
class _SnappyPagePhysics extends ScrollPhysics {
  const _SnappyPagePhysics({super.parent});

  @override
  _SnappyPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _SnappyPagePhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 80,
        stiffness: 100,
        damping: 1,
      );
}

class _TopControls extends StatelessWidget {
  const _TopControls({
    required this.selected,
    required this.attentionCount,
    required this.processingCount,
    required this.onBack,
    required this.onRefresh,
    required this.onSelected,
  });

  final SocialReviewInboxFilter selected;
  final int attentionCount;
  final int processingCount;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final ValueChanged<SocialReviewInboxFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _GlassIconButton(
                icon: FeatherIcons.chevronLeft,
                semanticLabel: 'Back',
                onTap: onBack,
              ),
              const Spacer(),
              _GlassIconButton(
                icon: FeatherIcons.refreshCw,
                semanticLabel: 'Refresh',
                onTap: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Needs checking',
                  count: attentionCount,
                  selected: selected == SocialReviewInboxFilter.needsChecking,
                  onTap: () =>
                      onSelected(SocialReviewInboxFilter.needsChecking),
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
                  onTap: () =>
                      onSelected(SocialReviewInboxFilter.recentlySaved),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'All',
                  selected: selected == SocialReviewInboxFilter.all,
                  onTap: () => onSelected(SocialReviewInboxFilter.all),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
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
        color: Colors.black.withValues(alpha: .28),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 19, color: pinit.PinitColors.cream),
          ),
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? pinit.PinitColors.cream
                : Colors.black.withValues(alpha: .28),
            borderRadius: BorderRadius.circular(999),
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
                      ? pinit.PinitColors.aubergine
                      : pinit.PinitColors.cream,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? pinit.PinitColors.aubergine.withValues(alpha: .12)
                        : pinit.PinitColors.cream.withValues(alpha: .22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: selected
                          ? pinit.PinitColors.aubergine
                          : pinit.PinitColors.cream,
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

class _SharedPostPage extends StatelessWidget {
  const _SharedPostPage({
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
  Widget build(BuildContext context) {
    final review = item.review;
    final candidate = item.bestCandidate;
    final resolvedId = candidate == null
        ? null
        : review.savedLocationIds[candidate.id] ?? candidate.locationId;
    final location = resolvedId == null ? null : item.locationsById[resolvedId];
    final artwork = review.thumbnailUrl?.trim().isNotEmpty == true
        ? review.thumbnailUrl
        : location?.imageUrl;
    final candidateName = location?.name.trim().isNotEmpty == true
        ? location!.name.trim()
        : candidate?.name;

    return GestureDetector(
      onTap: onOpen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Backdrop(imageUrl: artwork, platform: review.platformType),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .35, 1],
                colors: [
                  Color(0x00000000),
                  Color(0x40000000),
                  Color(0xE6000000),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _PlatformLabel(review: review),
                        const Spacer(),
                        _StatusBadge(state: item.state),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      review.creatorHandle?.trim().isNotEmpty == true
                          ? '@${review.creatorHandle!.trim()}'
                          : '${review.platformLabel} creator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: pinit.PinitColors.cream.withValues(alpha: .82),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.summary,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: pinit.PinitColors.cream,
                        height: 1.24,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      item.statusExplanation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: pinit.PinitColors.cream.withValues(alpha: .78),
                        height: 1.35,
                      ),
                    ),
                    if (candidateName != null && candidateName.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _CandidateLine(
                        name: candidateName,
                        confidence: candidate?.confidenceScore,
                      ),
                    ],
                    if (item.insightChips.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final chip in item.insightChips)
                            _InsightChip(label: chip),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    _ActionRow(
                      primaryLabel: item.primaryActionLabel,
                      onPrimary: onOpen,
                      onOpenOriginal: onOpenOriginal,
                      onDismiss: onDismiss,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.imageUrl, required this.platform});

  final String? imageUrl;
  final SocialVideoPlatform platform;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            pinit.PinitColors.aubergineSoft,
            pinit.PinitColors.aubergine,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          platform == SocialVideoPlatform.instagram
              ? FeatherIcons.instagram
              : FeatherIcons.music,
          color: pinit.PinitColors.cream.withValues(alpha: .28),
          size: 72,
        ),
      ),
    );
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return fallback;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _PlatformLabel extends StatelessWidget {
  const _PlatformLabel({required this.review});

  final SocialPostReviewItem review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .3),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            review.platformType == SocialVideoPlatform.instagram
                ? FeatherIcons.instagram
                : FeatherIcons.music,
            size: 12,
            color: pinit.PinitColors.cream,
          ),
          const SizedBox(width: 6),
          Text(
            review.platformLabel,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: pinit.PinitColors.cream,
              letterSpacing: .4,
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateLine extends StatelessWidget {
  const _CandidateLine({required this.name, required this.confidence});

  final String name;
  final double? confidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            FeatherIcons.mapPin,
            size: 15,
            color: pinit.PinitColors.cream,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: pinit.PinitColors.cream,
              ),
            ),
          ),
          if (confidence != null) ...[
            const SizedBox(width: 10),
            Text(
              '${(confidence! * 100).round()}% match',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: pinit.PinitColors.cream.withValues(alpha: .85),
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: pinit.PinitColors.cream,
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.primaryLabel,
    required this.onPrimary,
    required this.onOpenOriginal,
    required this.onDismiss,
  });

  final String? primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback? onOpenOriginal;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (primaryLabel != null)
          Expanded(
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: pinit.PinitColors.cream,
                foregroundColor: pinit.PinitColors.aubergine,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(primaryLabel!),
            ),
          ),
        if (onOpenOriginal != null) ...[
          const SizedBox(width: 10),
          _GlassIconButton(
            icon: FeatherIcons.externalLink,
            semanticLabel: 'Open post',
            onTap: onOpenOriginal!,
          ),
        ],
        if (onDismiss != null) ...[
          const SizedBox(width: 10),
          _GlassIconButton(
            icon: FeatherIcons.x,
            semanticLabel: 'Dismiss post',
            onTap: onDismiss!,
          ),
        ],
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.filter});

  final SocialReviewInboxFilter filter;

  @override
  Widget build(BuildContext context) {
    final title = switch (filter) {
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
            Icon(
              FeatherIcons.inbox,
              size: 40,
              color: pinit.PinitColors.cream.withValues(alpha: .7),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: pinit.PinitColors.cream,
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
          Icon(
            FeatherIcons.alertCircle,
            size: 40,
            color: pinit.PinitColors.cream.withValues(alpha: .7),
          ),
          const SizedBox(height: 14),
          Text(
            'Couldn’t load shared posts',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: pinit.PinitColors.cream,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => unawaited(onRetry()),
            style: FilledButton.styleFrom(
              backgroundColor: pinit.PinitColors.cream,
              foregroundColor: pinit.PinitColors.aubergine,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

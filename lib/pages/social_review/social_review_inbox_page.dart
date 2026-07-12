import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/pages/social_review/social_review_place_item.dart';
import 'package:login/pages/social_review/widgets/social_place_search_sheet.dart';
import 'package:login/providers/social_review_provider.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/widgets/feedback/app_feedback.dart';
import 'package:login/widgets/home/expanded_card/social_review_context.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:login/widgets/home/location_list_card.dart';
import 'package:provider/provider.dart';

/// Restaurant-first history and correction surface for shared TikToks/Reels.
class SocialReviewInboxPage extends StatefulWidget {
  const SocialReviewInboxPage({
    super.key,
    this.onOpenItem,
    this.initialFilter,
  });

  /// Test/embedding seam. Production callers use the standard expanded card.
  final ValueChanged<SocialReviewPlaceItem>? onOpenItem;
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
    List<SocialReviewPlaceItem> items,
  ) {
    return _selectedFilter ??
        (items.any((item) => item.needsChecking)
            ? SocialReviewInboxFilter.needsChecking
            : SocialReviewInboxFilter.recentlySaved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pinit.PinitColors.cream,
      body: SafeArea(
        child: Consumer<SocialReviewProvider>(
          builder: (context, provider, _) {
            final filter = _effectiveFilter(provider.placeItems);
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
                  attentionCount: provider.placeItems
                      .where((item) => item.needsChecking)
                      .length,
                  onSelected: (value) =>
                      setState(() => _selectedFilter = value),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildBody(provider, filter),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(
    SocialReviewProvider provider,
    SocialReviewInboxFilter filter,
  ) {
    if (provider.isLoading && !provider.hasLoaded) {
      return const _LoadingList();
    }
    if (provider.error != null && provider.placeItems.isEmpty) {
      return _ErrorView(onRetry: provider.refresh);
    }

    final visible = visibleSocialReviewPlaces(
      provider.placeItems,
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
        padding: const EdgeInsets.fromLTRB(16, 4, 20, 28),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final item = visible[index];
          final location = item.location;
          if (location == null) {
            return _UnresolvedPlaceCard(
              item: item,
              onFind: () => unawaited(_findOrCorrect(item)),
              onDismiss: () => unawaited(_dismiss(item)),
            );
          }
          return LocationListCard(
            key: ValueKey('social-place:${item.id}'),
            location: location,
            sourceLabel: _sourceLabel(item),
            statusLabel: item.statusLabel,
            statusIcon: item.needsChecking
                ? FeatherIcons.alertCircle
                : FeatherIcons.checkCircle,
            borderColor: item.needsChecking
                ? pinit.PinitColors.accent
                : pinit.PinitColors.aubergine,
            onTap: () => _openResolved(item),
          );
        },
      ),
    );
  }

  String _sourceLabel(SocialReviewPlaceItem item) {
    final creator = item.review.creatorHandle?.trim();
    if (creator == null || creator.isEmpty) return item.review.platformLabel;
    return '${item.review.platformLabel} · @$creator';
  }

  void _openResolved(SocialReviewPlaceItem item) {
    final override = widget.onOpenItem;
    if (override != null) {
      override(item);
      return;
    }
    final location = item.location;
    if (location == null) return;
    final socialLocation = location.copyWith(
      savedFrom: item.review.openUrl,
      savedMethod: item.review.platform,
      socialVideoUrl: item.review.openUrl,
      socialVideoCreatorHandle: item.review.creatorHandle,
    );
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, _, __) => ExpandedLocationCard(
        location: socialLocation,
        onClose: () => Navigator.of(dialogContext).pop(),
        socialReviewContext: SocialReviewContext(
          platform: item.review.platform,
          placeName: location.name,
          confidenceScore: item.place?.confidenceScore,
          confidenceTier: item.place?.confidenceTier,
          onConfirm:
              item.needsChecking ? () => unawaited(_confirm(item)) : null,
          onCorrect: () => unawaited(_findOrCorrect(item)),
          onRemove: item.recentlySaved ? () => unawaited(_remove(item)) : null,
        ),
      ),
      transitionBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  Future<void> _confirm(SocialReviewPlaceItem item) async {
    final place = item.place;
    if (place == null) return;
    final ok = await context.read<SocialReviewProvider>().savePlace(
          item.review,
          place,
        );
    if (!mounted) return;
    if (ok) {
      AppFeedback.showSuccess(context, message: '${item.displayName} saved');
    } else {
      await _showFailure('Couldn’t confirm this restaurant');
    }
  }

  Future<void> _remove(SocialReviewPlaceItem item) async {
    final place = item.place;
    if (place == null) return;
    final ok = await context.read<SocialReviewProvider>().discardPlace(
          item.review,
          place,
        );
    if (!mounted) return;
    if (ok) {
      AppFeedback.showSuccess(context, message: 'Removed from your saves');
    } else {
      await _showFailure('Couldn’t remove this restaurant');
    }
  }

  Future<void> _findOrCorrect(SocialReviewPlaceItem item) async {
    final picked = await SocialPlaceSearchSheet.show(
      context,
      title: item.place == null
          ? 'Which restaurant was it?'
          : 'Which place did they mean?',
    );
    if (picked == null || !mounted) return;
    final provider = context.read<SocialReviewProvider>();
    final ok = item.place == null
        ? await provider.addManualPlace(item.review, picked)
        : await provider.correctPlace(item.review, item.place!, picked);
    if (!mounted) return;
    if (ok) {
      AppFeedback.showSuccess(context, message: 'Saved ${picked.name}');
    } else {
      await _showFailure('Couldn’t save that restaurant');
    }
  }

  Future<void> _dismiss(SocialReviewPlaceItem item) async {
    final provider = context.read<SocialReviewProvider>();
    final place = item.place;
    if (place == null) {
      await provider.dismissPost(item.review);
      return;
    }
    final ok = await provider.discardPlace(item.review, place);
    if (!ok && mounted) await _showFailure('Couldn’t dismiss this match');
  }

  Future<void> _showFailure(String message) {
    return AppFeedback.showError(
      context,
      title: message,
      message: 'Please try again in a moment.',
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
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: onBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: pinit.PinitColors.creamSunk,
                shape: BoxShape.circle,
                border: Border.all(color: pinit.PinitColors.creamDeep),
              ),
              child: const Icon(
                FeatherIcons.chevronLeft,
                size: 19,
                color: pinit.PinitColors.aubergine,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Shared saves',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.brandFamily,
                fontFamilyFallback: AppTypography.brandFallbackFamilies,
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: pinit.PinitColors.aubergine,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        cursorColor: pinit.PinitColors.aubergine,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: pinit.PinitColors.aubergine,
        ),
        decoration: InputDecoration(
          hintText: 'Search restaurants',
          hintStyle: GoogleFonts.dmSans(
            fontSize: 14,
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
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: pinit.PinitColors.creamDeep,
              width: 1.5,
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
    required this.onSelected,
  });

  final SocialReviewInboxFilter selected;
  final int attentionCount;
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
    return InkWell(
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? pinit.PinitColors.cream.withValues(alpha: 0.18)
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
    );
  }
}

class _UnresolvedPlaceCard extends StatefulWidget {
  const _UnresolvedPlaceCard({
    required this.item,
    required this.onFind,
    required this.onDismiss,
  });

  final SocialReviewPlaceItem item;
  final VoidCallback onFind;
  final VoidCallback onDismiss;

  @override
  State<_UnresolvedPlaceCard> createState() => _UnresolvedPlaceCardState();
}

class _UnresolvedPlaceCardState extends State<_UnresolvedPlaceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AnimatedScale(
      scale: _pressed ? 0.975 : 1,
      duration: const Duration(milliseconds: 140),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 110,
        decoration: BoxDecoration(
          color: pinit.PinitColors.cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: pinit.PinitColors.accent, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: pinit.PinitColors.accent,
              blurRadius: 0,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onHighlightChanged: (value) => setState(() => _pressed = value),
          onTap: widget.onFind,
          child: Row(
            children: [
              Container(
                width: 104,
                alignment: Alignment.center,
                color: pinit.PinitColors.creamSunk,
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: pinit.PinitColors.aubergine,
                  ),
                  child: Icon(
                    item.review.platform == 'instagram'
                        ? FeatherIcons.instagram
                        : FeatherIcons.music,
                    color: pinit.PinitColors.cream,
                    size: 21,
                  ),
                ),
              ),
              Container(width: 1.5, color: pinit.PinitColors.accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: pinit.PinitColors.aubergine,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.place == null
                            ? 'Restaurant not identified'
                            : 'Check this match',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: pinit.PinitColors.mute,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _MiniAction(
                            label: 'Find restaurant',
                            onTap: widget.onFind,
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: widget.onDismiss,
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Dismiss',
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: pinit.PinitColors.mute,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: pinit.PinitColors.aubergine,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: pinit.PinitColors.cream,
          ),
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 20, 28),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        height: 110,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: pinit.PinitColors.creamSunk,
          borderRadius: BorderRadius.circular(10),
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
        ? 'No matching restaurants'
        : switch (filter) {
            SocialReviewInboxFilter.needsChecking => 'No shares need checking',
            SocialReviewInboxFilter.recentlySaved => 'No recent social saves',
            SocialReviewInboxFilter.all => 'No shared restaurants yet',
          };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              FeatherIcons.mapPin,
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
            'Couldn’t load shared restaurants',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: pinit.PinitColors.aubergine,
            ),
          ),
          const SizedBox(height: 12),
          _MiniAction(label: 'Retry', onTap: () => unawaited(onRetry())),
        ],
      ),
    );
  }
}

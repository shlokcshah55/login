import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:login/models/social_review_models.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/pages/social_review/widgets/social_place_search_sheet.dart';
import 'package:login/providers/navigation_provider.dart';
import 'package:login/providers/social_review_provider.dart';
import 'package:login/themes/app_typography.dart';

/// List-based review screen for ONE shared social post (TikTok / Reel).
///
/// Users share a post, the backend extracts place candidates, and this screen
/// lets them save / discard / correct each candidate, add places manually, or
/// resolve the whole post in one go.
class SocialPostReviewPage extends StatefulWidget {
  final String postId;
  final String source; // 'inbox' | 'notification' | 'deeplink'

  const SocialPostReviewPage({
    Key? key,
    required this.postId,
    this.source = 'inbox',
  }) : super(key: key);

  @override
  State<SocialPostReviewPage> createState() => _SocialPostReviewPageState();
}

class _SocialPostReviewPageState extends State<SocialPostReviewPage> {
  bool _requestedRefresh = false;
  bool _trackedShown = false;

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
        provider.refresh();
      }
      return;
    }
    if (!_trackedShown) {
      _trackedShown = true;
      provider.trackPostShown(item, source: widget.source);
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _openPost(SocialPostReviewItem item) async {
    final provider = context.read<SocialReviewProvider>();
    provider.trackOpenedOriginalPost(item);
    final uri = Uri.tryParse(item.openUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _manualAdd(SocialPostReviewItem item) async {
    final provider = context.read<SocialReviewProvider>();
    final picked =
        await SocialPlaceSearchSheet.show(context, title: 'Which place was it?');
    if (picked == null) return;
    final ok = await provider.addManualPlace(item, picked);
    if (!mounted) return;
    _snack(ok ? 'Saved ${picked.name}' : 'Could not add that place');
  }

  Future<void> _saveAll(SocialPostReviewItem item) async {
    final provider = context.read<SocialReviewProvider>();
    final n = await provider.saveAll(item);
    if (!mounted) return;
    _snack(n > 0 ? 'Saved $n place${n == 1 ? '' : 's'}' : 'All set');
    Navigator.of(context).pop();
  }

  Future<void> _discardAll(SocialPostReviewItem item) async {
    final provider = context.read<SocialReviewProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pinit.PinitColors.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Discard all places from this post?',
          style: AppTypography.headingSmall
              .copyWith(color: pinit.PinitColors.textPrimary),
        ),
        content: Text(
          'Places already saved from this post will be removed from your Eat List.',
          style: AppTypography.bodyMedium
              .copyWith(color: pinit.PinitColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.bodyMedium
                  .copyWith(color: pinit.PinitColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Discard all',
              style: AppTypography.bodyMedium.copyWith(
                color: pinit.PinitColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await provider.discardAll(item);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _reviewLater(SocialPostReviewItem item) async {
    final provider = context.read<SocialReviewProvider>();
    await provider.reviewLater(item);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _dismiss(SocialPostReviewItem item) async {
    final provider = context.read<SocialReviewProvider>();
    await provider.dismissPost(item);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: pinit.PinitColors.aubergine,
        ),
      );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SocialReviewProvider>();
    final item = provider.itemByPostId(widget.postId);

    Widget body;
    if (item == null) {
      body = provider.hasLoaded ? _buildAllDone() : _buildLoading();
    } else {
      body = _buildReview(item);
    }

    return Scaffold(
      backgroundColor: pinit.PinitColors.cream,
      body: SafeArea(child: body),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: pinit.PinitColors.aubergine),
    );
  }

  Widget _buildAllDone() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FeatherIcons.checkCircle,
              size: 44, color: pinit.PinitColors.teal),
          const SizedBox(height: 16),
          Text(
            'All done',
            style: AppTypography.headingSmall
                .copyWith(color: pinit.PinitColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "This post isn't waiting for review",
            style: AppTypography.bodyMedium
                .copyWith(color: pinit.PinitColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: 'Back',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildReview(SocialPostReviewItem item) {
    final showBottomBar = item.hasPlaces && !item.isProcessing;
    return Column(
      children: [
        _buildHeader(item),
        Expanded(child: _buildContent(item)),
        if (showBottomBar) _buildBottomBar(item),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(SocialPostReviewItem item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(FeatherIcons.chevronLeft,
                color: pinit.PinitColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          _PlatformChip(label: item.platformLabel),
          if (item.creatorHandle != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '@${item.creatorHandle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall
                    .copyWith(color: pinit.PinitColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Content ────────────────────────────────────────────────────────────────

  Widget _buildContent(SocialPostReviewItem item) {
    if (item.isProcessing) {
      return _buildProcessing();
    }
    if (item.isFailed || !item.hasPlaces) {
      return _buildEmptyOrFailed(item);
    }
    return _buildPlacesList(item);
  }

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: pinit.PinitColors.aubergine),
          const SizedBox(height: 18),
          Text(
            'Still reading this post…',
            style: AppTypography.bodyMedium
                .copyWith(color: pinit.PinitColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrFailed(SocialPostReviewItem item) {
    final copy = item.isFailed
        ? "We couldn't spot the place in this post"
        : 'No places found in this post';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        children: [
          _buildOpenPostRow(item),
          if ((item.title ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildTitle(item),
          ],
          if (item.topVibes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildVibes(item),
          ],
          const SizedBox(height: 40),
          const Icon(FeatherIcons.mapPin,
              size: 44, color: pinit.PinitColors.mute),
          const SizedBox(height: 16),
          Text(
            copy,
            style: AppTypography.bodyLarge
                .copyWith(color: pinit.PinitColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: 'Add place manually',
            icon: FeatherIcons.plus,
            onTap: () => _manualAdd(item),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _dismiss(item),
            child: Text(
              'Dismiss',
              style: AppTypography.bodyMedium
                  .copyWith(color: pinit.PinitColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesList(SocialPostReviewItem item) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildOpenPostRow(item),
        if ((item.title ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildTitle(item),
        ],
        if (item.topVibes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildVibes(item),
        ],
        const SizedBox(height: 16),
        for (final place in item.places) ...[
          _buildPlaceRow(item, place),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        Center(
          child: TextButton.icon(
            onPressed: () => _manualAdd(item),
            icon: const Icon(FeatherIcons.plus,
                size: 16, color: pinit.PinitColors.aubergine),
            label: Text(
              'Add another place',
              style: AppTypography.bodyMedium.copyWith(
                color: pinit.PinitColors.aubergine,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOpenPostRow(SocialPostReviewItem item) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => _openPost(item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: pinit.PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: pinit.PinitColors.creamDeep,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(FeatherIcons.externalLink,
                  size: 14, color: pinit.PinitColors.aubergine),
              const SizedBox(width: 8),
              Text(
                'Open post',
                style: AppTypography.bodySmall.copyWith(
                  color: pinit.PinitColors.aubergine,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(SocialPostReviewItem item) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        item.title!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.titleMedium
            .copyWith(color: pinit.PinitColors.textPrimary),
      ),
    );
  }

  Widget _buildVibes(SocialPostReviewItem item) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final vibe in item.topVibes) _VibeChip(label: vibe),
        ],
      ),
    );
  }

  // ── Place row ────────────────────────────────────────────────────────────

  Widget _buildPlaceRow(SocialPostReviewItem item, SocialPostPlace place) {
    final action = item.placeActions[place.id];

    // Terminal states other than "saved" are fully resolved — static card.
    if (action == SocialPlaceAction.discarded ||
        action == SocialPlaceAction.corrected ||
        action == SocialPlaceAction.manualAdded) {
      return _PlaceCard(
        place: place,
        action: action,
        onTap: () => _openDetailSheet(item, place),
      );
    }

    // Already auto-saved: still swipeable, just discard-only (there's
    // nothing left to "save").
    if (action == SocialPlaceAction.saved) {
      final discardBg = _swipeBg(
        color: pinit.PinitColors.error,
        icon: FeatherIcons.x,
        label: 'Discard',
        alignment: Alignment.centerRight,
      );
      return Dismissible(
        key: ValueKey(place.id),
        direction: DismissDirection.endToStart,
        background: discardBg,
        secondaryBackground: discardBg,
        confirmDismiss: (_) async {
          final provider = context.read<SocialReviewProvider>();
          final ok = await provider.discardPlace(item, place);
          if (!ok && mounted) _snack('Couldn\'t discard — try again');
          return ok;
        },
        child: _PlaceCard(
          place: place,
          action: action,
          onTap: () => _openDetailSheet(item, place),
        ),
      );
    }

    // Not yet resolved (e.g. low-confidence, no location match) — swipe
    // right to save, left to discard.
    return Dismissible(
      key: ValueKey(place.id),
      background: _swipeBg(
        color: pinit.PinitColors.teal,
        icon: FeatherIcons.bookmark,
        label: 'Save',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _swipeBg(
        color: pinit.PinitColors.error,
        icon: FeatherIcons.x,
        label: 'Discard',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        final provider = context.read<SocialReviewProvider>();
        final bool ok;
        if (direction == DismissDirection.startToEnd) {
          ok = await provider.savePlace(item, place);
        } else {
          ok = await provider.discardPlace(item, place);
        }
        if (!ok && mounted) _snack('Couldn\'t save — try again');
        return ok;
      },
      child: _PlaceCard(
        place: place,
        action: null,
        onTap: () => _openDetailSheet(item, place),
      ),
    );
  }

  Widget _swipeBg({
    required Color color,
    required IconData icon,
    required String label,
    required Alignment alignment,
  }) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLeft) ...[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!isLeft) ...[
            const SizedBox(width: 8),
            Icon(icon, color: Colors.white, size: 18),
          ],
        ],
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar(SocialPostReviewItem item) {
    return Container(
      decoration: const BoxDecoration(
        color: pinit.PinitColors.cream,
        border: Border(
          top: BorderSide(color: pinit.PinitColors.creamDeep, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _PrimaryButton(
                  label: 'Save all',
                  icon: FeatherIcons.bookmark,
                  onTap: () => _saveAll(item),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OutlinedButton(
                  label: 'Discard all',
                  onTap: () => _discardAll(item),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () => _reviewLater(item),
            child: Text(
              'Review later',
              style: AppTypography.bodyMedium
                  .copyWith(color: pinit.PinitColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Detail sheet ─────────────────────────────────────────────────────────

  void _openDetailSheet(SocialPostReviewItem item, SocialPostPlace place) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaceDetailSheet(
        item: item,
        place: place,
        onSave: () async {
          final provider = context.read<SocialReviewProvider>();
          await provider.savePlace(item, place);
        },
        onDiscard: () async {
          final provider = context.read<SocialReviewProvider>();
          await provider.discardPlace(item, place);
        },
        onViewOnMap: () async {
          final provider = context.read<SocialReviewProvider>();
          final loc = await provider.fetchLocation(place.locationId!);
          if (!mounted) return;
          if (loc != null) {
            context.read<NavigationProvider>().navigateToLocationOnMap(loc);
            Navigator.of(context).popUntil((r) => r.isFirst);
          }
        },
        onCorrect: () async {
          final provider = context.read<SocialReviewProvider>();
          final picked = await SocialPlaceSearchSheet.show(
            context,
            title: 'Which place did they mean?',
          );
          if (picked == null) return;
          await provider.correctPlace(item, place, picked);
          if (!mounted) return;
          _snack('Saved ${picked.name} instead');
        },
      ),
    );
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _PlatformChip extends StatelessWidget {
  final String label;
  const _PlatformChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: pinit.PinitColors.aubergine,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: pinit.PinitColors.cream,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VibeChip extends StatelessWidget {
  final String label;
  const _VibeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: pinit.PinitColors.aubergine,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: pinit.PinitColors.aubergine,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: pinit.PinitColors.cream),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: pinit.PinitColors.cream,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlinedButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pinit.PinitColors.error, width: 1.4),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: pinit.PinitColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final SocialPostPlace place;
  final SocialPlaceAction? action;
  final VoidCallback onTap;

  const _PlaceCard({
    required this.place,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pinit.PinitColors.creamDeep, width: 1),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: pinit.PinitColors.creamSunk,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(FeatherIcons.mapPin,
                    size: 18, color: pinit.PinitColors.aubergineSoft),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyLarge.copyWith(
                        color: pinit.PinitColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((place.address ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          place.address!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                              color: pinit.PinitColors.textSecondary),
                        ),
                      ),
                    if (place.isLowConfidence)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _AmberChip(),
                      ),
                    if (place.keyDishNames.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '🍽 ${place.keyDishNames.take(2).join(' · ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                              color: pinit.PinitColors.textMuted),
                        ),
                      ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 8),
                _StatusChip(action: action!),
              ],
            ],
          ),
        ),
      ),
    );

    // Only dim fully-resolved rows — a "saved" row is still swipeable and
    // should read as active content, not a completed/faded one.
    if (action == null || action == SocialPlaceAction.saved) return card;
    return Opacity(opacity: 0.6, child: card);
  }
}

class _AmberChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pinit.PinitColors.warning.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(FeatherIcons.alertCircle,
              size: 12, color: pinit.PinitColors.warning),
          const SizedBox(width: 4),
          Text(
            'Not sure — tap to check',
            style: AppTypography.bodySmall.copyWith(
              color: pinit.PinitColors.warning,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final SocialPlaceAction action;
  const _StatusChip({required this.action});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    switch (action) {
      case SocialPlaceAction.saved:
        label = 'Saved';
        color = pinit.PinitColors.teal;
        break;
      case SocialPlaceAction.discarded:
        label = 'Discarded';
        color = pinit.PinitColors.mute;
        break;
      case SocialPlaceAction.corrected:
        label = 'Corrected';
        color = pinit.PinitColors.aubergine;
        break;
      case SocialPlaceAction.manualAdded:
        label = 'Added';
        color = pinit.PinitColors.teal;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PlaceDetailSheet extends StatelessWidget {
  final SocialPostReviewItem item;
  final SocialPostPlace place;
  final Future<void> Function() onSave;
  final Future<void> Function() onDiscard;
  final Future<void> Function() onViewOnMap;
  final Future<void> Function() onCorrect;

  const _PlaceDetailSheet({
    required this.item,
    required this.place,
    required this.onSave,
    required this.onDiscard,
    required this.onViewOnMap,
    required this.onCorrect,
  });

  String get _confidenceLabel {
    switch (place.confidenceTier) {
      case 'high':
        return 'High confidence match';
      case 'medium':
        return 'Medium confidence match';
      case 'low':
        return 'Low confidence match';
      default:
        return 'Match';
    }
  }

  List<Map<String, dynamic>> get _keyDishes {
    final dishes = place.extractedContext['key_dishes'];
    if (dishes is! List) return const [];
    return dishes.whereType<Map<String, dynamic>>().toList();
  }

  List<String> get _specialOffers {
    final offers = place.extractedContext['special_offers'];
    if (offers is! List) return const [];
    return offers
        .whereType<Map<String, dynamic>>()
        .map((o) => o['offer']?.toString() ?? '')
        .where((o) => o.isNotEmpty)
        .toList();
  }

  List<String> get _vibeSignals {
    final signals = place.extractedContext['vibe_signals'];
    if (signals is! Map) return const [];
    return signals.keys
        .map((k) => k.toString().replaceAll('_', ' '))
        .where((k) => k.isNotEmpty)
        .toList();
  }

  bool get _hasAnyContext =>
      _keyDishes.isNotEmpty ||
      (place.creatorNotes != null) ||
      _specialOffers.isNotEmpty ||
      _vibeSignals.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: pinit.PinitColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: pinit.PinitColors.mute.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: AppTypography.headingSmall
                          .copyWith(color: pinit.PinitColors.textPrimary),
                    ),
                    if ((place.address ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        place.address!,
                        style: AppTypography.bodyMedium.copyWith(
                            color: pinit.PinitColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _confidenceLabel,
                      style: AppTypography.bodySmall.copyWith(
                        color: place.isLowConfidence
                            ? pinit.PinitColors.warning
                            : pinit.PinitColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_hasAnyContext)
                      Text(
                        'No extra context from the post',
                        style: AppTypography.bodyMedium.copyWith(
                            color: pinit.PinitColors.textMuted),
                      )
                    else ...[
                      if (_keyDishes.isNotEmpty) ...[
                        _sectionHeader('Key dishes'),
                        const SizedBox(height: 8),
                        for (final dish in _keyDishes)
                          _buildDish(dish),
                        const SizedBox(height: 8),
                      ],
                      if (place.creatorNotes != null) ...[
                        _sectionHeader('Creator notes'),
                        const SizedBox(height: 8),
                        Text(
                          place.creatorNotes!,
                          style: AppTypography.bodyMedium.copyWith(
                              color: pinit.PinitColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_specialOffers.isNotEmpty) ...[
                        _sectionHeader('Special offers'),
                        const SizedBox(height: 8),
                        for (final offer in _specialOffers)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $offer',
                              style: AppTypography.bodyMedium.copyWith(
                                  color: pinit.PinitColors.textSecondary),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                      if (_vibeSignals.isNotEmpty) ...[
                        _sectionHeader('Vibes'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final vibe in _vibeSignals)
                              _VibeChip(label: vibe),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            _buildActions(context),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: AppTypography.titleSmall
          .copyWith(color: pinit.PinitColors.textPrimary),
    );
  }

  Widget _buildDish(Map<String, dynamic> dish) {
    final name = dish['name']?.toString() ?? '';
    final description = dish['description']?.toString().trim();
    if (name.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🍽 $name',
            style: AppTypography.bodyMedium.copyWith(
              color: pinit.PinitColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (description != null && description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 20),
              child: Text(
                description,
                style: AppTypography.bodySmall.copyWith(
                    color: pinit.PinitColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _PrimaryButton(
                  label: 'Save place',
                  icon: FeatherIcons.bookmark,
                  onTap: () async {
                    Navigator.of(context).pop();
                    await onSave();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OutlinedButton(
                  label: 'Discard',
                  onTap: () async {
                    Navigator.of(context).pop();
                    await onDiscard();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (place.locationId != null)
            TextButton.icon(
              onPressed: () => onViewOnMap(),
              icon: const Icon(FeatherIcons.map,
                  size: 16, color: pinit.PinitColors.aubergine),
              label: Text(
                'View on map',
                style: AppTypography.bodyMedium.copyWith(
                  color: pinit.PinitColors.aubergine,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await onCorrect();
            },
            child: Text(
              'Wrong place? Correct it',
              style: AppTypography.bodyMedium
                  .copyWith(color: pinit.PinitColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

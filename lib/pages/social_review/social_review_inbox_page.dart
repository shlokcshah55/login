import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/social_review_models.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/pages/social_review/social_post_review_page.dart';
import 'package:login/providers/social_review_provider.dart';
import 'package:login/themes/app_typography.dart';
import 'package:provider/provider.dart';

/// Full-screen inbox listing all pending and snoozed social post reviews.
class SocialReviewInboxPage extends StatefulWidget {
  const SocialReviewInboxPage({Key? key}) : super(key: key);

  @override
  State<SocialReviewInboxPage> createState() => _SocialReviewInboxPageState();
}

class _SocialReviewInboxPageState extends State<SocialReviewInboxPage>
    with SingleTickerProviderStateMixin {
  // Single controller drives the staggered entrance for the whole page.
  late final AnimationController _entrance;

  // Only run the entrance stagger on first load — later provider notifies
  // (refresh / review actions) must not make the list feel jumpy.
  bool _entrancePlayed = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _playEntranceOnce() {
    if (_entrancePlayed) return;
    _entrancePlayed = true;
    // Kick off after the current frame so the list is laid out first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entrance.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pinit.PinitColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: pinit.PinitColors.creamSunk,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0x2641133D),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        FeatherIcons.chevronLeft,
                        size: 18,
                        color: pinit.PinitColors.aubergine,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Page title — Rova display, mirrors CarouselListPage app bar.
                  Text(
                    'Shared posts',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTypography.brandFamily,
                      fontFamilyFallback: AppTypography.brandFallbackFamilies,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: pinit.PinitColors.aubergine,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: Consumer<SocialReviewProvider>(
                builder: (context, provider, _) {
                  final Widget child;

                  // Loading state (first load only)
                  if (provider.isLoading && !provider.hasLoaded) {
                    child = const _StateContainer(
                      key: ValueKey('loading'),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: pinit.PinitColors.aubergine,
                        ),
                      ),
                    );
                  } else if (provider.error != null) {
                    // Error state
                    child = _StateContainer(
                      key: const ValueKey('error'),
                      child: _ErrorView(onRetry: provider.refresh),
                    );
                  } else {
                    final pending = provider.pendingItems;
                    final snoozed = provider.snoozedItems;

                    if (pending.isEmpty && snoozed.isEmpty) {
                      // Empty state
                      child = const _StateContainer(
                        key: ValueKey('empty'),
                        child: _EmptyView(),
                      );
                    } else {
                      // List of posts — entrance stagger runs on first paint.
                      _playEntranceOnce();
                      child = _InboxList(
                        key: const ValueKey('list'),
                        pending: pending,
                        snoozed: snoozed,
                        onRefresh: provider.refresh,
                        entrance: _entrance,
                      );
                    }
                  }

                  // Cross-fade between loading / error / empty / list states.
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: child,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Inbox list ──────────────────────────────────────────────────────────────

class _InboxList extends StatelessWidget {
  final List<SocialPostReviewItem> pending;
  final List<SocialPostReviewItem> snoozed;
  final Future<void> Function() onRefresh;
  final Animation<double> entrance;

  const _InboxList({
    Key? key,
    required this.pending,
    required this.snoozed,
    required this.onRefresh,
    required this.entrance,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Build a flat list of animated rows so the stagger index is continuous
    // across both sections.
    final children = <Widget>[];
    var index = 0;

    if (pending.isNotEmpty) {
      children.add(
        _StaggeredItem(
          index: index++,
          animation: entrance,
          child: const _SectionLabel(label: 'To review'),
        ),
      );
      children.add(const SizedBox(height: 10));
      for (final item in pending) {
        children.add(
          _StaggeredItem(
            index: index++,
            animation: entrance,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PostCard(item: item),
            ),
          ),
        );
      }
    }

    if (snoozed.isNotEmpty) {
      children.add(const SizedBox(height: 8));
      children.add(
        _StaggeredItem(
          index: index++,
          animation: entrance,
          child: const _SectionLabel(label: 'Review later'),
        ),
      );
      children.add(const SizedBox(height: 10));
      for (final item in snoozed) {
        children.add(
          _StaggeredItem(
            index: index++,
            animation: entrance,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PostCard(item: item),
            ),
          ),
        );
      }
    }

    return RefreshIndicator(
      color: pinit.PinitColors.aubergine,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: children,
      ),
    );
  }
}

/// Fade + slight upward slide, staggered by [index]. Once the shared
/// controller has completed the row is fully settled, so refreshes that
/// reuse the same completed controller render instantly (no re-jump).
class _StaggeredItem extends StatelessWidget {
  final int index;
  final Animation<double> animation;
  final Widget child;

  const _StaggeredItem({
    required this.index,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // ~50ms stagger per index, each row eases over ~55% of the timeline.
    const total = 460.0;
    final start = (index * 50) / total;
    final begin = start.clamp(0.0, 1.0);
    final end = (begin + 0.55).clamp(0.0, 1.0);

    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, inner) {
        final t = curved.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: inner,
          ),
        );
      },
      child: child,
    );
  }
}

// ── Internal widgets ─────────────────────────────────────────────────────────

/// Fills available height so AnimatedSwitcher can cross-fade full-screen
/// states without layout jumps.
class _StateContainer extends StatelessWidget {
  final Widget child;
  const _StateContainer({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: child);
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    // Mirrors CarouselListPage's magic-search section header.
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 0),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: pinit.PinitColors.aubergine,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              FeatherIcons.alertCircle,
              size: 40,
              color: pinit.PinitColors.mute,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load your shared posts',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: pinit.PinitColors.aubergine,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: pinit.PinitColors.aubergine,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: pinit.PinitColors.black,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: pinit.PinitColors.black,
                      blurRadius: 0,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Retry',
                  style: AppTypography.sans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: pinit.PinitColors.cream,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              FeatherIcons.share2,
              size: 40,
              color: pinit.PinitColors.mute,
            ),
            const SizedBox(height: 16),
            Text(
              'No posts to review',
              style: AppTypography.headingSmall.copyWith(
                color: pinit.PinitColors.aubergine,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share a TikTok or Reel to Pinit and it shows up here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: pinit.PinitColors.mute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single shared-post row, restyled to the carousel "see all" idiom:
/// platform tile on the left (thumbnail slot), a vertical divider in the
/// border colour, then a creamSunk top strip + body on the right.
class _PostCard extends StatefulWidget {
  final SocialPostReviewItem item;
  const _PostCard({required this.item});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _pressed = false;

  SocialPostReviewItem get item => widget.item;

  bool get _isInstagram =>
      item.platform == 'instagram' || item.platformLabel == 'Reel';

  // Failed posts get the accent treatment, mirroring the wavy accent in
  // the reference cards — draws the eye to the row that needs a manual place.
  Color get _borderColor =>
      item.isFailed ? pinit.PinitColors.accent : pinit.PinitColors.aubergine;

  String get _titleText {
    if (item.creatorHandle != null && item.creatorHandle!.isNotEmpty) {
      return '@${item.creatorHandle}';
    }
    if (item.title != null && item.title!.isNotEmpty) {
      return item.title!;
    }
    return 'Shared post';
  }

  String get _subtitleText {
    final savedCount = item.places
        .where((p) => item.placeActions[p.id] == SocialPlaceAction.saved)
        .length;
    if (item.isProcessing) return 'Still processing…';
    if (item.isFailed) return 'Needs a manual place';
    if (savedCount > 0) {
      return '$savedCount place${savedCount == 1 ? '' : 's'} saved — review anytime';
    }
    if (item.hasPlaces) {
      return '${item.places.length} place${item.places.length == 1 ? '' : 's'} found — not sure which';
    }
    return 'No places found — add one';
  }

  /// Up to 2 place names previewed as secondary lines, in the same muted
  /// style CarouselListPage uses for summary text.
  List<String> get _placePreview => item.places
      .map((p) => p.name.trim())
      .where((n) => n.isNotEmpty)
      .take(2)
      .toList();

  String get _relativeTime {
    final diff = DateTime.now().difference(item.sharedAt);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  String get _topStripLabel => item.platformLabel.toUpperCase();

  void _open() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SocialPostReviewPage(
          postId: item.postId,
          source: 'inbox',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _borderColor;
    final preview = _placePreview;

    // Press feedback — scale-down like ShortlistPill (AnimatedScale ~0.97).
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _open,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: pinit.PinitColors.cream,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: borderColor,
                blurRadius: 0,
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left: platform tile (thumbnail slot) ──
                SizedBox(
                  width: 100,
                  child: _PlatformTile(
                    isInstagram: _isInstagram,
                    borderColor: borderColor,
                  ),
                ),

                // ── Vertical divider ──
                Container(width: 1.5, color: borderColor),

                // ── Right: info column ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Top label strip: platform + relative time.
                      Container(
                        color: pinit.PinitColors.creamSunk,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isInstagram
                                  ? FeatherIcons.instagram
                                  : FeatherIcons.music,
                              size: 11,
                              color: pinit.PinitColors.mute,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _topStripLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: pinit.PinitColors.mute,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const Icon(
                              FeatherIcons.clock,
                              size: 11,
                              color: pinit.PinitColors.mute,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _relativeTime,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: pinit.PinitColors.mute,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Body
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              // Title (creator handle / title)
                              Text(
                                _titleText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: pinit.PinitColors.aubergine,
                                  height: 1.15,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              // Status subtitle
                              Text(
                                _subtitleText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: item.isFailed
                                      ? pinit.PinitColors.accent
                                      : pinit.PinitColors.mute,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                              ),
                              const Spacer(),
                              // Place-name pills (secondary line preview)
                              if (preview.isNotEmpty)
                                SizedBox(
                                  height: 20,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    children: [
                                      for (final name in preview)
                                        _PinitPill(
                                          label: name,
                                          icon: FeatherIcons.mapPin,
                                        ),
                                    ],
                                  ),
                                )
                              else
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Icon(
                                    FeatherIcons.chevronRight,
                                    size: 16,
                                    color: pinit.PinitColors.mute,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
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

/// The visual anchor that sits in the thumbnail slot: an aubergine/cream
/// platform glyph (TikTok music note / Instagram) with a soft scrim, echoing
/// the reference card's image column.
class _PlatformTile extends StatelessWidget {
  final bool isInstagram;
  final Color borderColor;

  const _PlatformTile({
    required this.isInstagram,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: pinit.PinitColors.creamSunk),
        // Subtle bottom-up scrim, matching the reference image column.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x14000000)],
                stops: [0.55, 1.0],
              ),
            ),
          ),
        ),
        // Central glyph inside a bordered aubergine circle.
        Center(
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: pinit.PinitColors.aubergine,
              shape: BoxShape.circle,
              border: Border.all(
                color: pinit.PinitColors.cream,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              isInstagram ? FeatherIcons.instagram : FeatherIcons.music,
              size: 20,
              color: pinit.PinitColors.cream,
            ),
          ),
        ),
      ],
    );
  }
}

/// Universal pinit pill — same treatment as CarouselListPage / shortlist card.
class _PinitPill extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _PinitPill({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: pinit.PinitColors.creamDeep, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: pinit.PinitColors.aubergine),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: pinit.PinitColors.aubergine,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.4,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

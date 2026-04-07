import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/widgets/mode_toggle.dart';
import 'package:login/providers/shortlist_provider.dart';
import 'package:login/themes/app_typography.dart';
import 'package:provider/provider.dart';

/// Swipeable shortlist carousel with a final "Keep exploring" exit card.
class ShortlistCarouselSheet extends StatefulWidget {
  final List<LocationModel> items;
  final HomeMode currentMode;
  final ValueChanged<HomeMode> onReturnToMode;

  const ShortlistCarouselSheet({
    Key? key,
    required this.items,
    required this.currentMode,
    required this.onReturnToMode,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required HomeMode currentMode,
    required ValueChanged<HomeMode> onReturnToMode,
  }) {
    final snapshot = List<LocationModel>.from(
      context.read<ShortlistProvider>().items,
    );

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ShortlistCarouselSheet(
        items: snapshot,
        currentMode: currentMode,
        onReturnToMode: onReturnToMode,
      ),
    );
  }

  @override
  State<ShortlistCarouselSheet> createState() => _ShortlistCarouselSheetState();
}

class _ShortlistCarouselSheetState extends State<ShortlistCarouselSheet> {
  late final PageController _controller;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _exitToMode() async {
    if (_isClosing) return;
    _isClosing = true;

    widget.onReturnToMode(widget.currentMode);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handlePageChanged(int index) {
    if (index == widget.items.length) {
      // Small delay keeps the transition feeling intentional before dismissing.
      unawaited(
          Future<void>.delayed(const Duration(milliseconds: 240), _exitToMode));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1229) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(Icons.playlist_add_check_rounded,
                    color: colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Shortlist',
                  style: AppTypography.brand(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 255,
            child: widget.items.isEmpty
                ? _EmptyState(isDark: isDark)
                : PageView.builder(
                    controller: _controller,
                    itemCount: widget.items.length + 1,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    onPageChanged: _handlePageChanged,
                    itemBuilder: (context, index) {
                      if (index == widget.items.length) {
                        return _KeepExploringCard(
                          isDark: isDark,
                          mode: widget.currentMode,
                          onTap: _exitToMode,
                        );
                      }
                      return _ShortlistCarouselCard(
                        location: widget.items[index],
                        isDark: isDark,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ShortlistCarouselCard extends StatelessWidget {
  final LocationModel location;
  final bool isDark;

  const _ShortlistCarouselCard({
    required this.location,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = location.imageUrl ?? location.photoReference;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: isDark ? const Color(0xFF271A3D) : const Color(0xFFF6F0FB),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: isDark ? Colors.white10 : Colors.grey[300],
                        alignment: Alignment.center,
                        child: Text(
                          location.emoji ?? '📍',
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    )
                  : Container(
                      color: isDark ? Colors.white10 : Colors.grey[300],
                      alignment: Alignment.center,
                      child: Text(
                        location.emoji ?? '📍',
                        style: const TextStyle(fontSize: 40),
                      ),
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.05),
                      Colors.black.withValues(alpha: 0.62),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.brand(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    location.cuisine ??
                        location.vicinity ??
                        'In your shortlist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.sans(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepExploringCard extends StatelessWidget {
  final bool isDark;
  final HomeMode mode;
  final VoidCallback onTap;

  const _KeepExploringCard({
    required this.isDark,
    required this.mode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final modeLabel = mode == HomeMode.you ? 'You' : 'Explore';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF452364), Color(0xFF2B173F)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.explore_rounded,
                  color: Colors.white,
                  size: 34,
                ),
                const SizedBox(height: 10),
                Text(
                  'Keep exploring',
                  style: AppTypography.brand(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Back to $modeLabel mode',
                  style: AppTypography.sans(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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

class _EmptyState extends StatelessWidget {
  final bool isDark;

  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 40,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            'No places shortlisted yet',
            style: AppTypography.sans(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/home_view_model.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/widgets/home/expanded_location_card.dart';

/// Step 2 of Quick Picks — Tinder-style deck of nearby recommendations.
///
/// • Swipe right → add to shortlist (and save) + "Enjoy ___" banner
/// • Swipe left  → move to the next top recommendation
/// • Tap a card  → opens the full [ExpandedLocationCard]
class QuickPicksDeckPage extends StatefulWidget {
  const QuickPicksDeckPage({
    super.key,
    required this.viewModel,
    required this.locations,
    required this.walkingMinutes,
  });

  final HomeViewModel viewModel;
  final List<LocationModel> locations;
  final double walkingMinutes;

  @override
  State<QuickPicksDeckPage> createState() => _QuickPicksDeckPageState();
}

class _QuickPicksDeckPageState extends State<QuickPicksDeckPage>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  Offset _drag = Offset.zero;
  bool _dragging = false;

  late AnimationController _flyController;
  Animation<Offset>? _flyAnim;
  bool _flyingOut = false;

  // Pending banner state — rebuilt on each right swipe so the copy
  // reflects the card that was just liked.
  String? _lastLikedName;

  @override
  void initState() {
    super.initState();
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _flyController.dispose();
    super.dispose();
  }

  // ── Gesture handlers ────────────────────────────────────────

  void _onPanStart(DragStartDetails _) {
    if (_flyingOut) return;
    setState(() => _dragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_flyingOut) return;
    setState(() => _drag += details.delta);
  }

  void _onPanEnd(DragEndDetails _) {
    if (!_dragging || _flyingOut) return;
    final double w = MediaQuery.of(context).size.width;
    final double threshold = w * 0.28;

    if (_drag.dx.abs() > threshold) {
      _completeSwipe(_drag.dx > 0);
    } else {
      setState(() {
        _drag = Offset.zero;
        _dragging = false;
      });
    }
  }

  void _completeSwipe(bool liked) {
    final double w = MediaQuery.of(context).size.width;
    final Offset end = Offset(
      liked ? w * 1.4 : -w * 1.4,
      _drag.dy - 80,
    );
    _flyAnim = Tween<Offset>(begin: _drag, end: end).animate(
      CurvedAnimation(parent: _flyController, curve: Curves.easeInCubic),
    );
    setState(() => _flyingOut = true);

    _flyController.forward(from: 0).then((_) {
      if (!mounted) return;
      final LocationModel swiped = widget.locations[_index];

      if (liked) {
        widget.viewModel.saveQuickPick(swiped);
        _lastLikedName = swiped.name;
        _showEnjoyBanner(swiped.name);
      }

      setState(() {
        _index++;
        _drag = Offset.zero;
        _dragging = false;
        _flyingOut = false;
        _flyController.reset();
      });
    });
  }

  void _showEnjoyBanner(String name) {
    // Success snackbars are intentionally disabled.
    return;
  }

  void _openExpandedCard(LocationModel location) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel:
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, _, __) => ExpandedLocationCard(
        location: location,
        onClose: () => Navigator.of(ctx).pop(),
      ),
      transitionBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool finished = _index >= widget.locations.length;

    return Scaffold(
      backgroundColor: PinitColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              // ── Header ────────────────────────────────────
              Row(
                children: [
                  _CircleIconButton(
                    icon: FeatherIcons.x,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      Text(
                        'QUICK PICKS',
                        style: AppTypography.sans(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: PinitColors.aubergineSoft,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.walkingMinutes.round()} min walk',
                        style: AppTypography.sans(
                          fontSize: 11,
                          color: PinitColors.mute,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _DeckCounter(
                    current: math.min(_index + 1, widget.locations.length),
                    total: widget.locations.length,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Deck ──────────────────────────────────────
              Expanded(
                child: finished
                    ? _EmptyState(
                        lastLikedName: _lastLikedName,
                        onDone: () => Navigator.of(context).pop(),
                      )
                    : _buildDeck(),
              ),

              if (!finished) ...[
                const SizedBox(height: 12),
                _ActionRow(
                  onPass: _flyingOut
                      ? null
                      : () {
                          setState(() {
                            _drag = const Offset(-40, 0);
                            _dragging = true;
                          });
                          _completeSwipe(false);
                        },
                  onTap: () => _openExpandedCard(widget.locations[_index]),
                  onLike: _flyingOut
                      ? null
                      : () {
                          setState(() {
                            _drag = const Offset(40, 0);
                            _dragging = true;
                          });
                          _completeSwipe(true);
                        },
                ),
                const SizedBox(height: 6),
                Text(
                  'Swipe • Tap for details',
                  style: AppTypography.sans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PinitColors.mute,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeck() {
    final LocationModel current = widget.locations[_index];
    final LocationModel? next = _index + 1 < widget.locations.length
        ? widget.locations[_index + 1]
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Back-of-deck preview
            if (next != null)
              Positioned.fill(
                child: Transform.translate(
                  offset: const Offset(0, 14),
                  child: Transform.scale(
                    scale: 0.94,
                    child: IgnorePointer(
                      child: _QuickPickCard(
                        location: next,
                        dimmed: true,
                      ),
                    ),
                  ),
                ),
              ),

            // Active card
            AnimatedBuilder(
              animation: _flyController,
              builder: (context, child) {
                final Offset offset = _flyingOut && _flyAnim != null
                    ? _flyAnim!.value
                    : _drag;
                final double rotation = offset.dx / 1400;

                return Transform.translate(
                  offset: offset,
                  child: Transform.rotate(
                    angle: rotation,
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                onTap: _flyingOut ? null : () => _openExpandedCard(current),
                child: Stack(
                  children: [
                    _QuickPickCard(location: current),
                    // Like / pass stamps
                    if (_drag.dx > 20)
                      Positioned(
                        top: 28,
                        left: 28,
                        child: _Stamp(
                          label: 'SAVE',
                          color: PinitColors.success,
                          angle: -0.2,
                          opacity: (_drag.dx / 120).clamp(0, 1),
                        ),
                      ),
                    if (_drag.dx < -20)
                      Positioned(
                        top: 28,
                        right: 28,
                        child: _Stamp(
                          label: 'PASS',
                          color: PinitColors.accent,
                          angle: 0.2,
                          opacity: (_drag.dx.abs() / 120).clamp(0, 1),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────────────
//  Card
// ───────────────────────────────────────────────────────────────

class _QuickPickCard extends StatelessWidget {
  const _QuickPickCard({
    required this.location,
    this.dimmed = false,
  });

  final LocationModel location;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final String? photoUrl = location.imageUrl;

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: PinitColors.cream,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: PinitColors.aubergine,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: PinitColors.aubergine,
              blurRadius: 0,
              offset: Offset(4, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Hero image ──
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (photoUrl != null && photoUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      placeholder: (c, _) => Container(
                        color: PinitColors.creamSunk,
                      ),
                      errorWidget: (c, _, __) => Container(
                        color: PinitColors.creamSunk,
                        child: const Center(
                          child: Icon(
                            FeatherIcons.image,
                            color: PinitColors.mute,
                            size: 36,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      color: PinitColors.creamSunk,
                      child: const Center(
                        child: Icon(
                          FeatherIcons.coffee,
                          color: PinitColors.mute,
                          size: 48,
                        ),
                      ),
                    ),
                  // Bottom ink gradient so the chips read cleanly
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            PinitColors.aubergine.withValues(alpha: 0.55),
                          ],
                          stops: const [0.55, 1],
                        ),
                      ),
                    ),
                  ),
                  // Floating chips (rating + price)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (location.rating != null)
                          _FloatingChip(
                            icon: FeatherIcons.star,
                            label: location.rating!.toStringAsFixed(1),
                          ),
                        if (location.rating != null &&
                            location.priceLevel != null)
                          const SizedBox(width: 6),
                        if (location.priceLevel != null)
                          _FloatingChip(
                            label: '\$' * location.priceLevel!.clamp(1, 4),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Details slab ──
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                color: PinitColors.cream,
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.brand(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: PinitColors.aubergine,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (location.vicinity != null &&
                            location.vicinity!.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                FeatherIcons.mapPin,
                                size: 13,
                                color: PinitColors.mute,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  location.vicinity!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.sans(
                                    fontSize: 12,
                                    color: PinitColors.mute,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (location.cuisine != null &&
                        location.cuisine!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: PinitColors.creamSunk,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: PinitColors.creamDeep,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          location.cuisine!.toUpperCase(),
                          style: AppTypography.sans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: PinitColors.aubergine,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
//  Supporting widgets
// ───────────────────────────────────────────────────────────────

class _FloatingChip extends StatelessWidget {
  const _FloatingChip({this.icon, required this.label});
  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PinitColors.cream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: PinitColors.aubergine,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: PinitColors.aubergine),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.sans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: PinitColors.aubergine,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.label,
    required this.color,
    required this.angle,
    required this.opacity,
  });

  final String label;
  final Color color;
  final double angle;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 3),
          ),
          child: Text(
            label,
            style: AppTypography.brand(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeckCounter extends StatelessWidget {
  const _DeckCounter({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
      ),
      child: Text(
        '$current / $total',
        style: AppTypography.sans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: PinitColors.aubergine,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.onPass,
    required this.onTap,
    required this.onLike,
  });

  final VoidCallback? onPass;
  final VoidCallback onTap;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundAction(
          icon: FeatherIcons.x,
          color: PinitColors.accent,
          size: 60,
          onTap: onPass,
        ),
        const SizedBox(width: 20),
        _RoundAction(
          icon: FeatherIcons.info,
          color: PinitColors.aubergine,
          size: 48,
          onTap: onTap,
          fill: PinitColors.creamSunk,
        ),
        const SizedBox(width: 20),
        _RoundAction(
          icon: FeatherIcons.heart,
          color: PinitColors.success,
          size: 60,
          onTap: onLike,
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
    this.fill,
  });

  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: fill ?? PinitColors.cream,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: size * 0.42),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.lastLikedName, required this.onDone});
  final String? lastLikedName;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: PinitColors.creamSunk,
              shape: BoxShape.circle,
              border: Border.all(color: PinitColors.creamDeep, width: 1.5),
            ),
            child: const Icon(
              FeatherIcons.checkCircle,
              size: 42,
              color: PinitColors.aubergine,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'That\'s the deck',
            style: AppTypography.brand(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: PinitColors.aubergine,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              lastLikedName != null
                  ? 'Enjoy $lastLikedName — it\'s waiting in your saved list.'
                  : 'Nothing caught your eye this round. Try a longer walk.',
              textAlign: TextAlign.center,
              style: AppTypography.sans(
                fontSize: 14,
                color: PinitColors.aubergineSoft,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onDone,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: PinitColors.aubergine,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: PinitColors.aubergine,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: PinitColors.aubergine,
                      blurRadius: 0,
                      offset: Offset(3, 3),
                    ),
                  ],
                ),
                child: Text(
                  'BACK TO MAP',
                  style: AppTypography.sans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: PinitColors.cream,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            shape: BoxShape.circle,
            border: Border.all(
              color: PinitColors.creamDeep,
              width: 1.5,
            ),
          ),
          child: Icon(icon, size: 18, color: PinitColors.aubergine),
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// Mode toggle enum.
enum HomeMode { you, explore }

/// Unified chip row: You, Explore, Decide — Style.MD pinit pills.
///
/// • Default chip → cream-sunk fill, cream-deep border, aubergine ink
/// • Active chip  → aubergine fill, cream ink (the "filled" pinit pill)
/// • Decide chip  → accent fill, cream ink (the single high-energy CTA)
///
/// All chips are fully rounded pills with tracked uppercase labels — the
/// signature pinit move that matches the carousel cards and profile chips.
class HomeChipRow extends StatelessWidget {
  final HomeMode currentMode;
  final ValueChanged<HomeMode> onModeChanged;
  final VoidCallback onDecideTap;

  const HomeChipRow({
    Key? key,
    required this.currentMode,
    required this.onModeChanged,
    required this.onDecideTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(
          label: 'YOU',
          icon: FeatherIcons.user,
          state: currentMode == HomeMode.you
              ? _ChipState.filled
              : _ChipState.normal,
          onTap: () => onModeChanged(HomeMode.you),
        ),
        const SizedBox(width: 8),
        _Chip(
          label: 'EXPLORE',
          icon: FeatherIcons.compass,
          state: currentMode == HomeMode.explore
              ? _ChipState.filled
              : _ChipState.normal,
          onTap: () => onModeChanged(HomeMode.explore),
        ),
        const Spacer(),
        _Chip(
          label: 'DECIDE',
          icon: FeatherIcons.zap,
          state: _ChipState.accent,
          onTap: onDecideTap,
        ),
      ],
    );
  }
}

enum _ChipState { normal, filled, accent }

/// Pinit pill chip — matches the `_PinitPill` style used in the carousel.
/// Adds a hard offset shadow on the active state for the carousel-card vibe.
class _Chip extends StatefulWidget {
  final String label;
  final IconData icon;
  final _ChipState state;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.state,
    required this.onTap,
  });

  @override
  State<_Chip> createState() => _ChipStateState();
}

class _ChipStateState extends State<_Chip> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) => setState(() => _scale = 0.94);

  void _onTapUp(TapUpDetails _) {
    setState(() => _scale = 1.0);
    widget.onTap();
  }

  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final Color border;
    final bool elevated;

    switch (widget.state) {
      case _ChipState.accent:
        bg = PinitColors.accent;
        fg = PinitColors.cream;
        border = PinitColors.accent;
        elevated = true;
        break;
      case _ChipState.filled:
        bg = PinitColors.aubergine;
        fg = PinitColors.cream;
        border = PinitColors.aubergine;
        elevated = true;
        break;
      case _ChipState.normal:
        bg = PinitColors.cream;
        fg = PinitColors.aubergine;
        border = PinitColors.aubergine;
        elevated = false;
        break;
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 1.5),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: border,
                      blurRadius: 0,
                      offset: const Offset(2, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 12, color: fg),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: fg,
                  letterSpacing: 1.2,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

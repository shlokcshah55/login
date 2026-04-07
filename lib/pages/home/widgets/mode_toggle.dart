import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/themes/pinit_colors.dart';
import 'package:login/themes/pinit_theme.dart';

/// Mode toggle enum.
enum HomeMode { you, explore }

/// Unified chip row: You, Explore, Decide — all in one horizontal strip.
///
/// Colors come from PinitColors ThemeExtension:
/// • Active chip → filled primaryPurple, white text/icon
/// • Inactive chip → chipInactive surface, textPrimary/textSecondary
///
/// Decide is always inactive-colored (it triggers an action sheet, not a mode).
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
          label: 'You',
          icon: CupertinoIcons.person_fill,
          isActive: currentMode == HomeMode.you,
          onTap: () => onModeChanged(HomeMode.you),
        ),
        const SizedBox(width: 8),
        _Chip(
          label: 'Explore',
          icon: CupertinoIcons.compass_fill,
          isActive: currentMode == HomeMode.explore,
          onTap: () => onModeChanged(HomeMode.explore),
        ),
        const Spacer(),
        _Chip(
          label: 'Decide',
          icon: CupertinoIcons.sparkles,
          isActive: false,
          onTap: onDecideTap,
        ),
      ],
    );
  }
}

/// Individual chip with animated active/inactive states.
class _Chip extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) => setState(() => _scale = 0.94);

  void _onTapUp(TapUpDetails _) {
    setState(() => _scale = 1.0);
    widget.onTap();
  }

  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<PinitColors>()!;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: PinitMotion.fast,
        curve: PinitMotion.curve,
        child: AnimatedContainer(
          duration: PinitMotion.standard,
          curve: PinitMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive ? c.chipActive : c.chipInactive,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.isActive ? c.textOnPurple : c.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: AppTypography.brand(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isActive ? c.textOnPurple : c.textPrimary,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

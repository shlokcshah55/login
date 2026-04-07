import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/themes/pinit_colors.dart';
import 'package:login/themes/pinit_theme.dart';

/// Shortlist count pill — theme-aware surface + text.
class ShortlistPill extends StatefulWidget {
  final int count;
  final VoidCallback onTap;

  const ShortlistPill({
    Key? key,
    required this.count,
    required this.onTap,
  }) : super(key: key);

  @override
  State<ShortlistPill> createState() => _ShortlistPillState();
}

class _ShortlistPillState extends State<ShortlistPill> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<PinitColors>()!;

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.94),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: PinitMotion.fast,
        curve: PinitMotion.curve,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: c.elevatedSurface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.tray_arrow_up_fill,
                size: 14,
                color: c.primaryPurple,
              ),
              const SizedBox(width: 6),
              Text(
                'Shortlist (${widget.count})',
                style: AppTypography.brand(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
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

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;

/// Shortlist count pill styled to match the home action pills.
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
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.94),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                offset: const Offset(3, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                FeatherIcons.bookmark,
                size: 13,
                color: pinit.PinitColors.cream,
              ),
              const SizedBox(width: 6),
              Text(
                'Shortlist (${widget.count})',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: pinit.PinitColors.cream,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

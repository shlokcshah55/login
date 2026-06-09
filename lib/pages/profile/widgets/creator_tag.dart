import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pinit_colors.dart';

/// Small pill shown beneath a verified creator's name on profile headers.
class CreatorTag extends StatelessWidget {
  const CreatorTag({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: PinitColors.cream.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: PinitColors.cream.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 11,
            color: PinitColors.cream,
          ),
          const SizedBox(width: 5),
          Text(
            'CREATOR',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: PinitColors.cream,
              letterSpacing: 0.12 * 10,
            ),
          ),
        ],
      ),
    );
  }
}

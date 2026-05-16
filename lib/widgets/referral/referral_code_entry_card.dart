import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

class ReferralCodeEntryCard extends StatelessWidget {
  final VoidCallback onTap;

  const ReferralCodeEntryCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(24),
            border: const Border(
              right: BorderSide(color: PinitColors.aubergine, width: 3),
              bottom: BorderSide(color: PinitColors.aubergine, width: 3),
            ),
            boxShadow: PinitColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: PinitColors.cream,
                  borderRadius: BorderRadius.circular(16),
                  border: const Border(
                    right: BorderSide(color: PinitColors.aubergine, width: 2),
                    bottom: BorderSide(color: PinitColors.aubergine, width: 2),
                  ),
                ),
                child: const Icon(
                  Icons.local_offer_outlined,
                  color: PinitColors.aubergine,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add a referral code',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: PinitColors.aubergine,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use the code you were given to unlock your signup reward.',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        height: 1.35,
                        color: PinitColors.aubergineSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_rounded,
                color: PinitColors.aubergine,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

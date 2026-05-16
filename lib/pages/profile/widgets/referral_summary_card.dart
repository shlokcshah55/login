import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pinit_colors.dart';

class ReferralSummaryCard extends StatelessWidget {
  final String referralCode;
  final int acceptedReferralCount;

  const ReferralSummaryCard({
    super.key,
    required this.referralCode,
    required this.acceptedReferralCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PinitColors.cream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
        boxShadow: PinitColors.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REFERRALS',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: PinitColors.aubergineSoft,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Referrals that turn into rewards',
            style: TextStyle(
              fontFamily: 'Rova',
              fontSize: 28,
              fontWeight: FontWeight.w100,
              color: PinitColors.aubergine,
              letterSpacing: 1.4,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Share your code, track successful signups, and use each one-time reward once it lands.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              height: 1.45,
              color: PinitColors.aubergineSoft,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _InfoPill(
                  label: 'Your code',
                  value: referralCode,
                  trailing: IconButton(
                    onPressed: referralCode.isEmpty
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            Clipboard.setData(
                              ClipboardData(text: referralCode),
                            );
                          },
                    icon: const Icon(Icons.copy_rounded),
                    color: PinitColors.aubergine,
                    tooltip: 'Copy code',
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: _InfoPill(
                  label: 'Successful referrals',
                  value: acceptedReferralCount.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;

  const _InfoPill({
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PinitColors.creamDeep, width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: PinitColors.aubergineSoft,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Rova',
                    fontSize: 20,
                    fontWeight: FontWeight.w100,
                    color: PinitColors.aubergine,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pinit_colors.dart';

class ReferralSummaryCard extends StatefulWidget {
  final String referralCode;
  final int acceptedReferralCount;

  const ReferralSummaryCard({
    super.key,
    required this.referralCode,
    required this.acceptedReferralCount,
  });

  @override
  State<ReferralSummaryCard> createState() => _ReferralSummaryCardState();
}

class _ReferralSummaryCardState extends State<ReferralSummaryCard> {
  bool _isExpanded = false;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final referralCode = widget.referralCode;
    final acceptedReferralCount = widget.acceptedReferralCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PinitColors.creamDeep,
        borderRadius: BorderRadius.circular(24),
        border: const Border(
          right: BorderSide(color: PinitColors.aubergine, width: 4),
          bottom: BorderSide(color: PinitColors.aubergine, width: 4),
        ),
        boxShadow: PinitColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _toggle,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Referrals',
                      style: GoogleFonts.dmSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: PinitColors.aubergine,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: PinitColors.aubergine,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: Text(
              'Share your code, track successful signups and use each one-time reward once it lands.',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                height: 1.45,
                color: PinitColors.aubergineSoft,
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: _buildDetails(referralCode, acceptedReferralCount),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(String referralCode, int acceptedReferralCount) {
    return Row(
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
        border: const Border(
          right: BorderSide(color: PinitColors.aubergine, width: 2),
          bottom: BorderSide(color: PinitColors.aubergine, width: 2),
        ),
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
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PinitColors.aubergineSoft,
                    letterSpacing: 0.2,
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

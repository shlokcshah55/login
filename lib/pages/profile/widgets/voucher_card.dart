import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/reward_voucher.dart';

import 'pinit_colors.dart';

class VoucherCard extends StatelessWidget {
  final RewardVoucher voucher;
  final bool isRedeeming;
  final VoidCallback? onRedeem;

  const VoucherCard({
    super.key,
    required this.voucher,
    this.isRedeeming = false,
    this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    final canRedeem = voucher.isAvailable && onRedeem != null && !isRedeeming;
    final rewardRole = voucher.metadata['reward_role']?.toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: voucher.isAvailable ? PinitColors.cream : PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: voucher.isAvailable
              ? PinitColors.aubergine.withValues(alpha: 0.16)
              : PinitColors.creamDeep,
          width: 1.4,
        ),
        boxShadow: voucher.isAvailable ? PinitColors.cardShadow : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _VoucherBadge(
                label: voucher.isAvailable ? 'Available now' : 'Used',
                isAccent: voucher.isAvailable,
              ),
              const Spacer(),
              if (rewardRole != null && rewardRole.isNotEmpty)
                Text(
                  rewardRole == 'inviter' ? 'Inviter reward' : 'Invitee reward',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PinitColors.aubergineSoft,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _displayTitle(voucher),
            style: const TextStyle(
              fontFamily: 'Rova',
              fontSize: 24,
              fontWeight: FontWeight.w100,
              color: PinitColors.aubergine,
              letterSpacing: 1.1,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            voucher.description.isNotEmpty
                ? voucher.description
                : 'Single-use reward for a completed referral.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              height: 1.45,
              color: PinitColors.aubergineSoft,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.storefront_rounded,
                label: voucher.merchantName,
              ),
              _MetaChip(
                icon: Icons.sell_outlined,
                label: '${voucher.discountPercent}% off',
              ),
              _MetaChip(
                icon: voucher.isAvailable
                    ? Icons.schedule_rounded
                    : Icons.check_circle_rounded,
                label: voucher.isAvailable
                    ? 'Issued ${_formatDate(voucher.issuedAt)}'
                    : 'Used ${_formatDate(voucher.redeemedAt ?? voucher.issuedAt)}',
              ),
            ],
          ),
          if (voucher.termsText.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              voucher.termsText,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                height: 1.45,
                color: PinitColors.mute,
              ),
            ),
          ],
          if (onRedeem != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      canRedeem ? PinitColors.aubergine : PinitColors.creamDeep,
                  foregroundColor:
                      canRedeem ? PinitColors.cream : PinitColors.aubergineSoft,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: canRedeem ? onRedeem : null,
                child: isRedeeming
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: PinitColors.cream,
                        ),
                      )
                    : Text(
                        voucher.isAvailable ? 'Use voucher' : 'Used',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _displayTitle(RewardVoucher voucher) {
    if (voucher.discountPercent > 0 && voucher.merchantName.isNotEmpty) {
      return '${voucher.discountPercent}% off ${voucher.merchantName} at Selected Stores';
    }
    return voucher.title;
  }

  static String _formatDate(DateTime value) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }
}

class _VoucherBadge extends StatelessWidget {
  final String label;
  final bool isAccent;

  const _VoucherBadge({
    required this.label,
    required this.isAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAccent
            ? PinitColors.accent.withValues(alpha: 0.1)
            : PinitColors.creamDeep,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isAccent ? PinitColors.accent : PinitColors.aubergineSoft,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PinitColors.creamDeep, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: PinitColors.aubergine),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: PinitColors.aubergine,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

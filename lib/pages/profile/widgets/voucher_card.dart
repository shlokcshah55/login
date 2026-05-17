import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/reward_voucher.dart';

import 'pinit_colors.dart';

class VoucherCard extends StatefulWidget {
  final RewardVoucher voucher;
  final bool isRedeeming;
  final Future<void> Function()? onRedeem;

  const VoucherCard({
    super.key,
    required this.voucher,
    this.isRedeeming = false,
    this.onRedeem,
  });

  @override
  State<VoucherCard> createState() => _VoucherCardState();
}

class _VoucherCardState extends State<VoucherCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scale;
  late final Animation<double> _lift;
  bool _isAnimatingRedeem = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0.975)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 38,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.975, end: 1.025)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 62,
      ),
    ]).animate(_pressController);
    _lift = Tween<double>(begin: 0, end: -4).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  Future<void> _handleRedeem() async {
    final onRedeem = widget.onRedeem;
    if (!_canRedeem || onRedeem == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _isAnimatingRedeem = true);
    try {
      await _pressController.forward(from: 0);
      if (!mounted) return;
      await _pressController.reverse();
      if (!mounted) return;
      await onRedeem();
    } finally {
      if (mounted) {
        setState(() => _isAnimatingRedeem = false);
      }
    }
  }

  bool get _canRedeem =>
      widget.voucher.isAvailable &&
      widget.onRedeem != null &&
      !widget.isRedeeming &&
      !_isAnimatingRedeem;

  @override
  Widget build(BuildContext context) {
    final voucher = widget.voucher;
    final canRedeem = _canRedeem;
    final isAvailable = voucher.isAvailable;
    final rewardRole = voucher.metadata['reward_role']?.toString();
    final availableSurface =
        Color.lerp(PinitColors.cream, PinitColors.tertiaryOrange, 0.18)!;
    final usedSurface = Color.lerp(PinitColors.creamSunk, Colors.grey, 0.16)!;
    final primaryTextColor =
        isAvailable ? PinitColors.aubergine : PinitColors.mute;
    final secondaryTextColor =
        isAvailable ? PinitColors.aubergineSoft : PinitColors.mute;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canRedeem ? _handleRedeem : null,
      child: AnimatedBuilder(
        animation: _pressController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _lift.value),
            child: Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isAvailable ? availableSurface : usedSurface,
            borderRadius: BorderRadius.circular(22),
            border: isAvailable
                ? const Border(
                    right: BorderSide(color: PinitColors.aubergine, width: 3),
                    bottom: BorderSide(color: PinitColors.aubergine, width: 3),
                  )
                : null,
            boxShadow: isAvailable
                ? [
                    const BoxShadow(
                      color: Color(0x33FFB800),
                      blurRadius: 22,
                      offset: Offset(0, 10),
                    ),
                    ...PinitColors.cardShadow,
                  ]
                : null,
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
                      rewardRole == 'inviter'
                          ? 'Inviter reward'
                          : 'Invitee reward',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _buildTitleSection(voucher, primaryTextColor, secondaryTextColor),
              const SizedBox(height: 8),
              Text(
                voucher.description.isNotEmpty
                    ? voucher.description
                    : 'Single-use reward for a completed referral.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  height: 1.45,
                  color: secondaryTextColor,
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
                    isMuted: !isAvailable,
                  ),
                  _MetaChip(
                    icon: Icons.sell_outlined,
                    label: '${voucher.discountPercent}% off',
                    isMuted: !isAvailable,
                  ),
                  _MetaChip(
                    icon: isAvailable
                        ? Icons.schedule_rounded
                        : Icons.check_circle_rounded,
                    label: isAvailable
                        ? 'Issued ${_formatDate(voucher.issuedAt)}'
                        : 'Used ${_formatDate(voucher.redeemedAt ?? voucher.issuedAt)}',
                    isMuted: !isAvailable,
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
                    color: secondaryTextColor,
                  ),
                ),
              ],
              if (widget.onRedeem != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: canRedeem
                          ? PinitColors.tertiaryOrange
                          : PinitColors.creamDeep,
                      foregroundColor: canRedeem
                          ? PinitColors.aubergine
                          : PinitColors.aubergineSoft,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: canRedeem ? _handleRedeem : null,
                    child: widget.isRedeeming
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: PinitColors.cream,
                            ),
                          )
                        : Text(
                            isAvailable ? 'Use voucher' : 'Used',
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
        ),
      ),
    );
  }

  static Widget _buildTitleSection(
    RewardVoucher voucher,
    Color primary,
    Color secondary,
  ) {
    if (voucher.discountPercent > 0 && voucher.merchantName.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${voucher.discountPercent}%',
                  style: GoogleFonts.dmSans(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: primary,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
                TextSpan(
                  text: ' off',
                  style: GoogleFonts.dmSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: primary,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${voucher.merchantName} · Selected Stores',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: secondary,
            ),
          ),
        ],
      );
    }
    return Text(
      voucher.title,
      style: GoogleFonts.dmSans(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: primary,
        height: 1.15,
      ),
    );
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
            ? PinitColors.tertiaryOrange.withValues(alpha: 0.28)
            : PinitColors.creamDeep,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isAccent ? PinitColors.aubergine : PinitColors.aubergineSoft,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isMuted;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.isMuted = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isMuted ? PinitColors.mute : PinitColors.aubergine;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isMuted
            ? Colors.white.withValues(alpha: 0.38)
            : PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(999),
        border: isMuted
            ? null
            : const Border(
                right: BorderSide(color: PinitColors.aubergine, width: 1.4),
                bottom: BorderSide(color: PinitColors.aubergine, width: 1.4),
              ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

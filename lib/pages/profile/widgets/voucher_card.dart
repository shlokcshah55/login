import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/reward_voucher.dart';

import 'pinit_colors.dart';

class VoucherCard extends StatefulWidget {
  final RewardVoucher voucher;
  final bool isRedeeming;
  final Future<void> Function()? onRedeem;
  final bool isOpeningLocation;
  final VoidCallback? onViewLocation;

  const VoucherCard({
    super.key,
    required this.voucher,
    this.isRedeeming = false,
    this.onRedeem,
    this.isOpeningLocation = false,
    this.onViewLocation,
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

    final showSlider =
        isAvailable && voucher.isSingleUse && widget.onRedeem != null;
    final hasTerms = voucher.termsText.isNotEmpty;

    return AnimatedBuilder(
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
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _MetaChip(
                      icon: isAvailable
                          ? Icons.schedule_rounded
                          : Icons.check_circle_rounded,
                      label: isAvailable
                          ? 'Issued ${_formatDate(voucher.issuedAt)}'
                          : 'Used ${_formatDate(voucher.redeemedAt ?? voucher.issuedAt)}',
                      isMuted: !isAvailable,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTitleSection(
                    voucher,
                    primaryTextColor,
                    secondaryTextColor,
                  ),
                ),
                if (hasTerms)
                  IconButton(
                    onPressed: () => _showTerms(context),
                    icon: const Icon(Icons.info_outline_rounded),
                    color: primaryTextColor,
                    tooltip: 'Terms and conditions',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
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
                if (voucher.discountPercent > 0)
                  _MetaChip(
                    icon: Icons.sell_outlined,
                    label: '${voucher.discountPercent}% off',
                    isMuted: !isAvailable,
                  ),
                if (rewardRole != null && rewardRole.isNotEmpty)
                  _MetaChip(
                    icon: Icons.card_giftcard_rounded,
                    label: rewardRole == 'inviter'
                        ? 'Inviter reward'
                        : 'Invitee reward',
                    isMuted: !isAvailable,
                  ),
              ],
            ),
            if (hasTerms) ...[
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
            if (voucher.locationId != null &&
                widget.onViewLocation != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PinitColors.aubergine,
                    side: const BorderSide(
                      color: PinitColors.aubergine,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed:
                      widget.isOpeningLocation ? null : widget.onViewLocation,
                  icon: widget.isOpeningLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PinitColors.aubergine,
                          ),
                        )
                      : const Icon(Icons.place_outlined, size: 18),
                  label: Text(
                    'View ${voucher.merchantName}',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            if (showSlider) ...[
              SizedBox(
                height:
                    voucher.locationId != null && widget.onViewLocation != null
                        ? 10
                        : 16,
              ),
              _SlideToRedeem(
                enabled: canRedeem,
                isBusy: widget.isRedeeming || _isAnimatingRedeem,
                onComplete: _handleRedeem,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showTerms(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: PinitColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _VoucherTermsSheet(voucher: widget.voucher),
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

class _SlideToRedeem extends StatefulWidget {
  final bool enabled;
  final bool isBusy;
  final Future<void> Function() onComplete;

  const _SlideToRedeem({
    required this.enabled,
    required this.isBusy,
    required this.onComplete,
  });

  @override
  State<_SlideToRedeem> createState() => _SlideToRedeemState();
}

class _SlideToRedeemState extends State<_SlideToRedeem>
    with SingleTickerProviderStateMixin {
  static const double _height = 56;
  static const double _thumbPadding = 4;
  static const double _completeThreshold = 0.85;

  late final AnimationController _position;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _position = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double travel) {
    if (!widget.enabled || _isCompleting || travel <= 0) return;
    _position.value += details.primaryDelta! / travel;
  }

  Future<void> _onDragEnd(DragEndDetails details) async {
    if (!widget.enabled || _isCompleting) return;

    if (_position.value < _completeThreshold) {
      await _position.animateTo(0, curve: Curves.easeOutCubic);
      return;
    }

    setState(() => _isCompleting = true);
    await _position.animateTo(1, curve: Curves.easeOutCubic);
    try {
      await widget.onComplete();
    } finally {
      // On success the voucher moves to the used list and this widget goes
      // away; on failure, slide back so it can be retried.
      if (mounted) {
        setState(() => _isCompleting = false);
        await _position.animateTo(0, curve: Curves.easeOutCubic);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = widget.isBusy || _isCompleting;

    return LayoutBuilder(
      builder: (context, constraints) {
        const thumbSize = _height - _thumbPadding * 2;
        final travel = constraints.maxWidth - thumbSize - _thumbPadding * 2;

        return Semantics(
          button: true,
          label: 'Slide to use voucher',
          onTap: widget.enabled && !isBusy ? widget.onComplete : null,
          child: Container(
            height: _height,
            decoration: BoxDecoration(
              color: widget.enabled || isBusy
                  ? PinitColors.tertiaryOrange
                  : PinitColors.creamDeep,
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedBuilder(
              animation: _position,
              builder: (context, _) {
                final offset = _position.value * travel;

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Center(
                      child: Opacity(
                        opacity: (1 - _position.value * 1.4).clamp(0.0, 1.0),
                        child: Text(
                          'Slide to use voucher',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: PinitColors.aubergine,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: _thumbPadding + offset,
                      child: GestureDetector(
                        onHorizontalDragUpdate: (details) =>
                            _onDragUpdate(details, travel),
                        onHorizontalDragEnd: _onDragEnd,
                        child: Container(
                          width: thumbSize,
                          height: thumbSize,
                          decoration: BoxDecoration(
                            color: PinitColors.aubergine,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Center(
                            child: isBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: PinitColors.cream,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: PinitColors.cream,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _VoucherTermsSheet extends StatelessWidget {
  final RewardVoucher voucher;

  const _VoucherTermsSheet({
    required this.voucher,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PinitColors.creamDeep,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Terms and conditions',
              style: GoogleFonts.dmSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: PinitColors.aubergine,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              voucher.title,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: PinitColors.aubergineSoft,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              voucher.termsText,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                height: 1.5,
                color: PinitColors.aubergine,
              ),
            ),
          ],
        ),
      ),
    );
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
            : Border.all(color: PinitColors.aubergine, width: 1.2),
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

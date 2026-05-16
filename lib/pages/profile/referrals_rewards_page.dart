import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/reward_voucher.dart';
import 'package:login/providers/referral_rewards_provider.dart';
import 'package:login/widgets/feedback/app_feedback.dart';
import 'package:login/widgets/referral/referral_code_entry_card.dart';
import 'package:login/widgets/referral/referral_code_prompt_sheet.dart';
import 'package:provider/provider.dart';

import 'widgets/pinit_colors.dart';
import 'widgets/referral_summary_card.dart';
import 'widgets/voucher_card.dart';

class ReferralsRewardsPage extends StatefulWidget {
  final ReferralRewardsProvider? provider;

  const ReferralsRewardsPage({
    super.key,
    this.provider,
  });

  @override
  State<ReferralsRewardsPage> createState() => _ReferralsRewardsPageState();
}

class _ReferralsRewardsPageState extends State<ReferralsRewardsPage> {
  late final ReferralRewardsProvider _provider;
  late final bool _ownsProvider;
  String? _redeemingVoucherId;
  bool _isReferralSheetVisible = false;
  bool _showUsedVouchers = false;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider ?? ReferralRewardsProvider();
    _ownsProvider = widget.provider == null;
    unawaited(_provider.loadDashboard());
  }

  @override
  void dispose() {
    if (_ownsProvider) {
      _provider.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReferralRewardsProvider>.value(
      value: _provider,
      child: Consumer<ReferralRewardsProvider>(
        builder: (context, provider, _) {
          final dashboard = provider.dashboard;
          final availableVouchers =
              dashboard?.availableVouchers ?? const <RewardVoucher>[];
          final usedVouchers =
              dashboard?.usedVouchers ?? const <RewardVoucher>[];

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark,
            child: Scaffold(
              backgroundColor: PinitColors.cream,
              body: SafeArea(
                child: provider.isLoading && dashboard == null
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: PinitColors.aubergine,
                        ),
                      )
                    : RefreshIndicator(
                        color: PinitColors.aubergine,
                        backgroundColor: PinitColors.cream,
                        onRefresh: provider.loadDashboard,
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          slivers: [
                            SliverToBoxAdapter(
                              child: _RewardsAppBar(
                                onBack: () => Navigator.of(context).pop(),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate(
                                  [
                                    if (provider.error != null) ...[
                                      _InlineError(message: provider.error!),
                                      const SizedBox(height: 14),
                                    ],
                                    ReferralSummaryCard(
                                      referralCode:
                                          dashboard?.referralCode ?? '',
                                      acceptedReferralCount:
                                          dashboard?.acceptedReferralCount ?? 0,
                                    ),
                                    if (dashboard != null &&
                                        !dashboard.hasEnteredReferralCode) ...[
                                      const SizedBox(height: 18),
                                      ReferralCodeEntryCard(
                                        onTap: _showReferralCodeSheet,
                                      ),
                                    ],
                                    if (availableVouchers.isNotEmpty) ...[
                                      const SizedBox(height: 18),
                                      _VoucherSection(
                                        title: 'Available vouchers',
                                        vouchers: availableVouchers,
                                        emptyMessage: '',
                                        builder: (voucher) => VoucherCard(
                                          voucher: voucher,
                                          isRedeeming:
                                              _redeemingVoucherId == voucher.id,
                                          onRedeem: () =>
                                              _handleRedeem(voucher),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 18),
                                    _UsedVoucherSection(
                                      title: 'Used vouchers',
                                      subtitle:
                                          'Redeemed vouchers will stay here as your reward history.',
                                      vouchers: usedVouchers,
                                      emptyMessage:
                                          'Redeemed vouchers will show up here after you use them.',
                                      isExpanded: _showUsedVouchers,
                                      onToggle: () {
                                        HapticFeedback.selectionClick();
                                        setState(
                                          () => _showUsedVouchers =
                                              !_showUsedVouchers,
                                        );
                                      },
                                      builder: (voucher) => VoucherCard(
                                        voucher: voucher,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleRedeem(RewardVoucher voucher) async {
    if (_redeemingVoucherId != null) return;

    HapticFeedback.mediumImpact();
    setState(() => _redeemingVoucherId = voucher.id);
    final success = await _provider.redeemVoucher(voucher.id);
    if (!mounted) return;
    setState(() => _redeemingVoucherId = null);

    if (!success && _provider.error != null) {
      unawaited(
        AppFeedback.showError(
          context,
          title: 'Couldn’t use voucher',
          message: _provider.error!,
        ),
      );
    }
  }

  Future<void> _showReferralCodeSheet() async {
    if (_isReferralSheetVisible) return;

    HapticFeedback.selectionClick();
    setState(() => _isReferralSheetVisible = true);

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return ReferralCodePromptSheet(
          skipForNow: false,
          onApply: (code) async {
            final success = await _provider.applyReferralCode(code);
            if (!success) {
              throw _provider.error ?? 'Failed to apply referral code.';
            }
          },
        );
      },
    );

    if (!mounted) return;
    setState(() => _isReferralSheetVisible = false);

    if (applied == true) {
      HapticFeedback.mediumImpact();
    }
  }
}

class _UsedVoucherSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<RewardVoucher> vouchers;
  final String emptyMessage;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget Function(RewardVoucher voucher) builder;

  const _UsedVoucherSection({
    required this.title,
    required this.subtitle,
    required this.vouchers,
    required this.emptyMessage,
    required this.isExpanded,
    required this.onToggle,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color.lerp(PinitColors.creamSunk, Colors.grey, 0.12)!,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.dmSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: PinitColors.aubergineSoft,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: PinitColors.mute,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.45,
              color: PinitColors.mute,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: vouchers.isEmpty
                        ? _SectionEmptyState(message: emptyMessage)
                        : Column(
                            children: [
                              for (var i = 0; i < vouchers.length; i++) ...[
                                builder(vouchers[i]),
                                if (i != vouchers.length - 1)
                                  const SizedBox(height: 12),
                              ],
                            ],
                          ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _RewardsAppBar extends StatelessWidget {
  final VoidCallback onBack;

  const _RewardsAppBar({
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onBack,
              child: Ink(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: PinitColors.creamSunk,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: PinitColors.creamDeep, width: 1.5),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: PinitColors.aubergine,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Referrals and rewards',
              style: const TextStyle(
                fontFamily: 'Rova',
                fontSize: 22,
                fontWeight: FontWeight.w100,
                color: PinitColors.aubergine,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoucherSection extends StatelessWidget {
  final String title;
  final List<RewardVoucher> vouchers;
  final String emptyMessage;
  final Widget Function(RewardVoucher voucher) builder;

  const _VoucherSection({
    required this.title,
    required this.vouchers,
    required this.emptyMessage,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PinitColors.creamDeep,
        borderRadius: BorderRadius.circular(24),
        border: const Border(
          right: BorderSide(color: PinitColors.aubergine, width: 3),
          bottom: BorderSide(color: PinitColors.aubergine, width: 3),
        ),
        boxShadow: PinitColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: PinitColors.aubergine,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 16),
          if (vouchers.isEmpty)
            _SectionEmptyState(message: emptyMessage)
          else
            Column(
              children: [
                for (var i = 0; i < vouchers.length; i++) ...[
                  builder(vouchers[i]),
                  if (i != vouchers.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  final String message;

  const _SectionEmptyState({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PinitColors.cream,
        borderRadius: BorderRadius.circular(18),
        border: const Border(
          right: BorderSide(color: PinitColors.aubergine, width: 2),
          bottom: BorderSide(color: PinitColors.aubergine, width: 2),
        ),
      ),
      child: Text(
        message,
        style: GoogleFonts.dmSans(
          fontSize: 13.5,
          height: 1.45,
          color: PinitColors.aubergineSoft,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PinitColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          right: BorderSide(color: PinitColors.aubergine, width: 2),
          bottom: BorderSide(color: PinitColors.aubergine, width: 2),
        ),
      ),
      child: Text(
        message,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          height: 1.4,
          color: PinitColors.aubergine,
        ),
      ),
    );
  }
}

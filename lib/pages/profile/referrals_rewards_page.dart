import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/reward_voucher.dart';
import 'package:login/providers/referral_rewards_provider.dart';
import 'package:login/widgets/feedback/app_feedback.dart';
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
                                    const SizedBox(height: 18),
                                    _VoucherSection(
                                      title: 'Available vouchers',
                                      subtitle:
                                          'Use each one-time reward to mark it as consumed.',
                                      vouchers: dashboard?.availableVouchers ??
                                          const [],
                                      emptyMessage:
                                          'No available vouchers right now.',
                                      builder: (voucher) => VoucherCard(
                                        voucher: voucher,
                                        isRedeeming:
                                            _redeemingVoucherId == voucher.id,
                                        onRedeem: () => _handleRedeem(voucher),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    _VoucherSection(
                                      title: 'Used vouchers',
                                      subtitle:
                                          'Redeemed vouchers will stay here as your reward history.',
                                      vouchers:
                                          dashboard?.usedVouchers ?? const [],
                                      emptyMessage:
                                          'Redeemed vouchers will show up here after you use them.',
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
              'Referrals & rewards',
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
  final String subtitle;
  final List<RewardVoucher> vouchers;
  final String emptyMessage;
  final Widget Function(RewardVoucher voucher) builder;

  const _VoucherSection({
    required this.title,
    required this.subtitle,
    required this.vouchers,
    required this.emptyMessage,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PinitColors.creamDeep, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Rova',
              fontSize: 24,
              fontWeight: FontWeight.w100,
              color: PinitColors.aubergine,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.45,
              color: PinitColors.aubergineSoft,
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
        border: Border.all(color: PinitColors.creamDeep, width: 1.2),
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
        border: Border.all(
          color: PinitColors.accent.withValues(alpha: 0.2),
          width: 1.2,
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

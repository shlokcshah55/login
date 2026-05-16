import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/referral_dashboard.dart';
import 'package:login/models/reward_voucher.dart';
import 'package:login/pages/profile/referrals_rewards_page.dart';
import 'package:login/providers/referral_rewards_provider.dart';

void main() {
  testWidgets('loads dashboard details and redeems an available voucher', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = _FakeReferralRewardsProvider(
      initialDashboard: ReferralDashboard(
        referralCode: 'PIN-FRIEND',
        acceptedReferralCount: 2,
        availableVouchers: [
          _voucher(
            id: 'voucher-1',
            status: 'available',
            redeemedAt: null,
          ),
        ],
        usedVouchers: [
          _voucher(
            id: 'voucher-2',
            status: 'redeemed',
            redeemedAt: DateTime(2026, 5, 15, 12),
          ),
        ],
      ),
      redeemedDashboard: ReferralDashboard(
        referralCode: 'PIN-FRIEND',
        acceptedReferralCount: 2,
        availableVouchers: const [],
        usedVouchers: [
          _voucher(
            id: 'voucher-1',
            status: 'redeemed',
            redeemedAt: DateTime(2026, 5, 16, 12),
          ),
          _voucher(
            id: 'voucher-2',
            status: 'redeemed',
            redeemedAt: DateTime(2026, 5, 15, 12),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReferralsRewardsPage(provider: provider),
      ),
    );

    await tester.pump();

    expect(find.text('Referrals & rewards'), findsOneWidget);
    expect(find.text('PIN-FRIEND'), findsOneWidget);
    expect(find.text('Successful referrals'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Available vouchers'), findsOneWidget);
    expect(find.text('Use voucher'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Used vouchers'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Used vouchers'), findsOneWidget);

    await tester.tap(find.text('Use voucher'));
    await tester.pump();

    expect(provider.redeemedVoucherIds, ['voucher-1']);

    await tester.pump();

    expect(find.text('Use voucher'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('No available vouchers right now.'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('No available vouchers right now.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Used vouchers'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Used vouchers'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no vouchers yet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = _FakeReferralRewardsProvider(
      initialDashboard: const ReferralDashboard(
        referralCode: 'PIN-EMPTY',
        acceptedReferralCount: 0,
        availableVouchers: [],
        usedVouchers: [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ReferralsRewardsPage(provider: provider),
      ),
    );

    await tester.pump();

    expect(find.text('PIN-EMPTY'), findsOneWidget);
    expect(find.text('No available vouchers right now.'), findsOneWidget);
    expect(find.text('Redeemed vouchers will show up here after you use them.'),
        findsOneWidget);
  });
}

class _FakeReferralRewardsProvider extends ReferralRewardsProvider {
  _FakeReferralRewardsProvider({
    required ReferralDashboard initialDashboard,
    ReferralDashboard? redeemedDashboard,
  })  : _dashboardValue = initialDashboard,
        _redeemedDashboard = redeemedDashboard ?? initialDashboard,
        _isLoadingValue = true;

  ReferralDashboard _dashboardValue;
  final ReferralDashboard _redeemedDashboard;
  bool _isLoadingValue;
  String? _errorValue;
  final List<String> redeemedVoucherIds = <String>[];

  @override
  ReferralDashboard? get dashboard => _dashboardValue;

  @override
  bool get isLoading => _isLoadingValue;

  @override
  String? get error => _errorValue;

  @override
  Future<void> loadDashboard() async {
    _isLoadingValue = false;
    notifyListeners();
  }

  @override
  Future<bool> redeemVoucher(String voucherId) async {
    redeemedVoucherIds.add(voucherId);
    _dashboardValue = _redeemedDashboard;
    _isLoadingValue = false;
    _errorValue = null;
    notifyListeners();
    return true;
  }
}

RewardVoucher _voucher({
  required String id,
  required String status,
  required DateTime? redeemedAt,
}) {
  return RewardVoucher(
    id: id,
    userId: 'user-1',
    sourceReferralId: 'referral-1',
    title: 'Imperial Farmers Market 10% Off',
    description: 'Reward for a successful referral.',
    campaignKey: 'imperial_farmers_market_10pct_selected_stores',
    merchantName: 'Imperial Farmers Market',
    discountPercent: 10,
    status: status,
    issuedAt: DateTime(2026, 5, 14, 12),
    redeemedAt: redeemedAt,
    expiresAt: null,
    termsText: 'Valid at selected stores. Single use.',
    sourceType: 'invitee_reward',
    redemptionToken: '',
    metadata: const <String, dynamic>{},
  );
}

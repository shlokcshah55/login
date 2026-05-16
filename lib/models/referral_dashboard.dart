import 'package:login/models/reward_voucher.dart';

class ReferralDashboard {
  final String referralCode;
  final int acceptedReferralCount;
  final bool hasEnteredReferralCode;
  final List<RewardVoucher> availableVouchers;
  final List<RewardVoucher> usedVouchers;

  const ReferralDashboard({
    required this.referralCode,
    required this.acceptedReferralCount,
    required this.hasEnteredReferralCode,
    required this.availableVouchers,
    required this.usedVouchers,
  });

  bool get hasAnyVouchers =>
      availableVouchers.isNotEmpty || usedVouchers.isNotEmpty;

  factory ReferralDashboard.fromJson(Map<String, dynamic> json) {
    List<RewardVoucher> parseList(String key) {
      final raw = json[key];
      if (raw is! List) return const <RewardVoucher>[];

      return raw
          .whereType<Map>()
          .map(
              (item) => RewardVoucher.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }

    final availableVouchers = parseList('available_vouchers');

    return ReferralDashboard(
      referralCode: json['referral_code'] as String? ?? '',
      acceptedReferralCount:
          (json['accepted_referral_count'] as num?)?.toInt() ?? 0,
      hasEnteredReferralCode:
          json['has_entered_referral_code'] as bool? ?? false,
      availableVouchers: _collapseAvailableVouchers(availableVouchers),
      usedVouchers: parseList('used_vouchers'),
    );
  }

  static List<RewardVoucher> _collapseAvailableVouchers(
    List<RewardVoucher> vouchers,
  ) {
    final vouchersByCampaign = <String, RewardVoucher>{};

    for (final voucher in vouchers) {
      final key =
          voucher.campaignKey.isNotEmpty ? voucher.campaignKey : voucher.id;
      vouchersByCampaign.putIfAbsent(key, () => voucher);
    }

    return List<RewardVoucher>.unmodifiable(vouchersByCampaign.values);
  }
}

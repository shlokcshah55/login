import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/referral_dashboard.dart';

void main() {
  test('collapses available vouchers by campaign key', () {
    final dashboard = ReferralDashboard.fromJson({
      'referral_code': 'PIN-TEST',
      'accepted_referral_count': 1,
      'has_entered_referral_code': true,
      'available_vouchers': [
        _voucherJson(
          id: 'newer-inviter',
          campaignKey: 'imperial_farmers_market_10pct_selected_stores',
          sourceType: 'inviter_reward',
          issuedAt: '2026-05-16T12:00:00Z',
        ),
        _voucherJson(
          id: 'older-invitee',
          campaignKey: 'imperial_farmers_market_10pct_selected_stores',
          sourceType: 'invitee_reward',
          issuedAt: '2026-05-15T12:00:00Z',
        ),
        _voucherJson(
          id: 'other-campaign',
          campaignKey: 'other_campaign',
          sourceType: 'invitee_reward',
          issuedAt: '2026-05-14T12:00:00Z',
        ),
      ],
      'used_vouchers': [
        _voucherJson(
          id: 'used-inviter',
          campaignKey: 'imperial_farmers_market_10pct_selected_stores',
          sourceType: 'inviter_reward',
          issuedAt: '2026-05-13T12:00:00Z',
          status: 'redeemed',
        ),
        _voucherJson(
          id: 'used-invitee',
          campaignKey: 'imperial_farmers_market_10pct_selected_stores',
          sourceType: 'invitee_reward',
          issuedAt: '2026-05-12T12:00:00Z',
          status: 'redeemed',
        ),
      ],
    });

    expect(
      dashboard.availableVouchers.map((voucher) => voucher.id),
      ['newer-inviter', 'other-campaign'],
    );
    expect(dashboard.usedVouchers, hasLength(2));
  });
}

Map<String, Object?> _voucherJson({
  required String id,
  required String campaignKey,
  required String sourceType,
  required String issuedAt,
  String status = 'available',
}) {
  return {
    'id': id,
    'user_id': 'user-1',
    'source_referral_id': 'referral-1',
    'source_type': sourceType,
    'campaign_key': campaignKey,
    'title': 'Imperial Farmers Market 10% Off',
    'description': 'Referral reward.',
    'merchant_name': 'Imperial Farmers Market',
    'terms_text': 'Valid at selected stores. Single use.',
    'discount_percent': 10,
    'status': status,
    'issued_at': issuedAt,
    'redeemed_at': status == 'redeemed' ? '2026-05-16T13:00:00Z' : null,
    'expires_at': null,
    'metadata': const <String, Object?>{},
  };
}

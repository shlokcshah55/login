import 'package:login/models/referral_dashboard.dart';
import 'package:login/models/reward_voucher.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RewardsHelper {
  RewardsHelper({SupabaseClient? client})
      : _client = client ?? SupabaseClientManager().client;

  final SupabaseClient _client;

  Future<void> applyReferralCode(String code) async {
    await _client.schema(SupabaseConstants.schemaRewards).rpc(
      SupabaseConstants.rpcApplyReferralCode,
      params: {
        SupabaseConstants.paramReferralCode: code.trim(),
      },
    );
  }

  Future<ReferralDashboard> getDashboard() async {
    final response = await _client.schema(SupabaseConstants.schemaRewards).rpc(
          SupabaseConstants.rpcGetMyReferralDashboard,
        );
    return ReferralDashboard.fromJson(
        Map<String, dynamic>.from(response as Map));
  }

  Future<RewardVoucher> redeemVoucher(String voucherId) async {
    final response = await _client.schema(SupabaseConstants.schemaRewards).rpc(
      SupabaseConstants.rpcRedeemVoucher,
      params: {
        SupabaseConstants.paramVoucherId: voucherId,
      },
    );
    return RewardVoucher.fromJson(Map<String, dynamic>.from(response as Map));
  }
}

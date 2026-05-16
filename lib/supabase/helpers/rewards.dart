import 'package:login/models/referral_dashboard.dart';
import 'package:login/models/reward_voucher.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RewardsHelper {
  RewardsHelper({SupabaseClient? client})
      : _client = client ?? SupabaseClientManager().client;

  final SupabaseClient _client;

  Future<void> applyReferralCode(
    String code, {
    bool acceptIfWizardComplete = false,
  }) async {
    await _client.schema(SupabaseConstants.schemaRewards).rpc(
      SupabaseConstants.rpcApplyReferralCode,
      params: {
        SupabaseConstants.paramReferralCode: code.trim(),
      },
    );

    if (!acceptIfWizardComplete) return;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot accept referral without a signed-in user.');
    }

    await _client.schema(SupabaseConstants.schemaRewards).rpc(
      SupabaseConstants.rpcAcceptPendingReferralForUser,
      params: {
        SupabaseConstants.paramUserId: userId,
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

  Future<bool> hasEnteredReferralCode() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot check referral state without a signed-in user.');
    }

    final response = await _client
        .schema(SupabaseConstants.schemaRewards)
        .from(SupabaseConstants.tableRewardReferrals)
        .select('id')
        .eq('invitee_user_id', userId)
        .limit(1);

    return response.isNotEmpty;
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

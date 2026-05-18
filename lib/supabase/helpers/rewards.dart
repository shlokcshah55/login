import 'package:flutter/foundation.dart';
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
    final trimmedCode = code.trim();
    debugPrint(
      '[RewardsHelper] Calling rewards.apply_referral_code with code="$trimmedCode" length=${trimmedCode.length}, acceptIfWizardComplete=$acceptIfWizardComplete',
    );

    try {
      await _client.schema(SupabaseConstants.schemaRewards).rpc(
        SupabaseConstants.rpcApplyReferralCode,
        params: {
          SupabaseConstants.paramReferralCode: trimmedCode,
        },
      );
      debugPrint('[RewardsHelper] rewards.apply_referral_code succeeded.');
    } catch (e, stackTrace) {
      debugPrint('[RewardsHelper] rewards.apply_referral_code failed: $e');
      debugPrintStack(
        label: '[RewardsHelper] apply_referral_code stack',
        stackTrace: stackTrace,
      );
      rethrow;
    }

    if (!acceptIfWizardComplete) return;

    final userId = _client.auth.currentUser?.id;
    debugPrint(
      '[RewardsHelper] Current user id for referral acceptance: ${userId ?? '(none)'}',
    );
    if (userId == null) {
      throw StateError('Cannot accept referral without a signed-in user.');
    }

    try {
      debugPrint(
        '[RewardsHelper] Calling rewards.accept_pending_referral_for_user.',
      );
      await _client.schema(SupabaseConstants.schemaRewards).rpc(
        SupabaseConstants.rpcAcceptPendingReferralForUser,
        params: {
          SupabaseConstants.paramUserId: userId,
        },
      );
      debugPrint(
        '[RewardsHelper] rewards.accept_pending_referral_for_user succeeded.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[RewardsHelper] rewards.accept_pending_referral_for_user failed: $e',
      );
      debugPrintStack(
        label: '[RewardsHelper] accept_pending_referral_for_user stack',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<ReferralDashboard> getDashboard() async {
    debugPrint('[RewardsHelper] Calling rewards.get_my_referral_dashboard.');
    try {
      final response =
          await _client.schema(SupabaseConstants.schemaRewards).rpc(
                SupabaseConstants.rpcGetMyReferralDashboard,
              );
      debugPrint(
          '[RewardsHelper] rewards.get_my_referral_dashboard response: $response');
      return ReferralDashboard.fromJson(
          Map<String, dynamic>.from(response as Map));
    } catch (e, stackTrace) {
      debugPrint(
          '[RewardsHelper] rewards.get_my_referral_dashboard failed: $e');
      debugPrintStack(
        label: '[RewardsHelper] get_my_referral_dashboard stack',
        stackTrace: stackTrace,
      );
      rethrow;
    }
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

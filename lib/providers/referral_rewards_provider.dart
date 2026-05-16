import 'package:flutter/foundation.dart';
import 'package:login/models/referral_dashboard.dart';
import 'package:login/supabase/service.dart';

class ReferralRewardsProvider with ChangeNotifier {
  ReferralRewardsProvider({SupabaseService? service})
      : _service = service ?? SupabaseService();

  final SupabaseService _service;

  ReferralDashboard? _dashboard;
  bool _isLoading = false;
  String? _error;

  ReferralDashboard? get dashboard => _dashboard;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _dashboard = await _service.rewards.getDashboard();
    } catch (e) {
      _error = 'Failed to load rewards dashboard: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> redeemVoucher(String voucherId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.rewards.redeemVoucher(voucherId);
      _dashboard = await _service.rewards.getDashboard();
      return true;
    } catch (e) {
      _error = 'Failed to redeem voucher: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> applyReferralCode(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.rewards.applyReferralCode(
        code,
        acceptIfWizardComplete: true,
      );
      _dashboard = await _service.rewards.getDashboard();
      return true;
    } catch (e) {
      _error = 'Failed to apply referral code: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

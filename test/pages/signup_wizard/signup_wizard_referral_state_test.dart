import 'package:flutter_test/flutter_test.dart';
import 'package:login/models/signup_wizard_state.dart';

void main() {
  group('SignupWizardState referral code', () {
    test('normalizes referral code input and clears stale errors', () {
      final state = SignupWizardState();

      state.setReferralCodeError('Invalid code');
      state.setReferralCode('  friend123  ');

      expect(state.referralCode, 'FRIEND123');
      expect(state.referralCodeError, isNull);
    });

    test('reset clears referral code and error state', () {
      final state = SignupWizardState();

      state.setUserId('user-123');
      state.setReferralCode('welcome');
      state.setReferralCodeError('Try again');

      state.reset();

      expect(state.userId, isNull);
      expect(state.referralCode, isEmpty);
      expect(state.referralCodeError, isNull);
    });
  });
}

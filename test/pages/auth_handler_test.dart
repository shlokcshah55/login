import 'package:flutter_test/flutter_test.dart';
import 'package:login/pages/auth_handler.dart';

void main() {
  test(
      'shouldPresentWizardCompletionAfterAppleSignIn returns true for incomplete Apple onboarding',
      () {
    final shouldPresent = shouldPresentWizardCompletionAfterAppleSignIn(
      pendingAppleWizardRouting: true,
      wizardCompleted: false,
    );

    expect(shouldPresent, isTrue);
  });

  test(
      'shouldPresentWizardCompletionAfterAppleSignIn returns false when wizard is already complete',
      () {
    final shouldPresent = shouldPresentWizardCompletionAfterAppleSignIn(
      pendingAppleWizardRouting: true,
      wizardCompleted: true,
    );

    expect(shouldPresent, isFalse);
  });

  test(
      'shouldPresentWizardCompletionAfterAppleSignIn returns false without a pending Apple route',
      () {
    final shouldPresent = shouldPresentWizardCompletionAfterAppleSignIn(
      pendingAppleWizardRouting: false,
      wizardCompleted: false,
    );

    expect(shouldPresent, isFalse);
  });
}

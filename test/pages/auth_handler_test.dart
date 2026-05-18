import 'package:flutter_test/flutter_test.dart';
import 'package:login/pages/auth_handler.dart';

void main() {
  test(
      'shouldPresentWizardCompletionAfterOAuthSignIn returns true for incomplete OAuth onboarding',
      () {
    final shouldPresent = shouldPresentWizardCompletionAfterOAuthSignIn(
      pendingOAuthWizardRouting: true,
      wizardCompleted: false,
    );

    expect(shouldPresent, isTrue);
  });

  test(
      'shouldPresentWizardCompletionAfterOAuthSignIn returns false when wizard is already complete',
      () {
    final shouldPresent = shouldPresentWizardCompletionAfterOAuthSignIn(
      pendingOAuthWizardRouting: true,
      wizardCompleted: true,
    );

    expect(shouldPresent, isFalse);
  });

  test(
      'shouldPresentWizardCompletionAfterOAuthSignIn returns false without a pending OAuth route',
      () {
    final shouldPresent = shouldPresentWizardCompletionAfterOAuthSignIn(
      pendingOAuthWizardRouting: false,
      wizardCompleted: false,
    );

    expect(shouldPresent, isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:login/pages/auth_handler.dart';

void main() {
  group('resolveAuthenticatedStartupSurface', () {
    test('shows home when cached startup data and consent are usable', () {
      expect(
        resolveAuthenticatedStartupSurface(
          hasValidSession: true,
          hasProfile: true,
          hasSavedLocations: true,
          hasCurrentConsent: true,
        ),
        AuthenticatedStartupSurface.home,
      );
    });

    test('shows legal consent when cached consent is not current', () {
      expect(
        resolveAuthenticatedStartupSurface(
          hasValidSession: true,
          hasProfile: true,
          hasSavedLocations: true,
          hasCurrentConsent: false,
        ),
        AuthenticatedStartupSurface.legalConsent,
      );
    });

    test('keeps the splash up until all required startup data exists', () {
      for (final input in <({bool session, bool profile, bool locations})>[
        (session: false, profile: true, locations: true),
        (session: true, profile: false, locations: true),
        (session: true, profile: true, locations: false),
      ]) {
        expect(
          resolveAuthenticatedStartupSurface(
            hasValidSession: input.session,
            hasProfile: input.profile,
            hasSavedLocations: input.locations,
            hasCurrentConsent: true,
          ),
          AuthenticatedStartupSurface.splash,
        );
      }
    });
  });

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

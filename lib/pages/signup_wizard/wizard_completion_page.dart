import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/signup_wizard_state.dart';
import '../../services/onboarding_analytics.dart';
import '../../services/onboarding_resume_service.dart';
import '../../supabase/supabase_client.dart';
import '../profile/widgets/pinit_colors.dart';
import 'onboarding_flow.dart';

/// Onboarding for users who already have an account but haven't finished it:
/// Google/Apple sign-ups (routed here by `AuthHandler`), a resume after an
/// abandoned email sign-up, and the home "complete your profile" popover.
class WizardCompletionPage extends StatelessWidget {
  const WizardCompletionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final wizardState = SignupWizardState();
        final userId = SupabaseClientManager().currentUser?.id;
        if (userId != null) {
          wizardState.setUserId(userId);
        }
        return wizardState;
      },
      child: const _WizardCompletionContent(),
    );
  }
}

class _WizardCompletionContent extends StatefulWidget {
  const _WizardCompletionContent();

  @override
  State<_WizardCompletionContent> createState() =>
      _WizardCompletionContentState();
}

class _WizardCompletionContentState extends State<_WizardCompletionContent> {
  late final OnboardingAnalytics _analytics;

  @override
  void initState() {
    super.initState();
    final user = SupabaseClientManager().currentUser;
    final provider = user?.appMetadata['provider'];
    _analytics = OnboardingAnalytics(
      flow: provider is String && provider != 'email' ? provider : 'email',
    )..markAccountCreated();
    if (user != null) {
      // If they close the app now, resume once on next launch.
      OnboardingResumeService().markInProgress(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PinitColors.surfaceLight,
      body: OnboardingFlow(analytics: _analytics),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/signup_wizard_state.dart';
import '../../services/onboarding_analytics.dart';
import '../../services/onboarding_resume_service.dart';
import '../profile/widgets/pinit_colors.dart';
import 'account_step.dart';
import 'onboarding_flow.dart';
import 'signup_intro_video_page.dart';

/// Email sign-up: intro video -> account -> onboarding flow (first save,
/// make it yours, bubble + invite). Google/Apple users skip the first two and
/// enter the same [OnboardingFlow] through `WizardCompletionPage`.
class SignupWizardPage extends StatelessWidget {
  const SignupWizardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SignupWizardState(),
      child: const _SignupWizardContent(),
    );
  }
}

class _SignupWizardContent extends StatefulWidget {
  const _SignupWizardContent();

  @override
  State<_SignupWizardContent> createState() => _SignupWizardContentState();
}

class _SignupWizardContentState extends State<_SignupWizardContent> {
  final PageController _pageController = PageController();
  final OnboardingAnalytics _analytics = OnboardingAnalytics(flow: 'email');
  int _currentStep = 0;

  static const int _accountPage = 1;
  static const int _flowPage = 2;

  @override
  void initState() {
    super.initState();
    _analytics.viewed(OnboardingStep.introVideo);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onIntroDone() {
    _analytics.completed(OnboardingStep.introVideo);
    _analytics.viewed(OnboardingStep.account);
    _goTo(_accountPage);
  }

  void _onAccountCreated() {
    final userId = context.read<SignupWizardState>().userId;
    _analytics.completed(OnboardingStep.account);
    _analytics.markAccountCreated();
    if (userId != null) {
      // If the app is closed mid-onboarding, resume once on next launch.
      OnboardingResumeService().markInProgress(userId);
    }
    _goTo(_flowPage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PinitColors.surfaceLight,
      body: SafeArea(
        // The intro video (step 0) is full-bleed and handles its own insets;
        // the onboarding steps handle theirs too.
        top: _currentStep == _accountPage,
        bottom: _currentStep == _accountPage,
        child: Material(
          color: PinitColors.surfaceLight,
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentStep = index),
            children: [
              SignupIntroVideoPage(
                onContinue: _onIntroDone,
                onSkipped: () => _analytics.skipped(OnboardingStep.introVideo),
              ),
              AccountStep(onNext: _onAccountCreated),
              OnboardingFlow(analytics: _analytics),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../services/onboarding_analytics.dart';
import 'onboarding_completion.dart';
import 'steps/bubble_invite_step.dart';
import 'steps/first_save_step.dart';
import 'steps/make_it_yours_step.dart';

/// The three post-account onboarding steps: first save, make it yours
/// (optional), bubble + invite. Shared by the email sign-up wizard and the
/// OAuth completion page, and requires a `SignupWizardState` above it.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.analytics});

  final OnboardingAnalytics analytics;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pages = PageController();
  int _index = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= 2 || _finishing) return;
    setState(() => _index += 1);
    _pages.animateToPage(
      _index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final ok = await completeOnboarding(context, analytics: widget.analytics);
    // On success we navigate away; only re-enable on failure.
    if (!ok && mounted) setState(() => _finishing = false);
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pages,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        FirstSaveStep(
          analytics: widget.analytics,
          onDone: _next,
          onSkip: _next,
        ),
        MakeItYoursStep(
          analytics: widget.analytics,
          onDone: _next,
          onSkip: _next,
        ),
        BubbleInviteStep(
          analytics: widget.analytics,
          onFinish: _finish,
          onSkip: _finish,
          isFinishing: _finishing,
        ),
      ],
    );
  }
}

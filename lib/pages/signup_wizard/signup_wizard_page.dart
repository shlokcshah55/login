import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/signup_wizard_state.dart';
import '../../providers/user_data_provider.dart';
import '../../services/referral_code_prompt_service.dart';
import '../../services/what_we_do_wizard_service.dart';
import '../../supabase/service.dart';
import '../../supabase/constants.dart';
import '../../widgets/feedback/app_feedback.dart';
import '../auth_handler.dart';
import '../profile/widgets/pinit_colors.dart';
import 'account_step.dart';
import 'steps/dietary_step.dart';

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
  int _currentStep = 0;
  bool _isCompletingWizard = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeWizard() async {
    setState(() {
      _isCompletingWizard = true;
    });
    try {
      // Use this.context from the State class, not the build method's context
      final wizardState =
          Provider.of<SignupWizardState>(this.context, listen: false);
      final supabase =
          Provider.of<SupabaseService>(this.context, listen: false);

      // Validate required data
      if (wizardState.userId == null) {
        throw Exception('User ID is required to complete wizard');
      }

      // Step 1: Atomically mark the wizard complete + persist spice
      // tolerance + seed dietary tag affinities. Vibe tags were already
      // initialized on account creation; no additional onboarding steps.
      await supabase.users.finalizeSignupWizard(
        wizardState.userId!,
        spiceTolerance: wizardState.spiceTolerance,
        dietaryTagIds: wizardState.selectedDietaryTagIds,
      );

      // Step 2: Persist place actions in parallel. Collect failures instead
      // of aborting the batch — a single flaky RPC shouldn't block completion.
      final failures = <String>[];
      Future<void> guard(String label, Future<dynamic> fut) =>
          fut.then((_) {}).catchError((e) {
            failures.add('$label: $e');
          });

      await Future.wait([
        for (final id in wizardState.addedLocationIds)
          guard(
            'save $id',
            supabase.locations.saveLocation(
              id,
              savedMethod: SupabaseConstants.savedMethodInApp,
            ),
          ),
        for (final id in wizardState.beenToLocationIds)
          guard('been-to $id', supabase.reviews.markBeenTo(locationId: id)),
      ]);

      if (failures.isNotEmpty && mounted) {
        await AppFeedback.showError(
          this.context,
          title: 'Not everything saved',
          message:
              '${failures.length} place(s) didn\'t save — you can add them later.',
        );
      }

      // wizard_completed already flipped by finalizeSignupWizard above.
      if (mounted) {
        this.context.read<UserDataProvider>().setWizardCompleted(true);
      }

      await WhatWeDoWizardService().markPending();
      await ReferralCodePromptService().markPending();

      // Step 4: Navigate to main app
      if (mounted) {
        Navigator.of(this.context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AuthHandler(),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isCompletingWizard = false;
      });
      if (mounted) {
        await AppFeedback.showError(
          this.context,
          title: 'Setup failed',
          message: 'We’re working hard to fix this — sorry.',
        );
      }
    }
    // Note: Don't set _isCompletingWizard = false on success since we're navigating away
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PinitColors.surfaceLight,
      body: SafeArea(
        child: Material(
          color: PinitColors.surfaceLight,
          child: Column(
            children: [
              //   // Progress Indicator
              //   Padding(
              //     padding:
              //         const EdgeInsets.symmetric(horizontal: 24.0, vertical: 5),
              //     child: Column(
              //       crossAxisAlignment: CrossAxisAlignment.start,
              //       children: [
              //         Text(
              //           _stepTitles[_currentStep],
              //           style: const TextStyle(
              //             fontFamily: 'Rova',
              //             fontSize: 32,
              //             fontWeight: FontWeight.w100,
              //             color: PinitColors.aubergine,
              //             letterSpacing: 1.5,
              //           ),
              //         ),
              //         const SizedBox(height: 12),
              //         // Progress bar
              //         Container(
              //           height: 12,
              //           decoration: BoxDecoration(
              //             color: PinitColors.creamDeep,
              //             borderRadius: BorderRadius.circular(4),
              //           ),
              //           child: LayoutBuilder(
              //             builder: (context, constraints) {
              //               return AnimatedContainer(
              //                 duration: const Duration(milliseconds: 400),
              //                 curve: Curves.easeOutQuint,
              //                 width: constraints.maxWidth * _calculateProgress(),
              //                 decoration: BoxDecoration(
              //                   color: PinitColors.accent,
              //                   borderRadius: BorderRadius.circular(4),
              //                 ),
              //               );
              //             },
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),
              // Page Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics:
                      const NeverScrollableScrollPhysics(), // Disable swipe, use buttons
                  onPageChanged: (index) {
                    setState(() {
                      _currentStep = index;
                    });
                  },
                  children: [
                    AccountStep(
                      onNext: _nextStep,
                    ),
                    DietaryStep(
                      onNext: () {
                        if (_isCompletingWizard) return;
                        unawaited(_completeWizard());
                      },
                      onBack: _previousStep,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

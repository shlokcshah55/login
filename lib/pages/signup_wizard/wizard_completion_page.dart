import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/signup_wizard_state.dart';
import '../../providers/location_list_provider.dart';
import '../../supabase/service.dart';
import '../../supabase/supabase_client.dart';
import '../../supabase/constants.dart';
import '../../providers/user_data_provider.dart';
import '../../services/what_we_do_wizard_service.dart';
import '../../widgets/feedback/app_feedback.dart';
import '../auth_handler.dart';
import '../profile/widgets/pinit_colors.dart';
import 'steps/dietary_step.dart';
import 'steps/vibe_step.dart';

class WizardCompletionPage extends StatelessWidget {
  const WizardCompletionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final wizardState = SignupWizardState();
        // Populate with current user ID
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
  final PageController _pageController = PageController();
  int _currentStep = 0; // 0 = Dietary, 1 = Vibe

  final List<String> _stepTitles = [
    'Dietary Preferences',
    'Your Vibe',
  ];
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
      final wizardState =
          Provider.of<SignupWizardState>(context, listen: false);
      final supabase = Provider.of<SupabaseService>(context, listen: false);

      // Validate required data
      if (wizardState.userId == null) {
        throw Exception('User ID is required to complete wizard');
      }

      final userId = wizardState.userId!;

      // Step 1: Atomically mark the wizard complete + persist spice
      // tolerance + seed dietary tag affinities. Vibe tags were already
      // written by vibe_step via updateUserTagsPhotos.
      await supabase.users.finalizeSignupWizard(
        userId,
        spiceTolerance: wizardState.spiceTolerance,
        dietaryTagIds: wizardState.selectedDietaryTagIds,
      );

      // Step 2: Persist place actions in parallel. Collect failures instead
      // of aborting the batch.
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
          context,
          title: 'Not everything saved',
          message:
              '${failures.length} place(s) didn\'t save — you can add them later.',
        );
      }

      // Ensure saved locations are re-fetched before returning to HomePage so we
      // don't accidentally show the "no saved locations" popover based on stale
      // cached state from before the wizard saved places.
      unawaited(
        context.read<LocationListManager>().refreshSavedLocations(),
      );

      // wizard_completed already flipped by finalizeSignupWizard above.
      if (mounted) {
        context.read<UserDataProvider>().setWizardCompleted(true);
      }

      await WhatWeDoWizardService().markPending();

      // Step 4: Navigate back to main app
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const AuthHandler(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _isCompletingWizard = false;
      });

      if (mounted) {
        await AppFeedback.showError(
          context,
          title: 'Setup failed',
          message: 'We’re working hard to fix this — sorry.',
        );
      }
    }
    // Note: Don't set _isCompletingWizard = false on success since we're navigating away
  }

  double _calculateProgress() {
    // Total: 2 steps
    return (_currentStep + 1) / 2.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PinitColors.surfaceLight,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: PinitColors.aubergine),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        _stepTitles[_currentStep],
                        style: const TextStyle(
                          fontFamily: 'Rova',
                          fontSize: 22,
                          fontWeight: FontWeight.w100,
                          color: PinitColors.aubergine,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: PinitColors.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutQuint,
                          width: constraints.maxWidth * _calculateProgress(),
                          decoration: BoxDecoration(
                            color: PinitColors.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
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
                  DietaryStep(
                    onNext: _nextStep,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  VibeStep(
                    onNext: () {
                      _completeWizard();
                    },
                    onBack: _previousStep,
                    isLoadingRestaurants: _isCompletingWizard,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

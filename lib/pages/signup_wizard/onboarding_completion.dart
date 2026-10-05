import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/signup_wizard_state.dart';
import '../../providers/location_list_provider.dart';
import '../../providers/user_data_provider.dart';
import '../../services/onboarding_analytics.dart';
import '../../services/onboarding_resume_service.dart';
import '../../services/what_we_do_wizard_service.dart';
import '../../supabase/service.dart';
import '../../widgets/feedback/app_feedback.dart';
import '../auth_handler.dart';

/// The single place onboarding ends. Used by the email sign-up wizard and the
/// OAuth completion page. `wizard_completed` is flipped only by the atomic
/// `complete_signup_wizard` RPC (spice tolerance + dietary vector + flag).
///
/// Returns false (after showing an error) if the RPC failed, so the caller can
/// re-enable its buttons.
Future<bool> completeOnboarding(
  BuildContext context, {
  required OnboardingAnalytics analytics,
}) async {
  final wizardState = context.read<SignupWizardState>();
  final supabase = context.read<SupabaseService>();
  final userData = context.read<UserDataProvider>();
  final locations = context.read<LocationListManager>();
  final navigator = Navigator.of(context);

  try {
    final userId = wizardState.userId;
    if (userId == null) {
      throw Exception('User ID is required to complete onboarding');
    }

    await supabase.users.finalizeSignupWizard(
      userId,
      spiceTolerance: wizardState.spiceTolerance,
      dietaryTagIds: wizardState.selectedDietaryTagIds,
    );

    // Re-fetch so the first save made during onboarding shows on home and the
    // "no saved places" popover isn't driven by stale state.
    unawaited(locations.refreshSavedLocations());
    userData.setWizardCompleted(true);
    await WhatWeDoWizardService().markPending();
    await OnboardingResumeService().clear(userId);
    analytics.finished();

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthHandler()),
      (route) => false,
    );
    return true;
  } catch (_) {
    if (context.mounted) {
      await AppFeedback.showError(
        context,
        title: 'Setup failed',
        message: 'We’re working hard to fix this — sorry.',
      );
    }
    return false;
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:login/services/analytics_service.dart';
import 'package:login/services/fcm_service.dart';
import 'package:login/services/referral_prompt_service.dart';
import 'package:login/pages/bubbles_page.dart';
import 'package:login/pages/home_page.dart';
import 'package:login/pages/profile/profile_page.dart';
<<<<<<< Updated upstream
import 'package:login/providers/user_data_provider.dart';
import 'package:login/widgets/referral_code_dialog.dart';
=======
import 'package:login/services/referral_code_prompt_service.dart';
import 'package:login/services/what_we_do_wizard_service.dart';
import 'package:login/supabase/service.dart';
>>>>>>> Stashed changes
import 'package:login/widgets/navigation/bottom_nav_bar.dart';
import 'package:login/providers/navigation_provider.dart';
import 'package:login/providers/nav_bar/visibility_provider.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  NavigationProvider? _navigationProvider;
  final AnalyticsService _analyticsService = AnalyticsService();
<<<<<<< Updated upstream
  final ReferralPromptService _referralPromptService = ReferralPromptService();
=======
  final ReferralCodePromptService _referralCodePromptService =
      ReferralCodePromptService();
  final WhatWeDoWizardService _whatWeDoWizardService = WhatWeDoWizardService();
>>>>>>> Stashed changes
  bool _referralPromptScheduled = false;
  bool _referralPromptVisible = false;
  bool _referralPromptChecking = false;
  bool _referralPromptShownThisSession = false;
  Timer? _referralPromptRetryTimer;

  static const Duration _referralPromptRetryDelay = Duration(milliseconds: 800);

  static const Map<int, String> _tabNames = <int, String>{
    0: 'home',
    1: 'bubbles',
    2: 'profile',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationProvider = context.read<NavigationProvider>();
      _navigationProvider!.addListener(_handleNavigationRequest);
      context.read<BottomNavVisibilityProvider>().showTemporarily();
      FCMService().consumePendingInitialMessage();
      _analyticsService.trackScreen(_tabNames[_currentIndex] ?? 'home');
    });
  }

  @override
  void dispose() {
    _referralPromptRetryTimer?.cancel();
    _navigationProvider?.removeListener(_handleNavigationRequest);
    super.dispose();
  }

  void _handleNavigationRequest() {
    print('MainScreen listener fired!');
    if (_navigationProvider == null) return;
    if (_navigationProvider!.hasPendingNavigation) {
      final targetIndex = _navigationProvider!.pendingTabIndex;
      print('Navigating to tab: $targetIndex from current: $_currentIndex');
      _navigationProvider!.clearPendingNavigation();

      _setCurrentIndex(targetIndex, trigger: 'navigation_provider');
      print('Tab switched to: $_currentIndex');
    }
  }

  void _onIndexChanged(int index) {
    _setCurrentIndex(index, trigger: 'tap');
  }

<<<<<<< Updated upstream
=======
  void _scheduleReferralPrompt({Duration delay = Duration.zero}) {
    if (_referralPromptScheduled ||
        _referralPromptVisible ||
        _referralPromptChecking ||
        _referralPromptShownThisSession) {
      return;
    }
    _referralPromptScheduled = true;

    _referralPromptRetryTimer?.cancel();
    _referralPromptRetryTimer = Timer(delay, () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_showReferralPromptIfNeeded());
      });
    });
  }

  Future<void> _showReferralPromptIfNeeded() async {
    if (_referralPromptVisible ||
        _referralPromptChecking ||
        _referralPromptShownThisSession) {
      _referralPromptScheduled = false;
      return;
    }
    _referralPromptScheduled = false;
    _referralPromptChecking = true;

    final hasFinishedWhatWeDoWizard = await _whatWeDoWizardService.hasSeen();
    if (!hasFinishedWhatWeDoWizard) {
      _referralPromptChecking = false;
      _scheduleReferralPrompt(delay: _referralPromptRetryDelay);
      return;
    }

    final shouldShow = await _referralCodePromptService.shouldShowNow();
    if (!shouldShow || !mounted) {
      _referralPromptChecking = false;
      return;
    }

    try {
      final hasEnteredReferralCode = await context
          .read<SupabaseService>()
          .rewards
          .hasEnteredReferralCode();
      if (!mounted) {
        _referralPromptChecking = false;
        return;
      }

      if (hasEnteredReferralCode) {
        await _referralCodePromptService.markCompleted();
        _referralPromptChecking = false;
        return;
      }
    } catch (_) {
      _referralPromptChecking = false;
      return;
    }

    _referralPromptShownThisSession = true;
    await _referralCodePromptService.markCompleted();
    _referralPromptChecking = false;
    _referralPromptVisible = true;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return ReferralCodePromptSheet(
          onApply: (code) {
            return context.read<SupabaseService>().rewards.applyReferralCode(
                  code.trim(),
                  acceptIfWizardComplete: true,
                );
          },
        );
      },
    );

    if (mounted) {
      setState(() => _referralPromptVisible = false);
    }
  }

>>>>>>> Stashed changes
  void _setCurrentIndex(int nextIndex, {required String trigger}) {
    if (nextIndex == _currentIndex) return;

    final previous = _currentIndex;
    final previousName = _tabNames[previous] ?? 'unknown';
    final nextName = _tabNames[nextIndex] ?? 'unknown';

    setState(() {
      _currentIndex = nextIndex;
    });

    _analyticsService.trackTabSwitch(
      fromTab: previousName,
      toTab: nextName,
      trigger: trigger,
    );
    _analyticsService.trackScreen(nextName);
  }

  void _scheduleReferralPromptIfNeeded(UserDataProvider userDataProvider) {
    if (_referralPromptScheduled || _referralPromptVisible) return;

    final user = userDataProvider.supabaseUserData;
    final userId = user?.supabaseId;
    final referralCode = user?.referralCode?.trim();
    if (userId == null || userId.isEmpty) return;
    if (referralCode != null && referralCode.isNotEmpty) return;

    _referralPromptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showReferralPromptIfNeeded(userId);
    });
  }

  Future<void> _showReferralPromptIfNeeded(String userId) async {
    _referralPromptScheduled = false;
    if (!mounted || _referralPromptVisible) return;

    final userDataProvider = context.read<UserDataProvider>();
    final user = userDataProvider.supabaseUserData;
    final currentUserId = user?.supabaseId;
    final referralCode = user?.referralCode?.trim();
    if (currentUserId != userId) return;
    if (referralCode != null && referralCode.isNotEmpty) return;

    final shouldShow = await _referralPromptService.shouldShowForUser(userId);
    if (!mounted || !shouldShow) return;

    _referralPromptVisible = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return ReferralCodeDialog(
          onApply: (code) async {
            final ok =
                await context.read<UserDataProvider>().applyReferralCode(code);
            if (ok) {
              await _referralPromptService.markHandledForUser(userId);
            }
            return ok;
          },
          onDismiss: () => _referralPromptService.markHandledForUser(userId),
        );
      },
    );

    if (mounted) {
      setState(() => _referralPromptVisible = false);
    } else {
      _referralPromptVisible = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userDataProvider = context.watch<UserDataProvider>();
    _scheduleReferralPromptIfNeeded(userDataProvider);

    final pages = [
      HomePage(isActive: _currentIndex == 0),
      BubblesPage(isActive: _currentIndex == 1),
      ProfilePage(isActive: _currentIndex == 2),
    ];

    return Scaffold(
      extendBody: true,
      // Use a passive Listener (raw pointer events, never enters the gesture
      // arena) to wake the bottom nav. A GestureDetector with onPanDown here
      // would claim pan gestures and prevent the Mapbox MapWidget from
      // panning/dragging.
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) =>
            context.read<BottomNavVisibilityProvider>().showTemporarily(),
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onIndexChanged: _onIndexChanged,
      ),
    );
  }
}

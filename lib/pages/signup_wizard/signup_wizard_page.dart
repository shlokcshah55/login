import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/signup_wizard_state.dart';
import '../../models/locations.dart';
import '../../supabase/service.dart';
import '../../supabase/constants.dart';
import '../auth_handler.dart';
import '../profile/widgets/pinit_colors.dart';
import 'account_step.dart';
import 'steps/dietary_step.dart';
import 'steps/vibe_step.dart';
import 'steps/restaurant_swipe_step.dart';

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
  static const int _accountSubStepCount = 5;
  static const int _totalWizardUnits = _accountSubStepCount + 3;
  int _currentStep = 0;
  int _accountSubStep = 1; // Track account sub-steps (1-5)
  List<LocationModel>? _restaurants;
  bool _isLoadingRestaurants = false;
  bool _isCompletingWizard = false;

  final List<String> _stepTitles = [
    'Create Account', // After finishing this step we actually creates the account
    'Dietary Preferences',
    'Your Vibe',
    'Find Your Restaurants',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
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

  Future<void> _nextStepWithRestaurants(
      Future<List<LocationModel>> Function() fetchRestaurants) async {
    if (_currentStep < 3) {
      setState(() {
        _isLoadingRestaurants = true;
      });

      try {
        final restaurants = await fetchRestaurants();
        setState(() {
          _restaurants = restaurants;
          _isLoadingRestaurants = false;
        });

        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } catch (e) {
        setState(() {
          _isLoadingRestaurants = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load restaurants: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
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

      // Step 1: Save tags and spice tolerance in parallel
      final combinedTags = [
        ...wizardState.selectedDietaryTagIds,
        ...wizardState.selectedVibeTagIds,
      ];

      await Future.wait([
        if (combinedTags.isNotEmpty)
          supabase.users.addUserTags(wizardState.userId!, combinedTags),
        supabase.users.AddSpiceTolerance(
          wizardState.userId!,
          wizardState.spiceTolerance,
        ),
      ]);

      // Step 2: Process restaurant decisions in parallel
      final restaurantFutures = <Future>[];

      for (final entry in wizardState.restaurantDecisions.entries) {
        final locationId = entry.key;
        final saved = entry.value;

        if (saved) {
          restaurantFutures.add(supabase.locations.saveLocation(locationId,
              savedMethod: SupabaseConstants.savedMethodInApp));
        } else {
          restaurantFutures.add(supabase.locations.dislikeLocation(locationId));
        }
      }

      // Wait for all restaurant operations to complete
      if (restaurantFutures.isNotEmpty) {
        await Future.wait(restaurantFutures);
      }

      // Step 3: Mark wizard as complete
      await supabase.users.completeSignupWizard(wizardState.userId!);

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
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete setup: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
    // Note: Don't set _isCompletingWizard = false on success since we're navigating away
  }

  void _updateAccountSubStep(int subStep) {
    setState(() {
      _accountSubStep = subStep;
    });
  }

  double _calculateProgress() {
    if (_currentStep == 0) {
      return _accountSubStep / _totalWizardUnits;
    } else if (_currentStep == 1) {
      return _accountSubStepCount / _totalWizardUnits;
    } else if (_currentStep == 2) {
      return (_accountSubStepCount + 1) / _totalWizardUnits;
    } else if (_currentStep == 3) {
      return (_accountSubStepCount + 2) / _totalWizardUnits;
    }
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PinitColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _stepTitles[_currentStep],
                    style: const TextStyle(
                      fontFamily: 'Rova',
                      fontSize: 32,
                      fontWeight: FontWeight.w100,
                      color: PinitColors.aubergine,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: PinitColors.creamDeep,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutQuint,
                          width: constraints.maxWidth * _calculateProgress(),
                          decoration: BoxDecoration(
                            color: PinitColors.accent,
                            borderRadius: BorderRadius.circular(4),
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
                  AccountStep(
                    onNext: _nextStep,
                    onSubStepChanged: _updateAccountSubStep,
                  ),
                  DietaryStep(
                    onNext: _nextStep,
                    onBack: _previousStep,
                  ),
                  VibeStep(
                    onNext: _nextStep,
                    onBack: _previousStep,
                    onNextWithRestaurants: _nextStepWithRestaurants,
                    isLoadingRestaurants: _isLoadingRestaurants,
                  ),
                  RestaurantSwipeStep(
                    onBack: _previousStep,
                    onComplete: _completeWizard,
                    isCompleting: _isCompletingWizard,
                    restaurants: _restaurants ?? [],
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

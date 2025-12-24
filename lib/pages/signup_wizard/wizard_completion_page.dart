import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/signup_wizard_state.dart';
import '../../models/locations.dart';
import '../../supabase/service.dart';
import '../../supabase/supabase_client.dart';
import '../../supabase/constants.dart';
import '../auth_handler.dart';
import 'steps/dietary_step.dart';
import 'steps/vibe_step.dart';
import 'steps/restaurant_swipe_step.dart';

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
  State<_WizardCompletionContent> createState() => _WizardCompletionContentState();
}

class _WizardCompletionContentState extends State<_WizardCompletionContent> {
  final PageController _pageController = PageController();
  int _currentStep = 0; // 0 = Dietary, 1 = Vibe, 2 = Restaurant
  List<LocationModel>? _restaurants;
  bool _isLoadingRestaurants = false;
  bool _isCompletingWizard = false;

  final List<String> _stepTitles = [
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
    if (_currentStep < 2) {
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

  Future<void> _nextStepWithRestaurants(Future<List<LocationModel>> Function() fetchRestaurants) async {
    if (_currentStep < 2) {
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
      final wizardState = Provider.of<SignupWizardState>(context, listen: false);
      final supabase = Provider.of<SupabaseService>(context, listen: false);

      // Validate required data
      if (wizardState.userId == null) {
        throw Exception('User ID is required to complete wizard');
      }

      final userId = wizardState.userId!;

      print(wizardState.selectedVibeTagIds);
      // Add dietary tags and spice tolerance and update the vibe tags
      await supabase.users.addUserTags(userId, wizardState.selectedDietaryTagIds);
      await supabase.users.AddSpiceTolerance(
        userId,
        wizardState.spiceTolerance,
      );
      await supabase.tags.updateUserTagsPhotos(userId, wizardState.selectedVibeTagIds);


      // Step 2: Process restaurant decisions

      for (final entry in wizardState.restaurantDecisions.entries) {
        final locationId = entry.key;
        final saved = entry.value;

        if (saved) {
          await supabase.locations.saveLocation(
            locationId,
            savedMethod: SupabaseConstants.savedMethodInApp,
          );
          // CRITICAL: Update tag affinities (+8 weight)
          if (wizardState.userId != null) {
            await supabase.tags.updateUserTagsSaving(wizardState.userId!, locationId);
          }
        } else {
          await supabase.locations.dislikeLocation(locationId);
        }
      }


      // Step 3: Mark wizard as complete
      await supabase.users.completeSignupWizard(wizardState.userId!);

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
        ScaffoldMessenger.of(context).showSnackBar(
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

  double _calculateProgress() {
    // Total: 3 steps
    return (_currentStep + 1) / 3.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF42143d),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Close button
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutQuint,
                          width: constraints.maxWidth * _calculateProgress(),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _stepTitles[_currentStep],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Step ${_currentStep + 1} of 3',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Page Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe, use buttons
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

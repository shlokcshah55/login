import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/signup_wizard_state.dart';
import '../../models/locations.dart';
import 'steps/account_step.dart';
import 'steps/dietary_step.dart';
import 'steps/vibe_step.dart';
import 'steps/restaurant_swipe_step.dart';

class SignupWizardPage extends StatefulWidget {
  const SignupWizardPage({super.key});

  @override
  State<SignupWizardPage> createState() => _SignupWizardPageState();
}

class _SignupWizardPageState extends State<SignupWizardPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  List<LocationModel>? _restaurants;
  bool _isLoadingRestaurants = false;

  final List<String> _stepTitles = [
    'Create Account',
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

  Future<void> _nextStepWithRestaurants(Future<List<LocationModel>> Function() fetchRestaurants) async {
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

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SignupWizardState(),
      child: Scaffold(
        backgroundColor: const Color(0xFF6A1B9A), // Purple background
        body: SafeArea(
          child: Column(
            children: [
              // Progress Indicator
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: List.generate(
                        4,
                        (index) => Expanded(
                          child: Container(
                            margin: EdgeInsets.only(
                              left: index == 0 ? 0 : 4,
                              right: index == 3 ? 0 : 4,
                            ),
                            height: 4,
                            decoration: BoxDecoration(
                              color: index <= _currentStep
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
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
                      'Step ${_currentStep + 1} of 4',
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
                    AccountStep(onNext: _nextStep),
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
                      restaurants: _restaurants ?? [],
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

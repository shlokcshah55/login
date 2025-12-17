import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/signup_wizard_state.dart';
import '../../../models/locations.dart';
import '../../../supabase/service.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/swipe_card_stack.dart';
import '../../auth_handler.dart';

class RestaurantSwipeStep extends StatefulWidget {
  final VoidCallback onBack;
  final List<LocationModel> restaurants;

  const RestaurantSwipeStep({
    super.key,
    required this.onBack,
    required this.restaurants,
  });

  @override
  State<RestaurantSwipeStep> createState() => _RestaurantSwipeStepState();
}

class _RestaurantSwipeStepState extends State<RestaurantSwipeStep> {
  bool _isSaving = false;
  final GlobalKey<SwipeCardStackState> _swipeKey = GlobalKey();

  void _handleSwipe(LocationModel location, bool liked) {
    final wizardState = Provider.of<SignupWizardState>(context, listen: false);
    wizardState.recordRestaurantDecision(location.locationId, liked);
  }

  Future<void> _completeWizard() async {
    setState(() => _isSaving = true);

    try {
      final wizardState = Provider.of<SignupWizardState>(context, listen: false);
      final supabase = Provider.of<SupabaseService>(context, listen: false);

      final combinedTags = [
        ...wizardState.selectedDietaryTagIds,
        ...wizardState.selectedVibeTagIds,
      ];
      await supabase.users.addUserTags(wizardState.userId!, combinedTags);
      await supabase.users.AddSpiceTolerance(
        wizardState.userId!,
        wizardState.spiceTolerance,
      );
      
      final likedLocationIds = wizardState.likedRestaurantIds;
      if (likedLocationIds.isNotEmpty) {
        likedLocationIds.map(supabase.locations.likeLocation);
      }

      final dislikedLocationIds = wizardState.restaurantDecisions.entries
          .where((entry) => entry.value == false)
          .map((entry) => entry.key)
          .toList();
      if (dislikedLocationIds.isNotEmpty) {
        dislikedLocationIds.map(supabase.locations.dislikeLocation);
      }
      
      await supabase.users.completeSignupWizard(
        wizardState.userId!,
      );

      // Navigate to main app
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AuthHandler(),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                const Text(
                  'I want to show you restaurants that are my vibe',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Swipe right if you\'d go, left if not',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Swipe cards or empty state
          Expanded(
            child: widget.restaurants.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.restaurant_menu,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No restaurants available',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : SwipeCardStack(
                    key: _swipeKey,
                    locations: widget.restaurants,
                    onSwipe: _handleSwipe,
                    onComplete: () {
                      // Cards swiped, enable the complete button
                      setState(() {});
                    },
                  ),
          ),

          // Swipe buttons and navigation
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Swipe action buttons
                if (widget.restaurants.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pass button
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.red,
                            width: 2,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () => _swipeKey.currentState?.swipeLeft(),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.red,
                            size: 32,
                          ),
                          iconSize: 48,
                        ),
                      ),
                      const SizedBox(width: 48),
                      // Like button
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.green,
                            width: 2,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () => _swipeKey.currentState?.swipeRight(),
                          icon: const Icon(
                            Icons.favorite,
                            color: Colors.green,
                            size: 32,
                          ),
                          iconSize: 48,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 24),

                // Navigation buttons
                Row(
                  children: [
                    // Back button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : widget.onBack,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFF42143d)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Back',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF42143d),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Complete button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _completeWizard,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF42143d),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSaving
                            ? const LoadingWidget(width: 24, height: 24)
                            : const Text(
                                'Complete Setup',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

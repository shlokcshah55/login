import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/signup_wizard_state.dart';
import '../../../models/locations.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/swipe_card_stack.dart';
import '../../profile/widgets/pinit_colors.dart';

class RestaurantSwipeStep extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onComplete;
  final bool isCompleting;
  final List<LocationModel> restaurants;

  const RestaurantSwipeStep({
    super.key,
    required this.onBack,
    required this.onComplete,
    required this.isCompleting,
    required this.restaurants,
  });

  @override
  State<RestaurantSwipeStep> createState() => _RestaurantSwipeStepState();
}

class _RestaurantSwipeStepState extends State<RestaurantSwipeStep> {
  final GlobalKey<SwipeCardStackState> _swipeKey = GlobalKey();

  void _handleSwipe(LocationModel location, bool saved) {
    final wizardState = Provider.of<SignupWizardState>(context, listen: false);
    wizardState.recordRestaurantDecision(location.locationId, saved);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PinitColors.cream,
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
                    fontFamily: 'Rova',
                    fontSize: 28,
                    fontWeight: FontWeight.w100,
                    color: PinitColors.aubergine,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Swipe right if you\'d go, left if not',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    color: PinitColors.aubergineSoft,
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
                          color: PinitColors.mute,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No restaurants available',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            color: PinitColors.mute,
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
              color: PinitColors.cream,
              boxShadow: [
                BoxShadow(
                  color: PinitColors.aubergine.withValues(alpha: 0.06),
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
                            color: PinitColors.aubergine.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () => _swipeKey.currentState?.swipeLeft(),
                          icon: const Icon(
                            Icons.close,
                            color: PinitColors.aubergine,
                            size: 32,
                          ),
                          iconSize: 48,
                        ),
                      ),
                      const SizedBox(width: 48),
                      // Save button
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: PinitColors.accent,
                            width: 2,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () => _swipeKey.currentState?.swipeRight(),
                          icon: const Icon(
                            Icons.favorite,
                            color: PinitColors.accent,
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
                        onPressed: widget.isCompleting ? null : widget.onBack,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(
                            color: PinitColors.aubergine,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          'Back',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: PinitColors.aubergine,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Complete button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed:
                            widget.isCompleting ? null : widget.onComplete,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: PinitColors.aubergine,
                          foregroundColor: PinitColors.cream,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: widget.isCompleting
                            ? const LoadingWidget(width: 24, height: 24)
                            : Text(
                                'Complete Setup',
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
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

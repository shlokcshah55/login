import 'package:flutter/material.dart';
import 'package:login/animations/common_animations.dart';
import 'package:provider/provider.dart';
import '../../../models/signup_wizard_state.dart';
import '../../../models/locations.dart';
import '../../../supabase/service.dart';
import '../../../widgets/spinnable_tile.dart';

class VibeStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  final Future<void> Function(Future<List<LocationModel>> Function()) onNextWithRestaurants;
  final bool isLoadingRestaurants;

  const VibeStep({
    super.key,
    required this.onNext,
    required this.onBack,
    required this.onNextWithRestaurants,
    required this.isLoadingRestaurants,
  });

  @override
  State<VibeStep> createState() => _VibeStepState();
}

class _VibeStepState extends State<VibeStep> {
  // We'll derive the grid images from the `lib/assets/vibe` filenames.
  final Map<String, String> _imageNames = const {
  'brunchy.png' : 'Weekend brunchie - Trendy weekend spots with a lively, social atmosphere',
  'cozy.png': 'Quiet comfort - Warm, cozy spots with a relaxed atmosphere',
  'localSpot.png': 'No-fuss foodie - Comfortable quick-bite spots with a casual, welcoming vibe',
  'rooftop.jpg': 'Urban socialite - Trendy rooftop bars with skyline views',
  'rusticLocal.png': 'Rustic Local - Charming local spots with a homey, rustic feel',
  'upscaleGuy.png': 'High-end enthusiast - Sophisticated venues with upscale ambiance and fine dining',
  };

  final Map<String, List<String>> _imageTags = const {
    'brunchy.png' : [
      'brunch',
      'small-plates',
      'chef-owned',
      'outdoor-seating',
    ],
    'cozy.png': [
      'cafe',
      'quiet',
      'coffee-shop',
      'cozy',
      'modern'
    ],
    'localSpot.png': [
      'quick-bit',
      'diner',
      'takeout-friendly',
      'traditional'
    ],
    'rooftop.jpg': [
      'rooftop',
      'lively',
      'trendy',
      'craft-cocktails',
    ],
    'rusticLocal.png': [
      'rustic',
      'casual',
      'dog-friendly',
      'walk-ins-only'
    ],
    'upscaleGuy.png': [
      'fine-dining',
      'tasting-menu',
      'elegant',
      'special-occasion',
      'upscale'
    ],
  };

  final Set<String> _selected = <String>{};
  bool get _hasTwoSelected => _selected.length == 2;
  
  Future<void> _handleNext() async {
    if (!_hasTwoSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select exactly 2 items before continuing.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Map images to associated tags 
    List<String> selectedTags = _selected.map((name) => _imageTags[name]!).expand((tags) => tags).toList();

    // Persist the selections into the wizard state using basename ids.
    final wizardState = Provider.of<SignupWizardState>(context, listen: false);
    wizardState.setVibeTags(selectedTags);

    await _proceedToRestaurantStep();
  }

  Future<void> _proceedToRestaurantStep() async {
    // Call the recommendation function to fetch restaurants
    await widget.onNextWithRestaurants(() async {
      final supabase = Provider.of<SupabaseService>(context, listen: false);

      // TODO: Replace this with custom recommendation function
      final allLocations = await supabase.locations.getAllLocations();
      return allLocations.take(5).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
  // keep wizardState available via Provider where needed; we don't read it here directly

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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Small textbox-like hint area
                  TypingText(
                      text: 'Of these people, which 2 are you most commonly like? (hold for more info)',
                      style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    totalDuration: const Duration(milliseconds: 2200),
                  ),
                  

                  const SizedBox(height: 12),

                  // Grid of 6 images: 2 per row, 3 rows
                  // Portrait-oriented tiles that size naturally
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    // childAspectRatio = width / height; 0.75 makes tiles portrait-oriented
                    childAspectRatio: 0.75,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _imageNames.entries.map((entry) {
                      final name = entry.key;
                      final description = entry.value;
                      final id = name.split('.').first;
                      final assetPath = 'lib/assets/vibe/$name';
                      final selected = _selected.contains(name);

                      return SpinnableTile(
                        assetPath: assetPath,
                        title: id,
                        description: description,
                        isSelected: selected,
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selected.remove(name);
                            } else {
                              if (_selected.length < 2) {
                                _selected.add(name);
                              } else {
                                // show a small toast
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('You can only select exactly 2 items.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }

                            // Keep the wizard state in sync so other logic can read it
                            final wizardState = Provider.of<SignupWizardState>(context, listen: false);
                            wizardState.setVibeTags(_selected.toList());
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),

                  // Helper/counter text
                  Text(
                    '${_selected.length} / 2 selected',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _selected.length == 2 ? const Color(0xFF42143d) : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Navigation buttons
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
            child: Row(
              children: [
                // Back button
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onBack,
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
                // Next button
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (widget.isLoadingRestaurants || !_hasTwoSelected) ? null : _handleNext,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF42143d),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: widget.isLoadingRestaurants
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Loading restaurants...',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
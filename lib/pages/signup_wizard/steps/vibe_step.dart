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
      '5b50e311-533f-450b-b679-bb5009a1430a',
      '80b705b8-c158-4703-b775-b5c00f4fd622',
      '23849d6f-bfb1-4a9a-b02a-11f0357abc75',
      '412190b7-897f-4391-bdfb-205afab14e40',
    ],
    'cozy.png': [
      '73a5103f-84e4-4f04-89f7-eff560e44883',
      '0cc10eb4-6935-425e-b177-b528c669b18f',
      '85f83be2-8537-4a9d-94a5-1d5972fc243d',
      'a30e5b03-552a-4134-89d3-cc7bf45c86e0',
      
    ],
    'localSpot.png': [
      'c6d0d291-f782-4890-b703-7a250a53a0a3',
      'e07fea00-c562-46f2-a558-f2ea8d65c030',
      'dea683b2-5730-4a57-bdf5-c8c0e4a7f468',
      '3c3e37d9-9ae0-4201-b998-ceee79bd22e0'
    ],
    'rooftop.jpg': [
      '9144608d-669d-4944-ae16-0da81f8ddbb2',
      'c85dbbf9-abba-46e4-a1bc-d30a20ba660a',
      'ddfa5a36-ab39-4dc9-87bd-1c18a39a6b1e',
      '063f8f5b-79bd-4e5a-877e-934689660edb',
    ],
    'rusticLocal.png': [
      '362c3472-c713-45d0-9954-999271c772d6',
      '7f789b3e-ae55-4ac1-83fb-5ba3c785d793',
      '524d0710-f575-457d-8a9e-d00de696140d',
    ],
    'upscaleGuy.png': [
      '8960090a-0292-4635-995c-d47366f3b4af',
      '8625848c-d6b5-47ea-8069-e08103ac2d02',
      '4b107468-3693-4878-870d-f907b6924c2b',
      '76b42037-ff12-4536-a7fe-8a6063e95230',
      '878b661e-e245-4fab-95f3-fa5195162828'
      '5d6f988f-68bc-4ac3-bec1-70613f07ed01',
      
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

    await _proceedToRestaurantStep();
  }

  Future<void> _proceedToRestaurantStep() async {
    // Map images to associated tags
    List<String> selectedTags = _selected.map((name) => _imageTags[name]!).expand((tags) => tags).toList();

    // Capture BOTH providers before the async callback (from child widget context)
    final supabase = Provider.of<SupabaseService>(context, listen: false);
    final wizardState = Provider.of<SignupWizardState>(context, listen: false);

    // Persist the selections into the wizard state
    wizardState.setVibeTags(selectedTags);

    // if (wizardState.userId != null && wizardState.selectedVibeTagIds.isNotEmpty) {
    //     await supabase.tags.updateUserTagsPhotos(
    //       wizardState.userId!,
    //       wizardState.selectedVibeTagIds,
    //     );
    //   }

    // Call the recommendation function to fetch restaurants
    await widget.onNextWithRestaurants(() async {
    
      // TODO: Replace this with custom recommendation function
      final allLocations = await supabase.locations.getFiveLocations();
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
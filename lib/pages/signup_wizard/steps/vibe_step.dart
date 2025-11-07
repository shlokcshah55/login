import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/signup_wizard_state.dart';
import '../../../models/locations.dart';
import '../../../supabase/service.dart';
import '../../../widgets/loading_widget.dart';

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
  bool _isLoading = true;
  List<Map<String, dynamic>> _vibeTags = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVibeTags();
  }

  Future<void> _loadVibeTags() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final supabase = Provider.of<SupabaseService>(context, listen: false);
      final tags = await supabase.tags.getVibeTags();

      setState(() {
        _vibeTags = tags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load vibe tags: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleNext() async {
    final wizardState = Provider.of<SignupWizardState>(context, listen: false);

    if (wizardState.selectedVibeTagIds.isEmpty) {
      // Show warning but allow to proceed
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No vibes selected'),
          content: const Text(
            'Are you sure you want to continue without selecting any vibes? '
            'We recommend selecting at least a few to get better restaurant recommendations.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _proceedToRestaurantStep();
              },
              child: const Text('Continue Anyway'),
            ),
          ],
        ),
      );
    } else {
      await _proceedToRestaurantStep();
    }
  }

  Future<void> _proceedToRestaurantStep() async {
    // Call the recommendation function to fetch restaurants
    await widget.onNextWithRestaurants(() async {
      final supabase = Provider.of<SupabaseService>(context, listen: false);

      // TODO: Replace this with your custom recommendation function
      // This is a placeholder that fetches the first 5 restaurants
      // You should replace this with your personalized recommendation logic
      final allLocations = await supabase.locations.getAllLocations();
      print(allLocations);
      return allLocations.take(5).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wizardState = Provider.of<SignupWizardState>(context);
    final selectedCount = wizardState.selectedVibeTagIds.length;
    final canAddMore = wizardState.canAddMoreVibeTags();

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
            child: _isLoading
                ? const Center(child: LoadingWidget())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadVibeTags,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),

                            // Title
                            const Text(
                              'What\'s your vibe?',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select up to 10 vibes that match your style',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Counter
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selectedCount >= 10
                                    ? Colors.orange.shade100
                                    : const Color(0xFF6A1B9A).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$selectedCount / 10 selected',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: selectedCount >= 10
                                      ? Colors.orange.shade900
                                      : const Color(0xFF6A1B9A),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Vibe tags
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _vibeTags.map((tag) {
                                final tagId = tag['tag_id'] as String;
                                final isSelected = wizardState
                                    .selectedVibeTagIds
                                    .contains(tagId);

                                return FilterChip(
                                  label: Text(tag['text'] as String),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (!selected || canAddMore || isSelected) {
                                      wizardState.toggleVibeTag(tagId);
                                    } else {
                                      // Show message when limit reached
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Maximum 10 vibes can be selected',
                                          ),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  backgroundColor: Colors.grey.shade100,
                                  selectedColor: const Color(0xFF6A1B9A)
                                      .withOpacity(0.2),
                                  checkmarkColor: const Color(0xFF6A1B9A),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF6A1B9A)
                                        : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isSelected
                                          ? const Color(0xFF6A1B9A)
                                          : Colors.grey.shade300,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 40),
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
                      side: const BorderSide(color: Color(0xFF6A1B9A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6A1B9A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Next button
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_isLoading || widget.isLoadingRestaurants) ? null : _handleNext,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF6A1B9A),
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

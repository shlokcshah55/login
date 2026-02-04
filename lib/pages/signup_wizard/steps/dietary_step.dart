
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/signup_wizard_state.dart';
import '../../../supabase/service.dart';
import '../../../widgets/loading_widget.dart';

class DietaryStep extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const DietaryStep({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<DietaryStep> createState() => _DietaryStepState();
}

class _DietaryStepState extends State<DietaryStep> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _dietaryTags = [];
  String? _error;

  final List<String> _spiceLabels = [
    'Salt and Pepper\n(maybe) pls',
    'I sometimes get medium\n(if milk nearby)',
    'I like to think\nim above average',
    'I ask for "spicy"\nat ethnic restaurants',
    'If i can\'t handle spice\nit affects my ego',
  ];

  @override
  void initState() {
    super.initState();
    _loadDietaryTags();
  }

  Future<void> _loadDietaryTags() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final supabase = Provider.of<SupabaseService>(context, listen: false);
      final tags = await supabase.tags.getDietaryRequirementTags();

      setState(() {
        _dietaryTags = tags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load dietary tags: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Need to listen to wizardState to rebuild when tags are selected/deselected
    final wizardState = Provider.of<SignupWizardState>(context);

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
                              onPressed: _loadDietaryTags,
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
                              'Tell us about your dietary needs',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select all that apply (optional)',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Dietary tags
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _dietaryTags.map((tag) {
                                final tagId = tag['tag_id'] as String;
                                final isSelected = wizardState.selectedDietaryTagIds
                                    .contains(tagId);

                                return FilterChip(
                                  label: Text(tag['text'] as String),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    wizardState.toggleDietaryTag(tagId);
                                  },
                                  backgroundColor: tag['colour'] != null
                                      ? Color(int.parse(tag['colour'].toString().replaceAll('#', '0xFF')))
                                      : Colors.grey.shade100,
                                  selectedColor: const Color(0xFF42143d)
                                      .withOpacity(0.2),
                                  checkmarkColor: const Color(0xFF42143d),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF42143d)
                                        : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isSelected
                                          ? const Color(0xFF42143d)
                                          : Colors.grey.shade300,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 40),

                            // Spice tolerance section
                            const Text(
                              'How much spice can you handle?',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Spice level indicator
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF42143d).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _spiceLabels[wizardState.spiceTolerance - 1],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF42143d),
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Spice slider
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF42143d),
                                inactiveTrackColor:
                                    const Color(0xFF42143d).withOpacity(0.2),
                                thumbColor: const Color(0xFF42143d),
                                overlayColor:
                                    const Color(0xFF42143d).withOpacity(0.2),
                                trackHeight: 8,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 14,
                                ),
                              ),
                              child: Slider(
                                value: wizardState.spiceTolerance.toDouble(),
                                min: 1,
                                max: 5,
                                divisions: 4,
                                onChanged: (value) {
                                  wizardState.setSpiceTolerance(value.toInt());
                                },
                              ),
                            ),

                            // Level indicators
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  5,
                                  (index) => Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: wizardState.spiceTolerance ==
                                              (index + 1)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: wizardState.spiceTolerance ==
                                              (index + 1)
                                          ? const Color(0xFF42143d)
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
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
                    onPressed: _isLoading ? null : widget.onNext,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF42143d),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
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

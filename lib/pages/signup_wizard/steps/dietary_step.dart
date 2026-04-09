
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/signup_wizard_state.dart';
import '../../../supabase/service.dart';
import '../../../widgets/loading_widget.dart';
import '../../profile/widgets/pinit_colors.dart';

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
        color: PinitColors.cream,
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
                              style: GoogleFonts.dmSans(color: PinitColors.accent),
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
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title at the top
                            const Text(
                              'Dietary Preferences',
                              style: TextStyle(
                                fontFamily: 'Rova',
                                fontSize: 32,
                                fontWeight: FontWeight.w100,
                                color: PinitColors.aubergine,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Subtitle with avatar
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SvgPicture.asset(
                                  'lib/assets/illustrations/Avatars - Default.svg',
                                  width: 48,
                                  height: 48,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tell us about your dietary needs',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 15,
                                          color: PinitColors.aubergine,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Select all that apply (optional)',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 13,
                                          color: PinitColors.aubergineSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Dietary tags with shadow styling
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _dietaryTags.map((tag) {
                                final tagId = tag['tag_id'] as String;
                                final isSelected = wizardState.selectedDietaryTagIds
                                    .contains(tagId);
                                final tagColor = tag['colour'] != null
                                    ? Color(int.parse(tag['colour'].toString().replaceAll('#', '0xFF')))
                                    : PinitColors.creamSunk;

                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: PinitColors.aubergine,
                                        blurRadius: 0,
                                        offset: const Offset(3, 3),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: isSelected ? tagColor : tagColor,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      onTap: () {
                                        wizardState.toggleDietaryTag(tagId);
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isSelected)
                                              Padding(
                                                padding: const EdgeInsets.only(right: 6),
                                                child: Icon(
                                                  Icons.check,
                                                  size: 16,
                                                  color: PinitColors.aubergine,
                                                ),
                                              ),
                                            Text(
                                              tag['text'] as String,
                                              style: GoogleFonts.dmSans(
                                                fontSize: 14,
                                                color: PinitColors.aubergine,
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 16),

                            // Spice tolerance section
                            const Text(
                              'How much spice can you handle?',
                              style: TextStyle(
                                fontFamily: 'Rova',
                                fontSize: 24,
                                fontWeight: FontWeight.w100,
                                color: PinitColors.aubergine,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Spice level indicator
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: PinitColors.aubergine.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _spiceLabels[wizardState.spiceTolerance - 1],
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: PinitColors.aubergine,
                                    height: 1.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Spice slider
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: PinitColors.accent,
                                inactiveTrackColor: PinitColors.creamDeep,
                                thumbColor: PinitColors.accent,
                                overlayColor: PinitColors.accent.withValues(alpha: 0.2),
                                trackHeight: 6,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 12,
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
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  5,
                                  (index) => Text(
                                    '${index + 1}',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      fontWeight: wizardState.spiceTolerance ==
                                              (index + 1)
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      color: wizardState.spiceTolerance ==
                                              (index + 1)
                                          ? PinitColors.aubergine
                                          : PinitColors.mute,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Row(
              children: [
                // Back button
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onBack,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PinitColors.aubergine,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Next button
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : widget.onNext,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: PinitColors.aubergine,
                      foregroundColor: PinitColors.cream,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
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

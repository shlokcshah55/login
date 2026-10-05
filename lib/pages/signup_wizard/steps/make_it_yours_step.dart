import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../models/signup_wizard_state.dart';
import '../../../services/onboarding_analytics.dart';
import '../../../supabase/service.dart';
import '../../../widgets/onboarding/onboarding_headline.dart';
import '../../profile/widgets/pinit_colors.dart';
import 'dietary_step.dart';
import 'vibe_options.dart';

/// Onboarding step 2 (optional): pick up to two vibes plus dietary needs and
/// spice tolerance on one screen. Skipping leaves the server defaults.
class MakeItYoursStep extends StatefulWidget {
  const MakeItYoursStep({
    super.key,
    required this.analytics,
    required this.onDone,
    required this.onSkip,
  });

  final OnboardingAnalytics analytics;
  final VoidCallback onDone;
  final VoidCallback onSkip;

  @override
  State<MakeItYoursStep> createState() => _MakeItYoursStepState();
}

class _MakeItYoursStepState extends State<MakeItYoursStep> {
  final Set<int> _selected = <int>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.analytics.viewed(OnboardingStep.preferences);
  }

  void _toggle(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(index)) {
        if (_selected.length >= 2) {
          _selected.remove(_selected.first);
        }
        _selected.add(index);
      }
    });
  }

  Future<void> _continue() async {
    if (_saving) return;
    setState(() => _saving = true);
    final wizardState = context.read<SignupWizardState>();
    final supabase = context.read<SupabaseService>();
    final tagIds = [
      for (final i in _selected) ...kVibeOptions[i].tagIds,
    ];
    if (tagIds.isNotEmpty) {
      wizardState.setVibeTags(tagIds.take(10).toList());
      final userId = wizardState.userId;
      if (userId != null) {
        // Best effort: a failed vibe write must not block onboarding.
        await supabase.tags.updateUserTagsPhotos(userId, tagIds);
      }
    }
    widget.analytics.completed(OnboardingStep.preferences);
    if (mounted) widget.onDone();
  }

  void _skip() {
    context.read<SignupWizardState>()
      ..setDietaryTags(const [])
      ..setSpiceTolerance(3);
    widget.analytics.skipped(OnboardingStep.preferences);
    widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PinitColors.surfaceLight,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: OnboardingHeadline(text: 'Make it yours'),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Optional. Helps us rank places for you.',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PinitColors.aubergineSoft,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel('PICK UP TO TWO VIBES'),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.05,
                      children: [
                        for (var i = 0; i < kVibeOptions.length; i++)
                          _VibeCard(
                            option: kVibeOptions[i],
                            selected: _selected.contains(i),
                            onTap: () => _toggle(i),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel('ANYTHING WE SHOULD AVOID?'),
                    const SizedBox(height: 10),
                    DietaryStep(
                      embedded: true,
                      onNext: () {},
                      onBack: () {},
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : _skip,
                    child: Text(
                      'SKIP',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: PinitColors.mute,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _saving ? null : _continue,
                        style: FilledButton.styleFrom(
                          backgroundColor: PinitColors.aubergine,
                          foregroundColor: PinitColors.cream,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'CONTINUE',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.3,
        color: PinitColors.aubergineSoft,
      ),
    );
  }
}

class _VibeCard extends StatelessWidget {
  const _VibeCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final VibeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(
          selected ? 2 : 0,
          selected ? 2 : 0,
          0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: PinitColors.aubergine,
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? PinitColors.accent : PinitColors.aubergine,
              blurRadius: 0,
              offset: selected ? const Offset(1, 1) : const Offset(3, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(option.asset, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      PinitColors.aubergine.withValues(alpha: 0),
                      PinitColors.aubergine.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.title,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: PinitColors.cream,
                      ),
                    ),
                    Text(
                      option.blurb,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: PinitColors.cream.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: PinitColors.accent,
                    child: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: PinitColors.cream,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

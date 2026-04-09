import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/home_view_model.dart';
import 'package:login/pages/home/quick_picks/quick_picks_deck_page.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/themes/app_typography.dart';

/// Step 1 of Quick Picks — let the user pick how far they're willing to
/// walk, then fetch recommendations and hand them to the deck page.
///
/// Pinit styled: cream surface, aubergine ink, filled-pill primary CTA.
class QuickPicksDistancePage extends StatefulWidget {
  const QuickPicksDistancePage({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  State<QuickPicksDistancePage> createState() => _QuickPicksDistancePageState();
}

class _QuickPicksDistancePageState extends State<QuickPicksDistancePage> {
  double _minutes = 15;
  bool _loading = false;

  Future<void> _onFindPlaces() async {
    if (_loading) return;
    setState(() => _loading = true);

    final List<LocationModel> picks =
        await widget.viewModel.requestQuickPicks(_minutes);

    if (!mounted) return;

    if (picks.isEmpty) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No places found within that range — try widening the radius.',
            style: AppTypography.sans(
              fontSize: 13,
              color: PinitColors.cream,
            ),
          ),
          backgroundColor: PinitColors.aubergine,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => QuickPicksDeckPage(
          viewModel: widget.viewModel,
          locations: picks,
          walkingMinutes: _minutes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double approxKm = (_minutes * 5.0) / 60.0;

    return Scaffold(
      backgroundColor: PinitColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar: close + eyebrow ─────────────────
              Row(
                children: [
                  _CircleIconButton(
                    icon: FeatherIcons.x,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    'QUICK PICKS',
                    style: AppTypography.sans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: PinitColors.aubergineSoft,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 28),

              // ── Headline ─────────────────────────────────
              Text(
                'How far do you\nwant to walk?',
                style: AppTypography.brand(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: PinitColors.aubergine,
                  height: 1.02,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pick a walking budget — we\'ll deal you a deck of\nnearby places to swipe through.',
                style: AppTypography.sans(
                  fontSize: 14,
                  color: PinitColors.aubergineSoft,
                  height: 1.45,
                ),
              ),

              const Spacer(),

              // ── Distance readout card ────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: PinitColors.creamSunk,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: PinitColors.creamDeep,
                    width: 1.5,
                  ),
                  boxShadow: PinitColors.subtleShadow,
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_minutes.round()}',
                          style: AppTypography.brand(
                            fontSize: 84,
                            fontWeight: FontWeight.w700,
                            color: PinitColors.aubergine,
                            height: 0.9,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            'MIN',
                            style: AppTypography.sans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: PinitColors.aubergineSoft,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '~${approxKm.toStringAsFixed(1)} km away',
                      style: AppTypography.sans(
                        fontSize: 13,
                        color: PinitColors.mute,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: PinitColors.aubergine,
                        inactiveTrackColor:
                            PinitColors.aubergine.withValues(alpha: 0.15),
                        thumbColor: PinitColors.accent,
                        overlayColor:
                            PinitColors.accent.withValues(alpha: 0.15),
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 12,
                        ),
                      ),
                      child: Slider(
                        value: _minutes,
                        min: 5,
                        max: 30,
                        divisions: 25,
                        onChanged: _loading
                            ? null
                            : (v) => setState(() => _minutes = v),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '5 min',
                          style: AppTypography.sans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: PinitColors.mute,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          '30 min',
                          style: AppTypography.sans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: PinitColors.mute,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Primary CTA — filled pinit pill ──────────
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _loading ? null : _onFindPlaces,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: PinitColors.aubergine,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: PinitColors.aubergine,
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: PinitColors.aubergine,
                            blurRadius: 0,
                            offset: Offset(3, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    PinitColors.cream,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'DEAL THE DECK',
                                    style: AppTypography.sans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: PinitColors.cream,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(
                                    FeatherIcons.arrowRight,
                                    size: 16,
                                    color: PinitColors.cream,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            shape: BoxShape.circle,
            border: Border.all(
              color: PinitColors.creamDeep,
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: PinitColors.aubergine,
          ),
        ),
      ),
    );
  }
}

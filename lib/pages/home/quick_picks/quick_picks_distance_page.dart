import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/home_view_model.dart';
import 'package:login/pages/home/quick_picks/quick_picks_deck_page.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/themes/app_typography.dart';

/// Quick Picks walking-range chooser shown as a lightweight modal overlay.
class QuickPicksDistancePage extends StatefulWidget {
  const QuickPicksDistancePage({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  static Future<void> show(
    BuildContext context, {
    required HomeViewModel viewModel,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: PinitColors.aubergine.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, _, __) => QuickPicksDistancePage(viewModel: viewModel),
      transitionBuilder: (ctx, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.96,
              end: 1,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<QuickPicksDistancePage> createState() => _QuickPicksDistancePageState();
}

class _QuickPicksDistancePageState extends State<QuickPicksDistancePage> {
  double _minutes = 15;
  bool _loading = false;

  Future<void> _onDealDeck() async {
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
            'No places found within that range. Try widening the walk.',
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
    final approxKm = (_minutes * 5.0) / 60.0;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              decoration: BoxDecoration(
                color: PinitColors.cream,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: PinitColors.creamDeep,
                  width: 1.5,
                ),
                boxShadow: PinitColors.elevatedShadow,
              ),
              child: SafeArea(
                minimum: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: PinitColors.creamDeep,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QUICK PICKS',
                                style: AppTypography.sans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: PinitColors.aubergineSoft,
                                  letterSpacing: 1.32,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Walking range.',
                                style: AppTypography.brand(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: PinitColors.aubergine,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _CloseButton(
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 22,
                      ),
                      decoration: BoxDecoration(
                        color: PinitColors.cream,
                        borderRadius: BorderRadius.circular(24),
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
                      child: Column(
                        children: [
                          Text(
                            'WALKING RANGE',
                            style: AppTypography.sans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: PinitColors.aubergineSoft,
                              letterSpacing: 1.32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${_minutes.round()}',
                                style: AppTypography.brand(
                                  fontSize: 74,
                                  fontWeight: FontWeight.w800,
                                  color: PinitColors.aubergine,
                                  height: 0.9,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'MIN',
                                  style: AppTypography.sans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
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
                              fontWeight: FontWeight.w600,
                              color: PinitColors.mute,
                            ),
                          ),
                          const SizedBox(height: 20),
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
                                  : (value) => setState(() => _minutes = value),
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
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: _loading ? null : _onDealDeck,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          PinitColors.cream,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'DEAL THE DECK',
                                      style: AppTypography.sans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: PinitColors.cream,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: PinitColors.creamDeep,
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 18,
            color: PinitColors.aubergine,
          ),
        ),
      ),
    );
  }
}

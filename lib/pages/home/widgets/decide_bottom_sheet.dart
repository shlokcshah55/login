import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/themes/app_typography.dart';

/// Bottom sheet shown when the user taps the Decide chip.
class DecideBottomSheet extends StatelessWidget {
  final VoidCallback onQuickPicks;
  final VoidCallback onSweetTreat;

  const DecideBottomSheet({
    Key? key,
    required this.onQuickPicks,
    required this.onSweetTreat,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onQuickPicks,
    required VoidCallback onSweetTreat,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: PinitColors.aubergine.withValues(alpha: 0.18),
      isScrollControlled: true,
      builder: (_) => DecideBottomSheet(
        onQuickPicks: onQuickPicks,
        onSweetTreat: onSweetTreat,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: PinitColors.cream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: PinitColors.creamDeep,
          width: 1.5,
        ),
        boxShadow: PinitColors.elevatedShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
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
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'Just decide',
                  style: AppTypography.brand(
                    fontSize: 22,
                    fontWeight: FontWeight.w100,
                    color: PinitColors.aubergine,
                    letterSpacing: 0.3,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'Sometimes in life, you just cba and want somewhere quickly. That doesnt mean you should compromise',
                  style: AppTypography.sans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: PinitColors.aubergineSoft,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _DecideOption(
                        eyebrow: 'GAVEL',
                        label: 'Deal a deck',
                        subtitle: 'We give you 5 of the best nearby options. Just pick one and go!',
                        illustrationPath:
                            'lib/assets/illustrations/hot_dog_stand.svg',
                        onTap: () {
                          Navigator.pop(context);
                          onQuickPicks();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DecideOption(
                        eyebrow: 'SWEET TREAT',
                        label: 'Find dessert first',
                        subtitle: 'Show all sweet treats near you right now.',
                        illustrationPath:
                            'lib/assets/illustrations/Beep Beep - Food Van.svg',
                        filled: true,
                        onTap: () {
                          Navigator.pop(context);
                          onSweetTreat();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: bottomInset + 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _DecideOption extends StatelessWidget {
  final String eyebrow;
  final String label;
  final String subtitle;
  final String illustrationPath;
  final bool filled;
  final VoidCallback onTap;

  const _DecideOption({
    required this.eyebrow,
    required this.label,
    required this.subtitle,
    required this.illustrationPath,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shadowColor = filled ? PinitColors.black : PinitColors.aubergine;
    final backgroundColor = filled ? PinitColors.aubergine : PinitColors.cream;
    final borderColor = filled ? PinitColors.cream : PinitColors.aubergine;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 0,
            offset: const Offset(3, 3),
          ),
        ],
      ),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: filled
              ? PinitColors.cream.withValues(alpha: 0.08)
              : PinitColors.aubergine.withValues(alpha: 0.06),
          highlightColor: filled
              ? PinitColors.cream.withValues(alpha: 0.05)
              : PinitColors.aubergine.withValues(alpha: 0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: SizedBox(
                    height: 92,
                    child: SvgPicture.asset(
                      illustrationPath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  eyebrow,
                  style: AppTypography.sans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: filled
                        ? PinitColors.cream.withValues(alpha: 0.8)
                        : PinitColors.aubergineSoft,
                    letterSpacing: 1.2,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: AppTypography.brand(
                    fontSize: 18,
                    fontWeight: FontWeight.w100,
                    color: filled ? PinitColors.cream : PinitColors.aubergine,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: AppTypography.sans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: filled
                        ? PinitColors.cream.withValues(alpha: 0.9)
                        : PinitColors.mute,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

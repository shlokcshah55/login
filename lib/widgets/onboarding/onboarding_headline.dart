import 'package:flutter/material.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/themes/app_typography.dart';

/// Static, legible prompt for onboarding screens. Manrope ExtraBold replaces
/// the old Rova typing animation (Rova ships one weight, so the w100 prompts
/// rendered hairline-thin). Fades and slides in once; restart it by giving the
/// widget a new key.
class OnboardingHeadline extends StatelessWidget {
  const OnboardingHeadline({
    super.key,
    required this.text,
    this.fontSize = 26,
    this.color = PinitColors.aubergine,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final double fontSize;
  final Color color;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
      ),
      child: Text(
        text,
        textAlign: textAlign,
        style: AppTypography.sans(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: -0.2,
          height: 1.15,
        ),
      ),
    );
  }
}

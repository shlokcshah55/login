import 'package:flutter/material.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/themes/pinit_colors.dart';

/// Explains background nudges before iOS shows its one-shot "Always" prompt.
/// Resolves to true when the user chooses to turn them on.
Future<bool?> showProximityPrimingSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ProximityPrimingSheet(),
  );
}

class ProximityPrimingSheet extends StatelessWidget {
  const ProximityPrimingSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<PinitColors>() ??
        (theme.brightness == Brightness.dark
            ? PinitColors.dark
            : PinitColors.light);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'NEARBY',
            style: AppTypography.sans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Get a nudge when you're near a place you saved",
            style: AppTypography.headingLarge.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'When you walk past a spot from a TikTok or Instagram you saved, '
            'Pinit can tell you, even when the app is closed. '
            'Next, iOS will ask to let Pinit use your location "Always".',
            style: AppTypography.sans(
              fontSize: 15,
              height: 1.45,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Nearby places are matched on your phone. Your location never '
            'leaves it.',
            style: AppTypography.sans(
              fontSize: 13,
              height: 1.4,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primaryPurple,
                foregroundColor: colors.textOnPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
                textStyle: AppTypography.sans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Turn on nudges'),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: colors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: AppTypography.sans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Not now'),
            ),
          ),
        ],
      ),
    );
  }
}

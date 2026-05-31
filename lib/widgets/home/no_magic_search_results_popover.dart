import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/themes/app_typography.dart';

class NoMagicSearchResultsPopover extends StatelessWidget {
  const NoMagicSearchResultsPopover({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 390,
            maxHeight: size.height * 0.66,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: PinitColors.cream,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: PinitColors.aubergine.withValues(alpha: 0.12),
                ),
                boxShadow: PinitColors.elevatedShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.of(context).pop(),
                        child: Ink(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: PinitColors.creamSunk,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color:
                                  PinitColors.aubergine.withValues(alpha: 0.10),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: PinitColors.aubergine,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'We said niche...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Rova',
                        fontFamilyFallback: ['Naria'],
                        fontSize: 28,
                        fontWeight: FontWeight.w100,
                        color: PinitColors.aubergine,
                        letterSpacing: 1.4,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 190,
                      child: SvgPicture.asset(
                        'lib/assets/illustrations/Brazuca - Browsing.svg',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "but that's a bit too niche for your area, try searching something else",
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge.copyWith(
                        color: PinitColors.aubergine,
                        height: 1.55,
                        fontWeight: FontWeight.w600,
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

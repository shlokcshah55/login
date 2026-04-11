import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;

class NoRecommendationsPopover extends StatelessWidget {
  const NoRecommendationsPopover({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 380,
          maxHeight: size.height * 0.58,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: pinit.PinitColors.cream,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: pinit.PinitColors.aubergine.withValues(alpha: 0.14),
              ),
              boxShadow: pinit.PinitColors.elevatedShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Oops, we couldn't find places you're worthy of",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Rova',
                      fontSize: 26,
                      fontWeight: FontWeight.w100,
                      color: pinit.PinitColors.aubergine,
                      letterSpacing: 1.7,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 210,
                    child: SvgPicture.asset(
                      'lib/assets/illustrations/login_svg1.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

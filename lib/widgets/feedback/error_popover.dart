import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../pages/profile/widgets/pinit_colors.dart' as pinit;

class ErrorPopover extends StatelessWidget {
  const ErrorPopover({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  final String title;
  final String message;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 392,
          maxHeight: size.height * 0.58,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: pinit.PinitColors.cream,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: pinit.PinitColors.aubergine.withValues(alpha: 0.14),
                ),
                boxShadow: pinit.PinitColors.elevatedShadow,
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 28),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Rova',
                            fontSize: 26,
                            fontWeight: FontWeight.w100,
                            color: pinit.PinitColors.aubergine,
                            letterSpacing: 1.6,
                            height: 1.05,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 188,
                          child: SvgPicture.asset(
                            'lib/assets/illustrations/error_popover.svg',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color: pinit.PinitColors.aubergine
                                .withValues(alpha: 0.74),
                            decoration: TextDecoration.none,
                          ),
                        ),
                        if (primaryActionLabel != null &&
                            onPrimaryAction != null) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: pinit.PinitColors.aubergine,
                                foregroundColor: pinit.PinitColors.cream,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                onPrimaryAction?.call();
                              },
                              child: Text(
                                primaryActionLabel!,
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: pinit.PinitColors.aubergine
                            .withValues(alpha: 0.06),
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: pinit.PinitColors.aubergine,
                      ),
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

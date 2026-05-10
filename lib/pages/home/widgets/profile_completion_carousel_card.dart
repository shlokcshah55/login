import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/providers/navigation_provider.dart';
import 'package:login/services/profile_completion_checklist_service.dart';
import 'package:provider/provider.dart';

class ProfileCompletionCarouselCard extends StatelessWidget {
  final bool isCollapsed;
  final ProfileCompletionChecklistState? state;

  const ProfileCompletionCarouselCard({
    super.key,
    required this.isCollapsed,
    required this.state,
  });

  static const _borderWidth = 2.2;
  static const _cardRadius = 10.0;
  static const _innerRadius = 8.5;
  static const _microRadius = 8.0;

  @override
  Widget build(BuildContext context) {
    final checklistState = state;
    final done = checklistState?.completedCount ?? 0;
    final badgeText = checklistState == null ? '--/4' : '$done/4';

    return LayoutBuilder(
      builder: (context, constraints) {
        // When bottom nav is visible, the carousel height is smaller
        // (see LocationCarousel). Treat that layout as "compact".
        final isCompact = constraints.maxHeight <= 190;
        final effectiveCompact = isCompact || isCollapsed;
        final verticalPadding = effectiveCompact ? 10.0 : 12.0;
        final rowGap = effectiveCompact ? 8.0 : 10.0;
        final footerGap = effectiveCompact ? 8.0 : 10.0;

        return Container(
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(_cardRadius),
            border: Border.all(
              color: PinitColors.aubergine,
              width: _borderWidth,
            ),
            boxShadow: const [
              BoxShadow(
                color: PinitColors.aubergine,
                blurRadius: 0,
                offset: Offset(5, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_innerRadius),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                verticalPadding,
                14,
                verticalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: PinitColors.teal,
                          borderRadius: BorderRadius.circular(_microRadius),
                          border: Border.all(
                            color: PinitColors.aubergine,
                            width: 1.6,
                          ),
                        ),
                        child: Text(
                          'SETUP',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 10 * 0.16,
                            color: PinitColors.aubergine,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: checklistState?.isComplete == true
                              ? PinitColors.teal
                              : PinitColors.accent,
                          borderRadius: BorderRadius.circular(_microRadius),
                          border: Border.all(
                            color: PinitColors.aubergine,
                            width: 1.6,
                          ),
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: PinitColors.cream,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: rowGap),
                  if (isCollapsed)
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: PinitColors.creamDeep,
                            borderRadius: BorderRadius.circular(_microRadius),
                            border: Border.all(
                              color: PinitColors.aubergine,
                              width: 1.4,
                            ),
                          ),
                          child: const Icon(
                            Icons.checklist_rounded,
                            size: 16,
                            color: PinitColors.aubergine,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            checklistState?.isComplete == true
                                ? 'Profile complete'
                                : 'Finish setup',
                            style: GoogleFonts.dmSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                              color: PinitColors.aubergine,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            context.read<NavigationProvider>().navigateToTab(2);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PinitColors.aubergine,
                            foregroundColor: PinitColors.cream,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_microRadius),
                            ),
                            side: BorderSide(
                              color: checklistState?.isComplete == true
                                  ? PinitColors.teal
                                  : PinitColors.cream,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            checklistState?.isComplete == true
                                ? 'View'
                                : 'Finish',
                            style: GoogleFonts.dmSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Container(
                          width: effectiveCompact ? 32 : 34,
                          height: effectiveCompact ? 32 : 34,
                          decoration: BoxDecoration(
                            color: PinitColors.creamDeep,
                            borderRadius: BorderRadius.circular(_microRadius),
                            border: Border.all(
                              color: PinitColors.aubergine,
                              width: 1.4,
                            ),
                          ),
                          child: Icon(
                            Icons.checklist_rounded,
                            size: effectiveCompact ? 17 : 18,
                            color: PinitColors.aubergine,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Finish setting up',
                            style: GoogleFonts.dmSans(
                              fontSize: effectiveCompact ? 14.5 : 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                              color: PinitColors.aubergine,
                            ),
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: rowGap),
                  if (!effectiveCompact)
                    Text(
                      checklistState == null
                          ? 'Loading your checklist…'
                          : checklistState.isComplete
                              ? 'All set. Your profile is complete.'
                              : 'Follow these steps to maximise Pinit',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: PinitColors.aubergineSoft,
                        height: 1.2,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  SizedBox(height: footerGap),
                  if (!isCollapsed)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              context
                                  .read<NavigationProvider>()
                                  .navigateToTab(2);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PinitColors.aubergine,
                              foregroundColor: PinitColors.cream,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(_microRadius),
                              ),
                              side: BorderSide(
                                color: checklistState?.isComplete == true
                                    ? PinitColors.teal
                                    : PinitColors.cream,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              checklistState?.isComplete == true
                                  ? 'View profile'
                                  : 'Finish',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

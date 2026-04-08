import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// "About" — editorial / generated summary blurb. Returns
/// SizedBox.shrink() if no summary text is available, so the parent
/// can include this section unconditionally.
class AboutSection extends StatelessWidget {
  const AboutSection({
    super.key,
    required this.generatedSummary,
    required this.editorialSummary,
  });

  final String? generatedSummary;
  final String? editorialSummary;

  @override
  Widget build(BuildContext context) {
    final summary = generatedSummary ?? editorialSummary ?? '';
    if (summary.trim().isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ABOUT',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: PinitColors.aubergineSoft,
            letterSpacing: 0.12 * 11,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'The story',
          style: TextStyle(
            fontFamily: 'Rova',
            fontSize: 28,
            fontWeight: FontWeight.w100,
            color: PinitColors.aubergine,
            letterSpacing: 1.3,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          summary,
          style: GoogleFonts.dmSans(
            fontSize: 15,
            color: PinitColors.aubergineSoft,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

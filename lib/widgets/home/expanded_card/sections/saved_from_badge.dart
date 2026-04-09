import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// "Saved from TikTok" provenance pill that appears at the top of the
/// expanded card when the location was saved from an external short
/// video. Tapping it opens the original TikTok URL in the system
/// browser.
///
/// The badge is intentionally treated as a "flash" signal — accent
/// fill, cream text, chevron — so it reads instantly above the
/// restaurant identity without competing with other actions.
///
/// Returns SizedBox.shrink() if [sourceUrl] is null/empty so callers
/// can include it unconditionally.
class SavedFromBadge extends StatelessWidget {
  const SavedFromBadge({
    super.key,
    required this.savedMethod,
    required this.sourceUrl,
    required this.onTap,
  });

  final String? savedMethod;
  final String? sourceUrl;
  final VoidCallback onTap;

  bool get _isTikTok =>
      (savedMethod ?? '').toLowerCase() == 'tiktok' &&
      (sourceUrl ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_isTikTok) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: PinitColors.accent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: PinitColors.subtleShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.music_note_rounded,
              size: 15,
              color: PinitColors.cream,
            ),
            const SizedBox(width: 7),
            Text(
              'Saved from this TikTok',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: PinitColors.cream,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.open_in_new_rounded,
              size: 13,
              color: PinitColors.cream,
            ),
          ],
        ),
      ),
    );
  }
}

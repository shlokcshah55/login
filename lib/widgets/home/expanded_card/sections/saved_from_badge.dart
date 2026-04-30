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
    this.creatorHandle,
  });

  final String? savedMethod;
  final String? sourceUrl;
  final VoidCallback onTap;
  final String? creatorHandle;

  String? get _normalizedUrl {
    final trimmed = sourceUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String get _normalizedMethod => (savedMethod ?? '').toLowerCase();

  bool get _isTikTok {
    final url = _normalizedUrl;
    if (url == null) return false;
    if (_normalizedMethod == 'tiktok') return true;
    return url.toLowerCase().contains('tiktok.com');
  }

  bool get _isInstagram {
    final url = _normalizedUrl;
    if (url == null) return false;
    if (_normalizedMethod == 'instagram') return true;
    return url.toLowerCase().contains('instagram.com');
  }

  String get _label {
    final handle = creatorHandle?.trim();
    final hasHandle = handle != null && handle.isNotEmpty;

    if (_isTikTok) {
      return hasHandle
          ? 'Saved from @$handle\u2019s TikTok'
          : 'Saved from this TikTok';
    }
    if (_isInstagram) {
      return hasHandle
          ? 'Saved from @$handle\u2019s Reel'
          : 'Saved from this Reel';
    }
    return 'Source video';
  }

  @override
  Widget build(BuildContext context) {
    if (_normalizedUrl == null) return const SizedBox.shrink();

    final icon = _isTikTok
        ? Icons.music_note_rounded
        : (_isInstagram ? Icons.movie_creation_rounded : Icons.play_arrow);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: PinitColors.accent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: PinitColors.subtleShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: PinitColors.cream,
              ),
              const SizedBox(width: 10),
              Text(
                _label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: PinitColors.cream,
                  letterSpacing: 0.3,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.open_in_new_rounded,
                size: 14,
                color: PinitColors.cream,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

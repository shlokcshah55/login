import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/widgets/home/expanded_card/social_review_context.dart';

class SocialMatchSection extends StatelessWidget {
  const SocialMatchSection({super.key, required this.context});

  final SocialReviewContext context;

  bool get _isInstagram => context.platform.toLowerCase() == 'instagram';

  String get _matchLabel {
    switch (context.confidenceTier?.toLowerCase()) {
      case 'high':
        return 'Strong match';
      case 'medium':
        return 'Possible match';
      case 'low':
        return 'Needs checking';
      default:
        final score = context.confidenceScore;
        if (score == null) return 'Matched place';
        final normalized = score > 1 ? score / 100 : score;
        if (normalized >= 0.8) return 'Strong match';
        if (normalized >= 0.6) return 'Possible match';
        return 'Needs checking';
    }
  }

  String get _ratingText {
    final score = context.confidenceScore;
    if (score == null) return _matchLabel;
    final normalized = score > 1 ? score / 100 : score;
    return '${(normalized.clamp(0, 1) * 100).round()}% · $_matchLabel';
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (this.context.onConfirm != null)
        _Action(
          label: 'Confirm match',
          icon: FeatherIcons.check,
          onTap: this.context.onConfirm!,
          filled: true,
        ),
      if (this.context.onCorrect != null)
        _Action(
          label: 'Correct restaurant',
          icon: FeatherIcons.edit2,
          onTap: this.context.onCorrect!,
        ),
      if (this.context.onRemove != null)
        _Action(
          label: 'Remove from saves',
          icon: FeatherIcons.x,
          onTap: this.context.onRemove!,
        ),
    ];

    return Semantics(
      container: true,
      label:
          '${_isInstagram ? 'Reel' : 'TikTok'} match, $_ratingText, ${this.context.placeName}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: PinitColors.creamSunk,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PinitColors.creamDeep, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: PinitColors.aubergine,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isInstagram ? FeatherIcons.instagram : FeatherIcons.music,
                    size: 16,
                    color: PinitColors.cream,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_isInstagram ? 'Reel' : 'TikTok'} match',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: PinitColors.aubergine,
                    ),
                  ),
                ),
                Text(
                  _ratingText,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: PinitColors.aubergine,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'We matched this post to ${this.context.placeName}.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                height: 1.35,
                color: PinitColors.mute,
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final foreground = filled ? PinitColors.cream : PinitColors.aubergine;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: filled ? PinitColors.aubergine : PinitColors.cream,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: PinitColors.aubergine, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

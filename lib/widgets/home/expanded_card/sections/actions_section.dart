import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// Primary action row: "Add to Bubble" + Save + dislike + share, with
/// a full-width "Add to Collection" beneath. Stateless — parent owns the
/// save / dislike state and passes loading flags + handlers in.
class ActionsSection extends StatelessWidget {
  const ActionsSection({
    super.key,
    required this.isSaved,
    required this.isSaving,
    required this.isDisliking,
    required this.isBeenTo,
    required this.isBeenToLoading,
    required this.onAddToBubble,
    required this.onToggleSave,
    required this.onDislike,
    required this.onShare,
    required this.onAddToCollection,
    required this.onBeenTo,
  });

  final bool isSaved;
  final bool isSaving;
  final bool isDisliking;
  final bool isBeenTo;
  final bool isBeenToLoading;
  final VoidCallback onAddToBubble;
  final VoidCallback? onToggleSave;
  final VoidCallback? onDislike;
  final VoidCallback onShare;
  final VoidCallback onAddToCollection;
  final VoidCallback? onBeenTo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Primary CTA — given visual weight via shadow + 56px height
        // so it reads as the dominant action on the page.
        SizedBox(
          width: double.infinity,
          child: _ActionButton(
            label: 'Add to Bubble',
            icon: Icons.group_add_rounded,
            variant: _ActionVariant.primary,
            onTap: onAddToBubble,
          ),
        ),
        const SizedBox(height: 10),
        // Secondary row — Save flips between outlined and filled states
        // so saved-ness is unmistakable in the action row.
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: isSaved ? 'Saved' : 'Save',
                icon: isSaved
                    ? Icons.check_rounded
                    : Icons.bookmark_border_rounded,
                variant: isSaved
                    ? _ActionVariant.activeFilled
                    : _ActionVariant.outlined,
                isLoading: isSaving,
                onTap: isSaving ? null : onToggleSave,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                label: 'Collection',
                icon: Icons.collections_bookmark_rounded,
                variant: _ActionVariant.outlined,
                onTap: onAddToCollection,
              ),
            ),
            const SizedBox(width: 10),
            _IconAction(
              icon: Icons.share_rounded,
              onTap: onShare,
            ),
            const SizedBox(width: 8),
            _IconAction(
              icon: Icons.thumb_down_off_alt_rounded,
              onTap: isDisliking ? null : onDislike,
              isLoading: isDisliking,
            ),
          ],
        ),
        const SizedBox(height: 10),
        // "Been to" — third full-width row. Flips between filled (active)
        // and outlined states once a been-to review exists for this place.
        SizedBox(
          width: double.infinity,
          child: _ActionButton(
            label: isBeenTo ? 'Been here' : 'Been to',
            icon: isBeenTo
                ? Icons.check_circle_rounded
                : Icons.restaurant_menu_rounded,
            variant: isBeenTo
                ? _ActionVariant.activeFilled
                : _ActionVariant.outlined,
            isLoading: isBeenToLoading,
            onTap: (isBeenTo || isBeenToLoading) ? null : onBeenTo,
          ),
        ),
      ],
    );
  }
}

enum _ActionVariant {
  /// Aubergine fill, cream text, warm shadow. The page's primary CTA.
  primary,

  /// CreamSunk fill, aubergine text, 1.5px aubergine-deep border.
  outlined,

  /// Aubergine fill, cream text, no shadow. Used for "active" toggled
  /// states (e.g. Saved) so the state flip reads at a glance.
  activeFilled,
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.variant,
    this.onTap,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final _ActionVariant variant;
  final VoidCallback? onTap;
  final bool isLoading;

  bool get _isFilled =>
      variant == _ActionVariant.primary ||
      variant == _ActionVariant.activeFilled;

  Color get _bg =>
      _isFilled ? PinitColors.aubergine : PinitColors.creamSunk;

  Color get _fg =>
      _isFilled ? PinitColors.cream : PinitColors.aubergine;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == _ActionVariant.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: isPrimary ? 56 : 52,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(999),
          border: _isFilled
              ? null
              : Border.all(color: PinitColors.creamDeep, width: 1.5),
          boxShadow: isPrimary ? PinitColors.cardShadow : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _fg,
                ),
              )
            else
              Icon(icon, size: 19, color: _fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: isPrimary ? 15 : 14,
                fontWeight: FontWeight.w600,
                color: _fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: PinitColors.creamSunk,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: PinitColors.creamDeep, width: 1.5),
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: PinitColors.aubergine),
                ),
              )
            : Icon(icon, size: 20, color: PinitColors.aubergine),
      ),
    );
  }
}

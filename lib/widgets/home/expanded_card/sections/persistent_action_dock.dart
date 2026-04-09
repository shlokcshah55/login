import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// Persistent bottom action dock introduced by the 2026-04-08
/// restaurant expanded card structural redesign.
///
/// Replaces the inline [ActionsSection] for restaurant locations: the
/// primary actions stay anchored at the bottom of the sheet while the
/// editorial body scrolls behind. The dock is the *only* surface for
/// these actions in the new layout — they should not also appear in
/// the scroll body.
///
/// Contents (left → right):
///   • Add to Bubble       (primary CTA — wide pill)
///   • Save                (toggles between outlined and active)
///   • Add to Collection   (opens the AddToCollectionSheet)
///   • Dislike             (icon-only)
///
/// The dock is safe-area aware. The parent must add bottom padding
/// inside the scrollable body equal to [dockHeight] + breathing room
/// so the final section remains fully readable above the dock.
class PersistentActionDock extends StatelessWidget {
  const PersistentActionDock({
    super.key,
    required this.isSaved,
    required this.isSaving,
    required this.isDisliking,
    required this.isBeenTo,
    required this.isBeenToLoading,
    required this.onAddToBubble,
    required this.onToggleSave,
    required this.onAddToCollection,
    required this.onDislike,
    required this.onBeenTo,
  });

  final bool isSaved;
  final bool isSaving;
  final bool isDisliking;
  final bool isBeenTo;
  final bool isBeenToLoading;
  final VoidCallback onAddToBubble;
  final VoidCallback? onToggleSave;
  final VoidCallback onAddToCollection;
  final VoidCallback? onDislike;
  final VoidCallback? onBeenTo;

  /// Visual height of the dock chrome itself, excluding the bottom
  /// safe-area inset. The parent uses this + safe area to compute the
  /// scroll body's bottom padding.
  static const double dockHeight = 76.0;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
      decoration: const BoxDecoration(
        color: PinitColors.cream,
        border: Border(
          top: BorderSide(color: PinitColors.creamDeep, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _DockPrimaryButton(
              label: 'Add to Bubble',
              icon: Icons.group_add_rounded,
              onTap: onAddToBubble,
            ),
          ),
          const SizedBox(width: 10),
          _DockIconButton(
            icon: isSaved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            tooltip: isSaved ? 'Saved' : 'Save',
            isActive: isSaved,
            isLoading: isSaving,
            onTap: isSaving ? null : onToggleSave,
          ),
          const SizedBox(width: 8),
          _DockIconButton(
            icon: Icons.collections_bookmark_rounded,
            tooltip: 'Add to Collection',
            onTap: onAddToCollection,
          ),
          const SizedBox(width: 8),
          _DockIconButton(
            icon: isBeenTo
                ? Icons.check_circle_rounded
                : Icons.restaurant_menu_rounded,
            tooltip: isBeenTo ? 'Been here' : 'Been to',
            isActive: isBeenTo,
            isLoading: isBeenToLoading,
            onTap: (isBeenTo || isBeenToLoading) ? null : onBeenTo,
          ),
          const SizedBox(width: 8),
          _DockIconButton(
            icon: Icons.thumb_down_off_alt_rounded,
            tooltip: 'Hide',
            isLoading: isDisliking,
            onTap: isDisliking ? null : onDislike,
          ),
        ],
      ),
    );
  }
}

class _DockPrimaryButton extends StatelessWidget {
  const _DockPrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: PinitColors.aubergine,
          borderRadius: BorderRadius.circular(999),
          boxShadow: PinitColors.cardShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: PinitColors.cream),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: PinitColors.cream,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockIconButton extends StatelessWidget {
  const _DockIconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.isActive = false,
    this.isLoading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isActive;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? PinitColors.aubergine : PinitColors.creamSunk;
    final fg = isActive ? PinitColors.cream : PinitColors.aubergine;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: isActive
                ? null
                : Border.all(color: PinitColors.creamDeep, width: 1.5),
          ),
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  ),
                )
              : Icon(icon, size: 20, color: fg),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// Persistent bottom action dock introduced by the 2026-04-08
/// restaurant expanded card structural redesign.
///
/// Contents (left → right):
///   • Share to Bubble  (icon-only)
///   • Save             (medium, text + icon, toggles active)
///   • Add to Collection (medium, text + icon)
///   • Dislike          (icon-only)
class PersistentActionDock extends StatelessWidget {
  const PersistentActionDock({
    super.key,
    required this.isSaved,
    required this.isSaving,
    required this.isDisliking,
    required this.onAddToBubble,
    required this.onToggleSave,
    required this.onAddToCollection,
    required this.onDislike,
  });

  final bool isSaved;
  final bool isSaving;
  final bool isDisliking;
  final VoidCallback onAddToBubble;
  final VoidCallback? onToggleSave;
  final VoidCallback onAddToCollection;
  final VoidCallback? onDislike;

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
            child: _DockMediumButton(
              label: isSaved ? 'Saved' : 'Save',
              icon: isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              isActive: isSaved,
              isLoading: isSaving,
              onTap: isSaving ? null : onToggleSave,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DockMediumButton(
              label: 'Collection',
              icon: Icons.collections_bookmark_rounded,
              onTap: onAddToCollection,
            ),
          ),
          const SizedBox(width: 10),
          _DockIconButton(
            icon: Icons.thumb_down_off_alt_rounded,
            tooltip: 'Hide',
            isLoading: isDisliking,
            onTap: isDisliking ? null : onDislike,
          ),
          const SizedBox(width: 10),
          _DockIconButton(
            icon: Icons.send_rounded,
            tooltip: 'Share to Bubble',
            onTap: onAddToBubble,
          ),
        ],
      ),
    );
  }
}

class _DockMediumButton extends StatelessWidget {
  const _DockMediumButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.isActive = false,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isActive;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? PinitColors.aubergine : PinitColors.creamSunk;
    final fg = isActive ? PinitColors.cream : PinitColors.aubergine;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: fg,
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
    this.isLoading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: PinitColors.creamDeep, width: 1.5),
          ),
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PinitColors.aubergine,
                    ),
                  ),
                )
              : Icon(icon, size: 20, color: PinitColors.aubergine),
        ),
      ),
    );
  }
}

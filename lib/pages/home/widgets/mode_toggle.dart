import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/supabase/helpers/collections.dart';

/// Mode toggle enum.
enum HomeMode { you, explore, bubble, bubbleSaved }

/// Single centered chip used while viewing magic search results.
class MagicSearchChipRow extends StatelessWidget {
  const MagicSearchChipRow({
    super.key,
    this.onTap,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Chip(
          label: 'MAGIC SEARCH',
          icon: FeatherIcons.zap,
          state: _ChipState.filled,
          onTap: onTap ?? () {},
        ),
      ],
    );
  }
}

/// Unified home chip row with an inline collections dropdown.
class HomeChipRow extends StatefulWidget {
  const HomeChipRow({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    required this.collections,
    required this.isLoadingCollections,
    required this.onCollectionMenuOpened,
    required this.onCollectionSelected,
    this.onCollectionsVisibilityChanged,
    this.activeCollectionId,
    this.activeBubbleName,
    this.rowSpotlightKey,
    this.trailingAction,
  });

  final HomeMode currentMode;
  final ValueChanged<HomeMode> onModeChanged;
  final List<CollectionItem> collections;
  final bool isLoadingCollections;
  final VoidCallback onCollectionMenuOpened;
  final ValueChanged<CollectionItem> onCollectionSelected;
  final ValueChanged<bool>? onCollectionsVisibilityChanged;
  final String? activeCollectionId;
  final String? activeBubbleName;
  final Key? rowSpotlightKey;
  final Widget? trailingAction;

  @override
  State<HomeChipRow> createState() => _HomeChipRowState();
}

class _HomeChipRowState extends State<HomeChipRow> {
  bool _showCollections = false;

  void _toggleCollections() {
    final next = !_showCollections;
    setState(() => _showCollections = next);
    widget.onCollectionsVisibilityChanged?.call(next);
    if (next) widget.onCollectionMenuOpened();
  }

  void _closeCollections() {
    if (!_showCollections) return;
    setState(() => _showCollections = false);
    widget.onCollectionsVisibilityChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final bubbleActive = widget.activeBubbleName != null;
    final collectionActive = !bubbleActive &&
        (_showCollections || widget.activeCollectionId != null);
    final chips = <Widget>[
      if (bubbleActive) ...[
        _Chip(
          label: 'BUBBLE',
          icon: FeatherIcons.users,
          state: widget.currentMode == HomeMode.bubble
              ? _ChipState.filled
              : _ChipState.normal,
          onTap: () {
            _closeCollections();
            widget.onModeChanged(HomeMode.bubble);
          },
        ),
        _Chip(
          label: 'SAVED',
          icon: FeatherIcons.bookmark,
          state: widget.currentMode == HomeMode.bubbleSaved
              ? _ChipState.filled
              : _ChipState.normal,
          onTap: () {
            _closeCollections();
            widget.onModeChanged(HomeMode.bubbleSaved);
          },
        ),
      ] else ...[
        _Chip(
          label: 'SAVED',
          icon: FeatherIcons.user,
          state: widget.currentMode == HomeMode.you && !collectionActive
              ? _ChipState.filled
              : _ChipState.normal,
          onTap: () {
            _closeCollections();
            widget.onModeChanged(HomeMode.you);
          },
        ),
        _Chip(
          label: 'PICKS',
          icon: FeatherIcons.compass,
          state: widget.currentMode == HomeMode.explore && !collectionActive
              ? _ChipState.filled
              : _ChipState.normal,
          onTap: () {
            _closeCollections();
            widget.onModeChanged(HomeMode.explore);
          },
        ),
        _Chip(
          label: 'EAT-LISTS',
          icon: FeatherIcons.bookmark,
          state: collectionActive ? _ChipState.filled : _ChipState.normal,
          trailing: Icon(
            _showCollections
                ? FeatherIcons.chevronUp
                : FeatherIcons.chevronDown,
            size: 11,
            color: collectionActive ? PinitColors.cream : PinitColors.aubergine,
          ),
          onTap: _toggleCollections,
        ),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RepaintBoundary(
          key: widget.rowSpotlightKey,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: chips.length == 1
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                for (var i = 0; i < chips.length; i++) ...[
                  if (chips.length > 1) Expanded(child: chips[i]) else chips[i],
                  if (i < chips.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
        if (!bubbleActive && widget.trailingAction != null)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 2),
              child: widget.trailingAction!,
            ),
          ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child: bubbleActive || !_showCollections
              ? const SizedBox.shrink()
              : Padding(
                  key: const ValueKey('collections_dropdown'),
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    decoration: BoxDecoration(
                      color: PinitColors.cream,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: PinitColors.aubergine,
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: PinitColors.aubergine,
                          blurRadius: 0,
                          offset: Offset(3, 3),
                        ),
                      ],
                    ),
                    child: widget.isLoadingCollections
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    PinitColors.aubergine,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : widget.collections.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                                child: Text(
                                  'No eat-lists yet.',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: PinitColors.aubergineSoft,
                                  ),
                                ),
                              )
                            : ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 280),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: widget.collections
                                        .map(
                                          (collection) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8),
                                            child: _CollectionDropdownRow(
                                              collection: collection,
                                              isActive:
                                                  widget.activeCollectionId ==
                                                      collection.collectionId,
                                              onTap: () {
                                                widget.onCollectionSelected(
                                                  collection,
                                                );
                                                _closeCollections();
                                              },
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                  ),
                ),
        ),
      ],
    );
  }
}

enum _ChipState { normal, filled, accent }

class _Chip extends StatefulWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.state,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final _ChipState state;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  State<_Chip> createState() => _ChipStateState();
}

class _ChipStateState extends State<_Chip> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) => setState(() => _scale = 0.94);

  void _onTapUp(TapUpDetails _) {
    setState(() => _scale = 1.0);
    widget.onTap();
  }

  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final Color border;
    final bool elevated;

    switch (widget.state) {
      case _ChipState.accent:
        bg = PinitColors.accent;
        fg = PinitColors.cream;
        border = PinitColors.aubergine;
        elevated = true;
        break;
      case _ChipState.filled:
        bg = PinitColors.aubergine;
        fg = PinitColors.cream;
        border = PinitColors.black;
        elevated = true;
        break;
      case _ChipState.normal:
        bg = PinitColors.cream;
        fg = PinitColors.aubergine;
        border = PinitColors.aubergine;
        elevated = false;
        break;
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 1.5),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: border,
                      blurRadius: 0,
                      offset: const Offset(2, 2),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 12, color: fg),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    letterSpacing: 1.0,
                    height: 1.0,
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 4),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const String _kSharedFindsName = 'Shared Finds';
const String _kSharedFindsDisplayName = 'Saved from your scroll';

class _CollectionDropdownRow extends StatelessWidget {
  const _CollectionDropdownRow({
    required this.collection,
    required this.onTap,
    required this.isActive,
  });

  final CollectionItem collection;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final isScrollSaved = collection.name == _kSharedFindsName;
    final displayName =
        isScrollSaved ? _kSharedFindsDisplayName : collection.name;
    final owner = collection.ownerName;
    final isReadOnly = !collection.canEdit && owner != null && owner.isNotEmpty;
    final subtitle = isReadOnly
        ? 'By $owner • ${collection.placeCount} place${collection.placeCount == 1 ? '' : 's'}'
        : '${collection.placeCount} place${collection.placeCount == 1 ? '' : 's'}';
    return Container(
      decoration: BoxDecoration(
        color: isScrollSaved
            ? PinitColors.accent
            : isActive
                ? PinitColors.creamSunk
                : PinitColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isScrollSaved
              ? PinitColors.accent
              : isActive
                  ? PinitColors.aubergine
                  : PinitColors.creamDeep,
          width: 1.5,
        ),
        boxShadow: isScrollSaved
            ? const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 0,
                  offset: Offset(2, 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isScrollSaved
                          ? PinitColors.cream
                          : PinitColors.aubergine,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isScrollSaved
                          ? PinitColors.cream.withValues(alpha: 0.75)
                          : PinitColors.aubergineSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isScrollSaved
                        ? PinitColors.creamSunk
                        : PinitColors.aubergine,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isScrollSaved
                          ? PinitColors.creamDeep
                          : PinitColors.aubergine,
                      width: 1.5,
                    ),
                    boxShadow: isScrollSaved
                        ? null
                        : const [
                            BoxShadow(
                              color: PinitColors.aubergine,
                              blurRadius: 0,
                              offset: Offset(2, 2),
                            ),
                          ],
                  ),
                  child: Text(
                    'SEE ALL',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isScrollSaved
                          ? PinitColors.aubergine
                          : PinitColors.cream,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

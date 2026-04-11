import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/search/header_search_types.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/themes/app_typography.dart';

class HomeHeaderSearchShell extends StatelessWidget {
  final HeaderSearchState state;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onEntryTap;
  final VoidCallback onMagicSearchTap;
  final VoidCallback onDismiss;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<SearchSuggestionItem> onSuggestionSelected;
  final ValueChanged<LocationModel> onPreviewStart;
  final VoidCallback onPreviewEnd;
  final Widget? footer;
  final bool isMagicSearchActive;
  final VoidCallback? onSearchSubmitted;

  const HomeHeaderSearchShell({
    super.key,
    required this.state,
    required this.controller,
    required this.focusNode,
    required this.onEntryTap,
    required this.onMagicSearchTap,
    required this.onDismiss,
    required this.onQueryChanged,
    required this.onSuggestionSelected,
    required this.onPreviewStart,
    required this.onPreviewEnd,
    this.footer,
    this.isMagicSearchActive = false,
    this.onSearchSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    if (!state.isActive) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _CollapsedSearchEntry(
                  controller: controller,
                  focusNode: focusNode,
                  onTap: onEntryTap,
                  isMagicSearchActive: isMagicSearchActive,
                  onChanged: onQueryChanged,
                  onSubmitted: onSearchSubmitted,
                ),
              ),
              const SizedBox(width: 10),
              _MagicSearchButton(
                onTap: onMagicSearchTap,
                isMagicSearchActive: isMagicSearchActive,
              ),
            ],
          ),
          if (footer != null) ...[
            const SizedBox(height: 8),
            footer!,
          ],
        ],
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final overlayTopOffset = mediaQuery.padding.top + 40;

    return SizedBox(
      height: mediaQuery.size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -16,
            right: -16,
            top: -overlayTopOffset,
            child: SizedBox(
              height: mediaQuery.size.height + overlayTopOffset,
              child: _SearchOverlay(
                state: state,
                controller: controller,
                focusNode: focusNode,
                onDismiss: onDismiss,
                onQueryChanged: onQueryChanged,
                onSuggestionSelected: onSuggestionSelected,
                onPreviewStart: onPreviewStart,
                onPreviewEnd: onPreviewEnd,
                onSearchSubmitted: onSearchSubmitted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedSearchEntry extends StatelessWidget {
  const _CollapsedSearchEntry({
    required this.controller,
    required this.focusNode,
    required this.onTap,
    required this.isMagicSearchActive,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final bool isMagicSearchActive;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    if (isMagicSearchActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: pinit.PinitColors.accent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: pinit.PinitColors.aubergine,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: pinit.PinitColors.aubergine,
              blurRadius: 0,
              offset: Offset(3, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              FeatherIcons.zap,
              color: pinit.PinitColors.cream,
              size: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('home_header_magic_search_field'),
                controller: controller,
                focusNode: focusNode,
                cursorColor: pinit.PinitColors.cream,
                scrollPadding: EdgeInsets.zero,
                textInputAction: TextInputAction.search,
                textCapitalization: TextCapitalization.sentences,
                style: AppTypography.sans(
                  fontSize: 15,
                  color: pinit.PinitColors.cream,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: 'Describe a vibe, place, or craving',
                  hintStyle: AppTypography.sans(
                    fontSize: 15,
                    color: pinit.PinitColors.cream.withValues(alpha: 0.74),
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: onChanged,
                onSubmitted: onSubmitted != null ? (_) => onSubmitted!() : null,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      key: const Key('home_header_search_entry'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: pinit.PinitColors.cream,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: pinit.PinitColors.aubergine,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: pinit.PinitColors.aubergine,
              blurRadius: 0,
              offset: Offset(3, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              FeatherIcons.search,
              color: pinit.PinitColors.aubergine,
              size: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'SEARCH PLACES',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: pinit.PinitColors.aubergineSoft,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: pinit.PinitColors.creamSunk,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: pinit.PinitColors.creamDeep,
                  width: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MagicSearchButton extends StatelessWidget {
  const _MagicSearchButton({
    required this.onTap,
    required this.isMagicSearchActive,
  });

  final VoidCallback onTap;
  final bool isMagicSearchActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: isMagicSearchActive
              ? pinit.PinitColors.accent
              : pinit.PinitColors.cream,
          shape: BoxShape.circle,
          border: Border.all(
            color: isMagicSearchActive ? pinit.PinitColors.aubergine
                : pinit.PinitColors.accent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isMagicSearchActive ? pinit.PinitColors.aubergine
                  : pinit.PinitColors.accent,
              blurRadius: 0,
              offset: Offset(3, 3),
            ),
          ],
        ),
        child: Icon(
          FeatherIcons.zap,
          color: isMagicSearchActive
              ? pinit.PinitColors.cream
              : pinit.PinitColors.accent,
          size: 22,
        ),
      ),
    );
  }
}

class _SearchOverlay extends StatefulWidget {
  final HeaderSearchState state;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onDismiss;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<SearchSuggestionItem> onSuggestionSelected;
  final ValueChanged<LocationModel> onPreviewStart;
  final VoidCallback onPreviewEnd;
  final VoidCallback? onSearchSubmitted;

  const _SearchOverlay({
    required this.state,
    required this.controller,
    required this.focusNode,
    required this.onDismiss,
    required this.onQueryChanged,
    required this.onSuggestionSelected,
    required this.onPreviewStart,
    required this.onPreviewEnd,
    required this.onSearchSubmitted,
  });

  @override
  State<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<_SearchOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.focusNode.hasFocus) {
        widget.focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.text != widget.state.query) {
      widget.controller.value = widget.controller.value.copyWith(
        text: widget.state.query,
        selection: TextSelection.collapsed(offset: widget.state.query.length),
        composing: TextRange.empty,
      );
    }

    return AnimatedBuilder(
      animation: _motionController,
      builder: (context, _) {
        final pulse =
            0.5 - 0.5 * math.cos(_motionController.value * math.pi * 2);
        final drift = 14 * (pulse - 0.5);

        return Material(
          color: Colors.transparent,
          child: DecoratedBox(
            key: const Key('header_search_fullscreen_layer'),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  pinit.PinitColors.cream,
                  pinit.PinitColors.cream,
                  pinit.PinitColors.creamSunk,
                ],
              ),
            ),
            child: Stack(
              children: [
                _SearchBackdrop(
                  pulse: pulse,
                  drift: drift,
                  isPreviewingMap: widget.state.isPreviewingMap,
                ),
                KeyedSubtree(
                  key: const Key('header_search_overlay'),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ExpandedSearchField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            inlineCompletion:
                                widget.state.result.inlineCompletion,
                            onChanged: widget.onQueryChanged,
                            onDismiss: widget.onDismiss,
                            onSubmitted: widget.onSearchSubmitted,
                          ),
                          if (widget.state.result.errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _SearchErrorBanner(
                              message: widget.state.result.errorMessage!,
                            ),
                          ],
                          const SizedBox(height: 18),
                          Expanded(
                            child: _PlaceResultsList(
                              section: _placeSection,
                              query: widget.state.result.query,
                              pulse: pulse,
                              onSuggestionSelected: widget.onSuggestionSelected,
                              onPreviewStart: widget.onPreviewStart,
                              onPreviewEnd: widget.onPreviewEnd,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  HeaderSearchSectionModel? get _placeSection {
    for (final section in widget.state.result.sections) {
      if (section.type == SearchSectionType.places) {
        return section;
      }
    }
    return null;
  }
}

class _SearchBackdrop extends StatelessWidget {
  final double pulse;
  final double drift;
  final bool isPreviewingMap;

  const _SearchBackdrop({
    required this.pulse,
    required this.drift,
    required this.isPreviewingMap,
  });

  @override
  Widget build(BuildContext context) {
    final overlayOpacity = isPreviewingMap ? 0.96 : 1.0;

    return Opacity(
      opacity: overlayOpacity,
      child: Stack(
        children: [
          Positioned(
            top: -80 + drift,
            right: -60,
            child: _BackdropOrb(
              size: 220,
              color: pinit.PinitColors.creamDeep.withValues(alpha: 0.72),
            ),
          ),
          Positioned(
            top: 140 - drift,
            left: -48,
            child: _BackdropOrb(
              size: 200,
              color: pinit.PinitColors.creamDeep.withValues(alpha: 0.54),
            ),
          ),
          Positioned(
            bottom: 110 + (drift * 0.6),
            right: 12,
            child: _BackdropOrb(
              size: 132,
              color: pinit.PinitColors.accent.withValues(
                alpha: 0.05 + (pulse * 0.03),
              ),
            ),
          ),
          Positioned(
            top: 120,
            left: 24,
            right: 24,
            child: Opacity(
              opacity: 0.22 + (pulse * 0.1),
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      pinit.PinitColors.cream.withValues(alpha: 0),
                      pinit.PinitColors.aubergine.withValues(alpha: 0.12),
                      pinit.PinitColors.cream.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _BackdropOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? inlineCompletion;
  final ValueChanged<String> onChanged;
  final VoidCallback onDismiss;
  final VoidCallback? onSubmitted;

  const _ExpandedSearchField({
    required this.controller,
    required this.focusNode,
    required this.inlineCompletion,
    required this.onChanged,
    required this.onDismiss,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pinit.PinitColors.creamDeep,
          width: 1.5,
        ),
        boxShadow: pinit.PinitColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: pinit.PinitColors.cream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: pinit.PinitColors.creamDeep,
                width: 1.25,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              CupertinoIcons.search,
              color: pinit.PinitColors.aubergine,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (inlineCompletion != null &&
                    inlineCompletion!.isNotEmpty &&
                    controller.text.isNotEmpty)
                  IgnorePointer(
                    child: Text(
                      inlineCompletion!,
                      key: const Key('header_search_inline_completion'),
                      style: AppTypography.sans(
                        fontSize: 15,
                        color: pinit.PinitColors.mute.withValues(alpha: 0.56),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                TextField(
                  key: const Key('header_search_text_field'),
                  controller: controller,
                  focusNode: focusNode,
                  cursorColor: pinit.PinitColors.aubergine,
                  textInputAction: TextInputAction.search,
                  style: AppTypography.sans(
                    fontSize: 15,
                    color: pinit.PinitColors.aubergine,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search places',
                    hintStyle: AppTypography.sans(
                      fontSize: 15,
                      color: pinit.PinitColors.mute,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: onChanged,
                  onSubmitted:
                      onSubmitted != null ? (_) => onSubmitted!() : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: pinit.PinitColors.cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: pinit.PinitColors.creamDeep,
                  width: 1.25,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.xmark,
                color: pinit.PinitColors.aubergineSoft,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchErrorBanner extends StatelessWidget {
  final String message;

  const _SearchErrorBanner({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pinit.PinitColors.creamDeep,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: pinit.PinitColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.sans(
                fontSize: 13,
                color: pinit.PinitColors.aubergine,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceResultsList extends StatelessWidget {
  final HeaderSearchSectionModel? section;
  final String query;
  final double pulse;
  final ValueChanged<SearchSuggestionItem> onSuggestionSelected;
  final ValueChanged<LocationModel> onPreviewStart;
  final VoidCallback onPreviewEnd;

  const _PlaceResultsList({
    required this.section,
    required this.query,
    required this.pulse,
    required this.onSuggestionSelected,
    required this.onPreviewStart,
    required this.onPreviewEnd,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 32;
    final hasQuery = query.trim().isNotEmpty;
    final items = section?.items ?? const <SearchSuggestionItem>[];
    final isLoading = section?.isLoading ?? false;

    if (isLoading) {
      return ListView.separated(
        padding: EdgeInsets.only(bottom: bottomPadding),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => _SearchResultListSkeleton(pulse: pulse),
      );
    }

    if (items.isEmpty) {
      return ListView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: pinit.PinitColors.creamSunk,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: pinit.PinitColors.creamDeep,
                width: 1.5,
              ),
              boxShadow: pinit.PinitColors.cardShadow,
            ),
            child: Text(
              hasQuery
                  ? 'No places found for that search yet.'
                  : 'Start with a place, area, or venue name.',
              style: AppTypography.sans(
                fontSize: 14,
                color: pinit.PinitColors.mute,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: EdgeInsets.only(bottom: bottomPadding),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return _SearchResultListTile(
          item: item,
          onSelected: onSuggestionSelected,
          onPreviewStart: onPreviewStart,
          onPreviewEnd: onPreviewEnd,
        );
      },
    );
  }
}

class _SearchResultListSkeleton extends StatelessWidget {
  final double pulse;

  const _SearchResultListSkeleton({
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: pinit.PinitColors.cream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: pinit.PinitColors.aubergine,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: pinit.PinitColors.aubergine,
            blurRadius: 0,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 120,
            decoration: BoxDecoration(
              color: pinit.PinitColors.creamDeep.withValues(
                alpha: 0.78 + (pulse * 0.1),
              ),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(8.5),
              ),
            ),
          ),
          Container(
            width: 1.5,
            color: pinit.PinitColors.aubergine,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 88,
                    height: 12,
                    decoration: BoxDecoration(
                      color: pinit.PinitColors.creamDeep,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 150,
                    height: 16,
                    decoration: BoxDecoration(
                      color:
                          pinit.PinitColors.aubergine.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 180,
                    height: 11,
                    decoration: BoxDecoration(
                      color:
                          pinit.PinitColors.aubergine.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 74,
                    height: 20,
                    decoration: BoxDecoration(
                      color: pinit.PinitColors.creamDeep,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultListTile extends StatelessWidget {
  final SearchSuggestionItem item;
  final ValueChanged<SearchSuggestionItem> onSelected;
  final ValueChanged<LocationModel> onPreviewStart;
  final VoidCallback onPreviewEnd;

  const _SearchResultListTile({
    required this.item,
    required this.onSelected,
    required this.onPreviewStart,
    required this.onPreviewEnd,
  });

  @override
  Widget build(BuildContext context) {
    final location = item.location;
    final canPreview = location != null;
    final keyValue = item.id.replaceAll(':', '-');
    final isWavy = (location?.vibe?.wavyScore ?? 0) > 0.45;
    final borderColor =
        isWavy ? pinit.PinitColors.accent : pinit.PinitColors.aubergine;

    return GestureDetector(
      key: Key('header_search_list_item_$keyValue'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelected(item),
      onLongPress: canPreview ? () => onPreviewStart(location) : null,
      onLongPressEnd: canPreview ? (_) => onPreviewEnd() : null,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: pinit.PinitColors.cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: borderColor,
              blurRadius: 0,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _SearchResultImage(item: item),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00000000),
                              Color(0x33000000),
                            ],
                            stops: [0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                    if (item.isMapboxResult)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: pinit.PinitColors.cream,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: pinit.PinitColors.aubergine,
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            'MAP',
                            style: GoogleFonts.dmSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: pinit.PinitColors.aubergine,
                              letterSpacing: 0.8,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: 1.5,
                color: borderColor,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: pinit.PinitColors.creamSunk,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            FeatherIcons.mapPin,
                            size: 11,
                            color: pinit.PinitColors.mute,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _topStripLabel(item).toUpperCase(),
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                color: pinit.PinitColors.mute,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                height: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (location?.rating != null) ...[
                            _SearchListRating(
                              rating: location!.rating!,
                              reviewCount: location.userRatingsTotal,
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: pinit.PinitColors.aubergine,
                                height: 1.15,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            if (_summaryText(item) != null)
                              Text(
                                _summaryText(item)!,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: pinit.PinitColors.mute,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const Spacer(),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _buildMetaPills(item),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _topStripLabel(SearchSuggestionItem item) {
    final location = item.location;
    if (item.isMapboxResult) {
      return 'Map Result';
    }
    if (location?.savedCount != null && location!.savedCount! > 0) {
      return '${location.savedCount} Saves';
    }
    if (location?.preference == LocationPreference.search) {
      return 'Match';
    }
    return 'Search Result';
  }

  String? _summaryText(SearchSuggestionItem item) {
    final location = item.location;
    if (location?.generatedSummary?.isNotEmpty == true) {
      return location!.generatedSummary!;
    }
    if (location?.editorialSummary?.isNotEmpty == true) {
      return location!.editorialSummary!;
    }
    if (location?.vicinity?.isNotEmpty == true) {
      return location!.vicinity!;
    }
    if (item.subtitle?.isNotEmpty == true) {
      return item.subtitle!;
    }
    return null;
  }

  List<Widget> _buildMetaPills(SearchSuggestionItem item) {
    final location = item.location;
    final pills = <Widget>[];

    if (location?.priceLevel != null && location!.priceLevel! > 0) {
      pills.add(_SearchMetaPill(label: '£' * location.priceLevel!));
    }
    if (location?.cuisine?.isNotEmpty == true) {
      pills.add(_SearchMetaPill(label: location!.cuisine!));
    }
    if (location?.openNow != null) {
      pills.add(
        _SearchMetaPill(label: location!.openNow! ? 'Open' : 'Closed'),
      );
    }
    if (pills.isEmpty && item.isMapboxResult) {
      pills.add(const _SearchMetaPill(label: 'Mapbox'));
    }
    return pills.take(3).toList(growable: false);
  }
}

class _SearchResultImage extends StatelessWidget {
  final SearchSuggestionItem item;

  const _SearchResultImage({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final location = item.location;
    final url = location?.imageUrl ?? location?.photoReference;

    if (url != null && url.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => _imagePlaceholder(),
        errorWidget: (_, __, ___) => _imageFallback(),
      );
    }

    return _imageFallback();
  }

  Widget _imagePlaceholder() {
    return Container(
      color: pinit.PinitColors.creamSunk,
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(pinit.PinitColors.aubergineSoft),
          ),
        ),
      ),
    );
  }

  Widget _imageFallback() {
    final emoji = item.location?.emoji;
    return Container(
      color: pinit.PinitColors.creamSunk,
      alignment: Alignment.center,
      child: emoji != null && emoji.isNotEmpty
          ? Text(
              emoji,
              style: const TextStyle(fontSize: 40),
            )
          : const Icon(
              FeatherIcons.mapPin,
              color: pinit.PinitColors.aubergineSoft,
              size: 32,
            ),
    );
  }
}

class _SearchListRating extends StatelessWidget {
  final double rating;
  final int? reviewCount;

  const _SearchListRating({
    required this.rating,
    this.reviewCount,
  });

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          FeatherIcons.star,
          size: 11,
          color: pinit.PinitColors.aubergine,
        ),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.dmSans(
            color: pinit.PinitColors.aubergine,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            height: 1.0,
            letterSpacing: 0.2,
          ),
        ),
        if (reviewCount != null && reviewCount! > 0) ...[
          const SizedBox(width: 3),
          Text(
            '(${_formatCount(reviewCount!)})',
            style: GoogleFonts.dmSans(
              color: pinit.PinitColors.mute,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchMetaPill extends StatelessWidget {
  final String label;

  const _SearchMetaPill({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: pinit.PinitColors.creamDeep,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: pinit.PinitColors.aubergine,
          letterSpacing: 0.4,
          height: 1.0,
        ),
      ),
    );
  }
}

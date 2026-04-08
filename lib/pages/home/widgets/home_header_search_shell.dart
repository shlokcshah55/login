import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/search/header_search_types.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/themes/pinit_colors.dart';
import 'package:login/themes/pinit_theme.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    if (!state.isActive) {
      return _CollapsedHeaderSearch(
        onEntryTap: onEntryTap,
        onMagicSearchTap: onMagicSearchTap,
        footer: footer,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedHeaderSearch extends StatelessWidget {
  final VoidCallback onEntryTap;
  final VoidCallback onMagicSearchTap;
  final Widget? footer;

  const _CollapsedHeaderSearch({
    required this.onEntryTap,
    required this.onMagicSearchTap,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _CollapsedSearchEntry(
                onTap: onEntryTap,
              ),
            ),
            const SizedBox(width: 10),
            _MagicSearchButton(
              onTap: onMagicSearchTap,
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
}

class _CollapsedSearchEntry extends StatelessWidget {
  final VoidCallback onTap;

  const _CollapsedSearchEntry({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PinitColors>()!;

    return GestureDetector(
      key: const Key('home_header_search_entry'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: PinitMotion.standard,
        curve: PinitMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.searchSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.glowAccent.withValues(alpha: 0.1),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.search,
              color: colors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Search places, prompts, or people',
                style: AppTypography.sans(
                  fontSize: 14,
                  color: colors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              CupertinoIcons.arrow_up_left_arrow_down_right,
              color: colors.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _MagicSearchButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MagicSearchButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<PinitColors>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              colors.primaryPurple,
              colors.softPurple,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primaryPurple.withValues(alpha: 0.24),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          color: Colors.white,
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

  const _SearchOverlay({
    required this.state,
    required this.controller,
    required this.focusNode,
    required this.onDismiss,
    required this.onQueryChanged,
    required this.onSuggestionSelected,
    required this.onPreviewStart,
    required this.onPreviewEnd,
  });

  @override
  State<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<_SearchOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
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
        final drift = 18 * (pulse - 0.5);

        return Material(
          color: Colors.transparent,
          child: DecoratedBox(
            key: const Key('header_search_fullscreen_layer'),
            decoration: const BoxDecoration(
              color: _HeaderSearchPalette.canvasBase,
            ),
            child: Stack(
              children: [
                _MistBackground(
                  pulse: pulse,
                  drift: drift,
                  isPreviewingMap: widget.state.isPreviewingMap,
                ),
                KeyedSubtree(
                  key: const Key('header_search_overlay'),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _OverlayStatusRow(
                            pulse: pulse,
                            isSearching: widget.state.result.isSearching,
                          ),
                          const SizedBox(height: 12),
                          _ExpandedSearchField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            inlineCompletion:
                                widget.state.result.inlineCompletion,
                            onChanged: widget.onQueryChanged,
                            onDismiss: widget.onDismiss,
                            pulse: pulse,
                          ),
                          if (widget
                              .state.result.quickSuggestions.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _SuggestionChipRow(
                              suggestions: widget.state.result.quickSuggestions,
                              onSelected: widget.onSuggestionSelected,
                            ),
                          ],
                          if (widget
                              .state.result.databaseMatches.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _SuggestionChipRow(
                              suggestions: widget.state.result.databaseMatches,
                              onSelected: widget.onSuggestionSelected,
                            ),
                          ],
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView.separated(
                              padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.of(context).padding.bottom + 28,
                              ),
                              itemCount: widget.state.result.sections.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                return _SectionCarousel(
                                  section: widget.state.result.sections[index],
                                  onSuggestionSelected:
                                      widget.onSuggestionSelected,
                                  onPreviewStart: widget.onPreviewStart,
                                  onPreviewEnd: widget.onPreviewEnd,
                                  pulse: pulse,
                                  emphasize: index == 0,
                                );
                              },
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
}

class _MistBackground extends StatelessWidget {
  final double pulse;
  final double drift;
  final bool isPreviewingMap;

  const _MistBackground({
    required this.pulse,
    required this.drift,
    required this.isPreviewingMap,
  });

  @override
  Widget build(BuildContext context) {
    final overlayOpacity = isPreviewingMap ? 0.95 : 1.0;

    return Opacity(
      opacity: overlayOpacity,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              key: const Key('header_search_mist_background'),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _HeaderSearchPalette.canvasTop,
                    _HeaderSearchPalette.canvasMiddle,
                    _HeaderSearchPalette.canvasBottom,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -42 + drift,
            right: -26 - (drift * 0.4),
            child: _MistOrb(
              size: 228,
              color: _HeaderSearchPalette.roseMist.withValues(alpha: 0.3),
            ),
          ),
          Positioned(
            top: 168 - (drift * 0.5),
            left: -54,
            child: _MistOrb(
              size: 208,
              color: _HeaderSearchPalette.mintMist.withValues(alpha: 0.34),
            ),
          ),
          Positioned(
            bottom: 112 + (drift * 0.4),
            right: 28,
            child: _MistOrb(
              size: 144,
              color: _HeaderSearchPalette.apricotMist.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            top: 132,
            left: 20,
            right: 20,
            child: Opacity(
              opacity: 0.4 + (pulse * 0.22),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0xBFFFFFFF),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SizedBox(height: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MistOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _MistOrb({
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

class _OverlayStatusRow extends StatelessWidget {
  final double pulse;
  final bool isSearching;

  const _OverlayStatusRow({
    required this.pulse,
    required this.isSearching,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Search',
          style: AppTypography.brand(
            fontSize: 12,
            letterSpacing: 1.8,
            color: _HeaderSearchPalette.labelText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _HeaderSearchPalette.panelBorder.withValues(alpha: 0.85),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _HeaderSearchPalette.roseAccent.withValues(
                    alpha: 0.45 + (pulse * 0.45),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isSearching ? 'Live' : 'Ready',
                style: AppTypography.brand(
                  fontSize: 11,
                  color: _HeaderSearchPalette.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpandedSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? inlineCompletion;
  final ValueChanged<String> onChanged;
  final VoidCallback onDismiss;
  final double pulse;

  const _ExpandedSearchField({
    required this.controller,
    required this.focusNode,
    required this.inlineCompletion,
    required this.onChanged,
    required this.onDismiss,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.998 + (pulse * 0.004),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _HeaderSearchPalette.panelBorder.withValues(
              alpha: 0.8 + (pulse * 0.15),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: _HeaderSearchPalette.depthShadow.withValues(
                alpha: 0.08 + (pulse * 0.05),
              ),
              blurRadius: 24 + (pulse * 8),
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.search,
              color: _HeaderSearchPalette.roseAccent,
              size: 18,
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
                          color: _HeaderSearchPalette.mutedText.withValues(
                            alpha: 0.48,
                          ),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  TextField(
                    key: const Key('header_search_text_field'),
                    controller: controller,
                    focusNode: focusNode,
                    cursorColor: _HeaderSearchPalette.roseAccent,
                    style: AppTypography.sans(
                      fontSize: 15,
                      color: _HeaderSearchPalette.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search places, prompts, or people',
                      hintStyle: AppTypography.sans(
                        fontSize: 15,
                        color: _HeaderSearchPalette.mutedText,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  CupertinoIcons.xmark,
                  color: _HeaderSearchPalette.secondaryText,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChipRow extends StatelessWidget {
  final List<SearchSuggestionItem> suggestions;
  final ValueChanged<SearchSuggestionItem> onSelected;

  const _SuggestionChipRow({
    required this.suggestions,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return GestureDetector(
            onTap: () => onSelected(suggestion),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.54),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _HeaderSearchPalette.panelBorder,
                ),
              ),
              child: Text(
                suggestion.title,
                style: AppTypography.brand(
                  fontSize: 12.5,
                  color: _HeaderSearchPalette.primaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionCarousel extends StatelessWidget {
  final HeaderSearchSectionModel section;
  final ValueChanged<SearchSuggestionItem> onSuggestionSelected;
  final ValueChanged<LocationModel> onPreviewStart;
  final VoidCallback onPreviewEnd;
  final double pulse;
  final bool emphasize;

  const _SectionCarousel({
    required this.section,
    required this.onSuggestionSelected,
    required this.onPreviewStart,
    required this.onPreviewEnd,
    required this.pulse,
    required this.emphasize,
  });

  @override
  Widget build(BuildContext context) {
    final glowAlpha = emphasize ? 0.1 + (pulse * 0.06) : 0.06;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _HeaderSearchPalette.panelBorder,
        ),
        boxShadow: [
          BoxShadow(
            color:
                _HeaderSearchPalette.depthShadow.withValues(alpha: glowAlpha),
            blurRadius: emphasize ? 28 : 20,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    section.title,
                    key: ValueKey<String>(section.title),
                    style: AppTypography.brand(
                      fontSize: 12,
                      letterSpacing: 1.4,
                      color: _HeaderSearchPalette.labelText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (emphasize
                            ? _HeaderSearchPalette.roseAccent
                            : _HeaderSearchPalette.mintAccent)
                        .withValues(alpha: 0.4 + (pulse * 0.4)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 136,
            child: section.isLoading
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, __) => _LoadingCard(
                      pulse: pulse,
                    ),
                  )
                : section.items.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'No matches yet',
                            style: AppTypography.sans(
                              fontSize: 13,
                              color: _HeaderSearchPalette.mutedText,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: section.items.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = section.items[index];
                          return _SearchResultCard(
                            item: item,
                            onSelected: onSuggestionSelected,
                            onPreviewStart: onPreviewStart,
                            onPreviewEnd: onPreviewEnd,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final double pulse;

  const _LoadingCard({
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 186,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52 + (pulse * 0.08)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 24,
            decoration: BoxDecoration(
              color: _HeaderSearchPalette.roseMist.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const Spacer(),
          Container(
            width: 108,
            height: 12,
            decoration: BoxDecoration(
              color: _HeaderSearchPalette.labelText.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 136,
            height: 10,
            decoration: BoxDecoration(
              color: _HeaderSearchPalette.labelText.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final SearchSuggestionItem item;
  final ValueChanged<SearchSuggestionItem> onSelected;
  final ValueChanged<LocationModel> onPreviewStart;
  final VoidCallback onPreviewEnd;

  const _SearchResultCard({
    required this.item,
    required this.onSelected,
    required this.onPreviewStart,
    required this.onPreviewEnd,
  });

  @override
  Widget build(BuildContext context) {
    final keyValue = item.id.replaceAll(':', '-');
    final canPreview = item.location != null;

    return GestureDetector(
      key: Key('header_search_card_$keyValue'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelected(item),
      onLongPress: canPreview ? () => onPreviewStart(item.location!) : null,
      onLongPressEnd: canPreview ? (_) => onPreviewEnd() : null,
      child: Container(
        width: 186,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _HeaderSearchPalette.cardTop,
              _HeaderSearchPalette.cardBottom,
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: item.isMapboxResult
                ? _HeaderSearchPalette.roseAccent.withValues(alpha: 0.28)
                : _HeaderSearchPalette.panelBorder,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x141A0D14),
              blurRadius: 22,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.56),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                _labelForItem(item),
                style: AppTypography.brand(
                  fontSize: 10.5,
                  color: _HeaderSearchPalette.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.brand(
                fontSize: 16,
                color: _HeaderSearchPalette.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (item.subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                item.subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sans(
                  fontSize: 12,
                  color: _HeaderSearchPalette.secondaryText,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _labelForItem(SearchSuggestionItem item) {
    switch (item.kind) {
      case SearchSuggestionKind.recentQuery:
        return 'Recent';
      case SearchSuggestionKind.personalPrompt:
        return 'Prompt';
      case SearchSuggestionKind.place:
        return item.isMapboxResult ? 'Mapbox' : 'Place';
      case SearchSuggestionKind.naturalLanguage:
        return 'Recommended';
      case SearchSuggestionKind.person:
        return 'Person';
    }
  }
}

class _HeaderSearchPalette {
  static const canvasBase = Color(0xFFFFFAF7);
  static const canvasTop = Color(0xFFFFF1F4);
  static const canvasMiddle = Color(0xFFF1FAF6);
  static const canvasBottom = Color(0xFFFFFAF7);

  static const roseAccent = Color(0xFFD95D85);
  static const roseMist = Color(0xFFF6C7D5);
  static const mintAccent = Color(0xFF7CCAB4);
  static const mintMist = Color(0xFFD6F0E7);
  static const apricotMist = Color(0xFFFFD9C0);

  static const cardTop = Color(0xF7FFFFFF);
  static const cardBottom = Color(0xFFFDF4F2);
  static const panelBorder = Color(0x26A8687F);
  static const depthShadow = Color(0x261F1118);

  static const primaryText = Color(0xFF5F3948);
  static const secondaryText = Color(0xFF8B6673);
  static const mutedText = Color(0xFFA38791);
  static const labelText = Color(0xAA6E4857);
}

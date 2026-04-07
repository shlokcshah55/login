import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/themes/pinit_colors.dart';
import 'package:login/themes/pinit_theme.dart';

/// Clean, minimal search bar — reads colors from PinitColors extension.
///
/// Dark: uses searchSurface (#2A1740), subtle glow on focus
/// Light: uses searchSurface (#F3ECF9), elevation on focus
/// No border in either mode.
class PinitSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  const PinitSearchBar({
    Key? key,
    required this.controller,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<PinitSearchBar> createState() => _PinitSearchBarState();
}

class _PinitSearchBarState extends State<PinitSearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    });
    widget.controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<PinitColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: PinitMotion.standard,
      curve: PinitMotion.curve,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: c.searchSurface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: isDark
                      ? c.glowAccent.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.08),
                  blurRadius: isDark ? 16 : 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.search,
            size: 18,
            color: _isFocused ? c.primaryPurple : c.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                widget.onSubmit(value);
                _focusNode.unfocus();
              },
              style: AppTypography.sans(
                fontSize: 14,
                color: c.textPrimary,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: 'Search places, vibes, or friends…',
                hintStyle: AppTypography.sans(
                  fontSize: 13.5,
                  color: c.textMuted,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (widget.controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                widget.controller.clear();
                setState(() {});
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 16,
                  color: c.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

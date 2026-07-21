import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

class HomeSocialInboxButton extends StatefulWidget {
  const HomeSocialInboxButton({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  State<HomeSocialInboxButton> createState() => _HomeSocialInboxButtonState();
}

class _HomeSocialInboxButtonState extends State<HomeSocialInboxButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final hasCount = widget.count > 0;
    final countLabel = widget.count > 99 ? '99+' : '${widget.count}';
    final semanticLabel = hasCount
        ? 'Open shared saves inbox, ${widget.count} need checking'
        : 'Open shared saves inbox';

    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('home_social_inbox_button'),
        onTapDown: (_) => setState(() => _scale = 0.94),
        onTapUp: (_) => setState(() => _scale = 1),
        onTapCancel: () => setState(() => _scale = 1),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: PinitColors.cream,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: PinitColors.aubergine,
                        width: 1.6,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: PinitColors.aubergine,
                          blurRadius: 0,
                          offset: Offset(3, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      FeatherIcons.inbox,
                      color: PinitColors.aubergine,
                      size: 21,
                    ),
                  ),
                ),
                if (hasCount)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 19),
                      height: 19,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: const BoxDecoration(
                        color: PinitColors.aubergine,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        countLabel,
                        style: GoogleFonts.dmSans(
                          color: PinitColors.cream,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

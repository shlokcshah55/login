import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single Decide CTA styled to match the mode toggle —
/// dark Pinit brand pill with lighter text.
class DecideButton extends StatefulWidget {
  final VoidCallback onTap;

  const DecideButton({Key? key, required this.onTap}) : super(key: key);

  @override
  State<DecideButton> createState() => _DecideButtonState();
}

class _DecideButtonState extends State<DecideButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  static const _pillBg = Color(0xFF3A1435);
  static const _pillBorder = Color(0xFF5A3055);
  static const _textColor = Color(0xFFEEDDEC);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scale = Tween(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Transform.scale(
            scale: _scale.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _pillBg,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _pillBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: _textColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Decide',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                      letterSpacing: 0.15,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

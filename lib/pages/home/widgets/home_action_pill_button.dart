import 'package:flutter/material.dart';
import 'package:login/themes/app_typography.dart';

class HomeActionPillButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<Color> gradientColors;
  final Color foregroundColor;
  final VoidCallback onPressed;

  const HomeActionPillButton({
    Key? key,
    required this.label,
    required this.icon,
    required this.gradientColors,
    required this.foregroundColor,
    required this.onPressed,
  }) : super(key: key);

  @override
  State<HomeActionPillButton> createState() => _HomeActionPillButtonState();
}

class _HomeActionPillButtonState extends State<HomeActionPillButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _glowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _controller.forward();
  void _onTapUp(TapUpDetails details) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                gradient: LinearGradient(
                  colors: widget.gradientColors
                      .map(
                        (c) => Color.lerp(
                          c,
                          c.withValues(alpha: 0.85),
                          _glowAnim.value,
                        )!,
                      )
                      .toList(),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: widget.foregroundColor.withValues(alpha: 0.15),
                  width: 0.5,
                ),
                boxShadow: [
                  // Soft colored glow beneath
                  BoxShadow(
                    color: widget.gradientColors.first.withValues(
                      alpha: 0.3 + (_glowAnim.value * 0.15),
                    ),
                    blurRadius: 12 + (_glowAnim.value * 4),
                    offset: const Offset(0, 4),
                    spreadRadius: -2,
                  ),
                  // Subtle inner highlight
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.08),
                    blurRadius: 1,
                    offset: const Offset(0, -0.5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    size: 13.0,
                    color: widget.foregroundColor.withValues(alpha: 0.9),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    widget.label,
                    style: AppTypography.brand(
                      color: widget.foregroundColor,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

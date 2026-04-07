import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:login/models/bubble.dart';
import 'package:login/themes/app_typography.dart';

/// A Siri-like glow overlay that appears around the screen edges
/// when bubble mode is activated
class BubbleModeOverlay extends StatefulWidget {
  final Bubble bubble;
  final Future<void> Function() onDeactivate;

  const BubbleModeOverlay({
    super.key,
    required this.bubble,
    required this.onDeactivate,
  });

  @override
  State<BubbleModeOverlay> createState() => _BubbleModeOverlayState();
}

class _BubbleModeOverlayState extends State<BubbleModeOverlay>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late AnimationController _entryController;
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _entryAnimation;
  bool _isDropdownExpanded = false;

  @override
  void initState() {
    super.initState();

    // Glow rotation animation
    _glowController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // Pulse animation for the glow intensity
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Entry animation
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutBack,
    );
    _entryController.forward();

    _glowAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _pulseController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    setState(() {
      _isDropdownExpanded = !_isDropdownExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // Animated glow border - fills entire screen
        Positioned.fill(
          child: IgnorePointer(
            child: ListenableBuilder(
              listenable: Listenable.merge([_glowController, _pulseController]),
              builder: (context, child) {
                return CustomPaint(
                  painter: _SiriGlowPainter(
                    rotationAngle: _glowAnimation.value,
                    intensity: _pulseAnimation.value,
                    colors: [
                      const Color(0xFF9C27B0), // Purple
                      const Color(0xFFE040FB), // Pink accent
                      const Color(0xFF7C4DFF), // Deep purple accent
                      const Color(0xFFAB47BC), // Purple 300
                      const Color(0xFF9C27B0), // Purple (loop)
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // Bubble indicator dropdown at top
        Positioned(
          top: topPadding + 8,
          left: 0,
          right: 0,
          child: Center(
            child: ListenableBuilder(
              listenable: _entryController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _entryAnimation.value,
                  child: child,
                );
              },
              child: _BubbleIndicator(
                bubble: widget.bubble,
                isExpanded: _isDropdownExpanded,
                onTap: _toggleDropdown,
                onDeactivate: widget.onDeactivate,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The dropdown indicator showing the active bubble
class _BubbleIndicator extends StatelessWidget {
  final Bubble bubble;
  final bool isExpanded;
  final VoidCallback onTap;
  final Future<void> Function() onDeactivate;

  const _BubbleIndicator({
    required this.bubble,
    required this.isExpanded,
    required this.onTap,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isExpanded ? 12 : 8,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF9C27B0).withValues(alpha: 0.95),
              const Color(0xFF7B1FA2).withValues(alpha: 0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(isExpanded ? 16 : 24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9C27B0).withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: const Color(0xFFE040FB).withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main row with bubble info
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bubble avatar
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    image: bubble.groupAvatar.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(bubble.groupAvatar),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: bubble.groupAvatar.isEmpty
                        ? Colors.white.withValues(alpha: 0.3)
                        : null,
                  ),
                  child: bubble.groupAvatar.isEmpty
                      ? const Icon(
                          Icons.group,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                // Bubble name
                Text(
                  bubble.name,
                  style: AppTypography.brand(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                // Dropdown arrow
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: isExpanded ? 0.5 : 0,
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),

            // Expanded content
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    // Member count info
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${bubble.memberCount} members',
                          style: AppTypography.sans(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${bubble.groupLocations.length} pins',
                          style: AppTypography.sans(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Exit button
                    GestureDetector(
                      onTap: onDeactivate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Exit Bubble Mode',
                              style: AppTypography.brand(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the Siri-like glow effect around the screen edges
class _SiriGlowPainter extends CustomPainter {
  final double rotationAngle;
  final double intensity;
  final List<Color> colors;

  _SiriGlowPainter({
    required this.rotationAngle,
    required this.intensity,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final borderWidth = 6.0;
    final blurRadius = 20.0 * intensity;

    // Create a gradient that rotates around the border
    final sweepGradient = SweepGradient(
      center: Alignment.center,
      startAngle: rotationAngle,
      endAngle: rotationAngle + 2 * math.pi,
      colors: colors,
      tileMode: TileMode.clamp,
    );

    // Draw multiple layers for a more intense glow effect
    for (int i = 3; i >= 0; i--) {
      final currentBlur = blurRadius * (i + 1) / 2;
      final currentWidth = borderWidth + (i * 4);
      final currentOpacity = intensity * (1 - i * 0.2);

      final paint = Paint()
        ..shader = sweepGradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = currentWidth
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, currentBlur);

      // Apply opacity
      paint.color = paint.color.withValues(alpha: currentOpacity);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          currentWidth / 2,
          currentWidth / 2,
          size.width - currentWidth,
          size.height - currentWidth,
        ),
        const Radius.circular(0),
      );

      canvas.drawRRect(rrect, paint);
    }

    // Draw the main sharp border
    final mainPaint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final mainRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        borderWidth / 2,
        borderWidth / 2,
        size.width - borderWidth,
        size.height - borderWidth,
      ),
      const Radius.circular(0),
    );

    canvas.drawRRect(mainRRect, mainPaint);
  }

  @override
  bool shouldRepaint(_SiriGlowPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.intensity != intensity;
  }
}

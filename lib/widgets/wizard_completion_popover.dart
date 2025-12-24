import 'package:flutter/material.dart';
import 'package:login/themes/app_colors.dart';
import 'package:login/animations/common_animations.dart';

/// Bold, energetic popover that prompts users to complete their profile wizard
class WizardCompletionPopover extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onDismiss;

  const WizardCompletionPopover({
    Key? key,
    required this.onComplete,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<WizardCompletionPopover> createState() => _WizardCompletionPopoverState();
}

class _WizardCompletionPopoverState extends State<WizardCompletionPopover>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    // Button pulse animation (1.0 ↔ 1.05 over 1.5 seconds)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Shimmer sweep animation (left to right over 2 seconds)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: size.height * 0.65,
        ),
        child: SizedBox(
          width: size.width * 0.85,
          child: Container(
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage('lib/assets/background.jpg'),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Typing title animation
                  const TypingText(
                    text: 'Give us some more...',
                    totalDuration: Duration(milliseconds: 800),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description text
                  Text(
                    'We do better with more information! It takes less time that 3 scrolls on Tiktok 😉',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Pulsing + Shimmer CTA button
                  _buildAnimatedButton(),
                  const SizedBox(height: 16),

                  // "Later" button
                  TextButton(
                    onPressed: widget.onDismiss,
                    child: Text(
                      'Later',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }

  /// Builds the animated CTA button with pulse and shimmer effects
  Widget _buildAnimatedButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.05);
        final glowOpacity = 0.3 * _pulseController.value;

        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(glowOpacity),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      'Complete Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    // Shimmer overlay
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: _ButtonShimmerPainter(
                              shimmerProgress: _shimmerController.value,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for button shimmer effect
class _ButtonShimmerPainter extends CustomPainter {
  final double shimmerProgress;
  final Color color;

  _ButtonShimmerPainter({
    required this.shimmerProgress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1 + shimmerProgress * 3, 0),
        end: Alignment(-0.5 + shimmerProgress * 3, 0),
        colors: [
          color.withOpacity(0.0),
          color,
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ButtonShimmerPainter oldDelegate) {
    return oldDelegate.shimmerProgress != shimmerProgress;
  }
}

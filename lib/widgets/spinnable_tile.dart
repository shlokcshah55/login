import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// Reusable spinnable tile widget.
/// Shows an image on the front and a description on the back. It flips on
/// long-press and briefly on tap. It also displays a selection overlay.
class SpinnableTile extends StatefulWidget {
  final String assetPath;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const SpinnableTile({
    Key? key,
    required this.assetPath,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  State<SpinnableTile> createState() => _SpinnableTileState();
}

class _SpinnableTileState extends State<SpinnableTile> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _flipAnim = Tween<double>(begin: 0.0, end: math.pi).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: (_) => _ctrl.forward(),
      onLongPressEnd: (_) => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final isHalf = _flipAnim.value > (math.pi / 2);
          final rotationY = _flipAnim.value;

          final frontMatrix = Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(rotationY);
          final backMatrix = Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(rotationY + math.pi);

          final cardDecoration = BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PinitColors.aubergine, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: PinitColors.aubergine,
                blurRadius: 0,
                offset: Offset(3, 3),
              ),
            ],
          );

          Widget frontFace = Container(
            decoration: cardDecoration,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.expand(
                child: Image.asset(
                  widget.assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            ),
          );

          Widget backFace = Container(
            decoration: cardDecoration.copyWith(color: Colors.white),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    widget.description,
                    style: const TextStyle(
                      fontFamily: 'Rova',
                      fontSize: 16,
                      fontWeight: FontWeight.w100,
                      color: PinitColors.aubergine,
                      letterSpacing: 1.5,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );

          return Stack(
            alignment: Alignment.center,
            children: [
              Transform(
                transform: frontMatrix,
                alignment: Alignment.center,
                child: Visibility(
                  visible: !isHalf,
                  maintainState: true,
                  maintainAnimation: true,
                  child: frontFace,
                ),
              ),

              Transform(
                transform: backMatrix,
                alignment: Alignment.center,
                child: Visibility(
                  visible: isHalf,
                  maintainState: true,
                  maintainAnimation: true,
                  child: backFace,
                ),
              ),

              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: widget.isSelected ? 1.0 : 0.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Center(
                      child: Icon(Icons.check_circle, color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:login/themes/pinit_colors.dart';
import 'package:login/themes/pinit_theme.dart';

/// Location FAB — theme-aware.
///
/// Dark: elevated surface circle with glow-accent icon.
/// Light: white circle with purple icon.
class MyLocationButton extends StatefulWidget {
  final VoidCallback onTap;

  const MyLocationButton({Key? key, required this.onTap}) : super(key: key);

  @override
  State<MyLocationButton> createState() => _MyLocationButtonState();
}

class _MyLocationButtonState extends State<MyLocationButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<PinitColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.90),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: PinitMotion.fast,
        curve: PinitMotion.curve,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? c.elevatedSurface : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.10),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              CupertinoIcons.location_fill,
              size: 18,
              color: isDark ? c.glowAccent : c.primaryPurple,
            ),
          ),
        ),
      ),
    );
  }
}

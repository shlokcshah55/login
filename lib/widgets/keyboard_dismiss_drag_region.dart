import 'package:flutter/material.dart';

class KeyboardDismissDragRegion extends StatefulWidget {
  const KeyboardDismissDragRegion({
    super.key,
    required this.child,
    this.verticalDismissThreshold = 18,
  });

  final Widget child;
  final double verticalDismissThreshold;

  @override
  State<KeyboardDismissDragRegion> createState() =>
      _KeyboardDismissDragRegionState();
}

class _KeyboardDismissDragRegionState extends State<KeyboardDismissDragRegion> {
  final Map<int, Offset> _pointerOrigins = <int, Offset>{};

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _pointerOrigins[event.pointer] = event.position;
      },
      onPointerMove: (event) {
        final origin = _pointerOrigins[event.pointer];
        if (origin == null) return;

        final delta = event.position - origin;
        final isDownwardSwipe = delta.dy >= widget.verticalDismissThreshold &&
            delta.dy.abs() > delta.dx.abs();
        if (!isDownwardSwipe) return;

        final focus = FocusManager.instance.primaryFocus;
        if (focus == null || !focus.hasFocus) return;

        focus.unfocus();
        _pointerOrigins.remove(event.pointer);
      },
      onPointerUp: (event) {
        _pointerOrigins.remove(event.pointer);
      },
      onPointerCancel: (event) {
        _pointerOrigins.remove(event.pointer);
      },
      child: widget.child,
    );
  }
}

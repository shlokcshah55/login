import 'package:flutter/material.dart';
import 'animation_builders.dart';

/// Typing text widget used for subtle title animations in forms.
class TypingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration totalDuration;
  final Duration startDelay;

  const TypingText({
    Key? key,
    required this.text,
    this.style,
  this.totalDuration = const Duration(milliseconds: 2200),
    this.startDelay = Duration.zero,
  }) : super(key: key);

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<int> _charCount;

  @override
  void initState() {
    super.initState();
    final len = widget.text.length;
    final duration = widget.totalDuration;
    _ctrl = AnimationController(vsync: this, duration: duration);
    _charCount = StepTween(begin: 0, end: len).animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
    if (widget.startDelay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.startDelay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void didUpdateWidget(covariant TypingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.totalDuration != widget.totalDuration) {
      _ctrl.reset();
      final len = widget.text.length;
      _charCount = StepTween(begin: 0, end: len).animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
      Future.microtask(() => _ctrl.forward());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _charCount,
      builder: (context, child) {
        final count = _charCount.value.clamp(0, widget.text.length);
        final visible = widget.text.substring(0, count);
        return Text(
          visible,
          style: widget.style,
          textAlign: TextAlign.center,
        );
      },
    );
  }
}

/// Common animation pattern: Entrance with scale, fade, and slide
class EntranceAnimations {
  final Animation<double> scale;
  final Animation<double> fade;
  final Animation<Offset> slide;
  final Animation<double> rotation;

  EntranceAnimations({
    required AnimationController controller,
  })  : scale = AnimationBuilders.createScaleAnimation(controller),
        fade = AnimationBuilders.createFadeAnimation(controller),
        slide = AnimationBuilders.createMainSlideAnimation(controller),
        rotation = AnimationBuilders.createRotationAnimation(controller);
}

/// Staggered animations for form fields
class StaggeredFormAnimations {
  final Animation<Offset> textSlide;
  final Animation<Offset> fieldSlide;
  final Animation<Offset> bottomSlide;
  final Animation<double> fade;

  StaggeredFormAnimations({
    required AnimationController controller,
  })  : textSlide = AnimationBuilders.createTextSlideAnimation(controller),
        fieldSlide = AnimationBuilders.createFieldSlideAnimation(controller),
        bottomSlide = AnimationBuilders.createBottomSlideAnimation(controller),
        fade = AnimationBuilders.createFadeAnimation(controller);
}

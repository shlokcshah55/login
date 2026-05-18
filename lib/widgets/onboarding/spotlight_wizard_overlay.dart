import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/themes/app_typography.dart';

enum SpotlightBubblePlacement { above, below, auto }

enum SpotlightHighlightShape { rounded, pill, circle }

class SpotlightWizardStep {
  const SpotlightWizardStep({
    required this.title,
    required this.description,
    this.targetKey,
    this.placement = SpotlightBubblePlacement.auto,
    this.highlightShape = SpotlightHighlightShape.rounded,
    this.shadowColor = PinitColors.aubergine,
    this.showHighlightShadow = true,
    this.illustrationAssetPath,
    this.titleLogoAssetPath,
    this.badgeIcon,
    this.badgeColor = PinitColors.aubergine,
    this.beforeShow,
    this.bubbleHeightEstimate,
    this.eyebrow,
    this.bodyBuilder,
  });

  final GlobalKey? targetKey;
  final String title;
  final String description;
  final SpotlightBubblePlacement placement;
  final SpotlightHighlightShape highlightShape;
  final Color shadowColor;
  final bool showHighlightShadow;
  final String? illustrationAssetPath;
  final String? titleLogoAssetPath;
  final IconData? badgeIcon;
  final Color badgeColor;
  final FutureOr<void> Function()? beforeShow;
  final double? bubbleHeightEstimate;
  final String? eyebrow;
  final WidgetBuilder? bodyBuilder;

  bool get hasTarget => targetKey != null;
}

class SpotlightWizardOverlay extends StatefulWidget {
  const SpotlightWizardOverlay({
    super.key,
    required this.steps,
    required this.onCompleted,
    required this.onSkipped,
  });

  final List<SpotlightWizardStep> steps;
  final VoidCallback onCompleted;
  final VoidCallback onSkipped;

  @override
  State<SpotlightWizardOverlay> createState() => _SpotlightWizardOverlayState();
}

class _SpotlightWizardOverlayState extends State<SpotlightWizardOverlay> {
  final GlobalKey _overlayKey = GlobalKey();
  Rect? _targetRect;
  int? _preparedStepIndex;
  int _index = 0;

  SpotlightWizardStep get _step => widget.steps[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prepareAndResolveCurrentStep());
    });
  }

  @override
  void didUpdateWidget(covariant SpotlightWizardOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.steps.isEmpty) return;
    if (_index >= widget.steps.length) {
      _index = widget.steps.length - 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prepareAndResolveCurrentStep());
    });
  }

  Future<void> _prepareAndResolveCurrentStep() async {
    if (!mounted || widget.steps.isEmpty) return;
    if (_preparedStepIndex != _index) {
      _preparedStepIndex = _index;
      await _step.beforeShow?.call();
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
    }
    _resolveTargetRect();
  }

  void _resolveTargetRect() {
    if (!mounted || widget.steps.isEmpty) return;
    final overlayContext = _overlayKey.currentContext;
    final targetKey = _step.targetKey;
    if (targetKey == null) {
      setState(() => _targetRect = null);
      return;
    }

    final targetContext = targetKey.currentContext;
    if (overlayContext == null || targetContext == null) {
      setState(() => _targetRect = null);
      return;
    }

    final overlayObject = overlayContext.findRenderObject();
    final targetObject = targetContext.findRenderObject();
    if (overlayObject is! RenderBox ||
        targetObject is! RenderBox ||
        !targetObject.attached ||
        targetObject.size.isEmpty) {
      setState(() => _targetRect = null);
      return;
    }

    final overlayOrigin = overlayObject.localToGlobal(Offset.zero);
    final targetOrigin = targetObject.localToGlobal(Offset.zero);
    final nextRect = targetOrigin - overlayOrigin & targetObject.size;

    if (_targetRect != nextRect) {
      setState(() => _targetRect = nextRect);
    }
  }

  void _goNext() {
    if (_index == widget.steps.length - 1) {
      widget.onCompleted();
      return;
    }
    setState(() {
      _index += 1;
      _targetRect = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prepareAndResolveCurrentStep());
    });
  }

  void _goBack() {
    if (_index == 0) return;
    setState(() {
      _index -= 1;
      _targetRect = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_prepareAndResolveCurrentStep());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    return Positioned.fill(
      child: SizedBox.expand(
        key: _overlayKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final spotlightRect = _targetRect == null
                ? null
                : _expandedAndClampedRect(_targetRect!, size);
            final bubbleOffset = _bubbleOffsetFor(
              size,
              spotlightRect,
              MediaQuery.viewInsetsOf(context).bottom,
            );

            return Material(
              type: MaterialType.transparency,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: _SpotlightBackdrop(
                        spotlightRect: spotlightRect,
                        highlightShape: _step.highlightShape,
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    left: bubbleOffset.dx,
                    top: bubbleOffset.dy,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) {
                        final curved = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        );
                        return FadeTransition(
                          opacity: curved,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.96, end: 1).animate(
                              curved,
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: _SpotlightBubble(
                        key: ValueKey<int>(_index),
                        step: _step,
                        stepLabel: _stepLabelFor(_index),
                        index: _index,
                        total: widget.steps.length,
                        canGoBack: _index > 0,
                        onBack: _goBack,
                        onNext: _goNext,
                        onSkip: widget.onSkipped,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _stepLabelFor(int index) {
    final step = widget.steps[index];
    if (!step.hasTarget) return step.eyebrow ?? 'WELCOME';

    final featureTotal = widget.steps.where((step) => step.hasTarget).length;
    final featureIndex =
        widget.steps.take(index + 1).where((step) => step.hasTarget).length;
    return step.eyebrow ?? 'PIN $featureIndex OF $featureTotal';
  }

  Rect _expandedAndClampedRect(Rect rect, Size size) {
    const padding = 8.0;
    return Rect.fromLTRB(
      math.max(12, rect.left - padding),
      math.max(12, rect.top - padding),
      math.min(size.width - 12, rect.right + padding),
      math.min(size.height - 12, rect.bottom + padding),
    );
  }

  Offset _bubbleOffsetFor(
    Size size,
    Rect? spotlightRect,
    double bottomInset,
  ) {
    const margin = 18.0;
    const bubbleWidth = 326.0;
    final isIntro = !_step.hasTarget;
    final actualEstimatedBubbleHeight =
        _step.bubbleHeightEstimate ?? (isIntro ? 390.0 : 360.0);
    final availableHeight = math.max(margin * 2, size.height - bottomInset);

    if (spotlightRect == null) {
      return Offset(
        math.max(margin, (size.width - bubbleWidth) / 2),
        math.max(
          margin,
          (availableHeight - actualEstimatedBubbleHeight) / 2,
        ),
      );
    }

    final width = math.min(bubbleWidth, size.width - (margin * 2));
    final left = ((spotlightRect.center.dx - width / 2)
            .clamp(margin, size.width - width - margin))
        .toDouble();
    final belowY = spotlightRect.bottom + 16;
    final aboveY = spotlightRect.top - actualEstimatedBubbleHeight - 16;
    final hasRoomBelow =
        belowY + actualEstimatedBubbleHeight <= availableHeight - margin;
    final hasRoomAbove = aboveY >= margin;

    final useBelow = switch (_step.placement) {
      SpotlightBubblePlacement.below => true,
      SpotlightBubblePlacement.above => false,
      SpotlightBubblePlacement.auto => hasRoomBelow || !hasRoomAbove,
    };

    final top = useBelow
        ? math.min(
            belowY,
            availableHeight - actualEstimatedBubbleHeight - margin,
          )
        : math.max(margin, aboveY);

    return Offset(left, top.toDouble());
  }
}

class _SpotlightBubble extends StatelessWidget {
  const _SpotlightBubble({
    super.key,
    required this.step,
    required this.stepLabel,
    required this.index,
    required this.total,
    required this.canGoBack,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
  });

  final SpotlightWizardStep step;
  final String stepLabel;
  final int index;
  final int total;
  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = math.min(326.0, mediaQuery.size.width - 36);
    final maxHeight = math.max(
      240.0,
      mediaQuery.size.height - mediaQuery.viewInsets.bottom - 36,
    );
    final isLast = index == total - 1;
    final isIntro = !step.hasTarget;

    return SizedBox(
      width: width,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: PinitColors.creamSunk,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: PinitColors.aubergine,
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: PinitColors.aubergine,
                  blurRadius: 0,
                  offset: Offset(4, 4),
                ),
                BoxShadow(
                  color: Color(0x3341133D),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        stepLabel,
                        style: AppTypography.sans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: PinitColors.aubergineSoft,
                          letterSpacing: 1.2,
                          height: 1,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onSkip,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Text(
                            'SKIP',
                            style: AppTypography.sans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: PinitColors.mute,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _StepTitle(step: step, isIntro: isIntro)),
                      if (step.badgeIcon != null) ...[
                        const SizedBox(width: 14),
                        _StepBadge(step: step),
                      ],
                    ],
                  ),
                  if (step.illustrationAssetPath != null) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: SizedBox(
                        height: isIntro ? 142 : 110,
                        child: SvgPicture.asset(
                          step.illustrationAssetPath!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (step.bodyBuilder case final bodyBuilder?)
                    bodyBuilder(context)
                  else
                    Text(
                      step.description,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PinitColors.aubergineSoft,
                      ),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      SizedBox(
                        width: 42,
                        height: 42,
                        child: Material(
                          color: PinitColors.creamSunk,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: canGoBack ? onBack : null,
                            child: Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                              color: canGoBack
                                  ? PinitColors.aubergine
                                  : PinitColors.mute.withValues(alpha: 0.38),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: PinitColors.aubergine,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [
                              BoxShadow(
                                color: PinitColors.aubergine,
                                blurRadius: 0,
                                offset: Offset(3, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: onNext,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: Center(
                                  child: Text(
                                    isLast ? 'DONE' : 'NEXT',
                                    style: AppTypography.sans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: PinitColors.cream,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.step,
    required this.isIntro,
  });

  final SpotlightWizardStep step;
  final bool isIntro;

  @override
  Widget build(BuildContext context) {
    final logoAsset = step.titleLogoAssetPath;
    if (logoAsset == null) {
      return Text(
        step.title,
        style: AppTypography.brand(
          fontSize: isIntro ? 30 : 28,
          fontWeight: FontWeight.w100,
          color: PinitColors.aubergine,
          height: 1.0,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          step.title,
          style: AppTypography.brand(
            fontSize: 30,
            fontWeight: FontWeight.w100,
            color: PinitColors.aubergine,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 3),
        Image.asset(
          logoAsset,
          height: 40,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({
    required this.step,
  });

  final SpotlightWizardStep step;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: step.badgeColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (step.badgeColor == PinitColors.aubergine)
                ? PinitColors.cream
                : PinitColors.aubergine,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (step.badgeColor == PinitColors.aubergine)
                  ? PinitColors.black
                  : PinitColors.aubergine,
              blurRadius: 0,
              offset: const Offset(3, 3),
            ),
          ],
        ),
        child: Icon(
          step.badgeIcon,
          color: PinitColors.cream,
          size: 22,
        ),
      ),
    );
  }
}

class _SpotlightBackdrop extends StatelessWidget {
  const _SpotlightBackdrop({
    required this.spotlightRect,
    required this.highlightShape,
  });

  final Rect? spotlightRect;
  final SpotlightHighlightShape highlightShape;

  @override
  Widget build(BuildContext context) {
    final rect = spotlightRect;
    if (rect == null) {
      return BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.8),
          child: const SizedBox.expand(),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipPath(
          clipper: _SpotlightOutsideClipper(
            rect: rect,
            highlightShape: highlightShape,
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: const SizedBox.expand(),
          ),
        ),
        CustomPaint(
          painter: _SpotlightScrimPainter(
            rect: rect,
            highlightShape: highlightShape,
          ),
        ),
      ],
    );
  }
}

class _SpotlightOutsideClipper extends CustomClipper<Path> {
  const _SpotlightOutsideClipper({
    required this.rect,
    required this.highlightShape,
  });

  final Rect rect;
  final SpotlightHighlightShape highlightShape;

  @override
  Path getClip(Size size) {
    return _outsidePathFor(
      size: size,
      rect: rect,
      highlightShape: highlightShape,
    );
  }

  @override
  bool shouldReclip(_SpotlightOutsideClipper oldClipper) {
    return oldClipper.rect != rect ||
        oldClipper.highlightShape != highlightShape;
  }
}

class _SpotlightScrimPainter extends CustomPainter {
  const _SpotlightScrimPainter({
    required this.rect,
    required this.highlightShape,
  });

  final Rect rect;
  final SpotlightHighlightShape highlightShape;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.8);
    canvas.drawPath(
      _outsidePathFor(
        size: size,
        rect: rect,
        highlightShape: highlightShape,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SpotlightScrimPainter oldDelegate) {
    return oldDelegate.rect != rect ||
        oldDelegate.highlightShape != highlightShape;
  }
}

Path _outsidePathFor({
  required Size size,
  required Rect rect,
  required SpotlightHighlightShape highlightShape,
}) {
  final outerPath = Path()..addRect(Offset.zero & size);
  final spotlightPath = Path();

  switch (highlightShape) {
    case SpotlightHighlightShape.circle:
      spotlightPath.addOval(rect);
    case SpotlightHighlightShape.pill:
      spotlightPath.addRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)),
      );
    case SpotlightHighlightShape.rounded:
      spotlightPath.addRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(20)),
      );
  }

  return Path.combine(PathOperation.difference, outerPath, spotlightPath);
}

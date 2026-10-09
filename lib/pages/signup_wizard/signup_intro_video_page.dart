import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../profile/widgets/pinit_colors.dart';

/// 9:16 intro shown before the account step, letterboxed on cream. Silent
/// (the asset has no audio track) and skippable. If the video can't load it calls
/// [onContinue] straight away so sign-up is never blocked.
class SignupIntroVideoPage extends StatefulWidget {
  const SignupIntroVideoPage({
    super.key,
    required this.onContinue,
    this.onSkipped,
  });

  static const String assetPath = 'lib/assets/videos/pinit-wizard-video.mp4';

  final VoidCallback onContinue;

  /// Called (before [onContinue]) when the user taps Skip.
  final VoidCallback? onSkipped;

  @override
  State<SignupIntroVideoPage> createState() => _SignupIntroVideoPageState();
}

class _SignupIntroVideoPageState extends State<SignupIntroVideoPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const Duration _ctaDelay = Duration(seconds: 6);

  late final VideoPlayerController _controller;
  late final AnimationController _entrance;
  Timer? _ctaTimer;
  bool _ready = false;
  bool _ctaVisible = false;
  bool _finished = false;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _controller = VideoPlayerController.asset(
      SignupIntroVideoPage.assetPath,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _init();
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      await _controller.setVolume(0);
      await _controller.setLooping(false);
      _controller.addListener(_onTick);
      if (!mounted) return;
      setState(() => _ready = true);
      _entrance.forward();
      await _controller.play();
      _ctaTimer = Timer(_ctaDelay, _showCta);
    } catch (e, st) {
      debugPrint('Signup intro video failed to start: $e\n$st');
      _leave();
    }
  }

  void _onTick() {
    final value = _controller.value;
    if (value.hasError) {
      debugPrint('Signup intro video error: ${value.errorDescription}');
      _leave();
      return;
    }
    final done = value.duration > Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 120);
    if (done && !_finished) {
      _finished = true;
      _showCta();
    }
    if (mounted) setState(() {});
  }

  void _showCta() {
    if (!mounted || _ctaVisible) return;
    setState(() => _ctaVisible = true);
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    // The PageView keeps this page alive after navigating away.
    _ctaTimer?.cancel();
    if (_ready) {
      _controller.setVolume(0);
      _controller.pause();
    }
    widget.onContinue();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready) return;
    if (state == AppLifecycleState.resumed) {
      if (!_finished) _controller.play();
    } else {
      _controller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctaTimer?.cancel();
    _controller.removeListener(_onTick);
    _controller.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final fills = chapterFills(
      position: _controller.value.position,
      duration: _ready ? _controller.value.duration : Duration.zero,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        // Matches the video's own background, so the video sits on the page
        // with no visible frame and can be letterboxed instead of cropped.
        backgroundColor: PinitColors.cream,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    _ChapterProgress(fills: fills),
                    const SizedBox(height: 6),
                    // The intro video has no audio track, so there is no
                    // sound toggle — just Skip, right-aligned.
                    Row(
                      children: [
                        const Spacer(),
                        _GhostAction(
                          onTap: () {
                            widget.onSkipped?.call();
                            _leave();
                          },
                          semanticsLabel: 'Skip intro',
                          child: Text('SKIP', style: _label),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _ready
                    ? AnimatedBuilder(
                        animation: _entrance,
                        builder: (context, child) {
                          final t =
                              Curves.easeOutCubic.transform(_entrance.value);
                          return Opacity(
                            opacity: t,
                            child: Transform.scale(
                              scale: reduceMotion ? 1 : 1.03 - 0.03 * t,
                              child: child,
                            ),
                          );
                        },
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: _controller.value.size.width,
                            height: _controller.value.size.height,
                            child: VideoPlayer(_controller),
                          ),
                        ),
                      )
                    : const SizedBox.expand(),
              ),
              SizedBox(
                height: 88,
                child: Center(
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    offset: _ctaVisible || reduceMotion
                        ? Offset.zero
                        : const Offset(0, 0.4),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      opacity: _ctaVisible ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !_ctaVisible,
                        child: _ContinueButton(onPressed: _leave),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle get _label => GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: PinitColors.aubergine,
      );
}

/// Where each chapter of the intro video starts, read off its headline cuts.
/// The last one is the logo end card. Update these if the video changes.
const List<Duration> _chapterStarts = [
  Duration.zero,
  Duration(milliseconds: 2600), // Share it to Pinit
  Duration(milliseconds: 7600), // We'll remind you when you're near
  Duration(milliseconds: 9100), // Hear what the creator said
  Duration(milliseconds: 12100), // And what your mates think
  Duration(milliseconds: 14600), // Every save, on one map
  Duration(milliseconds: 17600), // Any vibe, dish, or craving
  Duration(milliseconds: 25400), // Settle the group-chat debate
  Duration(milliseconds: 29200), // Logo end card
];

const Duration _expectedDuration = Duration(milliseconds: 31500);

/// How full each progress segment is (0 to 1), one per chapter. Falls back to
/// a single segment if the asset's length no longer matches [_chapterStarts].
@visibleForTesting
List<double> chapterFills({
  required Duration position,
  required Duration duration,
}) {
  if (duration <= Duration.zero) {
    return List<double>.filled(_chapterStarts.length, 0);
  }
  final offBy = (duration - _expectedDuration).abs();
  if (offBy > const Duration(seconds: 1)) {
    return [
      (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0),
    ];
  }
  final fills = <double>[];
  for (var i = 0; i < _chapterStarts.length; i++) {
    final start = _chapterStarts[i].inMilliseconds;
    final end = i + 1 < _chapterStarts.length
        ? _chapterStarts[i + 1].inMilliseconds
        : duration.inMilliseconds;
    final fill = (position.inMilliseconds - start) / (end - start);
    fills.add(fill.clamp(0.0, 1.0));
  }
  return fills;
}

class _ChapterProgress extends StatelessWidget {
  const _ChapterProgress({required this.fills});

  final List<double> fills;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < fills.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: PinitColors.creamDeep),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: fills[i],
                        child: const ColoredBox(color: PinitColors.aubergine),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GhostAction extends StatelessWidget {
  const _GhostAction({
    required this.child,
    required this.onTap,
    required this.semanticsLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Center(widthFactor: 1, child: child),
          ),
        ),
      ),
    );
  }
}

class _ContinueButton extends StatefulWidget {
  const _ContinueButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: "Let's go",
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
            decoration: BoxDecoration(
              color: PinitColors.aubergine,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Let's go",
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: PinitColors.cream,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: PinitColors.cream,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

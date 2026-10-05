import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../profile/widgets/pinit_colors.dart';

/// Full-bleed 9:16 intro shown before the account step. Autoplays muted,
/// skippable, tap to toggle sound. If the video can't load it calls
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
  bool _muted = true;
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

  void _toggleMute() {
    HapticFeedback.selectionClick();
    setState(() => _muted = !_muted);
    _controller.setVolume(_muted ? 0 : 1);
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

  double get _progress {
    final total = _controller.value.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (_controller.value.position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: PinitColors.aubergine,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleMute,
              child: AnimatedBuilder(
                animation: _entrance,
                builder: (context, child) {
                  final t = Curves.easeOutCubic.transform(_entrance.value);
                  return Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: reduceMotion ? 1 : 1.04 - 0.04 * t,
                      child: child,
                    ),
                  );
                },
                child: FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
            ),
          const IgnorePointer(child: _Scrims()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                children: [
                  _ProgressBar(progress: _progress),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _GlassPill(
                        onTap: _toggleMute,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _muted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              size: 16,
                              color: PinitColors.cream,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _muted ? 'TAP FOR SOUND' : 'SOUND ON',
                              style: _label,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _GlassPill(
                        onTap: () {
                          widget.onSkipped?.call();
                          _leave();
                        },
                        child: Text('SKIP', style: _label),
                      ),
                    ],
                  ),
                  const Spacer(),
                  AnimatedSlide(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    offset: _ctaVisible ? Offset.zero : const Offset(0, 0.4),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      opacity: _ctaVisible ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !_ctaVisible,
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            onPressed: _leave,
                            style: FilledButton.styleFrom(
                              backgroundColor: PinitColors.cream,
                              foregroundColor: PinitColors.aubergine,
                              shape: const StadiumBorder(),
                            ),
                            child: Text(
                              "LET'S GO",
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _label => GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: PinitColors.cream,
      );
}

class _Scrims extends StatelessWidget {
  const _Scrims();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.22, 0.72, 1],
          colors: [
            PinitColors.aubergine.withValues(alpha: 0.55),
            PinitColors.aubergine.withValues(alpha: 0),
            PinitColors.aubergine.withValues(alpha: 0),
            PinitColors.aubergine.withValues(alpha: 0.6),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: PinitColors.cream.withValues(alpha: 0.28)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: const ColoredBox(color: PinitColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: PinitColors.aubergine.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: child,
      ),
    );
  }
}

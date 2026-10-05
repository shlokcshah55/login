import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// Auto-advancing walkthrough of sharing a TikTok to Pinit, built from the
/// four screenshots in `lib/assets/wizards/`. Crossfades + slides between
/// frames with a caption pill and progress dots.
class TikTokShareDemo extends StatefulWidget {
  const TikTokShareDemo({super.key, this.imageHeight = 250});

  final double imageHeight;

  @override
  State<TikTokShareDemo> createState() => _TikTokShareDemoState();
}

class _TikTokShareDemoState extends State<TikTokShareDemo> {
  static const _frames = <({String asset, String caption})>[
    (asset: 'lib/assets/wizards/tiktok1.png', caption: '1  TAP SHARE'),
    (asset: 'lib/assets/wizards/tiktok2.png', caption: '2  SEND TO PINIT'),
    (asset: 'lib/assets/wizards/tiktok3.png', caption: '3  OR PICK PINIT'),
    (asset: 'lib/assets/wizards/tiktok4.png', caption: '4  WE DO THE REST'),
  ];

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _frames.length);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final frame in _frames) {
      precacheImage(AssetImage(frame.asset), context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final frame = _frames[_index];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.imageHeight,
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: reduceMotion ? 0 : 420),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Image.asset(
              frame.asset,
              key: ValueKey(frame.asset),
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: Duration(milliseconds: reduceMotion ? 0 : 220),
          child: Container(
            key: ValueKey(frame.caption),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: PinitColors.aubergine,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              frame.caption,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: PinitColors.cream,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _frames.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: i == _index ? 20 : 6,
                decoration: BoxDecoration(
                  color: i == _index
                      ? PinitColors.accent
                      : PinitColors.aubergine.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Explains what happens after a share: a faux notification card slides in,
/// then the place lands in the "Saved from your scroll" rail.
class ShareProcessingDemo extends StatefulWidget {
  const ShareProcessingDemo({super.key});

  @override
  State<ShareProcessingDemo> createState() => _ShareProcessingDemoState();
}

class _ShareProcessingDemoState extends State<ShareProcessingDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          // 0.00-0.30 reading, 0.30-0.65 found, 0.65-1.0 saved.
          final phase = t < 0.3 ? 0 : (t < 0.65 ? 1 : 2);
          final enter = Curves.easeOutCubic
              .transform((t / 0.15).clamp(0.0, 1.0).toDouble());
          final (icon, title, sub) = switch (phase) {
            0 => (FeatherIcons.link, 'Reading the post…', 'tiktok.com/…'),
            1 => (
                FeatherIcons.mapPin,
                'Found a place',
                'Confirm it in your inbox',
              ),
            _ => (
                FeatherIcons.check,
                'Saved to your scroll',
                'Find it under Saved from your scroll',
              ),
          };
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: enter,
                  child: Transform.translate(
                    offset: Offset(0, -24 * (1 - enter)),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PinitColors.cream,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: PinitColors.aubergine,
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: PinitColors.aubergine,
                            blurRadius: 0,
                            offset: Offset(3, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: phase == 2
                                  ? PinitColors.teal
                                  : PinitColors.aubergine,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              icon,
                              size: 18,
                              color: PinitColors.cream,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: PinitColors.aubergine,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  sub,
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: PinitColors.aubergineSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Text(
                  'No copy-pasting. No screenshots.',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: PinitColors.mute,
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

/// Shows where vouchers live: Profile -> menu -> Rewards, as a breadcrumb
/// that lights up one hop at a time above a sliding voucher card.
class RewardsPathDemo extends StatefulWidget {
  const RewardsPathDemo({super.key});

  @override
  State<RewardsPathDemo> createState() => _RewardsPathDemoState();
}

class _RewardsPathDemoState extends State<RewardsPathDemo>
    with SingleTickerProviderStateMixin {
  static const _hops = <(IconData, String)>[
    (FeatherIcons.user, 'PROFILE'),
    (FeatherIcons.menu, 'MENU'),
    (FeatherIcons.gift, 'REFERRALS'),
  ];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final active = (t * 3).floor().clamp(0, 2);
        final voucherT = Curves.easeOutBack
            .transform(((t - 0.62) / 0.3).clamp(0.0, 1.0).toDouble());
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _hops.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: i <= active
                            ? PinitColors.accent
                            : PinitColors.mute.withValues(alpha: 0.5),
                      ),
                    ),
                  _Hop(
                    icon: _hops[i].$1,
                    label: _hops[i].$2,
                    active: i == active,
                    reached: i <= active,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Opacity(
              opacity: voucherT.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 18 * (1 - voucherT)),
                child: Transform.rotate(
                  angle: -0.03 * voucherT,
                  child: const _MiniVoucher(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Hop extends StatelessWidget {
  const _Hop({
    required this.icon,
    required this.label,
    required this.active,
    required this.reached,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          width: active ? 52 : 44,
          height: active ? 52 : 44,
          decoration: BoxDecoration(
            color: reached ? PinitColors.aubergine : PinitColors.cream,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PinitColors.aubergine, width: 1.5),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: PinitColors.accent,
                      blurRadius: 0,
                      offset: Offset(3, 3),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: reached ? PinitColors.cream : PinitColors.aubergine,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: reached ? PinitColors.aubergine : PinitColors.mute,
          ),
        ),
      ],
    );
  }
}

class _MiniVoucher extends StatelessWidget {
  const _MiniVoucher();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: PinitColors.aubergine,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: PinitColors.accent,
            blurRadius: 0,
            offset: Offset(3, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(FeatherIcons.gift, color: PinitColors.cream, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Referrals: vouchers and rewards',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: PinitColors.cream,
              ),
            ),
          ),
          Text(
            'TAP TO USE',
            style: GoogleFonts.dmSans(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: PinitColors.cream.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

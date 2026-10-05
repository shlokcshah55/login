import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/onboarding_analytics.dart';
import '../../../services/share_extension_bridge.dart';
import '../../../services/social_link_ingest_service.dart';
import '../../../supabase/service.dart';
import '../../../supabase/supabase_client.dart';
import '../../../utils/social_video_link.dart';
import '../../../widgets/onboarding/onboarding_headline.dart';
import '../../home/onboarding/tour_hero_widgets.dart';
import '../../profile/widgets/pinit_colors.dart';
import '../first_save_watcher.dart';

enum _Phase { idle, submitting, waiting, saved }

/// Onboarding step 1: save a first place. Teaches the share-sheet gesture
/// (TikTok / Instagram -> Share -> Pinit) first, with paste-a-link and
/// notes import as fallbacks.
class FirstSaveStep extends StatefulWidget {
  const FirstSaveStep({
    super.key,
    required this.analytics,
    required this.onDone,
    required this.onSkip,
    this.watcher,
    this.ingest,
  });

  final OnboardingAnalytics analytics;

  /// Called after a save is detected (once the celebration has played) or when
  /// the user chooses to keep going while a save is still processing.
  final VoidCallback onDone;
  final VoidCallback onSkip;

  /// Injectable for tests.
  final FirstSaveWatcher? watcher;
  final SocialLinkIngestService? ingest;

  @override
  State<FirstSaveStep> createState() => _FirstSaveStepState();
}

class _FirstSaveStepState extends State<FirstSaveStep>
    with WidgetsBindingObserver {
  static const Duration _longWait = Duration(seconds: 25);
  static const Duration _poll = Duration(seconds: 4);

  late final FirstSaveWatcher _watcher;
  late final SocialLinkIngestService _ingest;
  final TextEditingController _linkController = TextEditingController();
  StreamSubscription<void>? _saveSub;
  Timer? _pollTimer;
  Timer? _longWaitTimer;
  Timer? _advanceTimer;

  _Phase _phase = _Phase.idle;
  String _method = 'share';
  String? _error;
  bool _shareReady = false;
  bool _leftToShare = false;
  bool _longWaiting = false;
  bool _finished = false;
  // The user moved on (Keep going / Skip); a later save still gets tracked
  // but must not advance the flow again.
  bool _leftEarly = false;

  bool get _isIOS => Platform.isIOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.analytics.viewed(OnboardingStep.firstSave);
    _watcher = widget.watcher ?? FirstSaveWatcher();
    _ingest = widget.ingest ?? SocialLinkIngestService();
    _saveSub = _watcher.onFirstSave.listen((_) => _onSaved());
    _watcher.start();
    unawaited(_watcher.check());
    unawaited(_prepareShareExtension());
  }

  Future<void> _prepareShareExtension() async {
    if (!_isIOS) return;
    final ok = await ShareExtensionBridge.syncUserId();
    if (mounted) setState(() => _shareReady = ok);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _finished) return;
    if (_leftToShare && _phase == _Phase.idle) {
      _startWaiting();
    }
    unawaited(_watcher.check());
  }

  void _startWaiting() {
    setState(() {
      _phase = _Phase.waiting;
      _longWaiting = false;
      _error = null;
    });
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_poll, (_) => unawaited(_watcher.check()));
    _longWaitTimer?.cancel();
    _longWaitTimer = Timer(_longWait, () {
      if (mounted && _phase == _Phase.waiting) {
        setState(() => _longWaiting = true);
      }
    });
  }

  void _onSaved() {
    if (_finished || !mounted) return;
    _finished = true;
    _pollTimer?.cancel();
    _longWaitTimer?.cancel();
    HapticFeedback.mediumImpact();
    widget.analytics.completed(OnboardingStep.firstSave, method: _method);
    widget.analytics.firstSave(method: _method);
    if (_leftEarly) return;
    setState(() => _phase = _Phase.saved);
    _advanceTimer = Timer(const Duration(milliseconds: 1600), widget.onDone);
  }

  Future<void> _openApp(String scheme, String fallback) async {
    HapticFeedback.selectionClick();
    _leftToShare = true;
    _method = 'share';
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(scheme),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!launched) {
      try {
        await launchUrl(
          Uri.parse(fallback),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        _leftToShare = false;
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (SocialVideoLink.parse(text) == null) {
      setState(() => _error =
          'Copy a TikTok or Instagram Reel link first, then tap Paste.');
      return;
    }
    _linkController.text = text;
    setState(() => _error = null);
    await _submitLink();
  }

  Future<void> _submitLink() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _phase = _Phase.submitting;
      _error = null;
    });
    final result = await _ingest.submit(_linkController.text);
    if (!mounted) return;
    if (result.isQueued) {
      _method = 'link';
      _startWaiting();
      return;
    }
    setState(() {
      _phase = _Phase.idle;
      _error = result.message ??
          switch (result.status) {
            SocialIngestStatus.networkError =>
              'Couldn’t reach Pinit. Check your connection and try again.',
            SocialIngestStatus.notSignedIn => 'Please sign in again.',
            _ => 'Something went wrong. Try again in a moment.',
          };
    });
  }

  Future<void> _importNotes() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PinitColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _NotesPasteSheet(),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;

    setState(() {
      _phase = _Phase.submitting;
      _error = null;
    });
    try {
      final userId = SupabaseClientManager().currentUser?.id;
      if (userId == null) throw StateError('not signed in');
      final supabase = context.read<SupabaseService>();
      await supabase.notesImport.importText(
        userId: userId,
        text: text,
        sourceName: 'Notes',
      );
      if (!mounted) return;
      _method = 'notes';
      _startWaiting();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _error = 'Couldn’t import those notes. Try again or paste a link.';
      });
    }
  }

  void _showShareHelp() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PinitColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ShareHelpSheet(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveSub?.cancel();
    _pollTimer?.cancel();
    _longWaitTimer?.cancel();
    _advanceTimer?.cancel();
    _linkController.dispose();
    unawaited(_watcher.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PinitColors.surfaceLight,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                child: switch (_phase) {
                  _Phase.saved => const _SavedCelebration(key: ValueKey('ok')),
                  _Phase.waiting => _WaitingView(
                      key: const ValueKey('wait'),
                      method: _method,
                      longWaiting: _longWaiting,
                      onContinue: () {
                        _leftEarly = true;
                        widget.onDone();
                      },
                    ),
                  _ => _buildIdle(),
                },
              ),
            ),
            if (_phase != _Phase.saved)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: TextButton(
                  onPressed: () {
                    _leftEarly = true;
                    widget.analytics.skipped(OnboardingStep.firstSave);
                    widget.onSkip();
                  },
                  child: Text(
                    'SKIP FOR NOW',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: PinitColors.mute,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdle() {
    final busy = _phase == _Phase.submitting;
    return SingleChildScrollView(
      key: const ValueKey('idle'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OnboardingHeadline(text: 'Save your first place'),
          const SizedBox(height: 8),
          Text(
            _isIOS
                ? 'See a restaurant on TikTok or Instagram? Share it to Pinit and we’ll find it and pin it for you.'
                : 'See a restaurant on TikTok or Instagram? Copy the link, paste it here and we’ll find it and pin it for you.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: PinitColors.aubergineSoft,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          if (_isIOS) ...[
            _HeroCard(
              child: Column(
                children: [
                  const TikTokShareDemo(imageHeight: 300),
                  const SizedBox(height: 14),
                  const _HowTo(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PillButton(
                          label: 'OPEN TIKTOK',
                          filled: true,
                          onTap: () => _openApp(
                            'tiktok://',
                            'https://www.tiktok.com',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PillButton(
                          label: 'OPEN INSTAGRAM',
                          filled: true,
                          onTap: () => _openApp(
                            'instagram://',
                            'https://www.instagram.com',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        child: Icon(
                          _shareReady
                              ? Icons.check_circle_rounded
                              : Icons.hourglass_empty_rounded,
                          key: ValueKey(_shareReady),
                          size: 16,
                          color:
                              _shareReady ? PinitColors.teal : PinitColors.mute,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _shareReady ? 'Sharing is ready' : 'Getting ready…',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PinitColors.aubergineSoft,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _showShareHelp,
                        child: Text(
                          'CAN’T SEE PINIT?',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: PinitColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'OR',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: PinitColors.mute,
              ),
            ),
            const SizedBox(height: 12),
          ],
          _LinkField(
            controller: _linkController,
            busy: busy,
            onPaste: _pasteFromClipboard,
            onSubmit: _submitLink,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PinitColors.accent,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _PillButton(
            label: 'IMPORT FROM NOTES',
            filled: false,
            onTap: busy ? null : _importNotes,
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PinitColors.aubergine, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: PinitColors.aubergine,
            blurRadius: 0,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HowTo extends StatelessWidget {
  const _HowTo();

  static const _steps = <String>[
    'Open a TikTok or Instagram Reel you like',
    'Tap Share (the arrow)',
    'Tap the Pinit icon',
    'We find the place and save it for you',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: PinitColors.aubergine,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: PinitColors.cream,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _steps[i],
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: PinitColors.aubergine,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Material(
        color: filled ? PinitColors.aubergine : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(color: PinitColors.aubergine, width: 1.5),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: filled ? PinitColors.cream : PinitColors.aubergine,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkField extends StatelessWidget {
  const _LinkField({
    required this.controller,
    required this.busy,
    required this.onPaste,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onPaste;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !busy,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => onSubmit(),
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PinitColors.aubergine,
            ),
            decoration: InputDecoration(
              hintText: 'Paste a TikTok or Reel link',
              hintStyle: GoogleFonts.manrope(
                fontSize: 14,
                color: PinitColors.mute,
              ),
              filled: true,
              fillColor: PinitColors.creamSunk,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(color: PinitColors.aubergine),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(
                  color: PinitColors.aubergine,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 88,
          child: _PillButton(
            label: busy ? '...' : 'PASTE',
            filled: true,
            onTap: busy ? null : onPaste,
          ),
        ),
      ],
    );
  }
}

class _WaitingView extends StatelessWidget {
  const _WaitingView({
    super.key,
    required this.method,
    required this.longWaiting,
    required this.onContinue,
  });

  final String method;
  final bool longWaiting;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final noun = method == 'notes' ? 'your notes' : 'that post';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingHeadline(
            text: longWaiting ? 'Still working on it' : 'Finding the place…',
          ),
          const SizedBox(height: 8),
          Text(
            longWaiting
                ? 'You don’t have to wait. We’ll tell you the moment it’s saved.'
                : 'We’re reading $noun and matching it to a real restaurant.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: PinitColors.aubergineSoft,
            ),
          ),
          const SizedBox(height: 28),
          const ShareProcessingDemo(),
          const Spacer(),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 280),
            opacity: longWaiting ? 1 : 0,
            child: IgnorePointer(
              ignoring: !longWaiting,
              child: _PillButton(
                label: 'KEEP GOING',
                filled: true,
                onTap: onContinue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedCelebration extends StatelessWidget {
  const _SavedCelebration({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, t, child) => Transform.scale(
          scale: 0.6 + 0.4 * t,
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: PinitColors.aubergine,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: PinitColors.accent,
                    blurRadius: 0,
                    offset: Offset(4, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.place_rounded,
                size: 44,
                color: PinitColors.cream,
              ),
            ),
            const SizedBox(height: 20),
            const OnboardingHeadline(text: 'First place saved'),
            const SizedBox(height: 6),
            Text(
              'That’s how easy it is.',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: PinitColors.aubergineSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesPasteSheet extends StatefulWidget {
  const _NotesPasteSheet();

  @override
  State<_NotesPasteSheet> createState() => _NotesPasteSheetState();
}

class _NotesPasteSheetState extends State<_NotesPasteSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OnboardingHeadline(text: 'Import from Notes', fontSize: 24),
          const SizedBox(height: 8),
          Text(
            'Open your list in Notes, copy it and paste it below. We’ll pick out the places.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: PinitColors.aubergineSoft,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            minLines: 5,
            maxLines: 8,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: PinitColors.aubergine,
            ),
            decoration: InputDecoration(
              hintText: 'Paste your notes here',
              filled: true,
              fillColor: PinitColors.creamSunk,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: PinitColors.aubergine),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_controller.text),
              style: FilledButton.styleFrom(
                backgroundColor: PinitColors.aubergine,
                foregroundColor: PinitColors.cream,
                shape: const StadiumBorder(),
              ),
              child: Text(
                'IMPORT',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareHelpSheet extends StatelessWidget {
  const _ShareHelpSheet();

  static const _steps = <String>[
    'Open the share sheet in TikTok or Instagram',
    'Scroll the row of app icons to the end',
    'Tap More',
    'Switch Pinit on (drag it to the top to keep it handy)',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const OnboardingHeadline(
              text: 'Can’t see Pinit?',
              fontSize: 24,
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${i + 1}.  ${_steps[i]}',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PinitColors.aubergine,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'You only need to do this once.',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PinitColors.aubergineSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

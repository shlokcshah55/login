import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/user_data_provider.dart';
import '../../supabase/service.dart';
import '../../widgets/home/expanded_card/helpers/vibe_display.dart';
import 'widgets/pinit_colors.dart';

/// Lets the user view all vibe tags and adjust each tag's affinity by ±5.
class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  static const int _step = 5;

  late Future<List<Map<String, dynamic>>> _tagsFuture;

  /// Local working copy of the affinity vector — sourced from the provider
  /// at construction time and only ever mutated by explicit user taps. We
  /// NEVER pad or default this list: that would silently overwrite real
  /// affinities with placeholder values the moment the user touched any
  /// +/- button.
  late final List<int> _localAffinity;

  Timer? _saveDebounce;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final supabase = context.read<SupabaseService>();
    _tagsFuture = supabase.tags.getVibeTags();
    // The page is gated upstream so we should always have real affinities by
    // the time we get here. Copy them once into a mutable working list.
    final fromProvider = context.read<UserDataProvider>().vibeTagAffinity;
    assert(
      fromProvider != null && fromProvider.isNotEmpty,
      'PreferencesPage opened before vibe affinities loaded — gate the '
      'navigation upstream so this never happens.',
    );
    _localAffinity = List<int>.from(fromProvider ?? const <int>[]);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    if (_dirty) {
      // Best-effort flush on exit (provider call doesn't depend on context).
      _flushNow();
    }
    super.dispose();
  }

  void _adjust(int index, int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _localAffinity[index] = _localAffinity[index] + delta;
      _dirty = true;
    });
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce =
        Timer(const Duration(milliseconds: 600), () => _flushNow());
  }

  Future<void> _flushNow() async {
    if (!_dirty) return;
    _dirty = false;
    final provider = context.read<UserDataProvider>();
    await provider.updateVibeTagAffinity(List<int>.from(_localAffinity));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: PinitColors.cream,
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _tagsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: PinitColors.aubergine,
                        ),
                      );
                    }
                    if (snapshot.hasError ||
                        snapshot.data == null ||
                        snapshot.data!.isEmpty) {
                      return _buildEmpty();
                    }
                    final tags = snapshot.data!;
                    // Only render rows for tags we have a real affinity for.
                    // If the backend ever adds new tags before this user's
                    // affinity vector is migrated, we drop the extras rather
                    // than fabricating zeros (which would clobber real data
                    // on the next save).
                    final renderable = tags.length <= _localAffinity.length
                        ? tags
                        : tags.sublist(0, _localAffinity.length);
                    return _buildList(renderable);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── pieces ─────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          _RoundIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Preferences',
              style: const TextStyle(
                fontFamily: 'Rova',
                fontSize: 22,
                fontWeight: FontWeight.w100,
                color: PinitColors.aubergine,
                letterSpacing: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> tags) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: tags.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) return _buildIntro(tags.length);
        final index = i - 1;
        final tag = tags[index];
        final rawText = (tag['text'] ?? '') as String;
        final value = _localAffinity[index];
        return _VibeRow(
          label: vibeDisplayName(rawText),
          icon: vibeIcons[rawText] ?? Icons.local_offer_rounded,
          value: value,
          onMinus: () => _adjust(index, -_step),
          onPlus: () => _adjust(index, _step),
        );
      },
    );
  }

  Widget _buildIntro(int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: PinitColors.creamSunk,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PinitColors.creamDeep, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'YOUR TASTE',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: PinitColors.aubergineSoft,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tune your vibes',
              style: const TextStyle(
                fontFamily: 'Rova',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: PinitColors.aubergine,
                letterSpacing: 1.6,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$count vibes shape your recommendations. Nudge each one up or down by 5 to teach Pinit how you really feel.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: PinitColors.aubergineSoft,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: PinitColors.creamSunk,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.local_offer_outlined,
                size: 32,
                color: PinitColors.mute,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No vibes available yet',
              style: GoogleFonts.dmSans(
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

// ─────────────────────────────────────────────────────────────────────────────
// Row + button widgets
// ─────────────────────────────────────────────────────────────────────────────

class _VibeRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _VibeRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: PinitColors.creamDeep,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: PinitColors.aubergine),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PinitColors.aubergine,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Affinity $value',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: PinitColors.aubergineSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _StepButton(icon: Icons.remove_rounded, onTap: onMinus),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: SizedBox(
              key: ValueKey(value),
              width: 36,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: PinitColors.aubergine,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _StepButton(icon: Icons.add_rounded, onTap: onPlus, filled: true),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _StepButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: filled ? PinitColors.aubergine : PinitColors.cream,
            shape: BoxShape.circle,
            border: Border.all(
              color: filled ? PinitColors.aubergine : PinitColors.creamDeep,
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: filled ? PinitColors.cream : PinitColors.aubergine,
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            shape: BoxShape.circle,
            border: Border.all(color: PinitColors.creamDeep, width: 1.5),
          ),
          child: Icon(icon, size: 20, color: PinitColors.aubergine),
        ),
      ),
    );
  }
}

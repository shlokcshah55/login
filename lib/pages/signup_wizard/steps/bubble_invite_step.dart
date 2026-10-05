import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../models/users.dart';
import '../../../providers/user_data_provider.dart';
import '../../../services/onboarding_analytics.dart';
import '../../../supabase/service.dart';
import '../../../supabase/supabase_client.dart';
import '../../../utils/invite_share.dart';
import '../../../widgets/feedback/app_feedback.dart';
import '../../../widgets/onboarding/onboarding_headline.dart';
import '../../../widgets/pinit_image.dart';
import '../../profile/widgets/pinit_colors.dart';

/// Onboarding step 3: "Better with friends". Quick-add people already on
/// Pinit, optionally start a bubble with them, or invite friends who aren't
/// on the app yet. Finishing (or skipping) completes onboarding.
class BubbleInviteStep extends StatefulWidget {
  const BubbleInviteStep({
    super.key,
    required this.analytics,
    required this.onFinish,
    required this.onSkip,
    this.isFinishing = false,
  });

  final OnboardingAnalytics analytics;
  final VoidCallback onFinish;
  final VoidCallback onSkip;

  /// True while the parent is completing onboarding (disables the buttons).
  final bool isFinishing;

  @override
  State<BubbleInviteStep> createState() => _BubbleInviteStepState();
}

class _BubbleInviteStepState extends State<BubbleInviteStep> {
  static const int _maxSuggestions = 8;

  final TextEditingController _name = TextEditingController();
  final Set<String> _selected = <String>{};

  List<UserModel> _people = const [];
  bool _loadingPeople = true;
  bool _busy = false;
  bool _done = false;
  String? _bubbleName;
  int _followed = 0;

  @override
  void initState() {
    super.initState();
    widget.analytics.viewed(OnboardingStep.bubble);
    unawaited(_loadPeople());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _referralCode =>
      context.read<UserDataProvider>().supabaseUserData?.referralCode;

  Future<void> _loadPeople() async {
    try {
      final users =
          await context.read<SupabaseService>().users.getSuggestedUsers();
      if (!mounted) return;
      setState(() {
        _people = users
            .where((u) => u.supabaseId != null && (u.name ?? '').isNotEmpty)
            .take(_maxSuggestions)
            .toList();
        _loadingPeople = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPeople = false);
    }
  }

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  bool get _hasName => _name.text.trim().isNotEmpty;
  bool get _canSubmit => (_hasName || _selected.isNotEmpty) && !_busy;

  String get _ctaLabel {
    final n = _selected.length;
    if (_busy) return 'WORKING...';
    if (_hasName && n > 0) return 'CREATE BUBBLE + FOLLOW $n';
    if (_hasName) return 'CREATE BUBBLE';
    if (n > 0) return 'FOLLOW $n ${n == 1 ? 'PERSON' : 'PEOPLE'}';
    return 'CREATE BUBBLE';
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    final supabase = context.read<SupabaseService>();
    final ids = _selected.toList();
    String? bubbleId;

    if (_hasName) {
      bubbleId = await supabase.bubbles.createBubble(
        name: _name.text.trim(),
        createdBy: userId,
      );
      if (!mounted) return;
      if (bubbleId == null) {
        setState(() => _busy = false);
        await AppFeedback.showError(
          context,
          title: 'Couldn’t create bubble',
          message: 'Please try again in a moment.',
        );
        return;
      }
    }

    // ADD only sends follow requests; nobody is put in the bubble without
    // accepting. Best effort: one failed request must not undo the rest.
    final results = await Future.wait([
      for (final id in ids)
        supabase.users
            .followUser(id)
            .then((_) => true)
            .catchError((_) => false),
    ]);
    if (!mounted) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _busy = false;
      _done = true;
      _bubbleName = bubbleId == null ? null : _name.text.trim();
      _followed = results.where((ok) => ok).length;
    });
  }

  Future<void> _invite() => InviteShare.share(
        referralCode: _referralCode,
        bubbleName: _bubbleName,
      );

  void _finish() {
    widget.analytics.completed(
      OnboardingStep.bubble,
      method: _bubbleName != null
          ? 'bubble'
          : (_followed > 0 ? 'follow' : 'invite'),
    );
    widget.onFinish();
  }

  Future<void> _inviteAndFinish() async {
    await _invite();
    if (mounted) _finish();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isFinishing;
    return Container(
      color: PinitColors.surfaceLight,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const OnboardingHeadline(text: 'Better with friends'),
                      const SizedBox(height: 8),
                      Text(
                        'Follow people on Pinit, and start a bubble to share places with your crew.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: PinitColors.aubergineSoft,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        child: _done
                            ? _DoneCard(
                                key: const ValueKey('done'),
                                bubbleName: _bubbleName,
                                followed: _followed,
                                onInvite: _invite,
                              )
                            : _buildForm(disabled),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _BottomBar(
              child: _done
                  ? _PrimaryButton(
                      label: disabled ? 'ONE MOMENT...' : 'FINISH',
                      enabled: !disabled,
                      onTap: _finish,
                    )
                  : Row(
                      children: [
                        TextButton(
                          onPressed: disabled
                              ? null
                              : () {
                                  widget.analytics
                                      .skipped(OnboardingStep.bubble);
                                  widget.onSkip();
                                },
                          child: Text(
                            'SKIP',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: PinitColors.mute,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PrimaryButton(
                            label: _ctaLabel,
                            enabled: _canSubmit && !disabled,
                            onTap: _submit,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(bool disabled) {
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('PEOPLE ON PINIT'),
        const SizedBox(height: 10),
        _PeopleStrip(
          people: _people,
          loading: _loadingPeople,
          selected: _selected,
          onToggle: _toggle,
        ),
        const SizedBox(height: 24),
        const _SectionLabel('START A BUBBLE (OPTIONAL)'),
        const SizedBox(height: 10),
        _BubbleNameField(
          controller: _name,
          enabled: !disabled && !_busy,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 24),
        _InviteCard(
          code: _referralCode,
          onInvite: disabled ? null : _inviteAndFinish,
        ),
      ],
    );
  }
}

// ───────────────────────── Pieces ─────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.3,
        color: PinitColors.aubergineSoft,
      ),
    );
  }
}

class _PeopleStrip extends StatelessWidget {
  const _PeopleStrip({
    required this.people,
    required this.loading,
    required this.selected,
    required this.onToggle,
  });

  final List<UserModel> people;
  final bool loading;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  static const double _height = 176;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: _height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => const _PersonSkeleton(),
        ),
      );
    }
    if (people.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PinitColors.creamSunk,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'No suggestions yet. Invite your friends below.',
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: PinitColors.aubergineSoft,
          ),
        ),
      );
    }
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: people.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final user = people[i];
          final id = user.supabaseId!;
          return _PersonCard(
            user: user,
            selected: selected.contains(id),
            onTap: () => onToggle(id),
          );
        },
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final UserModel user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = user.name ?? '';
    final firstName = name.split(' ').first;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 124,
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
        decoration: BoxDecoration(
          color: selected ? PinitColors.aubergine : PinitColors.creamSunk,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PinitColors.aubergine, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: selected ? PinitColors.accent : PinitColors.aubergine,
              blurRadius: 0,
              offset: const Offset(3, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _Avatar(url: user.profileImageUrl, name: name, size: 56),
                if (selected)
                  const Positioned(
                    right: -4,
                    bottom: -4,
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: PinitColors.accent,
                      child: Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: PinitColors.cream,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: selected ? PinitColors.cream : PinitColors.aubergine,
              ),
            ),
            if ((user.username ?? '').isNotEmpty)
              Text(
                '@${user.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? PinitColors.cream.withValues(alpha: 0.75)
                      : PinitColors.aubergineSoft,
                ),
              ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: selected ? PinitColors.cream : PinitColors.aubergine,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                selected ? 'ADDED' : 'ADD',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: selected ? PinitColors.aubergine : PinitColors.cream,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonSkeleton extends StatelessWidget {
  const _PersonSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 124,
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name, required this.size});

  final String? url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: PinitColors.creamDeep,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: GoogleFonts.manrope(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          color: PinitColors.aubergine,
        ),
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: PinitImage.avatar(
          url: url,
          diameter: size,
          fallback: fallback,
        ),
      ),
    );
  }
}

class _BubbleNameField extends StatelessWidget {
  const _BubbleNameField({
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PinitColors.aubergine, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: PinitColors.aubergine,
            blurRadius: 0,
            offset: Offset(3, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        cursorColor: PinitColors.aubergine,
        onChanged: (_) => onChanged(),
        style: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: PinitColors.aubergine,
        ),
        decoration: InputDecoration(
          hintText: 'Name it, e.g. Friday Crew',
          hintStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: PinitColors.mute,
          ),
          counterText: '',
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          prefixIcon: const Icon(
            Icons.bubble_chart_rounded,
            color: PinitColors.aubergineSoft,
          ),
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.code, required this.onInvite});

  final String? code;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PinitColors.aubergine,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.ios_share_rounded,
              color: PinitColors.cream,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Friends not on Pinit yet?',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: PinitColors.aubergine,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (code != null && code!.isNotEmpty)
                      ? 'Invite them with your code $code'
                      : 'Send them an invite',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PinitColors.aubergineSoft,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onInvite,
            child: Text(
              'INVITE',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: PinitColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({
    super.key,
    required this.bubbleName,
    required this.followed,
    required this.onInvite,
  });

  final String? bubbleName;
  final int followed;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (bubbleName != null) '$bubbleName is ready',
      if (followed > 0)
        'Follow ${followed == 1 ? 'request' : 'requests'} sent to $followed ${followed == 1 ? 'person' : 'people'}',
    ];
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: PinitColors.teal,
            size: 40,
          ),
          const SizedBox(height: 12),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: PinitColors.aubergine,
                ),
              ),
            ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onInvite,
            child: Text(
              'INVITE MORE FRIENDS',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: PinitColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: BoxDecoration(
        color: PinitColors.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: PinitColors.aubergine.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Solid pill with explicit enabled/disabled colours (Material's disabled
/// FilledButton styling turned the label grey on grey).
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.45,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: PinitColors.aubergine,
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: PinitColors.accent,
                    blurRadius: 0,
                    offset: Offset(3, 3),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: enabled ? onTap : null,
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: PinitColors.cream,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

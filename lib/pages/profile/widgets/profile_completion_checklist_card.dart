import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/providers/navigation_provider.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/services/profile_completion_card_preferences_service.dart';
import 'package:login/services/profile_completion_checklist_service.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/widgets/did_you_know_wizard_dialog.dart';
import 'package:provider/provider.dart';

class ProfileCompletionChecklistCard extends StatefulWidget {
  final ValueChanged<int> onSelectProfileTab;
  final VoidCallback? onRequestScrollToEatLists;

  const ProfileCompletionChecklistCard({
    super.key,
    required this.onSelectProfileTab,
    this.onRequestScrollToEatLists,
  });

  @override
  State<ProfileCompletionChecklistCard> createState() =>
      _ProfileCompletionChecklistCardState();
}

class _ProfileCompletionChecklistCardState
    extends State<ProfileCompletionChecklistCard> {
  final _service = ProfileCompletionChecklistService();
  final _homeCardPrefs = ProfileCompletionCardPreferencesService();
  Future<ProfileCompletionChecklistState>? _future;

  int _lastSavedCount = -1;
  bool _homeCardCollapsed = false;
  String? _homeCardPrefUserId;
  static const _borderWidth = 2.2;
  static const _cardRadius = 10.0;
  static const _innerRadius = 8.5;
  static const _microRadius = 8.0;

  @override
  void initState() {
    super.initState();
    unawaited(_syncHomeCardCollapsedPreference());
  }

  Future<void> _syncHomeCardCollapsedPreference() async {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return;
    if (_homeCardPrefUserId == userId) return;
    final collapsed = await _homeCardPrefs.isCollapsed(userId: userId);
    if (!mounted) return;
    setState(() {
      _homeCardPrefUserId = userId;
      _homeCardCollapsed = collapsed;
    });
  }

  void _toggleHomeCardCollapsed() {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return;
    final next = !_homeCardCollapsed;
    setState(() => _homeCardCollapsed = next);
    unawaited(_homeCardPrefs.setCollapsed(userId: userId, collapsed: next));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Intentionally empty. We refresh the backing Future in build so changes in
    // providers always re-evaluate.
  }

  @override
  Widget build(BuildContext context) {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return const SizedBox.shrink();

    if (_homeCardPrefUserId != userId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_syncHomeCardCollapsedPreference());
      });
    }

    final savedCount =
        context.watch<LocationListManager>().savedLocations.length;
    if (_future == null || savedCount != _lastSavedCount) {
      _lastSavedCount = savedCount;
      _future = _service.fetch(userId: userId, savedCount: savedCount);
    }

    return FutureBuilder<ProfileCompletionChecklistState>(
      future: _future,
      builder: (context, snap) {
        final state = snap.data;
        if (state == null) {
          // Keep layout stable; this should resolve quickly.
          return const SizedBox(height: 140);
        }
        final hasSavedFive = savedCount >= 5;
        final hasFollowAndBubble = state.hasFollowedFriendAndCreatedBubble;
        final completedCount = <bool>[
          state.hasEatList,
          hasSavedFive,
          state.hasSocialSave,
          hasFollowAndBubble,
        ].where((v) => v).length;

        if (completedCount >= 4) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Container(
            decoration: BoxDecoration(
              color: PinitColors.creamSunk,
              borderRadius: BorderRadius.circular(_cardRadius),
              border: Border.all(
                color: PinitColors.aubergine,
                width: _borderWidth,
              ),
              boxShadow: const [
                BoxShadow(
                  color: PinitColors.aubergine,
                  blurRadius: 0,
                  offset: Offset(6, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_innerRadius),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: PinitColors.teal,
                            borderRadius: BorderRadius.circular(_microRadius),
                            border: Border.all(
                              color: PinitColors.aubergine,
                              width: 1.6,
                            ),
                          ),
                          child: Text(
                            'SETUP CHECKLIST',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 10 * 0.16,
                              color: PinitColors.aubergine,
                            ),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: _toggleHomeCardCollapsed,
                          borderRadius: BorderRadius.circular(_microRadius),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _homeCardCollapsed
                                  ? PinitColors.teal
                                  : PinitColors.creamDeep,
                              borderRadius: BorderRadius.circular(_microRadius),
                              border: Border.all(
                                color: PinitColors.aubergine,
                                width: 1.6,
                              ),
                            ),
                            child: Icon(
                              _homeCardCollapsed
                                  ? Icons.unfold_more_rounded
                                  : Icons.unfold_less_rounded,
                              size: 18,
                              color: PinitColors.aubergine,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Finish your profile',
                          style: const TextStyle(
                            fontFamily: 'Rova',
                            fontSize: 18,
                            fontWeight: FontWeight.w100,
                            color: PinitColors.aubergine,
                            letterSpacing: 1.0,
                            height: 1.05,
                          ),
                        ),
                        const Spacer(),
                        _ProgressPill(done: completedCount, total: 4),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ChecklistRow(
                      done: state.hasEatList,
                      icon: Icons.collections_bookmark_rounded,
                      title: 'Add an eat-list',
                      subtitle: 'Adopt one or create your own',
                      tileColor: PinitColors.teal,
                      onTap: () {
                        final cb = widget.onRequestScrollToEatLists;
                        if (cb != null) {
                          cb();
                          return;
                        }
                        widget.onSelectProfileTab(1);
                      },
                    ),
                    const SizedBox(height: 8),
                    _ChecklistRow(
                      done: hasSavedFive,
                      icon: Icons.bookmark_add_rounded,
                      title: 'Save 5 places',
                      subtitle: 'Build your first map',
                      tileColor: PinitColors.accent,
                      onTap: () => context
                          .read<NavigationProvider>()
                          .navigateToHomeSearch(),
                    ),
                    const SizedBox(height: 8),
                    _ChecklistRow(
                      done: state.hasSocialSave,
                      icon: Icons.share_rounded,
                      title: 'Share a TikTok or Reel',
                      subtitle: 'Pin directly from socials',
                      tileColor: PinitColors.creamDeep,
                      onTap: () async {
                        await WhatWeDoWizardOverlay.push(context);
                      },
                    ),
                    const SizedBox(height: 8),
                    _ChecklistRow(
                      done: hasFollowAndBubble,
                      icon: Icons.group_add_rounded,
                      title: 'Make a friend + create a bubble',
                      subtitle: 'Start planning together',
                      tileColor: PinitColors.teal.withValues(alpha: 0.22),
                      onTap: () {
                        widget.onSelectProfileTab(2);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProgressPill extends StatelessWidget {
  final int done;
  final int total;

  const _ProgressPill({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final label = '$done/$total';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: done == total ? PinitColors.teal : PinitColors.accent,
        borderRadius: BorderRadius.circular(
            _ProfileCompletionChecklistCardState._microRadius),
        border: Border.all(color: PinitColors.aubergine, width: 1.6),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: PinitColors.cream,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final bool done;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tileColor;
  final VoidCallback onTap;

  const _ChecklistRow({
    required this.done,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tileColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(
            _ProfileCompletionChecklistCardState._microRadius),
        onTap: done ? null : onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: done ? PinitColors.creamDeep : PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(
                _ProfileCompletionChecklistCardState._microRadius),
            border: Border.all(
              color: PinitColors.aubergine,
              width: 1.6,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: done ? PinitColors.aubergine : tileColor,
                  borderRadius: BorderRadius.circular(
                      _ProfileCompletionChecklistCardState._microRadius),
                  border: Border.all(
                    color: PinitColors.aubergine,
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  done ? Icons.check_rounded : icon,
                  size: 20,
                  color: done ? PinitColors.cream : PinitColors.aubergine,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: PinitColors.aubergine,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PinitColors.aubergineSoft,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: done ? PinitColors.aubergine : PinitColors.cream,
                  borderRadius: BorderRadius.circular(
                      _ProfileCompletionChecklistCardState._microRadius),
                  border: Border.all(
                    color: PinitColors.aubergine,
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  done ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  size: 18,
                  color: done ? PinitColors.cream : PinitColors.aubergine,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

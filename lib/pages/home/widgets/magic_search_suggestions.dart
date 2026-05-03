import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;

class MagicSearchSuggestions extends StatefulWidget {
  const MagicSearchSuggestions({
    super.key,
    required this.onSelected,
    required this.onDismiss,
    this.nowProvider = DateTime.now,
  });

  final ValueChanged<String> onSelected;
  final VoidCallback onDismiss;
  final DateTime Function() nowProvider;

  @override
  State<MagicSearchSuggestions> createState() => _MagicSearchSuggestionsState();
}

class _MagicSearchSuggestionsState extends State<MagicSearchSuggestions> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _scheduleRefresh();
  }

  @override
  void didUpdateWidget(covariant MagicSearchSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nowProvider != widget.nowProvider) {
      _scheduleRefresh();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();

    final now = widget.nowProvider();
    final next = _nextRefreshBoundary(now);
    final delay = next.difference(now);

    _refreshTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _scheduleRefresh();
    });
  }

  DateTime _nextRefreshBoundary(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final sixAm = today.add(const Duration(hours: 6));
    final noon = today.add(const Duration(hours: 12));
    final threePm = today.add(const Duration(hours: 15));
    final sixPm = today.add(const Duration(hours: 18));
    final midnight = today.add(const Duration(days: 1));

    if (now.isBefore(sixAm)) return sixAm;
    if (now.isBefore(noon)) return noon;
    if (now.isBefore(threePm)) return threePm;
    if (now.isBefore(sixPm)) return sixPm;
    return midnight;
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.nowProvider();
    final suggestions = _suggestionsFor(now);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: pinit.PinitColors.cream,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: pinit.PinitColors.aubergine,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: pinit.PinitColors.aubergine,
            blurRadius: 0,
            offset: Offset(3, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Try a magic search…',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: pinit.PinitColors.aubergine,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onDismiss,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: pinit.PinitColors.creamSunk,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: pinit.PinitColors.creamDeep,
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: pinit.PinitColors.aubergineSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < suggestions.length; i++) ...[
            _SuggestionPill(
              label: suggestions[i].label,
              icon: suggestions[i].icon,
              onTap: () => widget.onSelected(suggestions[i].query),
            ),
            if (i < suggestions.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  List<_MagicSuggestion> _suggestionsFor(DateTime now) {
    final dynamicSuggestions = _timeBasedSuggestions(now);
    return [
      const _MagicSuggestion(
        label: 'Sweet treat nearby',
        query: 'Sweet treat nearby',
        icon: Icons.cake_rounded,
      ),
      ...dynamicSuggestions,
    ];
  }

  List<_MagicSuggestion> _timeBasedSuggestions(DateTime now) {
    final hour = now.hour;
    if (hour >= 6 && hour < 12) {
      return const [
        _MagicSuggestion(
          label: 'Avo toast in the sun',
          query: 'Avo toast in the sun',
          icon: Icons.wb_sunny_rounded,
        ),
        _MagicSuggestion(
          label: 'Quick latte + pastry to go',
          query: 'Quick latte and pastry to go',
          icon: Icons.coffee_rounded,
        ),
      ];
    }

    if (hour >= 12 && hour < 15) {
      return const [
        _MagicSuggestion(
          label: 'Healthy bowl for lunch',
          query: 'Healthy bowl for lunch',
          icon: Icons.spa_rounded,
        ),
        _MagicSuggestion(
          label: 'Quick lunch deal nearby',
          query: 'Quick lunch deal nearby',
          icon: Icons.lunch_dining_rounded,
        ),
      ];
    }

    if (hour >= 15 && hour < 18) {
      return const [
        _MagicSuggestion(
          label: 'Espresso nearby',
          query: 'Espresso nearby',
          icon: Icons.coffee_rounded,
        ),
        _MagicSuggestion(
          label: 'Spanish tapas',
          query: 'Spanish tapas',
          icon: Icons.restaurant_rounded,
        ),
      ];
    }

    if (hour >= 18) {
      return const [
        _MagicSuggestion(
          label: 'Dinner date spot',
          query: 'Dinner date spot',
          icon: Icons.dinner_dining_rounded,
        ),
        _MagicSuggestion(
          label: 'Cocktails + small plates',
          query: 'Cocktails and small plates',
          icon: Icons.local_bar_rounded,
        ),
      ];
    }

    // 12am → 6am
    return const [
      _MagicSuggestion(
        label: 'Late-night bite',
        query: 'Late-night bite',
        icon: Icons.nightlife_rounded,
      ),
      _MagicSuggestion(
        label: 'Comfort food open now',
        query: 'Comfort food open now',
        icon: Icons.ramen_dining_rounded,
      ),
    ];
  }
}

class _MagicSuggestion {
  const _MagicSuggestion({
    required this.label,
    required this.query,
    required this.icon,
  });

  final String label;
  final String query;
  final IconData icon;
}

class _SuggestionPill extends StatefulWidget {
  const _SuggestionPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_SuggestionPill> createState() => _SuggestionPillState();
}

class _SuggestionPillState extends State<_SuggestionPill> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails _) => setState(() => _scale = 0.97);

  void _onTapUp(TapUpDetails _) {
    setState(() => _scale = 1.0);
    widget.onTap();
  }

  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: pinit.PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: pinit.PinitColors.creamDeep,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: pinit.PinitColors.aubergine,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: pinit.PinitColors.aubergine,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: pinit.PinitColors.aubergineSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

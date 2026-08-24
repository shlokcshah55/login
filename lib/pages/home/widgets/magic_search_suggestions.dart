import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:url_launcher/url_launcher.dart';

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
  static final int _countryWheelBaseItem = _nariaCountries.length * 20;

  Timer? _refreshTimer;
  late final FixedExtentScrollController _wheelController;
  final math.Random _random = math.Random();
  var _showNariaIntro = false;
  var _showNariaWheel = false;
  var _isSpinning = false;
  var _wheelItem = _countryWheelBaseItem;
  var _selectedCountryIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedCountryIndex = _random.nextInt(_nariaCountries.length);
    _wheelItem = _countryWheelBaseItem + _selectedCountryIndex;
    _wheelController = FixedExtentScrollController(initialItem: _wheelItem);
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
    _wheelController.dispose();
    super.dispose();
  }

  String get _selectedCountry => _nariaCountries[_selectedCountryIndex];

  String get _selectedQuery => 'Authentic $_selectedCountry cuisine near me';

  Future<void> _spinNariaWheel() async {
    if (_isSpinning) return;

    HapticFeedback.selectionClick();
    setState(() => _isSpinning = true);

    final target = _wheelItem +
        (_nariaCountries.length * 2) +
        _random.nextInt(_nariaCountries.length);

    await _wheelController.animateToItem(
      target,
      duration: const Duration(milliseconds: 1450),
      curve: Curves.easeOutQuart,
    );

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _wheelItem = target;
      _selectedCountryIndex = target % _nariaCountries.length;
      _isSpinning = false;
    });
  }

  void _selectWheelItem(int item) {
    setState(() {
      _wheelItem = item;
      _selectedCountryIndex = item % _nariaCountries.length;
    });
  }

  void _searchNariaPick() {
    HapticFeedback.lightImpact();
    widget.onSelected(_selectedQuery);
  }

  Future<void> _openNariaLink(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    final nariaContent = _showNariaWheel
        ? _NariaCountryWheel(
            key: const ValueKey('naria-country-wheel'),
            controller: _wheelController,
            selectedCountry: _selectedCountry,
            selectedQuery: _selectedQuery,
            isSpinning: _isSpinning,
            onSelectedItemChanged: _selectWheelItem,
            onSpin: _spinNariaWheel,
            onSearch: _searchNariaPick,
            onBack: () => setState(() {
              _showNariaWheel = false;
              _showNariaIntro = true;
            }),
          )
        : _showNariaIntro
            ? _NariaIntroCard(
                key: const ValueKey('naria-intro-card'),
                onInstagramTap: () => unawaited(
                  _openNariaLink('https://www.instagram.com/kaianslife/'),
                ),
                onTikTokTap: () => unawaited(
                  _openNariaLink('https://www.tiktok.com/@kaianslife'),
                ),
                onSpin: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _showNariaIntro = false;
                    _showNariaWheel = true;
                  });
                },
              )
            : null;

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
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: nariaContent ??
            _MagicSearchSuggestionContent(
              key: const ValueKey('magic-suggestion-content'),
              suggestions: suggestions,
              onDismiss: widget.onDismiss,
              onSelected: widget.onSelected,
              onNariaTap: () {
                HapticFeedback.selectionClick();
                setState(() => _showNariaIntro = true);
              },
            ),
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

class _MagicSearchSuggestionContent extends StatelessWidget {
  const _MagicSearchSuggestionContent({
    super.key,
    required this.suggestions,
    required this.onDismiss,
    required this.onSelected,
    required this.onNariaTap,
  });

  final List<_MagicSuggestion> suggestions;
  final VoidCallback onDismiss;
  final ValueChanged<String> onSelected;
  final VoidCallback onNariaTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('magic-suggestion-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Suggested',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: pinit.PinitColors.aubergine,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: pinit.PinitColors.aubergineSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        _MagicPromptDeck(
          suggestions: suggestions,
          onSelected: onSelected,
        ),
        // ARCHIVED: "Try it Kaian's way" entry point. To restore, uncomment
        // the block below (widget classes/state left intact, untouched).
        // const SizedBox(height: 11),
        // const _NariaDivider(),
        // const SizedBox(height: 9),
        // _NariaWayButton(onTap: onNariaTap),
      ],
    );
  }
}

// ignore: unused_element
class _NariaDivider extends StatelessWidget {
  const _NariaDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            color: pinit.PinitColors.creamDeep,
            height: 1,
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'OR...',
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: pinit.PinitColors.aubergineSoft,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const Expanded(
          child: Divider(
            color: pinit.PinitColors.creamDeep,
            height: 1,
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

class _MagicPromptDeck extends StatelessWidget {
  const _MagicPromptDeck({
    required this.suggestions,
    required this.onSelected,
  });

  final List<_MagicSuggestion> suggestions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < suggestions.length; i++) ...[
          _SuggestionPill(
            label: suggestions[i].label,
            icon: suggestions[i].icon,
            onTap: () => onSelected(suggestions[i].query),
          ),
          if (i < suggestions.length - 1)
            const Divider(
              color: pinit.PinitColors.creamDeep,
              height: 1,
              thickness: 1,
              indent: 34,
            ),
        ],
      ],
    );
  }
}

class _NariaWayButton extends StatefulWidget {
  const _NariaWayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_NariaWayButton> createState() => _NariaWayButtonState();
}

class _NariaWayButtonState extends State<_NariaWayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motionController;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..repeat();
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => setState(() => _scale = 0.96);

  void _onTapCancel() => setState(() => _scale = 1.0);

  void _onTapUp(TapUpDetails _) {
    setState(() => _scale = 1.0);
    widget.onTap();
  }

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
        child: AnimatedBuilder(
          animation: _motionController,
          builder: (context, _) {
            final wave = math.sin(_motionController.value * math.pi * 2);
            final pulse = wave.abs();
            final idleLift = -1.6 * pulse;
            final idleScale = 1.0 + (0.012 * pulse);
            final arrowNudge =
                math.sin(_motionController.value * math.pi * 4) * 1.8;

            return Transform.translate(
              offset: Offset(0, idleLift),
              child: Transform.scale(
                scale: idleScale,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: pinit.PinitColors.aubergine,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: pinit.PinitColors.aubergine,
                        blurRadius: 0,
                        offset: Offset(2.5, 2.5 + (1.0 * pulse)),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: pinit.PinitColors.cream,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: pinit.PinitColors.cream,
                            width: 2,
                          ),
                        ),
                        child: Image.asset(
                          'lib/kaian.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Try it Kaian's way",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: pinit.PinitColors.cream,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Spin a country wheel and let fate pick the craving.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: pinit.PinitColors.cream
                                    .withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Transform.translate(
                        offset: Offset(arrowNudge, 0),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: pinit.PinitColors.cream,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: pinit.PinitColors.aubergine,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NariaIntroCard extends StatelessWidget {
  const _NariaIntroCard({
    super.key,
    required this.onInstagramTap,
    required this.onTikTokTap,
    required this.onSpin,
  });

  final VoidCallback onInstagramTap;
  final VoidCallback onTikTokTap;
  final VoidCallback onSpin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: pinit.PinitColors.aubergine,
          width: 1.3,
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: pinit.PinitColors.aubergine,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: pinit.PinitColors.cream,
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x2441133D),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'lib/kaian.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NariaSocialButton(
                        label: 'Instagram',
                        icon: FontAwesomeIcons.instagram,
                        onTap: onInstagramTap,
                      ),
                      const SizedBox(width: 6),
                      _NariaSocialButton(
                        label: 'TikTok',
                        icon: FontAwesomeIcons.tiktok,
                        onTap: onTikTokTap,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Kaian's way",
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: pinit.PinitColors.aubergine,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Kaian is exploring the world's cuisine without leaving London. He spins a wheel and finds a restaurant. Try it out in your city.",
                      style: GoogleFonts.dmSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: pinit.PinitColors.aubergineSoft,
                        height: 1.28,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onSpin,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: pinit.PinitColors.aubergine,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.casino_rounded,
                    size: 17,
                    color: pinit.PinitColors.cream,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Spin the wheel',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: pinit.PinitColors.cream,
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
}

class _NariaSocialButton extends StatelessWidget {
  const _NariaSocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 27,
          height: 27,
          decoration: BoxDecoration(
            color: pinit.PinitColors.cream,
            shape: BoxShape.circle,
            border: Border.all(
              color: pinit.PinitColors.creamDeep,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 14,
            color: pinit.PinitColors.aubergine,
          ),
        ),
      ),
    );
  }
}

class _NariaCountryWheel extends StatelessWidget {
  const _NariaCountryWheel({
    super.key,
    required this.controller,
    required this.selectedCountry,
    required this.selectedQuery,
    required this.isSpinning,
    required this.onSelectedItemChanged,
    required this.onSpin,
    required this.onSearch,
    required this.onBack,
  });

  final FixedExtentScrollController controller;
  final String selectedCountry;
  final String selectedQuery;
  final bool isSpinning;
  final ValueChanged<int> onSelectedItemChanged;
  final VoidCallback onSpin;
  final VoidCallback onSearch;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: pinit.PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: pinit.PinitColors.creamDeep,
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: pinit.PinitColors.cream,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: pinit.PinitColors.creamDeep,
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 16,
                        color: pinit.PinitColors.aubergine,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Naria's wheel",
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: pinit.PinitColors.aubergine,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'It will come up with a place.',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: pinit.PinitColors.mute,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 168,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: pinit.PinitColors.cream,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: pinit.PinitColors.aubergine,
                          width: 1.3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1441133D),
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                    ListWheelScrollView.useDelegate(
                      controller: controller,
                      itemExtent: 40,
                      diameterRatio: 1.35,
                      perspective: 0.0025,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: onSelectedItemChanged,
                      childDelegate: ListWheelChildLoopingListDelegate(
                        children: [
                          for (final country in _nariaCountries)
                            Center(
                              child: Text(
                                country,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: pinit.PinitColors.aubergine,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Positioned(
                      right: 10,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: 19,
                        color: pinit.PinitColors.aubergine,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  selectedQuery,
                  key: ValueKey(selectedQuery),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: pinit.PinitColors.aubergineSoft,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _WheelActionButton(
                label: isSpinning ? 'Spinning...' : 'Spin',
                icon: Icons.refresh_rounded,
                onTap: isSpinning ? null : onSpin,
                isPrimary: false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _WheelActionButton(
                label: 'Search',
                icon: Icons.search_rounded,
                onTap: isSpinning ? null : onSearch,
                isPrimary: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WheelActionButton extends StatelessWidget {
  const _WheelActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isPrimary,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final background =
        isPrimary ? pinit.PinitColors.aubergine : pinit.PinitColors.cream;
    final foreground =
        isPrimary ? pinit.PinitColors.cream : pinit.PinitColors.aubergine;

    return Opacity(
      opacity: enabled ? 1 : 0.58,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary
                  ? pinit.PinitColors.aubergine
                  : pinit.PinitColors.creamDeep,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const List<String> _nariaCountries = [
  'Afghanistan',
  'Albania',
  'Algeria',
  'Andorra',
  'Angola',
  'Antigua and Barbuda',
  'Argentina',
  'Armenia',
  'Australia',
  'Austria',
  'Azerbaijan',
  'Bahamas',
  'Bahrain',
  'Bangladesh',
  'Barbados',
  'Belarus',
  'Belgium',
  'Belize',
  'Benin',
  'Bhutan',
  'Bolivia',
  'Bosnia and Herzegovina',
  'Botswana',
  'Brazil',
  'Brunei',
  'Bulgaria',
  'Burkina Faso',
  'Burundi',
  'Cabo Verde',
  'Cambodia',
  'Cameroon',
  'Canada',
  'Central African Republic',
  'Chad',
  'Chile',
  'China',
  'Colombia',
  'Comoros',
  'Costa Rica',
  "Cote d'Ivoire",
  'Croatia',
  'Cuba',
  'Cyprus',
  'Czechia',
  'Democratic Republic of the Congo',
  'Denmark',
  'Djibouti',
  'Dominica',
  'Dominican Republic',
  'Ecuador',
  'Egypt',
  'El Salvador',
  'Equatorial Guinea',
  'Eritrea',
  'Estonia',
  'Eswatini',
  'Ethiopia',
  'Fiji',
  'Finland',
  'France',
  'Gabon',
  'Gambia',
  'Georgia',
  'Germany',
  'Ghana',
  'Greece',
  'Grenada',
  'Guatemala',
  'Guinea',
  'Guinea-Bissau',
  'Guyana',
  'Haiti',
  'Honduras',
  'Hungary',
  'Iceland',
  'India',
  'Indonesia',
  'Iran',
  'Iraq',
  'Ireland',
  'Israel',
  'Italy',
  'Jamaica',
  'Japan',
  'Jordan',
  'Kazakhstan',
  'Kenya',
  'Kiribati',
  'Kosovo',
  'Kuwait',
  'Kyrgyzstan',
  'Laos',
  'Latvia',
  'Lebanon',
  'Lesotho',
  'Liberia',
  'Libya',
  'Liechtenstein',
  'Lithuania',
  'Luxembourg',
  'Madagascar',
  'Malawi',
  'Malaysia',
  'Maldives',
  'Mali',
  'Malta',
  'Marshall Islands',
  'Mauritania',
  'Mauritius',
  'Mexico',
  'Micronesia',
  'Moldova',
  'Monaco',
  'Mongolia',
  'Montenegro',
  'Morocco',
  'Mozambique',
  'Myanmar',
  'Namibia',
  'Nauru',
  'Nepal',
  'Netherlands',
  'New Zealand',
  'Nicaragua',
  'Niger',
  'Nigeria',
  'North Korea',
  'North Macedonia',
  'Norway',
  'Oman',
  'Pakistan',
  'Palau',
  'Palestine',
  'Panama',
  'Papua New Guinea',
  'Paraguay',
  'Peru',
  'Philippines',
  'Poland',
  'Portugal',
  'Qatar',
  'Republic of the Congo',
  'Romania',
  'Russia',
  'Rwanda',
  'Saint Kitts and Nevis',
  'Saint Lucia',
  'Saint Vincent and the Grenadines',
  'Samoa',
  'San Marino',
  'Sao Tome and Principe',
  'Saudi Arabia',
  'Senegal',
  'Serbia',
  'Seychelles',
  'Sierra Leone',
  'Singapore',
  'Slovakia',
  'Slovenia',
  'Solomon Islands',
  'Somalia',
  'South Africa',
  'South Korea',
  'South Sudan',
  'Spain',
  'Sri Lanka',
  'Sudan',
  'Suriname',
  'Sweden',
  'Switzerland',
  'Syria',
  'Taiwan',
  'Tajikistan',
  'Tanzania',
  'Thailand',
  'Timor-Leste',
  'Togo',
  'Tonga',
  'Trinidad and Tobago',
  'Tunisia',
  'Turkey',
  'Turkmenistan',
  'Tuvalu',
  'Uganda',
  'Ukraine',
  'United Arab Emirates',
  'United Kingdom',
  'United States',
  'Uruguay',
  'Uzbekistan',
  'Vanuatu',
  'Vatican City',
  'Venezuela',
  'Vietnam',
  'Yemen',
  'Zambia',
  'Zimbabwe',
];

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
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: pinit.PinitColors.aubergineSoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: pinit.PinitColors.aubergine,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: pinit.PinitColors.aubergineSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

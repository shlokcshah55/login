import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/football_fixture.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/football_discovery_view_model.dart';
import 'package:login/pages/home/widgets/search_result_action_sheet.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/widgets/feedback/app_feedback.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:provider/provider.dart';

class FootballDiscoveryOverlay extends StatefulWidget {
  const FootballDiscoveryOverlay({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  State<FootballDiscoveryOverlay> createState() =>
      _FootballDiscoveryOverlayState();
}

class _FootballDiscoveryOverlayState extends State<FootballDiscoveryOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<FootballDiscoveryViewModel>().init());
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final sheetHeight = media.size.height * 0.92;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.04, end: 0),
          builder: (context, offset, child) {
            return Transform.translate(
              offset: Offset(0, sheetHeight * offset),
              child: child,
            );
          },
          child: Container(
            height: sheetHeight,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: pinit.PinitColors.cream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x3341133D),
                  blurRadius: 34,
                  offset: Offset(0, -12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              child: Consumer<FootballDiscoveryViewModel>(
                builder: (context, viewModel, _) {
                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _FootballHero(onClose: widget.onClose),
                      ),
                      SliverToBoxAdapter(
                        child: _SectionShell(
                          title: 'Match pubs near you',
                          subtitle:
                              'Sports bars and pubs picked from Pinit search',
                          trailing: viewModel.isPubSearchLoading
                              ? const _LiveDot()
                              : IconButton(
                                  tooltip: 'Refresh pubs',
                                  onPressed: () =>
                                      unawaited(viewModel.loadPubSearch()),
                                  icon: const Icon(
                                    FeatherIcons.refreshCw,
                                    size: 18,
                                  ),
                                ),
                          child: _PlacesStrip(
                            isLoading: viewModel.isPubSearchLoading,
                            error: viewModel.pubSearchError,
                            emptyTitle: 'No football pubs found nearby',
                            emptyMessage:
                                'Try refreshing once the map is centred where you want to watch.',
                            locations: viewModel.pubResults,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _FixtureSection(viewModel: viewModel),
                      ),
                      if (viewModel.selectedFixture != null)
                        SliverToBoxAdapter(
                          child: _CuisineResults(viewModel: viewModel),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 28)),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FootballHero extends StatelessWidget {
  const _FootballHero({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        18 + MediaQuery.of(context).padding.top * 0.16,
        18,
        18,
      ),
      decoration: const BoxDecoration(
        color: pinit.PinitColors.aubergine,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: pinit.PinitColors.cream.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: pinit.PinitColors.warning,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: pinit.PinitColors.cream,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: pinit.PinitColors.cream,
                      blurRadius: 0,
                      offset: Offset(3, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_soccer_rounded,
                  color: pinit.PinitColors.aubergine,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WORLD CUP MODE',
                      style: GoogleFonts.dmSans(
                        color: pinit.PinitColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Find me pubs to watch the football',
                      style: GoogleFonts.dmSans(
                        color: pinit.PinitColors.cream,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(
                  FeatherIcons.x,
                  color: pinit.PinitColors.cream,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        color: pinit.PinitColors.aubergine,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(
                        color: pinit.PinitColors.mute,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FixtureSection extends StatelessWidget {
  const _FixtureSection({required this.viewModel});

  final FootballDiscoveryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Browse by fixture',
      subtitle: viewModel.fixturesError ?? 'Food ideas shaped by the teams',
      trailing: viewModel.areFixturesLoading ? const _LiveDot() : null,
      child: SizedBox(
        height: 148,
        child: viewModel.areFixturesLoading
            ? const _FixtureSkeletonRow()
            : viewModel.fixtures.isEmpty
                ? const _EmptyPanel(
                    title: 'No fixtures available',
                    message: 'Check back when the next match list is live.',
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: viewModel.fixtures.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final fixture = viewModel.fixtures[index];
                      return _FixtureCard(
                        fixture: fixture,
                        isSelected: viewModel.selectedFixture?.id == fixture.id,
                        onTap: () => unawaited(
                          viewModel.selectFixture(fixture),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _FixtureCard extends StatelessWidget {
  const _FixtureCard({
    required this.fixture,
    required this.isSelected,
    required this.onTap,
  });

  final FootballFixture fixture;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _fixtureTone(fixture.id);
    final borderColor = isSelected ? tone.accent : tone.border;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 250,
        decoration: BoxDecoration(
          color: isSelected ? tone.selectedBackground : tone.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: borderColor,
              blurRadius: 0,
              offset: Offset(isSelected ? 4 : 3, isSelected ? 4 : 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 47,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                color: tone.accent.withValues(alpha: isSelected ? 0.20 : 0.13),
                child: Row(
                  children: [
                    _TeamBadge(
                      label: fixture.teamA,
                      country: fixture.countryAForSearch,
                      imageUrl: fixture.flagAUrl,
                      accentColor: tone.accent,
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: pinit.PinitColors.cream,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: borderColor.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        'vs',
                        style: GoogleFonts.dmSans(
                          color: borderColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    _TeamBadge(
                      label: fixture.teamB,
                      country: fixture.countryBForSearch,
                      imageUrl: fixture.flagBUrl,
                      accentColor: tone.accent,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fixture.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: pinit.PinitColors.aubergine,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _fixtureMeta(fixture),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: pinit.PinitColors.mute,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? tone.accent
                              : tone.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              FeatherIcons.compass,
                              size: 13,
                              color: isSelected
                                  ? pinit.PinitColors.cream
                                  : pinit.PinitColors.aubergine,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Browse food from these countries',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  color: isSelected
                                      ? pinit.PinitColors.cream
                                      : pinit.PinitColors.aubergine,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({
    required this.label,
    required this.country,
    this.imageUrl,
    required this.accentColor,
  });

  final String label;
  final String country;
  final String? imageUrl;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final initials = label
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final canUseImage =
        imageUrl != null && !imageUrl!.toLowerCase().endsWith('.svg');
    final assetPath = _flagAssetFor(country) ?? _flagAssetFor(label);

    return Container(
      width: 38,
      height: 38,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: pinit.PinitColors.cream,
        shape: BoxShape.circle,
        border: Border.all(color: accentColor, width: 1.5),
      ),
      child: assetPath != null
          ? Padding(
              padding: const EdgeInsets.all(5),
              child: SvgPicture.asset(
                assetPath,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => _InitialsFlagLabel(
                  initials: initials,
                ),
                errorBuilder: (_, __, ___) => _InitialsFlagLabel(
                  initials: initials,
                ),
              ),
            )
          : canUseImage
              ? Image.network(imageUrl!, fit: BoxFit.cover)
              : _InitialsFlagLabel(initials: initials),
    );
  }
}

String? _flagAssetFor(String value) {
  final key = _normaliseCountryKey(value);
  if (key.isEmpty) return null;

  final slug = _flagSlugAliases[key] ?? key.replaceAll(' ', '-');
  return 'lib/assets/openmoji-svg-color/$slug.svg';
}

String _normaliseCountryKey(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ã', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ô', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r"['’]"), '')
      .replaceAll(
          RegExp(r'\b(mens|men|womens|women|u[0-9]{2}|under [0-9]{2})\b'), ' ')
      .replaceAll(RegExp(r'\b(national|team|football|fc|afc)\b'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

const Map<String, String> _flagSlugAliases = {
  'cote divoire': 'ivory-coast',
  'cote d ivoire': 'ivory-coast',
  'curacao': 'curacao',
  'dr congo': 'congo-kinshasa',
  'democratic republic of congo': 'congo-kinshasa',
  'ivory coast': 'ivory-coast',
  'north korea': 'north-korea',
  'south korea': 'south-korea',
  'turkey': 'turkiye',
  'united kingdom': 'united-kingdom',
  'uk': 'united-kingdom',
  'usa': 'united-states',
  'us': 'united-states',
  'united states': 'united-states',
  'united states of america': 'united-states',
};

class _InitialsFlagLabel extends StatelessWidget {
  const _InitialsFlagLabel({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: GoogleFonts.dmSans(
          color: pinit.PinitColors.aubergine,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FixtureTone {
  const _FixtureTone({
    required this.accent,
    required this.border,
    required this.background,
    required this.selectedBackground,
  });

  final Color accent;
  final Color border;
  final Color background;
  final Color selectedBackground;
}

_FixtureTone _fixtureTone(String id) {
  const tones = [
    _FixtureTone(
      accent: pinit.PinitColors.accent,
      border: pinit.PinitColors.aubergine,
      background: Color(0xFFFFF0EC),
      selectedBackground: Color(0xFFFFE3DD),
    ),
    _FixtureTone(
      accent: pinit.PinitColors.teal,
      border: Color(0xFF176F66),
      background: Color(0xFFE9F7F3),
      selectedBackground: Color(0xFFD7F0EA),
    ),
    _FixtureTone(
      accent: pinit.PinitColors.warning,
      border: Color(0xFF8A6500),
      background: Color(0xFFFFF5D6),
      selectedBackground: Color(0xFFFFE8A6),
    ),
    _FixtureTone(
      accent: pinit.PinitColors.aubergineSoft,
      border: pinit.PinitColors.aubergine,
      background: Color(0xFFF2E7F0),
      selectedBackground: Color(0xFFE7D4E4),
    ),
  ];
  return tones[id.hashCode.abs() % tones.length];
}

class _CuisineResults extends StatelessWidget {
  const _CuisineResults({required this.viewModel});

  final FootballDiscoveryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final fixture = viewModel.selectedFixture!;
    return _SectionShell(
      title: fixture.displayTitle,
      subtitle: viewModel.isCuisineSearchLoading
          ? 'Searching restaurants for both sides'
          : 'Fixture food picks without leaving the overlay',
      trailing: viewModel.isCuisineSearchLoading ? const _LiveDot() : null,
      child: Column(
        children: [
          if (viewModel.isCuisineSearchLoading)
            const _SkeletonPlaceList()
          else if (viewModel.cuisineSearchError != null)
            _EmptyPanel(
              title: 'Could not load fixture food',
              message: viewModel.cuisineSearchError!,
            )
          else
            ...viewModel.cuisineGroups.map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _CuisineGroupView(group: group),
              ),
            ),
        ],
      ),
    );
  }
}

class _CuisineGroupView extends StatelessWidget {
  const _CuisineGroupView({required this.group});

  final FootballCuisineResultGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: pinit.PinitColors.aubergine,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                group.title,
                style: GoogleFonts.dmSans(
                  color: pinit.PinitColors.cream,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                group.country,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: pinit.PinitColors.mute,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _PlacesStrip(
          isLoading: false,
          error: group.error,
          emptyTitle: 'No ${group.cuisine} picks nearby',
          emptyMessage: 'Try another fixture or move the map.',
          locations: group.results,
        ),
      ],
    );
  }
}

class _PlacesStrip extends StatelessWidget {
  const _PlacesStrip({
    required this.isLoading,
    required this.error,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.locations,
  });

  final bool isLoading;
  final String? error;
  final String emptyTitle;
  final String emptyMessage;
  final List<LocationModel> locations;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _SkeletonPlaceList();
    if (error != null) {
      return _EmptyPanel(title: 'Search paused', message: error!);
    }
    if (locations.isEmpty) {
      return _EmptyPanel(title: emptyTitle, message: emptyMessage);
    }

    return Column(
      children: [
        for (final location in locations.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _FootballPlaceCard(location: location),
          ),
      ],
    );
  }
}

class _FootballPlaceCard extends StatelessWidget {
  const _FootballPlaceCard({required this.location});

  final LocationModel location;

  @override
  Widget build(BuildContext context) {
    final imageUrl = location.imageUrl?.trim();
    return GestureDetector(
      onTap: () => _openExpanded(context, location),
      child: Container(
        height: 122,
        decoration: BoxDecoration(
          color: pinit.PinitColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: pinit.PinitColors.aubergine, width: 1.3),
          boxShadow: const [
            BoxShadow(
              color: pinit.PinitColors.aubergine,
              blurRadius: 0,
              offset: Offset(3, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.7),
          child: Row(
            children: [
              SizedBox(
                width: 112,
                height: double.infinity,
                child: imageUrl == null || imageUrl.isEmpty
                    ? const _ImageFallback()
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const _ImageFallback(),
                        errorWidget: (_, __, ___) => const _ImageFallback(),
                      ),
              ),
              Container(width: 1.3, color: pinit.PinitColors.aubergine),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              location.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                color: pinit.PinitColors.aubergine,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                              ),
                            ),
                          ),
                          _IconCircle(
                            icon: FeatherIcons.bookmark,
                            onTap: () => unawaited(_save(context)),
                          ),
                          const SizedBox(width: 6),
                          _IconCircle(
                            icon: FeatherIcons.send,
                            onTap: () => unawaited(_sendToBubble(context)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: pinit.PinitColors.mute,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 24,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            if (location.rating != null)
                              _MetaPill(
                                icon: FeatherIcons.star,
                                label: location.rating!.toStringAsFixed(1),
                              ),
                            if (location.distanceKm != null)
                              _MetaPill(
                                icon: FeatherIcons.mapPin,
                                label:
                                    '${location.distanceKm!.toStringAsFixed(1)} km',
                              ),
                            if (location.matchScore != null)
                              _MetaPill(
                                icon: FeatherIcons.zap,
                                label:
                                    '${(location.matchScore! * 100).round()}% match',
                                accent: true,
                              ),
                            if (location.displayCuisine != null)
                              _MetaPill(label: location.displayCuisine!),
                            if (location.goodForWatchingSports == true)
                              const _MetaPill(
                                icon: Icons.sports_soccer_rounded,
                                label: 'Sports',
                                accent: true,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _subtitle {
    final reason = location.magicSearchMatchReasons.isNotEmpty
        ? location.magicSearchMatchReasons.first
        : null;
    final vicinity = location.vicinity?.trim();
    if (reason != null && reason.isNotEmpty) return reason;
    if (vicinity != null && vicinity.isNotEmpty) return vicinity;
    return 'Pinit Magic Search pick';
  }

  Future<void> _save(BuildContext context) async {
    try {
      await SearchResultActionHandler.save(context, location);
    } catch (_) {
      if (!context.mounted) return;
      unawaited(
        AppFeedback.showError(
          context,
          title: "Couldn't save",
          message: 'Try again in a moment.',
        ),
      );
    }
  }

  Future<void> _sendToBubble(BuildContext context) async {
    try {
      await SearchResultActionHandler.sendToBubble(context, location);
    } catch (_) {
      if (!context.mounted) return;
      unawaited(
        AppFeedback.showError(
          context,
          title: "Couldn't send",
          message: 'Try sharing this place to a bubble again.',
        ),
      );
    }
  }

  void _openExpanded(BuildContext context, LocationModel location) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, _, __) => ExpandedLocationCard(
        location: location,
        onClose: () => Navigator.of(ctx).pop(),
      ),
      transitionBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: pinit.PinitColors.creamSunk,
          shape: BoxShape.circle,
          border: Border.all(color: pinit.PinitColors.aubergine, width: 1),
        ),
        child: Icon(icon, size: 14, color: pinit.PinitColors.aubergine),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    this.icon,
    this.accent = false,
  });

  final String label;
  final IconData? icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            accent ? pinit.PinitColors.aubergine : pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: pinit.PinitColors.aubergine.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 11,
              color: accent
                  ? pinit.PinitColors.cream
                  : pinit.PinitColors.aubergine,
            ),
            const SizedBox(width: 4),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 116),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: accent
                    ? pinit.PinitColors.cream
                    : pinit.PinitColors.aubergine,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: pinit.PinitColors.creamDeep,
      child: const Center(
        child: Icon(
          Icons.sports_bar_rounded,
          color: pinit.PinitColors.aubergine,
          size: 28,
        ),
      ),
    );
  }
}

class _SkeletonPlaceList extends StatelessWidget {
  const _SkeletonPlaceList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _SkeletonPlaceCard(),
        SizedBox(height: 12),
        _SkeletonPlaceCard(),
        SizedBox(height: 12),
        _SkeletonPlaceCard(),
      ],
    );
  }
}

class _SkeletonPlaceCard extends StatelessWidget {
  const _SkeletonPlaceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pinit.PinitColors.aubergine.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 108,
            decoration: const BoxDecoration(
              color: pinit.PinitColors.creamDeep,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(13)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _skeletonBar(width: 150, height: 14),
                  const SizedBox(height: 10),
                  _skeletonBar(width: 210, height: 10),
                  const SizedBox(height: 18),
                  _skeletonBar(width: 120, height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonBar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: pinit.PinitColors.aubergine.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _FixtureSkeletonRow extends StatelessWidget {
  const _FixtureSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 2,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, __) => Container(
        width: 250,
        decoration: BoxDecoration(
          color: pinit.PinitColors.creamSunk,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pinit.PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pinit.PinitColors.aubergine.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            FeatherIcons.info,
            color: pinit.PinitColors.aubergine,
            size: 19,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    color: pinit.PinitColors.aubergine,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: GoogleFonts.dmSans(
                    color: pinit.PinitColors.mute,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: pinit.PinitColors.aubergine,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: pinit.PinitColors.warning,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'Live',
            style: GoogleFonts.dmSans(
              color: pinit.PinitColors.cream,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

String _fixtureMeta(FootballFixture fixture) {
  final pieces = <String>[];
  final competition = fixture.competition?.trim();
  if (competition != null && competition.isNotEmpty) {
    pieces.add(competition);
  }
  final kickoff = fixture.kickoffTime;
  if (kickoff != null) {
    pieces.add(_formatKickoff(kickoff.toLocal()));
  }
  return pieces.isEmpty ? 'Fixture food discovery' : pieces.join('  |  ');
}

String _formatKickoff(DateTime time) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.day} ${months[time.month - 1]} ${time.hour}:$minute';
}

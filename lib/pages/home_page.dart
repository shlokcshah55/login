import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/home/home_view_model.dart';
import 'package:login/pages/home/quick_picks/quick_picks_distance_page.dart';
import 'package:login/pages/home/search/header_search_types.dart';
import 'package:login/pages/home/widgets/home_carousel.dart';
import 'package:login/pages/home/widgets/home_filter_sheet.dart';
import 'package:login/pages/home/widgets/home_header_search_shell.dart';
import 'package:login/pages/home/widgets/home_map_layer.dart';
import 'package:login/pages/home/widgets/gavel_overlay.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/themes/app_typography.dart';
import 'package:login/themes/pinit_colors.dart';
import 'package:login/pages/home/widgets/mode_toggle.dart';
import 'package:login/pages/home/widgets/search_result_action_sheet.dart';
import 'package:login/pages/home/carousel_list_page.dart';
import 'package:login/pages/home/widgets/decide_bottom_sheet.dart';
import 'package:login/pages/home/widgets/shortlist_pill.dart';
import 'package:login/pages/home/widgets/shortlist_carousel_sheet.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/nav_bar/visibility_provider.dart';
import 'package:login/providers/shortlist_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/providers/bubble_mode_provider.dart';
import 'package:login/providers/navigation_provider.dart';
import 'package:login/supabase/service.dart';
import 'package:login/widgets/home/bubble_mode_overlay.dart';
import 'package:login/widgets/home/no_recommendations_popover.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:login/widgets/swipe_card_stack.dart';
import 'package:login/widgets/wizard_completion_popover.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  final bool isActive;

  const HomePage({
    Key? key,
    this.isActive = true,
  }) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeViewModel _viewModel;
  late final LocationListManager _locationListManager;
  late final MapStateProvider _mapStateProvider;
  late final BottomNavVisibilityProvider _bottomNavVisibilityProvider;
  late final ShortlistProvider _shortlistProvider;
  late final BubbleModeProvider _bubbleModeProvider;
  late final SupabaseService _supabaseService;
  late final UserDataProvider _userDataProvider;
  Set<String> _selectedVibeTagIds = <String>{};
  Set<String> _selectedCuisineTagIds = <String>{};
  bool _wizardPopoverScheduled = false;
  bool _wizardPopoverShown = false;
  String? _lastHandledError;
  bool _isNoRecommendationsPopoverVisible = false;

  @override
  void initState() {
    super.initState();
    _locationListManager = context.read<LocationListManager>();
    _mapStateProvider = context.read<MapStateProvider>();
    _bottomNavVisibilityProvider = context.read<BottomNavVisibilityProvider>();
    _shortlistProvider = context.read<ShortlistProvider>();
    _bubbleModeProvider = context.read<BubbleModeProvider>();
    _supabaseService = context.read<SupabaseService>();
    _userDataProvider = context.read<UserDataProvider>();
    _viewModel = HomeViewModel(
      locationListManager: _locationListManager,
      mapStateProvider: _mapStateProvider,
      bottomNavVisibilityProvider: _bottomNavVisibilityProvider,
      shortlistProvider: _shortlistProvider,
      supabaseService: _supabaseService,
      userDataProvider: _userDataProvider,
    );
    _viewModel.init();

    _locationListManager.addListener(_checkForErrors);
    _bubbleModeProvider.addListener(_handleBubbleModeRequest);
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _handleBubbleModeRequest();
      _handlePendingFocusLocation();
    }
  }

  void _handlePendingFocusLocation() {
    final navProvider = context.read<NavigationProvider>();
    final location = navProvider.pendingFocusLocation;
    if (location == null) return;
    navProvider.clearPendingFocusLocation();
    _locationListManager.focusSingleLocation(location);
    _mapStateProvider.setSelectedMarkerId(location.locationId.toString());
  }

  void _checkForErrors() {
    if (!mounted) return;
    final error = _locationListManager.error;
    if (error == null) {
      _lastHandledError = null;
      return;
    }
    if (error == _lastHandledError) {
      return;
    }

    _lastHandledError = error;

    if (error == LocationListManager.noRecommendationsInAreaMessage) {
      if (_isNoRecommendationsPopoverVisible) return;
      _isNoRecommendationsPopoverVisible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showNoRecommendationsPopover();
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _showNoRecommendationsPopover() async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, _, __) {
        return const NoRecommendationsPopover();
      },
      transitionBuilder: (dialogContext, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (mounted) {
      _isNoRecommendationsPopoverVisible = false;
    }
  }

  Future<void> _handleBubbleModeRequest() async {
    if (!mounted) return;
    if (_bubbleModeProvider.hasPendingActivation && widget.isActive) {
      final bubble = _bubbleModeProvider.pendingBubble!;
      _bubbleModeProvider.clearPendingBubble();
      await _viewModel.activateBubbleMode(bubble);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bubble mode activated for ${bubble.name}'),
            backgroundColor: PinitColors.dark.primaryPurple,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _scheduleWizardPopoverIfNeeded(UserDataProvider userDataProvider) {
    if (_wizardPopoverShown || _wizardPopoverScheduled || !widget.isActive) {
      return;
    }
    final userData = userDataProvider.supabaseUserData;
    if (userData == null || userData.wizardCompleted) return;
    _wizardPopoverScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showWizardPopoverIfNeeded();
    });
  }

  void _showWizardPopoverIfNeeded() {
    if (_wizardPopoverShown || !widget.isActive) return;
    final userDataProvider = context.read<UserDataProvider>();
    final userData = userDataProvider.supabaseUserData;
    if (userData == null || userData.wizardCompleted) {
      _wizardPopoverScheduled = false;
      return;
    }
    _wizardPopoverShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return WizardCompletionPopover(
          onComplete: () {
            Navigator.pop(dialogContext);
            Navigator.of(context, rootNavigator: true)
                .pushNamed('/wizardCompletion');
          },
          onDismiss: () => Navigator.pop(dialogContext),
        );
      },
    );
  }

  Future<void> _openHomeFilters() async {
    final result = await HomeFilterSheet.show(
      context,
      initialVibeTagIds: _selectedVibeTagIds,
      initialCuisineTagIds: _selectedCuisineTagIds,
      initialAvailabilityFilter: _locationListManager.availabilityFilter,
    );
    if (!mounted || result == null) return;
    setState(() {
      _selectedVibeTagIds = result.vibeTagIds;
      _selectedCuisineTagIds = result.cuisineTagIds;
    });
    await _locationListManager.applyFilters(
      vibeTagIds: result.vibeTagIds.toList(),
      cuisineTagIds: result.cuisineTagIds.toList(),
      availabilityFilter: result.availabilityFilter,
      vibeTagNames: result.vibeTagNames,
      cuisineTagNames: result.cuisineTagNames,
    );
  }

  @override
  void dispose() {
    _locationListManager.removeListener(_checkForErrors);
    _bubbleModeProvider.removeListener(_handleBubbleModeRequest);
    _viewModel.dispose();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<HomeViewModel>(
        builder: (context, viewModel, _) {
          final userDataProvider = context.watch<UserDataProvider>();
          _scheduleWizardPopoverIfNeeded(userDataProvider);
          final carouselBottom = viewModel.bottomNavVisible ? 110.0 : 20.0;
          final topPadding = MediaQuery.of(context).padding.top;

          return Scaffold(
            resizeToAvoidBottomInset: false,
            body: Stack(
              clipBehavior: Clip.none,
              children: [
                // ─── Layer 1: Map ──────────────────────────────
                Positioned.fill(
                  child: HomeMapLayer(
                    onMapTap: viewModel.onMapTap,
                    onSearchThisArea: viewModel.searchThisArea,
                  ),
                ),

                // ─── Layer 2+3: Purple header panel ────────────
                //     Logo + Search + Chip row as one unified surface
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _TopPanel(
                    topPadding: topPadding,
                    viewModel: viewModel,
                  ),
                ),

                // ─── Layer 5: Carousel + See All button ─────────
                if (!viewModel.isHeaderSearchActive &&
                    !viewModel.isMagicSearchFieldFocused)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutQuint,
                    bottom: carouselBottom,
                    left: 0,
                    right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 16, right: 16, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  // ── Location pill ──
                                  GestureDetector(
                                    onTap: () => _viewModel.locateUser(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: pinit.PinitColors.cream,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: pinit.PinitColors.aubergine,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: pinit.PinitColors.aubergine,
                                            blurRadius: 0,
                                            offset: const Offset(3, 3),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.my_location_rounded,
                                        size: 15,
                                        color: pinit.PinitColors.aubergine,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: _openHomeFilters,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: pinit.PinitColors.cream,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color:
                                                  pinit.PinitColors.aubergine,
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color:
                                                    pinit.PinitColors.aubergine,
                                                blurRadius: 0,
                                                offset: const Offset(3, 3),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            FeatherIcons.sliders,
                                            size: 15,
                                            color: pinit.PinitColors.aubergine,
                                          ),
                                        ),
                                        if (_selectedVibeTagIds.isNotEmpty ||
                                            _selectedCuisineTagIds.isNotEmpty)
                                          Positioned(
                                            top: -4,
                                            right: -2,
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                minWidth: 18,
                                                minHeight: 18,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 5,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: pinit.PinitColors.accent,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color:
                                                      pinit.PinitColors.cream,
                                                  width: 1.2,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${_selectedVibeTagIds.length + _selectedCuisineTagIds.length}',
                                                  style: AppTypography.sans(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        pinit.PinitColors.cream,
                                                    height: 1.0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (viewModel.locations.isNotEmpty &&
                                      viewModel.shortlistIsNotEmpty) ...[
                                    ShortlistPill(
                                      count: viewModel.shortlistCount,
                                      onTap: () => ShortlistCarouselSheet.show(
                                        context,
                                        currentMode: viewModel.homeMode,
                                        onReturnToMode: viewModel.setHomeMode,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  if (viewModel.locations.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => CarouselListPage(
                                            locations: viewModel.locations,
                                            title: switch (viewModel.homeMode) {
                                              HomeMode.you => 'Your Saves',
                                              HomeMode.explore => 'Top Picks',
                                              HomeMode.bubble => 'Bubble Picks',
                                            },
                                          ),
                                        ),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: pinit.PinitColors.cream,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: pinit.PinitColors.aubergine,
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  pinit.PinitColors.aubergine,
                                              blurRadius: 0,
                                              offset: const Offset(3, 3),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              FeatherIcons.list,
                                              size: 13,
                                              color:
                                                  pinit.PinitColors.aubergine,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'See All',
                                              style: GoogleFonts.dmSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    pinit.PinitColors.aubergine,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (viewModel.isMagicSearching)
                          const _MagicSearchGeneratingCard()
                        else if (viewModel.isLoadingRecommendations &&
                            viewModel.currentListType ==
                                LocationListType.recommended)
                          const _MagicSearchGeneratingCard(
                            eyebrow: 'FILTERING',
                            title: 'Matching your filters...',
                          )
                        else
                          HomeCarousel(
                            pageController: viewModel.pageController,
                            locations: viewModel.locations,
                            selectedMarkerId: viewModel.selectedMarkerId,
                            bottomNavVisible: viewModel.bottomNavVisible,
                            onPageChanged: viewModel.onCarouselPageChanged,
                            onScrollStart: viewModel.onCarouselScrollStart,
                            onLocationSelected: viewModel.onLocationSelected,
                            onSwipeUp: viewModel.onCarouselSwipeUp,
                            onSwipeDown: viewModel.onCarouselSwipeDown,
                          ),
                      ],
                    ),
                  ),

                // ─── Overlays (unchanged) ──────────────────────
                if (viewModel.showGavelOverlay)
                  GavelOverlay(
                    selectedMinutes: viewModel.justDecideMinutes,
                    onMinutesChanged: viewModel.setJustDecideMinutes,
                    onClose: () => viewModel.toggleJustDecideOverlay(false),
                    onSubmit: viewModel.submitJustDecide,
                  ),
                // ─── Bubble mode overlay ───────────────────────
                if (viewModel.isBubbleModeActive &&
                    viewModel.activeBubble != null)
                  BubbleModeOverlay(
                    bubble: viewModel.activeBubble!,
                    onDeactivate: viewModel.deactivateBubbleMode,
                  ),

                // ─── Magic search activated toast ──────────────
                if (viewModel.showMagicSearchActivated)
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) {
                        viewModel.dismissMagicSearchActivated();
                      },
                      child: const Center(
                        child: IgnorePointer(
                          child: _MagicSearchActivatedToast(),
                        ),
                      ),
                    ),
                  ),

                // ─── Just Decide swipe mode ────────────────────
                if (viewModel.showJustDecideSwipeMode)
                  Builder(builder: (ctx) {
                    final pc = Theme.of(ctx).extension<PinitColors>()!;
                    return Positioned.fill(
                      child: Container(
                        color: pc.surfaceBg,
                        child: SafeArea(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.close,
                                          color: pc.textPrimary),
                                      onPressed: viewModel.onJustDecideComplete,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Just Decide',
                                      style: AppTypography.brand(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: pc.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: viewModel.justDecideLocations.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                pc.primaryPurple,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Finding great places…',
                                              style: AppTypography.sans(
                                                fontSize: 15,
                                                color: pc.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : SwipeCardStack(
                                        locations:
                                            viewModel.justDecideLocations,
                                        onSwipe: viewModel.onJustDecideSwipe,
                                        onComplete:
                                            viewModel.onJustDecideComplete,
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Swipe right to save, left to pass',
                                  style: AppTypography.sans(
                                    fontSize: 13,
                                    color: pc.textMuted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Top panel — Style.MD pinit surface.
//  Cream fade → transparent. Tracked uppercase corner label, oversized
//  display title in Rova, then search shell + chip row. Matches the
//  bubbles / profile / carousel aesthetic.
// ─────────────────────────────────────────────────────────────────
class _TopPanel extends StatelessWidget {
  final double topPadding;
  final HomeViewModel viewModel;

  const _TopPanel({
    required this.topPadding,
    required this.viewModel,
  });

  Future<void> _openExpandedSearchLocation(
    BuildContext context,
    LocationModel location,
  ) async {
    final needsHydration = location.locationId <= 0;

    if (!needsHydration) {
      await _showExpandedLocationDialog(context, location);
      return;
    }

    final hydrationFuture =
        SearchResultActionHandler.ensureLocationReady(location);

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) => _LocationDetailsLoadingScreen(
        placeName: location.name,
        hydration: hydrationFuture,
        onReady: (hydrated) async {
          Navigator.of(ctx).pop();
          if (hydrated == null || !context.mounted) return;
          await _showExpandedLocationDialog(context, hydrated);
        },
        onFailed: () {
          Navigator.of(ctx).pop();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('We could not load that place just yet.'),
            ),
          );
        },
      ),
      transitionBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  Future<void> _showExpandedLocationDialog(
    BuildContext context,
    LocationModel location,
  ) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, _, __) => ExpandedLocationCard(
        location: location,
        onClose: () => Navigator.of(ctx).pop(),
      ),
      transitionBuilder: (ctx, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cream fade — lets the map breathe through the bottom edge.
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.6, 1.0],
          colors: [
            pinit.PinitColors.cream,
            Color(0xF2FBF6F3), // cream @ 95%
            Color(0x00FBF6F3), // cream @ 0%
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: topPadding + 4,
          left: 24,
          right: 24,
          bottom: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Logo — purplePinit, sized like a poster element ──
            Padding(
              padding: const EdgeInsets.only(left: 1),
              child: Image.asset(
                'lib/assets/purplePinit.png',
                height: 36,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: 10),
            HomeHeaderSearchShell(
              state: viewModel.headerSearchState,
              controller: viewModel.headerSearchController,
              focusNode: viewModel.headerSearchFocusNode,
              onEntryTap: () {
                viewModel.openHeaderSearch();
              },
              onMagicSearchTap: () {
                viewModel.closeHeaderSearch();
                viewModel.toggleMagicSearch();
                if (!viewModel.isMagicSearchActive) {
                  viewModel.headerSearchFocusNode.unfocus();
                }
              },
              isMagicSearchActive: viewModel.isMagicSearchActive,
              onSearchSubmitted: viewModel.isMagicSearchActive
                  ? () {
                      final query = viewModel.headerSearchController.text;
                      viewModel.closeHeaderSearch();
                      unawaited(viewModel.submitMagicSearch(query));
                    }
                  : null,
              onDismiss: viewModel.closeHeaderSearch,
              onQueryChanged: viewModel.isMagicSearchActive
                  ? (_) {}
                  : viewModel.updateHeaderSearchQuery,
              onPlaceActionTriggered: (item) {
                unawaited(
                  viewModel.rememberHeaderSearchQuery(
                    viewModel.headerSearchState.query.isNotEmpty
                        ? viewModel.headerSearchState.query
                        : (item.queryValue ?? item.title),
                  ),
                );
              },
              onSuggestionSelected: (item) {
                unawaited(() async {
                  switch (item.kind) {
                    case SearchSuggestionKind.recentQuery:
                    case SearchSuggestionKind.personalPrompt:
                      viewModel.applyHeaderSearchSuggestionQuery(
                        item.queryValue ?? item.title,
                      );
                      break;
                    case SearchSuggestionKind.place:
                      final resolved = item.location;
                      if (resolved == null) return;
                      await viewModel.rememberHeaderSearchQuery(
                        viewModel.headerSearchState.query.isNotEmpty
                            ? viewModel.headerSearchState.query
                            : (item.queryValue ?? item.title),
                      );
                      viewModel.closeHeaderSearch();
                      if (!context.mounted) return;
                      await _openExpandedSearchLocation(context, resolved);
                      break;
                  }
                }());
              },
              onPreviewStart: (location) {
                unawaited(viewModel.selectHeaderSearchLocation(location));
              },
              onPreviewEnd: () {},
              footer: HomeChipRow(
                currentMode: viewModel.homeMode,
                onModeChanged: viewModel.setHomeMode,
                activeBubbleName: viewModel.activeBubbleName,
                collections: viewModel.collections,
                isLoadingCollections: viewModel.isLoadingCollections,
                activeCollectionId: viewModel.activeCollectionId,
                onCollectionMenuOpened: () {
                  unawaited(viewModel.loadCollections());
                },
                onCollectionSelected: (collection) {
                  unawaited(() async {
                    final shown = await viewModel.showCollectionOnMap(
                      collection,
                    );
                    if (!context.mounted || shown) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'No places found in ${collection.name}',
                        ),
                        backgroundColor: pinit.PinitColors.aubergine,
                      ),
                    );
                  }());
                },
                onDecideTap: () {
                  DecideBottomSheet.show(
                    context,
                    onQuickPicks: () {
                      QuickPicksDistancePage.show(
                        context,
                        viewModel: viewModel,
                      );
                    },
                    onSweetTreat: () {
                      unawaited(viewModel.submitDefaultSweetTreatSearch());
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MagicSearchGeneratingCard extends StatefulWidget {
  const _MagicSearchGeneratingCard({
    this.eyebrow = 'MAGIC SEARCH',
    this.title = 'Finding your spots...',
  });

  final String eyebrow;
  final String title;

  @override
  State<_MagicSearchGeneratingCard> createState() =>
      _MagicSearchGeneratingCardState();
}

class _MagicSearchGeneratingCardState extends State<_MagicSearchGeneratingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Center(
        child: AnimatedBuilder(
          animation: _shimmer,
          builder: (context, child) {
            final pulse = (0.5 +
                0.5 *
                    Curves.easeInOut.transform(
                      (_shimmer.value * 2.0 % 1.0),
                    ));
            return Opacity(
              opacity: 0.6 + 0.4 * pulse,
              child: child,
            );
          },
          child: Container(
            width: MediaQuery.of(context).size.width * 0.78,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: pinit.PinitColors.accent,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: pinit.PinitColors.aubergine,
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: pinit.PinitColors.aubergine,
                  blurRadius: 0,
                  offset: Offset(4, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: pinit.PinitColors.cream.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: pinit.PinitColors.cream.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    FeatherIcons.zap,
                    color: pinit.PinitColors.cream,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.eyebrow,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color:
                              pinit.PinitColors.cream.withValues(alpha: 0.78),
                          letterSpacing: 1.6,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.title,
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: pinit.PinitColors.cream,
                          height: 1.2,
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
    );
  }
}

class _MagicSearchActivatedToast extends StatefulWidget {
  const _MagicSearchActivatedToast();

  @override
  State<_MagicSearchActivatedToast> createState() =>
      _MagicSearchActivatedToastState();
}

class _MagicSearchActivatedToastState extends State<_MagicSearchActivatedToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entrance = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final safeEntrance = entrance.value.clamp(0.0, 1.0);
        final glow = Curves.easeOut.transform(
          (_controller.value * 1.2).clamp(0.0, 1.0),
        );
        final shimmer = Curves.easeInOut.transform(
          (_controller.value * 1.35).clamp(0.0, 1.0),
        );

        return Transform.translate(
          offset: Offset(0, (1 - safeEntrance) * -20),
          child: Transform.scale(
            scale: 0.92 + (safeEntrance * 0.08),
            child: Opacity(
              opacity: safeEntrance,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 268 + (glow * 18),
                    height: 122 + (glow * 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          pinit.PinitColors.accent.withValues(
                            alpha: 0.26 - (glow * 0.08),
                          ),
                          pinit.PinitColors.accent.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    decoration: BoxDecoration(
                      color: pinit.PinitColors.accent,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: pinit.PinitColors.aubergine,
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: pinit.PinitColors.aubergine,
                          blurRadius: 0,
                          offset: Offset(4, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 4,
                          right: 2,
                          child: Opacity(
                            opacity: 0.18 + (shimmer * 0.16),
                            child: Container(
                              width: 84,
                              height: 84,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: pinit.PinitColors.cream,
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: pinit.PinitColors.cream
                                    .withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: pinit.PinitColors.cream
                                      .withValues(alpha: 0.3),
                                  width: 1.2,
                                ),
                              ),
                              child: const Icon(
                                FeatherIcons.zap,
                                color: pinit.PinitColors.cream,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MAGIC SEARCH',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: pinit.PinitColors.cream
                                          .withValues(alpha: 0.78),
                                      letterSpacing: 1.6,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Activated',
                                    style: AppTypography.brand(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w100,
                                      color: pinit.PinitColors.cream,
                                      letterSpacing: 0.3,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Welcome to magic search, Search a vibe, a really specific dish or anything you are really craving and we will find it for you.',
                                    style: AppTypography.sans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: pinit.PinitColors.cream
                                          .withValues(alpha: 0.9),
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LocationDetailsLoadingScreen extends StatefulWidget {
  const _LocationDetailsLoadingScreen({
    required this.placeName,
    required this.hydration,
    required this.onReady,
    required this.onFailed,
  });

  final String placeName;
  final Future<LocationModel?> hydration;
  final ValueChanged<LocationModel?> onReady;
  final VoidCallback onFailed;

  @override
  State<_LocationDetailsLoadingScreen> createState() =>
      _LocationDetailsLoadingScreenState();
}

class _LocationDetailsLoadingScreenState
    extends State<_LocationDetailsLoadingScreen>
    with TickerProviderStateMixin {
  static const List<String> _quips = [
    'Peeking through the window…',
    'Sniffing the kitchen…',
    'Tasting the vibe…',
    'Counting the candles…',
    'Charming the host…',
  ];

  late final AnimationController _spinController;
  late final AnimationController _bounceController;
  Timer? _quipTimer;
  int _quipIndex = 0;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _quipTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted) return;
      setState(() => _quipIndex = (_quipIndex + 1) % _quips.length);
    });

    widget.hydration.then((hydrated) {
      if (!mounted) return;
      if (hydrated == null || hydrated.locationId <= 0) {
        widget.onFailed();
      } else {
        widget.onReady(hydrated);
      }
    }).catchError((_) {
      if (!mounted) return;
      widget.onFailed();
    });
  }

  @override
  void dispose() {
    _quipTimer?.cancel();
    _spinController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 36),
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          decoration: BoxDecoration(
            color: pinit.PinitColors.cream,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: pinit.PinitColors.aubergine,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: pinit.PinitColors.aubergine,
                offset: Offset(6, 6),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 88,
                width: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RotationTransition(
                      turns: _spinController,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: pinit.PinitColors.aubergine,
                            width: 3,
                          ),
                          gradient: SweepGradient(
                            colors: [
                              pinit.PinitColors.cream,
                              pinit.PinitColors.accent,
                              pinit.PinitColors.aubergine,
                              pinit.PinitColors.cream,
                            ],
                          ),
                        ),
                      ),
                    ),
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.92, end: 1.08)
                          .animate(CurvedAnimation(
                        parent: _bounceController,
                        curve: Curves.easeInOut,
                      )),
                      child: Container(
                        height: 54,
                        width: 54,
                        decoration: BoxDecoration(
                          color: pinit.PinitColors.cream,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: pinit.PinitColors.aubergine,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          FeatherIcons.mapPin,
                          size: 26,
                          color: pinit.PinitColors.aubergine,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                widget.placeName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.sans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: pinit.PinitColors.aubergine,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                child: Text(
                  _quips[_quipIndex],
                  key: ValueKey<int>(_quipIndex),
                  textAlign: TextAlign.center,
                  style: AppTypography.sans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: pinit.PinitColors.mute,
                    height: 1.35,
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

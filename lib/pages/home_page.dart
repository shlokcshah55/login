import 'dart:async';

import 'package:flutter/material.dart';
import 'package:login/pages/home/home_view_model.dart';
import 'package:login/pages/home/search/header_search_types.dart';
import 'package:login/pages/home/widgets/home_carousel.dart';
import 'package:login/pages/home/widgets/home_header_search_shell.dart';
import 'package:login/pages/home/widgets/home_map_layer.dart';
import 'package:login/pages/home/widgets/magic_search_overlay.dart';
import 'package:login/pages/home/widgets/gavel_overlay.dart';
import 'package:login/pages/home/widgets/sweet_treat_overlay.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/themes/app_typography.dart';
import 'package:login/themes/pinit_colors.dart';
import 'package:login/pages/home/widgets/mode_toggle.dart';
import 'package:login/pages/home/widgets/decide_bottom_sheet.dart';
import 'package:login/pages/home/widgets/shortlist_pill.dart';
import 'package:login/pages/home/widgets/shortlist_carousel_sheet.dart';
import 'package:login/pages/home/widgets/my_location_button.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/nav_bar/visibility_provider.dart';
import 'package:login/providers/shortlist_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/providers/bubble_mode_provider.dart';
import 'package:login/providers/navigation_provider.dart';
import 'package:login/pages/profile/other_user_profile_page.dart';
import 'package:login/supabase/service.dart';
import 'package:login/widgets/home/bubble_mode_overlay.dart';
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
  bool _wizardPopoverScheduled = false;
  bool _wizardPopoverShown = false;

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
    if (_locationListManager.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_locationListManager.error!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
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

                // ─── Layer 4a: Location FAB ────────────────────
                //     Only visible floating button on the map
                if (!viewModel.isHeaderSearchActive)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutQuint,
                    bottom: carouselBottom + 225,
                    left: 16,
                    child: MyLocationButton(
                      onTap: () => _viewModel.locateUser(),
                    ),
                  ),

                // ─── Layer 4b: Shortlist pill (conditional) ────
                if (viewModel.shortlistIsNotEmpty &&
                    !viewModel.isHeaderSearchActive)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutQuint,
                    bottom: carouselBottom + 225,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ShortlistPill(
                        count: viewModel.shortlistCount,
                        onTap: () => ShortlistCarouselSheet.show(
                          context,
                          currentMode: viewModel.homeMode,
                          onReturnToMode: viewModel.setHomeMode,
                        ),
                      ),
                    ),
                  ),

                // ─── Layer 5: Carousel (untouched) ─────────────
                if (!viewModel.isHeaderSearchActive)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutQuint,
                    bottom: carouselBottom,
                    left: 0,
                    right: 0,
                    child: HomeCarousel(
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
                  ),

                // ─── Overlays (unchanged) ──────────────────────
                if (viewModel.showSearchOverlay)
                  MagicSearchOverlay(
                    controller: viewModel.magicSearchController,
                    onClose: () => viewModel.toggleSearchOverlay(false),
                    onSubmit: viewModel.submitMagicSearch,
                  ),
                if (viewModel.showGavelOverlay)
                  GavelOverlay(
                    selectedMinutes: viewModel.justDecideMinutes,
                    onMinutesChanged: viewModel.setJustDecideMinutes,
                    onClose: () => viewModel.toggleJustDecideOverlay(false),
                    onSubmit: viewModel.submitJustDecide,
                  ),
                if (viewModel.showSweetTreatOverlay)
                  SweetTreatOverlay(
                    onClose: () => viewModel.toggleSweetTreatOverlay(false),
                    onSubmit: viewModel.submitSweetTreatSearch,
                  ),

                // ─── Bubble mode overlay ───────────────────────
                if (viewModel.isBubbleModeActive &&
                    viewModel.activeBubble != null)
                  BubbleModeOverlay(
                    bubble: viewModel.activeBubble!,
                    onDeactivate: viewModel.deactivateBubbleMode,
                  ),

                // ─── Loading state ─────────────────────────────
                // IgnorePointer so the dim/spinner doesn't block map gestures.
                if (viewModel.isLoadingRecommendations &&
                    viewModel.currentListType == LocationListType.recommended)
                  Builder(builder: (ctx) {
                    final pc = Theme.of(ctx).extension<PinitColors>()!;
                    return Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.25),
                          child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(24.0),
                            decoration: BoxDecoration(
                              color: pc.elevatedSurface,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.10),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    pc.primaryPurple,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading recommendations…',
                                  style: AppTypography.sans(
                                    fontSize: 15,
                                    color: pc.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ),
                      ),
                    );
                  }),

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
                viewModel.toggleSearchOverlay(true);
              },
              onDismiss: viewModel.closeHeaderSearch,
              onQueryChanged: viewModel.updateHeaderSearchQuery,
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
                    case SearchSuggestionKind.naturalLanguage:
                      var resolved = item.location;
                      if (resolved == null && item.mapboxId != null) {
                        resolved =
                            await viewModel.resolveMapboxHeaderSelection(item);
                      }
                      if (resolved == null) return;
                      await viewModel.selectHeaderSearchLocation(
                        resolved,
                        query: viewModel.headerSearchState.query.isNotEmpty
                            ? viewModel.headerSearchState.query
                            : item.queryValue,
                      );
                      break;
                    case SearchSuggestionKind.person:
                      if (item.user == null) return;
                      await viewModel.rememberHeaderSearchQuery(
                        viewModel.headerSearchState.query.isNotEmpty
                            ? viewModel.headerSearchState.query
                            : (item.queryValue ?? item.title),
                      );
                      viewModel.closeHeaderSearch();
                      if (!context.mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              OtherUserProfilePage(user: item.user!),
                        ),
                      );
                      break;
                  }
                }());
              },
              onPreviewStart: (location) {
                viewModel.startHeaderSearchPreview(location);
              },
              onPreviewEnd: () {
                viewModel.endHeaderSearchPreview();
              },
              footer: HomeChipRow(
                currentMode: viewModel.homeMode,
                onModeChanged: viewModel.setHomeMode,
                onDecideTap: () {
                  DecideBottomSheet.show(
                    context,
                    onQuickPicks: () => viewModel.toggleJustDecideOverlay(true),
                    onSweetTreat: () => viewModel.toggleSweetTreatOverlay(true),
                    onSurpriseMe: viewModel.submitSurpriseMe,
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

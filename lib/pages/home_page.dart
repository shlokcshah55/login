import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/home/home_view_model.dart';
import 'package:login/pages/home/widgets/home_carousel.dart';
import 'package:login/pages/home/widgets/home_header.dart';
import 'package:login/pages/home/widgets/home_map_layer.dart';
import 'package:login/pages/home/widgets/magic_search_overlay.dart';
import 'package:login/pages/home/widgets/gavel_overlay.dart';
import 'package:login/pages/home/widgets/sweet_treat_overlay.dart';
import 'package:login/pages/home/widgets/quick_actions_bar.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/nav_bar/visibility_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/providers/bubble_mode_provider.dart';
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
  late final BubbleModeProvider _bubbleModeProvider;
  bool _wizardPopoverScheduled = false;
  bool _wizardPopoverShown = false;

  @override
  void initState() {
    super.initState();
    _locationListManager = context.read<LocationListManager>();
    _mapStateProvider = context.read<MapStateProvider>();
    _bottomNavVisibilityProvider = context.read<BottomNavVisibilityProvider>();
    _bubbleModeProvider = context.read<BubbleModeProvider>();
    _viewModel = HomeViewModel(
      locationListManager: _locationListManager,
      mapStateProvider: _mapStateProvider,
      bottomNavVisibilityProvider: _bottomNavVisibilityProvider,
    );
    _viewModel.init();

    _locationListManager.addListener(_checkForErrors);
    _bubbleModeProvider.addListener(_handleBubbleModeRequest);
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      print('HomePage became active, checking for pending activation');
      _handleBubbleModeRequest();
    }
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
    print(
        'HomePage listener fired! hasPending: ${_bubbleModeProvider.hasPendingActivation}, isActive: ${widget.isActive}');
    if (_bubbleModeProvider.hasPendingActivation && widget.isActive) {
      final bubble = _bubbleModeProvider.pendingBubble!;
      print('Processing bubble activation for: ${bubble.name}');
      _bubbleModeProvider.clearPendingBubble();

      await _viewModel.activateBubbleMode(bubble);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bubble mode activated for ${bubble.name}'),
            backgroundColor: Colors.purple,
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
    if (userData == null || userData.wizardCompleted) {
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<HomeViewModel>(
        builder: (context, viewModel, _) {
          final userDataProvider = context.watch<UserDataProvider>();
          _scheduleWizardPopoverIfNeeded(userDataProvider);
          final carouselBottom = viewModel.bottomNavVisible ? 90.0 : 20.0;

          Widget mainContent = Scaffold(
            body: Stack(
              children: [
                // ── Map ──
                Positioned.fill(
                  child: HomeMapLayer(
                    onMapTap: viewModel.onMapTap,
                    onSearchThisArea: viewModel.searchThisArea,
                  ),
                ),

                // ── Header (Saved / Recommended / Near Me tabs) ──
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: HomeHeader(
                    currentListType: viewModel.currentListType,
                    onListTypeChanged: viewModel.setListType,
                    isBubbleModeActive: viewModel.isBubbleModeActive,
                  ),
                ),

                // ── Quick Actions Bar (below header, right-aligned) ──
                // The HomeHeader typically occupies ~100-110pt including
                // the safe area. Adjust `top` if your header height differs.
                Positioned(
                  top: MediaQuery.of(context).padding.top + 90,
                  right: 12,
                  child: QuickActionsBar(
                    onMagicSearch: () => viewModel.toggleSearchOverlay(true),
                    onJustDecide: () =>
                        viewModel.toggleJustDecideOverlay(true),
                    onSweetTreat: () =>
                        viewModel.toggleSweetTreatOverlay(true),
                  ),
                ),

                // ── Carousel ──
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
                  ),
                ),

                // ── Overlays ──
                if (viewModel.showSearchOverlay)
                  MagicSearchOverlay(
                    controller: viewModel.searchController,
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

                // ── Bubble mode overlay ──
                if (viewModel.isBubbleModeActive &&
                    viewModel.activeBubble != null)
                  BubbleModeOverlay(
                    bubble: viewModel.activeBubble!,
                    onDeactivate: viewModel.deactivateBubbleMode,
                  ),

                // ── Loading indicator for recommendations ──
                if (viewModel.isLoadingRecommendations &&
                    viewModel.currentListType == LocationListType.recommended)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 77),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(24.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color.fromARGB(255, 68, 95, 12),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading recommendations...',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Just Decide swipe mode ──
                if (viewModel.showJustDecideSwipeMode)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white,
                      child: SafeArea(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: viewModel.onJustDecideComplete,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Just Decide',
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
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
                                          const CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Color.fromARGB(255, 68, 95, 12),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Finding great places...',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : SwipeCardStack(
                                      locations: viewModel.justDecideLocations,
                                      onSwipe: viewModel.onJustDecideSwipe,
                                      onComplete:
                                          viewModel.onJustDecideComplete,
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'Swipe right to save, left to pass',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );

          return mainContent;
        },
      ),
    );
  }
}
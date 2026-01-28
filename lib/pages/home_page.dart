import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/home/home_view_model.dart';
import 'package:login/pages/home/widgets/home_carousel.dart';
import 'package:login/pages/home/widgets/home_header.dart';
import 'package:login/pages/home/widgets/home_map_layer.dart';
import 'package:login/pages/home/widgets/magic_search_button.dart';
import 'package:login/pages/home/widgets/magic_search_overlay.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/nav_bar/visibility_provider.dart';
import 'package:login/providers/user_data_provider.dart';
import 'package:login/providers/bubble_mode_provider.dart';
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

    // Listen to location list manager errors and show snackbar
    _locationListManager.addListener(_checkForErrors);

    // Listen for bubble mode activation requests
    _bubbleModeProvider.addListener(_handleBubbleModeRequest);
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check for pending activation when page becomes active
    if (!oldWidget.isActive && widget.isActive) {
      print('HomePage became active, checking for pending activation');
      _handleBubbleModeRequest();
    }
  }

  void _checkForErrors() {
    if (_locationListManager.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_locationListManager.error!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _handleBubbleModeRequest() {
    print('HomePage listener fired! hasPending: ${_bubbleModeProvider.hasPendingActivation}, isActive: ${widget.isActive}');
    if (_bubbleModeProvider.hasPendingActivation && widget.isActive) {
      final bubble = _bubbleModeProvider.pendingBubble!;
      print('Processing bubble activation for: ${bubble.name}');
      _bubbleModeProvider.clearPendingBubble();

      _viewModel.activateBubbleMode(bubble);

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
    _mapStateProvider.controllerFuture.then((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showWizardPopoverIfNeeded();
      });
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

          return Container(
            decoration: viewModel.isBubbleModeActive
                ? BoxDecoration(
                    border: Border.all(
                      color: Colors.purple,
                      width: 4.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  )
                : null,
            child: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: HomeMapLayer(
                      onMapTap: viewModel.onMapTap,
                      onSearchThisArea: viewModel.searchThisArea,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: HomeHeader(
                      currentListType: viewModel.currentListType,
                      onListTypeChanged: viewModel.setListType,
                    ),
                  ),
                  if (viewModel.isBubbleModeActive && viewModel.activeBubble != null)
                    Positioned(
                      top: 60,
                      left: 0,
                      right: 0,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.purple, width: 1),
                        ),
                        child: Text(
                          '${viewModel.activeBubble!.name} activated...',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutQuint,
                    bottom: viewModel.bottomNavVisible ? 90.0 : 20.0,
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
                  Positioned(
                    top: 80,
                    right: 20,
                    child: MagicSearchButton(
                      onPressed: () => viewModel.toggleSearchOverlay(true),
                    ),
                  ),
                  if (viewModel.showSearchOverlay)
                    MagicSearchOverlay(
                      controller: viewModel.searchController,
                      onClose: () => viewModel.toggleSearchOverlay(false),
                      onSubmit: viewModel.submitMagicSearch,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

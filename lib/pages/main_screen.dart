import 'package:flutter/material.dart';
import 'package:login/services/fcm_service.dart';
import 'package:login/pages/bubbles_page.dart';
import 'package:login/pages/home_page.dart';
import 'package:login/pages/profile/profile_page.dart';
import 'package:login/widgets/navigation/bottom_nav_bar.dart';
import 'package:login/providers/navigation_provider.dart';
import 'package:login/providers/nav_bar/visibility_provider.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  NavigationProvider? _navigationProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationProvider = context.read<NavigationProvider>();
      _navigationProvider!.addListener(_handleNavigationRequest);
      context.read<BottomNavVisibilityProvider>().showTemporarily();
      FCMService().consumePendingInitialMessage();
    });
  }

  @override
  void dispose() {
    _navigationProvider?.removeListener(_handleNavigationRequest);
    super.dispose();
  }

  void _handleNavigationRequest() {
    print('MainScreen listener fired!');
    if (_navigationProvider == null) return;
    if (_navigationProvider!.hasPendingNavigation) {
      final targetIndex = _navigationProvider!.pendingTabIndex;
      print('Navigating to tab: $targetIndex from current: $_currentIndex');
      _navigationProvider!.clearPendingNavigation();

      if (targetIndex != _currentIndex) {
        setState(() {
          _currentIndex = targetIndex;
        });
        print('Tab switched to: $_currentIndex');
      }
    }
  }

  void _onIndexChanged(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(isActive: _currentIndex == 0),
      const BubblesPage(),
      ProfilePage(isActive: _currentIndex == 2),
    ];

    return Scaffold(
      extendBody: true,
      // Use a passive Listener (raw pointer events, never enters the gesture
      // arena) to wake the bottom nav. A GestureDetector with onPanDown here
      // would claim pan gestures and prevent the Mapbox MapWidget from
      // panning/dragging.
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) =>
            context.read<BottomNavVisibilityProvider>().showTemporarily(),
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onIndexChanged: _onIndexChanged,
      ),
    );
  }
}

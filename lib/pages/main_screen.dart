import 'package:flutter/material.dart';
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
      const ProfilePage(),
    ];

    return Scaffold(
      extendBody: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => context.read<BottomNavVisibilityProvider>().showTemporarily(),
        onPanDown: (_) => context.read<BottomNavVisibilityProvider>().showTemporarily(),
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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:login/providers/nav_bar/visibility_provider.dart';
import 'package:login/providers/nav_bar/dynamic_nav_provider.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:provider/provider.dart';

class BottomNavBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onIndexChanged;

  const BottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onIndexChanged,
  }) : super(key: key);

  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure animations are initialized if widget rebuilds before initState
    if (!_animationController.isAnimating) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Consumer2<BottomNavVisibilityProvider, DynamicNavProvider>(
      builder: (context, bottomNavProvider, dynamicNavProvider, child) {
        // Update animation based on visibility state
        if (bottomNavProvider.isVisible) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }

        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                height: 60,
                margin:
                    const EdgeInsets.only(left: 32, right: 32, bottom: 35, top: 0),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: bottomNavProvider.isVisible ? 20 : 8,
                      spreadRadius: 0,
                      offset: Offset(0, bottomNavProvider.isVisible ? 6 : 2),
                    ),
                  ],
                ),
                child: dynamicNavProvider.navState == NavState.standard
                    ? _buildStandardNav(theme)
                    : _buildDynamicNav(dynamicNavProvider, theme),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStandardNav(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildNavItem(FeatherIcons.home, 0, 'Home', theme),
        _buildNavItem(FeatherIcons.compass, 1, 'Explore', theme),
        _buildNavItem(FontAwesomeIcons.comments, 2, 'Bubbles', theme),
        _buildNavItem(FeatherIcons.user, 3, 'Profile', theme),
      ],
    );
  }

  Widget _buildDynamicNav(DynamicNavProvider dynamicNavProvider, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.apps),
          color: theme.primaryColor,
          onPressed: () {
            dynamicNavProvider.showStandardNav();
          },
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            elevation: 2,
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => ExpandedLocationCard(
                location: dynamicNavProvider.selectedLocation!,
                onClose: () => Navigator.of(context).pop(),
              ),
            );
          },
          child: const Text('Explore'),
        ),
      ],
    );
  }

  Widget _buildNavItem(IconData icon, int index, String label, ThemeData theme,
      {bool hasBadge = false}) {
    final isSelected = widget.currentIndex == index;
    final color = isSelected ? theme.primaryColor : theme.unselectedWidgetColor;

    final navItem = InkWell(
      onTap: () {
        context.read<BottomNavVisibilityProvider>().show();
        context.read<DynamicNavProvider>().showStandardNav();
        widget.onIndexChanged(index);
      },
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                if (hasBadge)
                  Positioned(
                    right: -4,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.cardColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: color,
                ),
                child: Text(label),
              ),
            ],
          ],
        ),
      ),
    );

    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return Tooltip(message: label, child: navItem);
    }

    return Semantics(label: label, child: navItem);
  }
}

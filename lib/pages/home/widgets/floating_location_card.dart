import 'package:flutter/material.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/widgets/home/LocationCarousel/location_carousel.dart';

/// A single, non-swipeable location card shown floating above the category
/// tiles on the home landing (Tier 1) stage when a map pin is tapped. Reuses
/// the shared [CarouselCard] visual so it matches the focused-stage carousel.
class FloatingLocationCard extends StatefulWidget {
  final LocationModel location;
  final Set<int> beenToLocationIds;
  final bool bottomNavVisible;
  final ValueChanged<LocationModel> onLocationSelected;
  final VoidCallback onDismiss;

  const FloatingLocationCard({
    super.key,
    required this.location,
    required this.onLocationSelected,
    required this.onDismiss,
    this.beenToLocationIds = const <int>{},
    this.bottomNavVisible = true,
  });

  @override
  State<FloatingLocationCard> createState() => _FloatingLocationCardState();
}

class _FloatingLocationCardState extends State<FloatingLocationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant FloatingLocationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Replay the entrance when switching between pins so the swap feels intentional.
    if (oldWidget.location.locationId != widget.location.locationId) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.bottomNavVisible ? 185.0 : 215.0;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CarouselCard(
                  location: widget.location,
                  sectionTitle: null,
                  isSelected: true,
                  bottomNavVisible: widget.bottomNavVisible,
                  beenToLocationIds: widget.beenToLocationIds,
                  onLocationSelected: widget.onLocationSelected,
                ),
                Positioned(
                  top: -8,
                  right: -4,
                  child: GestureDetector(
                    onTap: widget.onDismiss,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: PinitColors.cream,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: PinitColors.aubergine,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: PinitColors.aubergine,
                            blurRadius: 0,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: PinitColors.aubergine,
                      ),
                    ),
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

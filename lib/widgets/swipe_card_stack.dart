import 'package:flutter/material.dart';
import '../models/locations.dart';

/// A Tinder-style swipeable card stack for locations
class SwipeCardStack extends StatefulWidget {
  final List<LocationModel> locations;
  final Function(LocationModel location, bool liked) onSwipe;
  final VoidCallback? onComplete;

  const SwipeCardStack({
    super.key,
    required this.locations,
    required this.onSwipe,
    this.onComplete,
  });

  @override
  State<SwipeCardStack> createState() => SwipeCardStackState();
}

class SwipeCardStackState extends State<SwipeCardStack>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.3;

    if (_dragOffset.dx.abs() > threshold) {
      // Swipe decision made
      final liked = _dragOffset.dx > 0;
      _animateSwipe(liked);
    } else {
      // Return to center
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    }
  }

  void _animateSwipe(bool liked) {
    final screenWidth = MediaQuery.of(context).size.width;
    final endOffset = Offset(
      liked ? screenWidth * 1.5 : -screenWidth * 1.5,
      _dragOffset.dy,
    );

    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: endOffset,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward(from: 0).then((_) {
      if (mounted) {
        // Notify about the swipe
        widget.onSwipe(widget.locations[_currentIndex], liked);

        // Move to next card
        setState(() {
          _currentIndex++;
          _dragOffset = Offset.zero;
          _isDragging = false;
          _animationController.reset();
        });

        // Check if we've swiped all cards
        if (_currentIndex >= widget.locations.length) {
          widget.onComplete?.call();
        }
      }
    });
  }

  void swipeLeft() {
    if (_currentIndex < widget.locations.length) {
      setState(() {
        _dragOffset = Offset(-100, 0);
        _isDragging = true;
      });
      _animateSwipe(false);
    }
  }

  void swipeRight() {
    if (_currentIndex < widget.locations.length) {
      setState(() {
        _dragOffset = Offset(100, 0);
        _isDragging = true;
      });
      _animateSwipe(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.locations.length) {
      // All cards swiped
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Color(0xFF6A1B9A),
            ),
            SizedBox(height: 16),
            Text(
              'All done!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Thanks for your preferences',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Next card preview (if available)
        if (_currentIndex + 1 < widget.locations.length)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            bottom: 20,
            child: Transform.scale(
              scale: 0.9,
              child: Opacity(
                opacity: 0.5,
                child: _buildCard(widget.locations[_currentIndex + 1]),
              ),
            ),
          ),

        // Current card
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final offset =
                _animationController.isAnimating ? _slideAnimation.value : _dragOffset;
            final rotation = offset.dx / 1000;

            return Transform.translate(
              offset: offset,
              child: Transform.rotate(
                angle: rotation,
                child: Stack(
                  children: [
                    child!,
                    // Swipe indicators
                    if (_isDragging || _animationController.isAnimating) ...[
                      // Like indicator (right swipe)
                      if (offset.dx > 0)
                        Positioned.fill(
                          child: Container(
                            margin: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.green,
                                width: 4,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'LIKE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Pass indicator (left swipe)
                      if (offset.dx < 0)
                        Positioned.fill(
                          child: Container(
                            margin: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.red,
                                width: 4,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'PASS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
          child: GestureDetector(
            onPanStart: _onDragStart,
            onPanUpdate: _onDragUpdate,
            onPanEnd: _onDragEnd,
            child: _buildCard(widget.locations[_currentIndex]),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(LocationModel location) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
                child: location.photoReference != null
                    ? Image.network(
                        'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=${location.photoReference}&key=YOUR_API_KEY',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade300,
                            child: const Icon(
                              Icons.restaurant,
                              size: 80,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey.shade300,
                        child: const Icon(
                          Icons.restaurant,
                          size: 80,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),

            // Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (location.cuisine != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6A1B9A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          location.cuisine!,
                          style: const TextStyle(
                            color: Color(0xFF6A1B9A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (location.rating != null) ...[
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            location.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        if (location.priceLevel != null)
                          Text(
                            '\$' * location.priceLevel!,
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      location.vicinity!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

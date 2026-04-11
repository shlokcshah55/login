import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/supabase/supabase_client.dart';

class BeenToSwipeRanker extends StatefulWidget {
  final LocationModel newLocation;
  final List<Map<String, dynamic>> existingReviews;
  final Future<void> Function(double rating, String? notes, bool gatekeep)
      onSubmitted;

  const BeenToSwipeRanker({
    Key? key,
    required this.newLocation,
    required this.existingReviews,
    required this.onSubmitted,
  }) : super(key: key);

  @override
  State<BeenToSwipeRanker> createState() => _BeenToSwipeRankerState();
}

class _BeenToSwipeRankerState extends State<BeenToSwipeRanker>
    with SingleTickerProviderStateMixin {
  late List<Map<String, dynamic>> _comparisonReviews;
  late AnimationController _swipeAnimController;
  late Animation<Offset> _slideAnimation;

  int _currentComparisonIndex = 0;
  List<bool> _swipeResults = []; // true = right (better), false = left (worse)

  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  bool _rankingComplete = false;
  double? _derivedRating;

  // Form state for simplified form after ranking
  final TextEditingController _notesController = TextEditingController();
  bool _gatekeep = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    // Use up to 5 existing reviews for comparison (already sorted by rating DESC from RPC)
    _comparisonReviews = widget.existingReviews.take(5).toList();

    // Animation controller for swipe
    _swipeAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _swipeAnimController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _swipeAnimController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double _deriveRating() {
    // Calculate rating based on comparisons
    // Count how many were marked as better than the new location
    final betterCount = _swipeResults.where((r) => r).length;
    final totalCount = _swipeResults.length;

    if (totalCount == 0) return 5.0;

    // Get ratings of comparison items
    final ratings = _comparisonReviews
        .map((r) => (r['rating'] as num?)?.toDouble() ?? 5.0)
        .toList();

    // Find where the new location fits
    double derivedRating = 5.0;
    if (betterCount == 0) {
      // Worse than all comparisons
      derivedRating = (ratings.isNotEmpty ? ratings.last : 1.0) - 0.5;
    } else if (betterCount == totalCount) {
      // Better than all comparisons
      derivedRating = (ratings.isNotEmpty ? ratings.first : 10.0) + 0.5;
    } else {
      // Find insertion point and average surrounding ratings
      for (int i = 0; i < _swipeResults.length; i++) {
        if (!_swipeResults[i]) {
          // This one is worse, so new location is better than this
          derivedRating = ratings[i];
          break;
        }
      }
    }

    return (derivedRating * 10).round() / 10.0;
  }

  void _onDragStart(DragStartDetails details) {
    setState(() => _isDragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _dragOffset += details.delta);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isDragging) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.3;

    if (_dragOffset.dx.abs() > threshold) {
      final isBetter = _dragOffset.dx < 0; // left = comparison is worse = new location is better
      _animateAndAdvance(isBetter);
    } else {
      // Return to center
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    }
  }

  void _animateAndAdvance(bool isBetter) {
    final screenWidth = MediaQuery.of(context).size.width;
    final endOffset = Offset(
      _dragOffset.dx > 0 ? screenWidth * 1.5 : -screenWidth * 1.5,
      _dragOffset.dy,
    );

    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: endOffset,
    ).animate(
      CurvedAnimation(
        parent: _swipeAnimController,
        curve: Curves.easeOut,
      ),
    );

    _swipeAnimController.forward(from: 0).then((_) {
      if (!mounted) return;

      // Record this swipe result
      _swipeResults.add(isBetter);
      _currentComparisonIndex++;

      // Check if we've compared against all cards or reached 5 comparisons
      if (_currentComparisonIndex >= _comparisonReviews.length ||
          _currentComparisonIndex >= 5) {
        _derivedRating = _deriveRating();
        setState(() => _rankingComplete = true);
      } else {
        // Move to next comparison
        setState(() {
          _dragOffset = Offset.zero;
          _isDragging = false;
          _swipeAnimController.reset();
        });
      }
    });
  }

  Future<void> _submitForm() async {
    setState(() => _submitting = true);
    try {
      await widget.onSubmitted(
        _derivedRating!,
        _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        _gatekeep,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to log visit')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PinitColors.cream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _rankingComplete ? _buildSimplifiedForm() : _buildRankerView(),
    );
  }

  Widget _buildRankerView() {
    if (_currentComparisonIndex >= _comparisonReviews.length) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final comparison = _comparisonReviews[_currentComparisonIndex];
    final comparisonName = comparison['location_name'] as String? ?? 'A place';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 0),
          child: Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: PinitColors.creamDeep,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Round counter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Comparison ${_currentComparisonIndex + 1}/${_comparisonReviews.length}',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: PinitColors.aubergineSoft,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Question
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'vs ${widget.newLocation.name}',
            style: const TextStyle(
              fontFamily: 'Rova',
              fontSize: 28,
              fontWeight: FontWeight.w100,
              color: PinitColors.aubergine,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Card stack with swipe gesture (constrained height)
        SizedBox(
          height: 400,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background new location card (static reference)
              Transform.scale(
                scale: 0.85,
                child: Opacity(
                  opacity: 0.4,
                  child: _buildNewLocationCard(),
                ),
              ),

              // Next comparison card preview (peeking from behind)
              if (_currentComparisonIndex + 1 < _comparisonReviews.length)
                Transform.scale(
                  scale: 0.90,
                  child: Opacity(
                    opacity: 0.6,
                    child: _buildComparisonCard(
                      _comparisonReviews[_currentComparisonIndex + 1],
                    ),
                  ),
                ),

              // Swipeable comparison card
              GestureDetector(
                onPanStart: _onDragStart,
                onPanUpdate: _onDragUpdate,
                onPanEnd: _onDragEnd,
                child: AnimatedBuilder(
                  animation: _swipeAnimController,
                  builder: (context, child) {
                    final offset = _swipeAnimController.isAnimating
                        ? _slideAnimation.value
                        : _dragOffset;
                    final rotation = offset.dx / 1000;

                    return Transform.translate(
                      offset: offset,
                      child: Transform.rotate(
                        angle: rotation,
                        child: Stack(
                          children: [
                            child!,
                            // Swipe indicators
                            if (_isDragging ||
                                _swipeAnimController.isAnimating) ...[
                              // Better indicator (right swipe)
                              if (offset.dx > 0)
                                Positioned.fill(
                                  child: Container(
                                    // Match the card's horizontal margin and border radius
                                    margin: const EdgeInsets.symmetric(horizontal: 20),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.green,
                                        width: 3,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'BETTER',
                                            style: GoogleFonts.dmSans(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // Worse indicator (left swipe)
                              if (offset.dx < 0)
                                Positioned.fill(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 20),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.red,
                                        width: 3,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Align(
                                      alignment: Alignment.topRight,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'WORSE',
                                            style: GoogleFonts.dmSans(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.0,
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
                  child: _buildComparisonCard(comparison),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Hint labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '← $comparisonName is worse',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: PinitColors.mute,
                ),
              ),
              Text(
                '$comparisonName is better →',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: PinitColors.mute,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _timeAgo(String isoString) {
    final date = DateTime.tryParse(isoString);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 365) {
      final years = (diff.inDays / 365).floor();
      return ' ${years == 1 ? '1 YEAR' : '$years YEARS'} AGO';
    }
    if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).floor();
      return ' ${months == 1 ? '1 MONTH' : '$months MONTHS'} AGO';
    }
    if (diff.inDays >= 1) {
      return ' ${diff.inDays == 1 ? '1 DAY' : '${diff.inDays} DAYS'} AGO';
    }
    return 'TODAY';
  }

  Widget _buildComparisonCard(Map<String, dynamic> review) {
    final name = review['location_name'] as String? ?? 'A place';
    final rating = review['rating'] as num?;
    final createdAt = review['created_at'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: PinitColors.cream,
        borderRadius: BorderRadius.all(Radius.circular(10)),
        border: Border.fromBorderSide(
          BorderSide(color: PinitColors.aubergine, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: PinitColors.aubergine,
            blurRadius: 0,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top label strip
            Container(
              color: PinitColors.creamSunk,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(FeatherIcons.star, size: 11, color: PinitColors.mute),
                  const SizedBox(width: 5),
                  Text(
                      'YOU WENT ',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: PinitColors.mute,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  if (createdAt.isNotEmpty)
                    Text(
                      _timeAgo(createdAt),
                      style: GoogleFonts.dmSans(  
                        fontSize: 10,
                        color: PinitColors.mute,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                ],
              ),
            ),
            // Image
            Expanded(
              flex: 3,
              child: _buildComparisonImage(review),
            ),
            // Divider
            Container(height: 1.5, color: PinitColors.aubergine),
            // Name + rating
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.dmSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: PinitColors.aubergine,
                      height: 1.15,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (rating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${rating.toStringAsFixed(1)} / 10',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: PinitColors.aubergineSoft,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewLocationCard() {
    final imageUrl = widget.newLocation.imageUrl;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: PinitColors.cream,
        borderRadius: BorderRadius.all(Radius.circular(10)),
        border: Border.fromBorderSide(
          BorderSide(color: PinitColors.aubergine, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: PinitColors.aubergine,
            blurRadius: 0,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top label strip
            Container(
              color: PinitColors.creamSunk,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(FeatherIcons.mapPin, size: 11, color: PinitColors.mute),
                  const SizedBox(width: 5),
                  Text(
                    'RATING THIS',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: PinitColors.mute,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            // Image
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: PinitColors.creamSunk,
                            child: const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                      PinitColors.aubergineSoft),
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => _imageEmpty(
                              widget.newLocation.emoji),
                        )
                      : _imageEmpty(widget.newLocation.emoji),
                  // Gradient scrim
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0x33000000)],
                          stops: [0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Emoji badge
                  if (widget.newLocation.emoji != null &&
                      widget.newLocation.emoji!.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: PinitColors.cream,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: PinitColors.aubergine, width: 1.4),
                        ),
                        alignment: Alignment.center,
                        child: Text(widget.newLocation.emoji!,
                            style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                ],
              ),
            ),
            // Divider
            Container(height: 1.5, color: PinitColors.aubergine),
            // Name
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
              child: Text(
                widget.newLocation.name,
                style: GoogleFonts.dmSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: PinitColors.aubergine,
                  height: 1.15,
                  letterSpacing: -0.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageEmpty(String? emoji) => Container(
        color: PinitColors.creamSunk,
        child: Center(
          child: Text(
            emoji ?? '📍',
            style: const TextStyle(fontSize: 40),
          ),
        ),
      );

  Widget _buildComparisonImage(Map<String, dynamic> review) {
    final locationId = review['location_id'] as int?;
    final imageUrl = locationId != null
        ? SupabaseClientManager()
            .client
            .storage
            .from('location_photos')
            .getPublicUrl('$locationId.jpg')
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null)
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: PinitColors.creamSunk,
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation(PinitColors.aubergineSoft),
                  ),
                ),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: PinitColors.creamSunk,
              child: const Center(
                child: Icon(FeatherIcons.image,
                    size: 28, color: PinitColors.aubergineSoft),
              ),
            ),
          )
        else
          Container(
            color: PinitColors.creamSunk,
            child: const Center(
              child: Icon(FeatherIcons.image,
                  size: 28, color: PinitColors.aubergineSoft),
            ),
          ),
        // Gradient scrim
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x33000000)],
                stops: [0.55, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimplifiedForm() {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        16;

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: PinitColors.creamDeep,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Header label
            Text(
              'RATING',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: PinitColors.aubergineSoft,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            // Location name
            Text(
              widget.newLocation.name,
              style: const TextStyle(
                fontFamily: 'Rova',
                fontSize: 28,
                fontWeight: FontWeight.w100,
                color: PinitColors.aubergine,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 24),

            // Read-only rating display
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: PinitColors.creamSunk,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: PinitColors.creamDeep,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_derivedRating!.toStringAsFixed(1)} / 10',
                    style: GoogleFonts.dmSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: PinitColors.aubergine,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on your comparisons',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: PinitColors.mute,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Notes section
            Text(
              'Notes (optional)',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: PinitColors.aubergine,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              minLines: 1,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: PinitColors.aubergine,
              ),
              decoration: InputDecoration(
                hintText: 'What did you think?',
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: PinitColors.mute,
                ),
                filled: true,
                fillColor: PinitColors.creamSunk,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: PinitColors.creamDeep,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: PinitColors.aubergine,
                    width: 1.5,
                  ),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Gatekeep toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gatekeep',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PinitColors.aubergine,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hide this from your followers',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: PinitColors.mute,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _gatekeep,
                  activeThumbColor: PinitColors.aubergine,
                  onChanged: (value) => setState(() => _gatekeep = value),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: _submitting
                  ? Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PinitColors.aubergine,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PinitColors.aubergine,
                        foregroundColor: PinitColors.cream,
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      onPressed: _submitForm,
                      child: Text(
                        'Log visit',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

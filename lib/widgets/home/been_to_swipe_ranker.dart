import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// Binary-search swipe ranker shown when the user taps "Been to" and has
/// already logged more than 5 visits. Instead of asking for a numeric
/// rating directly, we ask up to 3 binary "which did you prefer?"
/// comparisons against existing reviews and derive the new rating from
/// where the location lands in the user's ranked list.
///
/// Algorithm: classic binary search over the user's existing been-to
/// reviews (sorted desc by rating). Right swipe = new is better; left
/// swipe = old is better. After 3 rounds (or convergence) the derived
/// rating is the midpoint of the upper and lower neighbours' ratings,
/// rounded to one decimal.
class BeenToSwipeRanker extends StatefulWidget {
  const BeenToSwipeRanker({
    super.key,
    required this.newLocation,
    required this.existingReviews,
    required this.onSubmitted,
  });

  final LocationModel newLocation;
  final List<Map<String, dynamic>> existingReviews;
  final Future<void> Function(double rating, String? notes, bool gatekeep)
      onSubmitted;

  @override
  State<BeenToSwipeRanker> createState() => _BeenToSwipeRankerState();
}

class _BeenToSwipeRankerState extends State<BeenToSwipeRanker>
    with SingleTickerProviderStateMixin {
  static const int _maxRounds = 3;

  late final List<Map<String, dynamic>> _sorted;
  int _lo = 0;
  int _hi = 0;
  int _mid = 0;
  int _round = 0;
  double? _derivedRating;

  // Swipe gesture state
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  late final AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  // Form state (post-ranking)
  final TextEditingController _notesController = TextEditingController();
  bool _gatekeep = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _sorted = List<Map<String, dynamic>>.from(widget.existingReviews)
      ..sort((a, b) {
        final ra = (a['rating'] as num?)?.toDouble() ?? 0.0;
        final rb = (b['rating'] as num?)?.toDouble() ?? 0.0;
        return rb.compareTo(ra);
      });
    _lo = 0;
    _hi = _sorted.length - 1;
    _mid = (_lo + _hi) ~/ 2;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation =
        Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  Ranking algorithm
  // ─────────────────────────────────────────────────────────────

  void _registerComparison({required bool newIsBetter}) {
    if (newIsBetter) {
      _hi = _mid - 1;
    } else {
      _lo = _mid + 1;
    }
    _round += 1;

    if (_round >= _maxRounds || _lo > _hi) {
      _derivedRating = _deriveRating();
    } else {
      _mid = (_lo + _hi) ~/ 2;
    }
    setState(() {});
  }

  double _deriveRating() {
    final upper = _lo > 0
        ? (_sorted[_lo - 1]['rating'] as num).toDouble()
        : 10.0;
    final lower = _lo < _sorted.length
        ? (_sorted[_lo]['rating'] as num).toDouble()
        : 0.0;
    return ((upper + lower) / 2 * 10).roundToDouble() / 10;
  }

  // ─────────────────────────────────────────────────────────────
  //  Swipe gesture handling (mirrors SwipeCardStack)
  // ─────────────────────────────────────────────────────────────

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
      _animateSwipe(_dragOffset.dx > 0);
    } else {
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    }
  }

  void _animateSwipe(bool newIsBetter) {
    final screenWidth = MediaQuery.of(context).size.width;
    final endOffset = Offset(
      newIsBetter ? screenWidth * 1.5 : -screenWidth * 1.5,
      _dragOffset.dy,
    );
    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: endOffset,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _animationController.forward(from: 0).then((_) {
      if (!mounted) return;
      _registerComparison(newIsBetter: newIsBetter);
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
        _animationController.reset();
      });
    });
  }

  // ─────────────────────────────────────────────────────────────
  //  Submit (post-ranking)
  // ─────────────────────────────────────────────────────────────

  Future<void> _handleSubmit() async {
    if (_submitting || _derivedRating == null) return;
    setState(() => _submitting = true);
    try {
      final notes = _notesController.text.trim();
      await widget.onSubmitted(
        _derivedRating!,
        notes.isEmpty ? null : notes,
        _gatekeep,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log visit: $e')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: size.height * 0.85,
        decoration: const BoxDecoration(
          color: PinitColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PinitColors.creamDeep,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _derivedRating == null
                    ? _buildRankingPhase()
                    : _buildFormPhase(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Ranking phase ──────────────────────────────────────────

  Widget _buildRankingPhase() {
    final comparison = _sorted[_mid];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            'BEEN TO',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: PinitColors.aubergineSoft,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Which did you prefer?',
            style: const TextStyle(
              fontFamily: 'Rova',
              fontSize: 26,
              color: PinitColors.aubergine,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Round ${_round + 1}/$_maxRounds',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: PinitColors.mute,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background — comparison card
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Transform.scale(
                      scale: 0.92,
                      child: Opacity(
                        opacity: 0.55,
                        child: _ComparisonCard(
                          imageUrl: comparison['image_url'] as String?,
                          name: (comparison['location_name'] as String?) ??
                              'Place',
                          rating:
                              (comparison['rating'] as num?)?.toDouble() ?? 0.0,
                          isNew: false,
                        ),
                      ),
                    ),
                  ),
                ),
                // Foreground — swipeable new location card
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final offset = _animationController.isAnimating
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
                            if (_isDragging || _animationController.isAnimating)
                              _SwipeOverlay(dx: offset.dx),
                          ],
                        ),
                      ),
                    );
                  },
                  child: GestureDetector(
                    onPanStart: _onDragStart,
                    onPanUpdate: _onDragUpdate,
                    onPanEnd: _onDragEnd,
                    child: _ComparisonCard(
                      imageUrl: widget.newLocation.imageUrl,
                      name: widget.newLocation.name,
                      rating: null,
                      isNew: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HintLabel(text: '← Worse', color: PinitColors.error),
              _HintLabel(text: 'Better →', color: PinitColors.success),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Form phase ────────────────────────────────────────────

  Widget _buildFormPhase() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BEEN TO',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: PinitColors.aubergineSoft,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.newLocation.name,
            style: const TextStyle(
              fontFamily: 'Rova',
              fontSize: 28,
              height: 1.1,
              color: PinitColors.aubergine,
            ),
          ),
          const SizedBox(height: 24),
          // Read-only derived rating display
          Center(
            child: Column(
              children: [
                Text(
                  '${_derivedRating!.toStringAsFixed(1)} / 10',
                  style: GoogleFonts.dmSans(
                    fontSize: 36,
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
          TextField(
            controller: _notesController,
            maxLines: 4,
            minLines: 3,
            style: GoogleFonts.dmSans(
                fontSize: 14, color: PinitColors.aubergine),
            decoration: InputDecoration(
              hintText: 'Notes (optional)',
              hintStyle: GoogleFonts.dmSans(
                fontSize: 14,
                color: PinitColors.mute,
              ),
              filled: true,
              fillColor: PinitColors.creamSunk,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: PinitColors.aubergine, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gatekeep',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: PinitColors.aubergine,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hide from followers',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: PinitColors.mute,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _gatekeep,
                onChanged: (v) => setState(() => _gatekeep = v),
                activeThumbColor: PinitColors.aubergine,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: PinitColors.aubergine,
                foregroundColor: PinitColors.cream,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PinitColors.cream,
                      ),
                    )
                  : Text(
                      'Log visit',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Comparison card (used in both swipe positions)
// ─────────────────────────────────────────────────────────────

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.imageUrl,
    required this.name,
    required this.rating,
    required this.isNew,
  });

  final String? imageUrl;
  final String name;
  final double? rating;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(24),
        boxShadow: PinitColors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: PinitColors.creamDeep),
                errorWidget: (_, __, ___) => Container(
                  color: PinitColors.creamDeep,
                  child: const Icon(
                    Icons.restaurant_menu_rounded,
                    size: 48,
                    color: PinitColors.aubergineSoft,
                  ),
                ),
              )
            else
              Container(
                color: PinitColors.creamDeep,
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  size: 48,
                  color: PinitColors.aubergineSoft,
                ),
              ),
            // Bottom gradient for legibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                    stops: const [0.55, 1.0],
                  ),
                ),
              ),
            ),
            // Label
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isNew ? 'NEW' : 'YOUR PICK',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: PinitColors.cream.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: PinitColors.cream,
                    ),
                  ),
                  if (rating != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Rated ${rating!.toStringAsFixed(1)}/10',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: PinitColors.cream.withValues(alpha: 0.9),
                      ),
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
}

// ─────────────────────────────────────────────────────────────
//  Swipe overlay — green/red BETTER/WORSE label during drag
// ─────────────────────────────────────────────────────────────

class _SwipeOverlay extends StatelessWidget {
  const _SwipeOverlay({required this.dx});
  final double dx;

  @override
  Widget build(BuildContext context) {
    if (dx == 0) return const SizedBox.shrink();
    final isBetter = dx > 0;
    final color = isBetter ? PinitColors.success : PinitColors.error;
    final label = isBetter ? 'BETTER' : 'WORSE';
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Align(
            alignment: isBetter ? Alignment.topLeft : Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HintLabel extends StatelessWidget {
  const _HintLabel({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

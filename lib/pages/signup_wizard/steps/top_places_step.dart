import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../models/locations.dart';
import '../../../models/signup_wizard_state.dart';
import '../../../pages/profile/widgets/pinit_colors.dart';
import '../../../widgets/home/expanded_location_card.dart';

class TopPlacesStep extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onComplete;
  final bool isCompleting;
  final List<LocationModel> recommendations;

  const TopPlacesStep({
    super.key,
    required this.onBack,
    required this.onComplete,
    required this.isCompleting,
    required this.recommendations,
  });

  @override
  State<TopPlacesStep> createState() => _TopPlacesStepState();
}

class _TopPlacesStepState extends State<TopPlacesStep>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  late final AnimationController _swipeAnimController;
  late Animation<Offset> _slideAnimation;

  LocationModel? _expandedLocation;

  @override
  void initState() {
    super.initState();
    _swipeAnimController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _swipeAnimController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _swipeAnimController.dispose();
    super.dispose();
  }

  bool get _allSwiped => _currentIndex >= widget.recommendations.length;

  void _onDragStart(DragStartDetails _) {
    setState(() => _isDragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _dragOffset += details.delta);
  }

  void _onDragEnd(DragEndDetails _) {
    if (!_isDragging) return;
    final threshold = MediaQuery.of(context).size.width * 0.3;
    if (_dragOffset.dx.abs() > threshold) {
      final isSave = _dragOffset.dx > 0; // right = save
      _animateAndAdvance(isSave);
    } else {
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    }
  }

  void _animateAndAdvance(bool isSave) {
    final screenWidth = MediaQuery.of(context).size.width;
    final endX =
        _dragOffset.dx > 0 ? screenWidth * 1.5 : -screenWidth * 1.5;

    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(endX, _dragOffset.dy),
    ).animate(CurvedAnimation(
      parent: _swipeAnimController,
      curve: Curves.easeOut,
    ));

    _swipeAnimController.forward(from: 0).then((_) {
      if (!mounted) return;
      if (isSave) {
        final wizardState =
            Provider.of<SignupWizardState>(context, listen: false);
        final loc = widget.recommendations[_currentIndex];
        if (!wizardState.addedLocationIds.contains(loc.locationId)) {
          wizardState.toggleAddedLocation(loc.locationId);
        }
      }
      setState(() {
        _currentIndex++;
        _dragOffset = Offset.zero;
        _isDragging = false;
        _swipeAnimController.reset();
      });
    });
  }

  void _openExpanded(LocationModel loc) {
    setState(() => _expandedLocation = loc);
  }

  void _closeExpanded() {
    setState(() => _expandedLocation = null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PinitColors.cream,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: widget.recommendations.isEmpty
                    ? _buildEmptyState()
                    : _buildSwipeArea(),
              ),
              _buildFooter(context),
            ],
          ),
          if (_expandedLocation != null)
            ExpandedLocationCard(
              location: _expandedLocation!,
              onClose: _closeExpanded,
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 48,
              color: PinitColors.mute,
            ),
            const SizedBox(height: 16),
            Text(
              "Couldn't load places right now",
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: PinitColors.aubergine,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You can skip for now and add favourites later.",
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: PinitColors.mute,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeArea() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _allSwiped ? _buildDoneState() : _buildCardStack(),
        ),
        if (!_allSwiped) _buildSwipeHints(),
      ],
    );
  }

  Widget _buildHeader() {
    final total = widget.recommendations.length;
    final current = _allSwiped ? total : _currentIndex + 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_allSwiped)
            Text(
              '$current of $total',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: PinitColors.aubergineSoft,
                letterSpacing: 1.2,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            _allSwiped
                ? "All done!"
                : 'Swipe right if you\'d go here,\nSwipe left if it\'s not for you.',
            style: const TextStyle(
              fontFamily: 'Rova',
              fontSize: 26,
              fontWeight: FontWeight.w100,
              color: PinitColors.aubergine,
              letterSpacing: 0.3,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a card to learn more.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: PinitColors.mute,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCardStack() {
    final current = widget.recommendations[_currentIndex];
    final hasNext = _currentIndex + 1 < widget.recommendations.length;
    final next = hasNext ? widget.recommendations[_currentIndex + 1] : null;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Background card (next in queue, peeking)
        if (next != null)
          Transform.scale(
            scale: 0.88,
            child: Opacity(
              opacity: 0.5,
              child: _buildCard(next, interactive: false),
            ),
          ),

        // Foreground swipeable card
        GestureDetector(
          onPanStart: _onDragStart,
          onPanUpdate: _onDragUpdate,
          onPanEnd: _onDragEnd,
          onTap: () => _openExpanded(current),
          child: AnimatedBuilder(
            animation: _swipeAnimController,
            builder: (context, child) {
              final offset = _swipeAnimController.isAnimating
                  ? _slideAnimation.value
                  : _dragOffset;
              final rotation = offset.dx / 1100;

              return Transform.translate(
                offset: offset,
                child: Transform.rotate(
                  angle: rotation,
                  child: Stack(
                    children: [
                      child!,
                      if (_isDragging || _swipeAnimController.isAnimating) ...[
                        if (offset.dx > 0)
                          _buildSwipeOverlay(
                            label: 'SAVE',
                            color: const Color(0xFF10B981),
                            alignment: Alignment.topRight,
                          ),
                        if (offset.dx < 0)
                          _buildSwipeOverlay(
                            label: 'SKIP',
                            color: const Color(0xFFEF4444),
                            alignment: Alignment.topLeft,
                          ),
                      ],
                    ],
                  ),
                ),
              );
            },
            child: _buildCard(current, interactive: true),
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeOverlay({
    required String label,
    required Color color,
    required Alignment alignment,
  }) {
    return Positioned.fill(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(LocationModel loc, {required bool interactive}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: PinitColors.cream,
        borderRadius: BorderRadius.all(Radius.circular(16)),
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
        borderRadius: BorderRadius.circular(14.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top label strip
            Container(
              color: PinitColors.creamSunk,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Icon(FeatherIcons.mapPin,
                      size: 11, color: PinitColors.mute),
                  const SizedBox(width: 5),
                  Text(
                    'NEARBY',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: PinitColors.mute,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  if (interactive) ...[
                    const Spacer(),
                    Text(
                      'Tap to explore',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: PinitColors.mute,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(FeatherIcons.externalLink,
                        size: 10, color: PinitColors.mute),
                  ],
                ],
              ),
            ),
            // Image
            AspectRatio(
              aspectRatio: 4 / 3,
              child: _buildCardImage(loc),
            ),
            // Divider
            Container(height: 1.5, color: PinitColors.aubergine),
            // Name + meta
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: PinitColors.aubergine,
                      height: 1.15,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (loc.rating != null) ...[
                        const Icon(Icons.star_rounded,
                            size: 14, color: PinitColors.accent),
                        const SizedBox(width: 3),
                        Text(
                          loc.rating!.toStringAsFixed(1),
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: PinitColors.aubergine,
                          ),
                        ),
                      ],
                      if (loc.cuisine != null &&
                          loc.cuisine!.isNotEmpty) ...[
                        if (loc.rating != null)
                          Text(
                            '  ·  ',
                            style: GoogleFonts.dmSans(
                                fontSize: 13, color: PinitColors.mute),
                          ),
                        Flexible(
                          child: Text(
                            loc.cuisine!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: PinitColors.mute,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardImage(LocationModel loc) {
    final url = loc.imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: PinitColors.creamSunk,
        child: Center(
          child: Text(
            loc.emoji ?? '📍',
            style: const TextStyle(fontSize: 40),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
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
            child: Center(
              child: Text(
                loc.emoji ?? '📍',
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
        ),
        // Scrim
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
        if (loc.emoji != null && loc.emoji!.isNotEmpty)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: PinitColors.cream,
                shape: BoxShape.circle,
                border: Border.all(color: PinitColors.aubergine, width: 1.4),
              ),
              alignment: Alignment.center,
              child: Text(loc.emoji!, style: const TextStyle(fontSize: 16)),
            ),
          ),
      ],
    );
  }

  Widget _buildSwipeHints() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(FeatherIcons.x,
                  size: 13, color: Color(0xFFEF4444)),
              const SizedBox(width: 5),
              Text(
                '← Skip',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: PinitColors.mute,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'Save →',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: PinitColors.mute,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(FeatherIcons.bookmark,
                  size: 13, color: Color(0xFF10B981)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoneState() {
    return Consumer<SignupWizardState>(
      builder: (context, wizardState, _) {
        final saved = wizardState.addedLocationIds.length;
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: PinitColors.aubergine,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: PinitColors.cream,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  saved > 0
                      ? 'You saved $saved ${saved == 1 ? 'place' : 'places'}!'
                      : 'All done!',
                  style: const TextStyle(
                    fontFamily: 'Rova',
                    fontSize: 26,
                    fontWeight: FontWeight.w100,
                    color: PinitColors.aubergine,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (saved > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'They\'ll be waiting for you on your home feed.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: PinitColors.mute,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Consumer<SignupWizardState>(
      builder: (context, wizardState, _) {
        final savedCount = wizardState.addedLocationIds.length;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: PinitColors.cream,
            boxShadow: [
              BoxShadow(
                color: PinitColors.aubergine.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (savedCount > 0 && _allSwiped)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '$savedCount ${savedCount == 1 ? 'place' : 'places'} saved',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PinitColors.aubergine,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.isCompleting ? null : widget.onBack,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(
                          color: PinitColors.aubergine,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Back',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: PinitColors.aubergine,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: widget.isCompleting ? null : widget.onComplete,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: PinitColors.aubergine,
                        foregroundColor: PinitColors.cream,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: widget.isCompleting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        PinitColors.cream),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Finishing up...',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              savedCount > 0 ? 'Finish' : 'Skip for now',
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

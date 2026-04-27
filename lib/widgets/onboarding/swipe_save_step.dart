import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/service.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/widgets/feedback/app_feedback.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:provider/provider.dart';

class SwipeSaveStep extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onLetsGo;
  final List<LocationModel> recommendations;

  const SwipeSaveStep({
    super.key,
    required this.onBack,
    required this.onLetsGo,
    required this.recommendations,
  });

  @override
  State<SwipeSaveStep> createState() => _SwipeSaveStepState();
}

class _SwipeSaveStepState extends State<SwipeSaveStep>
    with SingleTickerProviderStateMixin {
  static const double _maxCardWidth = 290;
  static const double _cardSidePadding = 18;
  static const double _cardImageAspectRatio = 16 / 10;
  static const double _swipeAreaMinHeight = 240;
  static const double _swipeAreaMaxHeight = 320;

  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  final Set<int> _savedLocationIds = <int>{};
  final TextEditingController _pasteController = TextEditingController();

  late final AnimationController _swipeAnimController;
  late Animation<Offset> _slideAnimation;

  LocationModel? _expandedLocation;

  bool get _allSwiped => _currentIndex >= widget.recommendations.length;

  double _cardWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - (_cardSidePadding * 2);
    final clamped = width.clamp(0.0, _maxCardWidth);
    return clamped.toDouble();
  }

  @override
  void initState() {
    super.initState();
    _swipeAnimController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
      CurvedAnimation(parent: _swipeAnimController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pasteController.dispose();
    _swipeAnimController.dispose();
    super.dispose();
  }

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
      if (isSave && !_allSwiped) {
        final loc = widget.recommendations[_currentIndex];
        unawaited(_saveLocation(loc.locationId));
      }
      setState(() {
        _currentIndex++;
        _dragOffset = Offset.zero;
        _isDragging = false;
        _swipeAnimController.reset();
      });
    });
  }

  Future<void> _saveLocation(int locationId) async {
    if (_savedLocationIds.contains(locationId)) return;
    _savedLocationIds.add(locationId);

    final supabase = context.read<SupabaseService>();
    try {
      await supabase.locations.saveLocation(
        locationId,
        savedMethod: SupabaseConstants.savedMethodInApp,
      );
      if (!mounted) return;
      unawaited(context.read<LocationListManager>().refreshSavedLocations());
    } catch (e) {
      if (!mounted) return;
      _savedLocationIds.remove(locationId);
      await AppFeedback.showError(
        context,
        title: 'Couldn’t save',
        message: 'Try again in a moment.',
      );
    }
  }

  void _openExpanded(LocationModel loc) {
    setState(() => _expandedLocation = loc);
  }

  void _closeExpanded() {
    setState(() => _expandedLocation = null);
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = _cardWidth(context);
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final swipeAreaHeight = (constraints.maxHeight * 0.42)
                        .clamp(_swipeAreaMinHeight, _swipeAreaMaxHeight)
                        .toDouble();

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Let\'s get you started with some recs',
                            textAlign: TextAlign.center,
                            style: AppTypography.brand(
                              fontSize: 30,
                              fontWeight: FontWeight.w100,
                              color: PinitColors.aubergine,
                              letterSpacing: 0.6,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Swipe right if you'd go, left if it's not a bit of you.",
                            textAlign: TextAlign.center,
                            style: AppTypography.sans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: PinitColors.aubergineSoft,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: swipeAreaHeight,
                            child: widget.recommendations.isEmpty
                                ? _buildEmptyState()
                                : Center(
                                    child: _buildSwipeArea(cardWidth),
                                  ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Or paste places to pin',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: PinitColors.aubergineSoft,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildPastePanel(context),
                        ],
                      ),
                    );
                  },
                ),
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

  Widget _buildPastePanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PinitColors.creamDeep, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: PinitColors.aubergine,
            blurRadius: 0,
            offset: Offset(3, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _pasteController,
              minLines: 2,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: PinitColors.aubergine,
              ),
              decoration: InputDecoration(
                hintText: 'Dishoom, Padella, Lina Stores…',
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PinitColors.mute,
                ),
                filled: true,
                fillColor: PinitColors.cream,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: PinitColors.creamDeep,
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: PinitColors.creamDeep,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: PinitColors.aubergine,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _pasteController.text.trim().isEmpty
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PinitColors.aubergine,
                  foregroundColor: PinitColors.cream,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Process',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
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
            const SizedBox(height: 10),
            Text(
              'No stress — you can start pinning from TikTok instead.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: PinitColors.mute,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeArea(double cardWidth) {
    final current = _allSwiped ? null : widget.recommendations[_currentIndex];
    final next =
        _currentIndex + 1 < widget.recommendations.length ? widget.recommendations[_currentIndex + 1] : null;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (next != null)
          SizedBox(
            width: cardWidth,
            child: _buildCard(context, next, interactive: false),
          ),
        if (current != null)
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
              child: SizedBox(
                width: cardWidth,
                child: _buildCard(context, current, interactive: true),
              ),
            ),
          ),
        if (_allSwiped)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 40,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nice one.',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: PinitColors.aubergine,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _savedLocationIds.isEmpty
                      ? 'Now you’re ready to start pinning.'
                      : '${_savedLocationIds.length} saved — now you’re ready to start pinning.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PinitColors.mute,
                    height: 1.4,
                  ),
                ),
              ],
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

  Widget _buildCard(BuildContext context, LocationModel loc,
      {required bool interactive}) {
    return Container(
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
            Container(
              color: PinitColors.creamSunk,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
            AspectRatio(
              aspectRatio: _cardImageAspectRatio,
              child: _buildCardImage(loc),
            ),
            Container(height: 1.5, color: PinitColors.aubergine),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
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
                      if (loc.cuisine != null && loc.cuisine!.isNotEmpty) ...[
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
                  valueColor: AlwaysStoppedAnimation(PinitColors.aubergineSoft),
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

  Widget _buildFooter(BuildContext context) {
    final savedCount = _savedLocationIds.length;

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
                  onPressed: widget.onBack,
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
                  onPressed: widget.onLetsGo,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: PinitColors.aubergine,
                    foregroundColor: PinitColors.cream,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    "Let’s go!",
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
  }
}

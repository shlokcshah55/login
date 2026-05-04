import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/collections_grid.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/providers/location_list_provider.dart';
import 'package:login/supabase/constants.dart';
import 'package:login/supabase/helpers/collections.dart';
import 'package:login/supabase/service.dart';
import 'package:login/supabase/supabase_client.dart';
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
  static const double _contentSidePadding = 20;
  static const double _swipeAreaMinHeight = 170;
  static const double _swipeAreaMaxHeight = 280;
  static const double _collectionsPanelMinHeight = 185;
  static const double _collectionsPanelMaxHeight = 220;

  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  final Set<int> _savedLocationIds = <int>{};
  final CollectionsHelper _collectionsHelper = CollectionsHelper();
  bool _loadingCollections = false;
  List<CollectionItem> _exploreCollections = const [];
  String? _savingCollectionId;

  late final AnimationController _swipeAnimController;
  late Animation<Offset> _slideAnimation;

  LocationModel? _expandedLocation;

  bool get _allSwiped => _currentIndex >= widget.recommendations.length;

  @override
  void initState() {
    super.initState();
    _swipeAnimController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
      CurvedAnimation(parent: _swipeAnimController, curve: Curves.easeOut),
    );

    unawaited(_loadExploreCollections());
  }

  @override
  void dispose() {
    _swipeAnimController.dispose();
    super.dispose();
  }

  Future<void> _handleLetsGo() async => widget.onLetsGo();

  static const List<String> _curatedCollectionIds = [
    'e9f50774-b41a-4712-b230-2700aad37ebd', // Date Night 🌹
    '33df0d5e-1a26-4cbe-8356-9ea2b46ddece', // Cheap Eats 💸
    '9e352f72-96b2-45dc-ae65-97e66a661262', // Vegetarian & Vegan 🌿
    'f1e64a86-ff68-4a95-a2c6-7d755bdd8485', // Splurge / Special Occasion 🌟
    '17ce4d6a-8239-45fc-b129-7e03241c77a3', // Group Dining / Big Night Out 🎉
    '85eedbc1-69cc-4d67-99e6-9b898e026628', // Hidden Gems / Under the Radar 🌍
    '12c325c0-d0b5-4ee3-8327-838f0b7615cf', // Comfort Food / Casual Classics 🍝
    'a897ae62-6ec0-4096-8e28-641554d8ab7e', // Crowd Favourites / The London Essentials 🏆
  ];

  Future<void> _loadExploreCollections() async {
    if (_loadingCollections) return;
    final userId = SupabaseClientManager().currentUser?.id;
    setState(() => _loadingCollections = true);
    try {
      final items = await _collectionsHelper.getCollectionsByIds(
          _curatedCollectionIds, userId);
      if (!mounted) return;
      setState(() => _exploreCollections = items);
    } catch (_) {
      if (!mounted) return;
      setState(() => _exploreCollections = const []);
    } finally {
      if (mounted) setState(() => _loadingCollections = false);
    }
  }

  Future<void> _toggleSaveCollection(CollectionItem collection) async {
    if (_savingCollectionId != null) return;
    setState(() => _savingCollectionId = collection.collectionId);
    try {
      if (collection.isSaved) {
        await _collectionsHelper.unsaveCollection(collection.collectionId);
      } else {
        await _collectionsHelper.saveCollection(collection.collectionId);
      }
      if (!mounted) return;

      setState(() {
        final index = _exploreCollections
            .indexWhere((c) => c.collectionId == collection.collectionId);
        if (index == -1) return;
        final current = _exploreCollections[index];
        final nextSaved = !current.isSaved;
        final nextCount = nextSaved
            ? current.saveCount + 1
            : (current.saveCount - 1) < 0
                ? 0
                : current.saveCount - 1;
        final next = current.copyWith(isSaved: nextSaved, saveCount: nextCount);
        _exploreCollections = List<CollectionItem>.from(_exploreCollections)
          ..[index] = next;
      });
    } catch (_) {
      if (!mounted) return;
      unawaited(
        AppFeedback.showError(
          context,
          title: 'Couldn’t update',
          message: 'Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _savingCollectionId = null);
    }
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
    final endX = _dragOffset.dx > 0 ? screenWidth * 1.5 : -screenWidth * 1.5;

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
    final availableWidth =
        MediaQuery.sizeOf(context).width - (_contentSidePadding * 2);
    final cardWidth = availableWidth.clamp(0.0, _maxCardWidth).toDouble();
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
                    const double fixedOverhead = 185;
                    final collectionsPanelHeight =
                        (constraints.maxHeight * 0.33)
                            .clamp(
                                _collectionsPanelMinHeight,
                                _collectionsPanelMaxHeight)
                            .toDouble();
                    final swipeAreaHeight = (constraints.maxHeight -
                            fixedOverhead -
                            collectionsPanelHeight)
                        .clamp(_swipeAreaMinHeight, _swipeAreaMaxHeight)
                        .toDouble();

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Get started with a few picks from us!',
                            textAlign: TextAlign.center,
                            style: AppTypography.brand(
                              fontSize: 22,
                              fontWeight: FontWeight.w100,
                              color: PinitColors.aubergine,
                              letterSpacing: 0.6,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: swipeAreaHeight,
                            child: widget.recommendations.isEmpty
                                ? _buildEmptyState()
                                : Center(
                                    child: _buildSwipeArea(
                                        cardWidth, swipeAreaHeight),
                                  ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.arrow_back_rounded,
                                  size: 18, color: Color(0xFFEF4444)),
                              const SizedBox(width: 6),
                              Text(
                                'skip',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: PinitColors.aubergineSoft,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Text(
                                'save',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: PinitColors.aubergineSoft,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded,
                                  size: 18, color: Color(0xFF10B981)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'And save a few of our handmade eat-lists',
                            textAlign: TextAlign.center,
                            style: AppTypography.brand(
                              fontSize: 20,
                              fontWeight: FontWeight.w100,
                              color: PinitColors.aubergine,
                              letterSpacing: 0.6,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildCollectionsPanel(context,
                              cardWidth: cardWidth,
                              panelHeight: collectionsPanelHeight),
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

  Widget _buildCollectionsPanel(BuildContext context,
      {required double cardWidth, required double panelHeight}) {
    return Center(
      child: SizedBox(
        width: cardWidth,
        height: panelHeight,
        child: _loadingCollections
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(PinitColors.aubergine),
                    ),
                  ),
                )
              : _exploreCollections.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'No friend eat-lists yet — you can still start swiping.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: PinitColors.aubergineSoft,
                            height: 1.35,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      clipBehavior: Clip.none,
                      itemCount: _exploreCollections.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final c = _exploreCollections[index];
                        final saving = _savingCollectionId == c.collectionId;
                        return SizedBox(
                          width: 160,
                          child: _ExploreCollectionCard(
                            collection: c,
                            saving: saving,
                            onToggleSave: () => _toggleSaveCollection(c),
                            onTap: () => _openCollectionDetail(c),
                          ),
                        );
                      },
                    ),
      ),
    );
  }

  void _openCollectionDetail(CollectionItem collection) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CollectionDetailSheet(
        collection: CollectionModel.fromItem(collection),
        onEdit: null,
        onDeleted: null,
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

  Widget _buildSwipeArea(double cardWidth, double cardHeight) {
    final current = _allSwiped ? null : widget.recommendations[_currentIndex];
    final next = _currentIndex + 1 < widget.recommendations.length
        ? widget.recommendations[_currentIndex + 1]
        : null;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (next != null)
          SizedBox(
            width: cardWidth,
            height: cardHeight,
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
                        if (_isDragging ||
                            _swipeAnimController.isAnimating) ...[
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
                height: cardHeight,
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
            Expanded(
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
                  onPressed: _handleLetsGo,
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

// Maps auto-generated collection labels to their bundled asset paths.
// Auto-generated collections whose cover is a bundled SVG illustration.
const Map<String, String> _kCollectionSvgAssets = {
  'Shared Finds': 'lib/assets/illustrations/Untitled design-3.svg',
  'Been To': 'lib/assets/illustrations/Brazuca - Date Night.svg',
};

const Map<String, String> _kCollectionAssets = {
  'Date Night 🌹': 'lib/assets/collection/date_night.png',
  'Brunch O\'Clock 🍳': 'lib/assets/collection/lunch.png',
  'On The Run 🏃': 'lib/assets/collection/lunch.png',
  'Midnight Munchies 🌙': 'lib/assets/collection/midnight.png',
  'Grab A Coffee ☕': 'lib/assets/collection/coffee.png',
  'Drinks Up 🍻': 'lib/assets/collection/pub.png',
  'Outside Outside ☀️': 'lib/assets/collection/summer.png',
};

class _ExploreCollectionCard extends StatelessWidget {
  final CollectionItem collection;
  final bool saving;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;

  const _ExploreCollectionCard({
    required this.collection,
    required this.saving,
    required this.onTap,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = _kCollectionAssets[collection.name];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PinitColors.aubergine, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: PinitColors.aubergine,
              blurRadius: 0,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.5),
          child: Container(
            color: PinitColors.creamSunk,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImage(
                        assetPath: assetPath,
                        coverColor: collection.coverColor,
                        networkPhoto: collection.photo,
                        name: collection.name,
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: saving ? null : onToggleSave,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: collection.isSaved
                                  ? PinitColors.aubergine
                                      .withValues(alpha: 0.92)
                                  : Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: saving
                                ? const SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    collection.isSaved
                                        ? FeatherIcons.check
                                        : FeatherIcons.plus,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (collection.ownerName != null &&
                          collection.ownerName!.isNotEmpty) ...[
                        Row(
                          children: [
                            if (collection.ownerAvatarUrl != null)
                              ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: collection.ownerAvatarUrl!,
                                  width: 18,
                                  height: 18,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: PinitColors.creamDeep,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 11,
                                  color: PinitColors.mute,
                                ),
                              ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                collection.ownerName!.toUpperCase(),
                                style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color:
                              pinit.PinitColors.aubergine,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w500,
                        ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        collection.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: PinitColors.aubergineSoft,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _buildMetaText(collection),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: PinitColors.mute,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildMetaText(CollectionItem collection) {
    final placesText =
        '${collection.placeCount} place${collection.placeCount == 1 ? "" : "s"}';
    final savesText =
        '${collection.saveCount} save${collection.saveCount == 1 ? "" : "s"}';
    return '$placesText • $savesText';
  }

  Widget _buildImage({
    required String name,
    required String? assetPath,
    required String? coverColor,
    required String? networkPhoto,
  }) {
    final svgAsset = _kCollectionSvgAssets[name];
    if (svgAsset != null) {
      return SvgPicture.asset(
        svgAsset,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }
    if (assetPath != null) {
      return Image.asset(assetPath, fit: BoxFit.cover, width: double.infinity);
    }
    final photoUrl = coverColor ?? networkPhoto;
    if (photoUrl != null) {
      return CachedNetworkImage(
        imageUrl: photoUrl,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }
    return Container(
      color: PinitColors.creamDeep,
      child: const Center(
        child: Icon(
          FeatherIcons.bookmark,
          size: 28,
          color: PinitColors.mute,
        ),
      ),
    );
  }
}

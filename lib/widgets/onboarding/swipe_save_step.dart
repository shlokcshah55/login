import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/collections_grid.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart' as pinit;
import 'package:login/supabase/helpers/collections.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/widgets/feedback/app_feedback.dart';

class SwipeSaveStep extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onLetsGo;

  const SwipeSaveStep({
    super.key,
    required this.onBack,
    required this.onLetsGo,
  });

  @override
  State<SwipeSaveStep> createState() => _SwipeSaveStepState();
}

class _SwipeSaveStepState extends State<SwipeSaveStep> {
  static const double _maxCardWidth = 290;
  static const double _contentSidePadding = 20;

  final CollectionsHelper _collectionsHelper = CollectionsHelper();
  bool _loadingCollections = false;
  List<CollectionItem> _exploreCollections = const [];
  List<String> _cityTabs = const [];
  String _selectedCity = '';
  String? _savingCollectionId;

  @override
  void initState() {
    super.initState();
    unawaited(_loadExploreCollections());
  }

  Future<void> _loadExploreCollections() async {
    if (_loadingCollections) return;
    final userId = SupabaseClientManager().currentUser?.id;
    setState(() => _loadingCollections = true);
    try {
      final items = await _collectionsHelper.getCuratedCollections(userId);
      if (!mounted) return;
      final cities = items
          .map((c) => (c.curatedCity ?? '').trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      setState(() {
        _exploreCollections = items;
        _cityTabs = cities;
        if (cities.isNotEmpty) _selectedCity = cities.first;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _exploreCollections = const []);
    } finally {
      if (mounted) setState(() => _loadingCollections = false);
    }
  }

  List<CollectionItem> get _groupedItems => _exploreCollections
      .where((c) =>
          (c.curatedCity ?? '').trim().toLowerCase() ==
          _selectedCity.trim().toLowerCase())
      .toList();

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
          title: "Couldn't update",
          message: 'Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _savingCollectionId = null);
    }
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
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                                                          const SizedBox(height: 32),

                  Text(
                    'Checkout and save a few of Pinit\'s custom eat-lists',
                    textAlign: TextAlign.center,
                    style: AppTypography.brand(
                      fontSize: 25,
                      fontWeight: FontWeight.w100,
                      color: PinitColors.aubergine,
                      letterSpacing: 1.2,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_cityTabs.isNotEmpty)
                    _CityPills(
                      cities: _cityTabs,
                      selected: _selectedCity,
                      onSelected: (city) =>
                          setState(() => _selectedCity = city),
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _buildCollectionsPanel(context, cardWidth: cardWidth),
                  ),
                ],
              ),
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildCollectionsPanel(BuildContext context,
      {required double cardWidth}) {
    if (_loadingCollections) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(PinitColors.aubergine),
          ),
        ),
      );
    }

    final items = _groupedItems;

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'No eat-lists found — you can always explore them later.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PinitColors.aubergineSoft,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final c = items[index];
        final saving = _savingCollectionId == c.collectionId;
        return _ExploreCollectionCard(
          collection: c,
          saving: saving,
          onToggleSave: () => _toggleSaveCollection(c),
          onTap: () => _openCollectionDetail(c),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
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
      child: Row(
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
                "Let's go!",
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
    );
  }
}

class _CityPills extends StatelessWidget {
  final List<String> cities;
  final String selected;
  final ValueChanged<String> onSelected;

  const _CityPills({
    required this.cities,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final city = cities[i];
          final isActive = city == selected;
          return GestureDetector(
            onTap: () => onSelected(city),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isActive ? PinitColors.aubergine : PinitColors.creamSunk,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive ? PinitColors.black : PinitColors.creamDeep,
                  width: 1.5,
                ),
                boxShadow: isActive
                    ? const [
                        BoxShadow(
                          color: PinitColors.black,
                          blurRadius: 0,
                          offset: Offset(2, 2),
                        )
                      ]
                    : null,
              ),
              child: Text(
                city.toUpperCase(),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color:
                      isActive ? PinitColors.cream : PinitColors.aubergine,
                  letterSpacing: 1.0,
                  height: 1.0,
                ),
              ),
            ),
          );
        },
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
                                  color: pinit.PinitColors.aubergine,
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

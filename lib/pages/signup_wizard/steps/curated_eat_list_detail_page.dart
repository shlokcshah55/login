import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/providers/navigation_provider.dart';
import 'package:login/supabase/helpers/collections.dart';
import 'package:login/widgets/feedback/app_feedback.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:provider/provider.dart';

class CuratedEatListDetailPage extends StatefulWidget {
  final CollectionItem collection;

  const CuratedEatListDetailPage({
    super.key,
    required this.collection,
  });

  @override
  State<CuratedEatListDetailPage> createState() =>
      _CuratedEatListDetailPageState();
}

class _CuratedEatListDetailPageState extends State<CuratedEatListDetailPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  bool _isLoading = true;
  bool _isShowingOnMap = false;
  List<LocationModel> _locations = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final locs = await CollectionsHelper()
          .getLocationsForCollection(widget.collection.collectionId);
      if (!mounted) return;
      setState(() {
        _locations = locs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<LocationModel> get _visibleLocations {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _locations;
    return _locations
        .where((l) => l.name.toLowerCase().contains(q))
        .toList(growable: false);
  }

  Future<void> _showOnMap() async {
    if (_isShowingOnMap || _isLoading) return;
    final valid = _locations.where((l) => l.position != null).toList();
    if (valid.isEmpty) {
      unawaited(
        AppFeedback.showError(
          context,
          title: 'Nothing to map',
          message: 'No mappable places in this eat-list yet.',
        ),
      );
      return;
    }

    setState(() => _isShowingOnMap = true);
    try {
      final navigationProvider = context.read<NavigationProvider>();

      if (!mounted) return;
      navigationProvider
          .navigateToCollectionMapOnly(widget.collection.collectionId);
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isShowingOnMap = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleLocations;

    return Scaffold(
      backgroundColor: PinitColors.cream,
      appBar: AppBar(
        backgroundColor: PinitColors.cream,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Icon(
              FeatherIcons.arrowLeft,
              color: PinitColors.aubergine,
              size: 24,
            ),
          ),
        ),
        title: Text(
          widget.collection.name,
          style: const TextStyle(
            fontFamily: 'Rova',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: PinitColors.aubergine,
            letterSpacing: 0.6,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    textInputAction: TextInputAction.search,
                    cursorColor: PinitColors.aubergine,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PinitColors.aubergine,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by name',
                      hintStyle: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: PinitColors.mute,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: PinitColors.aubergineSoft,
                      ),
                      suffixIcon: _query.trim().isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: PinitColors.aubergineSoft,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      fillColor: PinitColors.creamSunk,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: PinitColors.creamDeep,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: PinitColors.aubergine,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isShowingOnMap ? null : _showOnMap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: PinitColors.aubergine,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: PinitColors.black,
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: PinitColors.black,
                          blurRadius: 0,
                          offset: Offset(3, 3),
                        ),
                      ],
                    ),
                    child: _isShowingOnMap
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  PinitColors.cream),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.map_outlined,
                                size: 14,
                                color: PinitColors.cream,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'SHOW',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: PinitColors.cream,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(PinitColors.aubergine),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: PinitColors.mute,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : visible.isEmpty
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 40, 24, 40),
                              child: Text(
                                'No matches.',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: PinitColors.mute,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                            itemCount: visible.length,
                            itemBuilder: (context, index) =>
                                _LocationTile(location: visible[index]),
                          ),
          ),
        ],
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  final LocationModel location;
  const _LocationTile({required this.location});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel:
              MaterialLocalizations.of(context).modalBarrierDismissLabel,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (ctx, anim, _) => ExpandedLocationCard(
            location: location,
            onClose: () => Navigator.of(ctx).pop(),
          ),
          transitionBuilder: (ctx, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 110,
        decoration: BoxDecoration(
          color: PinitColors.cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: PinitColors.aubergine,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: PinitColors.aubergine,
              blurRadius: 0,
              offset: Offset(3, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(10)),
              child: SizedBox(
                width: 110,
                height: 110,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: PinitColors.creamSunk,
                    image:
                        (location.imageUrl ?? location.photoReference) != null
                            ? DecorationImage(
                                image: NetworkImage(
                                  location.imageUrl ?? location.photoReference!,
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                  ),
                  child: (location.imageUrl ?? location.photoReference) == null
                      ? Center(
                          child: Text(
                            location.emoji ?? '📍',
                            style: const TextStyle(fontSize: 32),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            Container(width: 1.5, color: PinitColors.aubergine),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: PinitColors.aubergine,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle(location),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PinitColors.aubergineSoft,
                        height: 1.25,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (location.rating != null) ...[
                          const Icon(Icons.star_rounded,
                              size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            location.rating!.toStringAsFixed(1),
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (location.priceLevel != null &&
                            (location.priceLevel ?? 0) > 0)
                          Text(
                            '£' * location.priceLevel!,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: PinitColors.mute,
                            ),
                          ),
                      ],
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

  String _subtitle(LocationModel location) {
    if (location.generatedSummary?.isNotEmpty == true)
      return location.generatedSummary!;
    if (location.editorialSummary?.isNotEmpty == true)
      return location.editorialSummary!;
    if (location.vicinity?.isNotEmpty == true) return location.vicinity!;
    return ' ';
  }
}

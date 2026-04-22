import 'dart:io';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:login/models/locations.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/navigation_provider.dart';
import 'package:login/supabase/helpers/collections.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'package:login/widgets/feedback/app_feedback.dart';
import 'package:provider/provider.dart';

import 'pinit_colors.dart';

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

class CollectionModel {
  final String id;
  final String name;
  final int placeCount;
  final String? emoji;
  final String? coverColor;
  final String? photo;
  final String? ownerName;
  final String? ownerAvatarUrl;

  CollectionModel({
    required this.id,
    required this.name,
    this.placeCount = 0,
    this.emoji,
    this.coverColor,
    this.photo,
    this.ownerName,
    this.ownerAvatarUrl,
  });

  factory CollectionModel.fromItem(CollectionItem item) => CollectionModel(
        id: item.collectionId,
        name: item.name,
        placeCount: item.placeCount,
        emoji: item.emoji,
        coverColor: item.coverColor,
        photo: item.photo,
        ownerName: item.ownerName,
        ownerAvatarUrl: item.ownerAvatarUrl,
      );
}

class CollectionsGrid extends StatefulWidget {
  final bool generatedCollections;
  final VoidCallback? onImportNotes;

  const CollectionsGrid({
    Key? key,
    this.generatedCollections = false,
    this.onImportNotes,
  }) : super(key: key);

  @override
  State<CollectionsGrid> createState() => _CollectionsGridState();
}

class _CollectionsGridState extends State<CollectionsGrid>
    with SingleTickerProviderStateMixin {
  final List<CollectionModel> _collections = [];
  final List<CollectionModel> _friendCollections = [];
  final CollectionsHelper _helper = CollectionsHelper();

  bool _isLoading = false;
  bool _isGenerating = false;
  String? _loadError;
  late bool _hasGenerated;

  late AnimationController _fillController;
  late Animation<double> _fillAnimation;

  @override
  void initState() {
    super.initState();
    _hasGenerated = widget.generatedCollections;
    debugPrint(
        '[CollectionsGrid] initState called, hasGenerated=$_hasGenerated');

    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    _fillAnimation = Tween<double>(begin: 0.0, end: 0.85).animate(
      CurvedAnimation(parent: _fillController, curve: Curves.easeInOut),
    );

    _loadCollections();
  }

  @override
  void dispose() {
    _fillController.dispose();
    super.dispose();
  }

  Future<void> _loadCollections() async {
    debugPrint('[CollectionsGrid] _loadCollections called');
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) {
      debugPrint('[CollectionsGrid] no authenticated user, skipping');
      return;
    }
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _helper.getUserCollections(userId),
        _helper.getFriendsCollections(userId),
      ]);
      if (mounted) {
        setState(() {
          _collections.clear();
          _collections.addAll(results[0].map(CollectionModel.fromItem));
          _friendCollections.clear();
          _friendCollections.addAll(results[1].map(CollectionModel.fromItem));
        });
      }
    } catch (e) {
      debugPrint('[CollectionsGrid] loadCollections error: $e');
      if (mounted) setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openEditSheet(CollectionModel collection) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditCollectionSheet(
        collection: collection,
        onSaved: _loadCollections,
      ),
    );
  }

  void _openCreateCollectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateCollectionSheet(
        onCreated: (name) async {
          await _loadCollections();
        },
      ),
    );
  }

  Future<void> _onGenerateButtonTap() async {
    final authUser = SupabaseClientManager().currentUser;
    if (authUser == null) return;

    setState(() => _isGenerating = true);
    _fillController.forward(from: 0.0);

    try {
      await (_hasGenerated
          ? _helper.autoUpdateCollections(authUser.id)
          : _helper.generateCollections(authUser.id));

      if (mounted) {
        context.read<LocationListManager>().invalidateAllCollectionCaches();
      }
      if (!_hasGenerated && mounted) setState(() => _hasGenerated = true);

      // Snap to 100% on success
      _fillController.animateTo(1.0,
          duration: const Duration(milliseconds: 300));
      await Future.delayed(const Duration(milliseconds: 350));

      await _loadCollections();
    } on CollectionsGenerationException catch (e) {
      if (mounted) {
        _fillController.stop();
        unawaited(
          AppFeedback.showError(
            context,
            title: 'Couldn’t generate',
            message: e.message,
          ),
        );
      }
    } catch (e) {
      debugPrint('[CollectionsGrid] generate error: $e');
      if (mounted) {
        _fillController.stop();
        unawaited(
          AppFeedback.showError(
            context,
            message: 'Something went wrong. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        _fillController.reset();
      }
    }
  }

  Widget _buildGrid(List<CollectionModel> collections,
      {bool showOwner = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: collections.length,
        itemBuilder: (context, index) => _CollectionCard(
          collection: collections[index],
          showOwner: showOwner,
          onEdit: showOwner ? null : () => _openEditSheet(collections[index]),
          onDeleted: showOwner ? null : _loadCollections,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onImportNotes != null) ...[
                GestureDetector(
                  onTap: widget.onImportNotes,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: PinitColors.aubergine,
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: PinitColors.aubergine,
                          blurRadius: 0,
                          offset: Offset(4, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18.5),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: PinitColors.creamSunk,
                        child: Row(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: PinitColors.cream,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: PinitColors.creamDeep,
                                  width: 1.2,
                                ),
                              ),
                              child: Image.asset(
                                'lib/assets/upload.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Import notes',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: PinitColors.aubergine,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pull places from Apple Notes or Notion',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      color: PinitColors.aubergineSoft,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              FeatherIcons.chevronRight,
                              size: 16,
                              color: PinitColors.aubergineSoft,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Text(
                      'Your Eat-Lists',
                      style: TextStyle(
                        fontFamily: 'Rova',
                        fontSize: 24,
                        fontWeight: FontWeight.w100,
                        color: PinitColors.aubergine,
                        letterSpacing: 1.2,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      // Generate button
                      GestureDetector(
                        onTap: _isGenerating ? null : _onGenerateButtonTap,
                        child: AnimatedBuilder(
                          animation: _fillAnimation,
                          builder: (context, child) {
                            final label = _isGenerating
                                ? (_hasGenerated
                                    ? 'Updating...'
                                    : 'Generating...')
                                : (_hasGenerated ? 'Update' : 'Generate');

                            Widget buildLabel(
                              Color iconColor,
                              Color textColor,
                            ) =>
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        FeatherIcons.zap,
                                        size: 13,
                                        color: iconColor,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        label,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: PinitColors.creamSunk,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _isGenerating
                                        ? PinitColors.aubergine
                                        : PinitColors.creamDeep,
                                    width: 1.5,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    buildLabel(
                                      PinitColors.aubergine,
                                      PinitColors.aubergine,
                                    ),
                                    if (_isGenerating)
                                      ClipRect(
                                        clipper:
                                            _FillClipper(_fillAnimation.value),
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: Container(
                                                color: PinitColors.aubergine,
                                              ),
                                            ),
                                            buildLabel(
                                              PinitColors.cream,
                                              PinitColors.cream,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _openCreateCollectionSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: PinitColors.aubergine,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                FeatherIcons.plus,
                                size: 13,
                                color: PinitColors.cream,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'New',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: PinitColors.cream,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Content
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_loadError != null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(FeatherIcons.alertCircle,
                    color: Colors.red, size: 28),
                const SizedBox(height: 12),
                const Text(
                  'Failed to load eat-lists',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: PinitColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _loadError!,
                  style: const TextStyle(
                      fontSize: 13, color: PinitColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _loadCollections,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: PinitColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Retry',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          )
        else if (_collections.isEmpty)
          _EmptyCollections(onCreateTap: _openCreateCollectionSheet)
        else
          _buildGrid(_collections),

        // ── Explore ──
        if (!_isLoading && _friendCollections.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Explore Eat-Lists',
                  style: TextStyle(
                    fontFamily: 'Rova',
                    fontSize: 24,
                    fontWeight: FontWeight.w100,
                    color: PinitColors.aubergine,
                    letterSpacing: 1.2,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          _buildGrid(_friendCollections, showOwner: true),
        ],
      ],
    );
  }
}

class _CreateCollectionSheet extends StatefulWidget {
  final void Function(String name) onCreated;

  const _CreateCollectionSheet({required this.onCreated});

  @override
  State<_CreateCollectionSheet> createState() => _CreateCollectionSheetState();
}

class _CreateCollectionSheetState extends State<_CreateCollectionSheet> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;

  bool get _canCreate => _nameController.text.trim().isNotEmpty && !_isSaving;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await SupabaseClientManager().client.rpc('create_collection', params: {
        'p_name': name,
        'p_is_public': true,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated(name);
      }
    } catch (e) {
      debugPrint('[CreateCollectionSheet] error: $e');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: PinitColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PinitColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'New Eat-List',
              style: TextStyle(
                fontFamily: 'Rova',
                fontSize: 28,
                fontWeight: FontWeight.w200,
                color: PinitColors.aubergine,
                letterSpacing: 1.5,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 24),

            // Name field
            const Text(
              'Name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PinitColors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                fontSize: 16,
                color: PinitColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. First date spots',
                hintStyle: TextStyle(
                  color: PinitColors.textMuted.withValues(alpha: 0.6),
                  fontWeight: FontWeight.normal,
                ),
                filled: true,
                fillColor: PinitColors.surfaceLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: PinitColors.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),

            // Restaurant search — coming soon placeholder
            const Text(
              'Restaurants',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PinitColors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: PinitColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: PinitColors.textMuted.withValues(alpha: 0.15),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    FeatherIcons.search,
                    size: 16,
                    color: PinitColors.textMuted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Search restaurants — coming soon',
                    style: TextStyle(
                      fontSize: 15,
                      color: PinitColors.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Create button
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _canCreate ? _submit : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _canCreate
                        ? PinitColors.aubergine
                        : PinitColors.creamDeep,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: PinitColors.cream,
                            ),
                          )
                        : Text(
                            'Create Eat-List',
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _canCreate
                                  ? PinitColors.cream
                                  : PinitColors.mute,
                            ),
                          ),
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

class _CollectionCard extends StatelessWidget {
  final CollectionModel collection;
  final bool showOwner;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;

  const _CollectionCard({
    required this.collection,
    this.showOwner = false,
    this.onEdit,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final assetPath = _kCollectionAssets[collection.name];

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => CollectionDetailSheet(
          collection: collection,
          onEdit: onEdit,
          onDeleted: onDeleted,
        ),
      ),
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
                // ── Image (top ~65%) ──
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImage(
                          assetPath, collection.coverColor, collection.photo),
                      if (onEdit != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: onEdit,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                FeatherIcons.edit2,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Solid label area (bottom) ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Owner name — shown prominently at top for friend collections
                      if (showOwner && collection.ownerName != null) ...[
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
                                child: const Icon(Icons.person,
                                    size: 11, color: PinitColors.mute),
                              ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                collection.ownerName!,
                                style: const TextStyle(
                                  fontFamily: 'Rova',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: PinitColors.aubergine,
                                  letterSpacing: 0.4,
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
                          fontSize: showOwner ? 12 : 15,
                          fontWeight:
                              showOwner ? FontWeight.w500 : FontWeight.w700,
                          color: showOwner
                              ? PinitColors.aubergineSoft
                              : PinitColors.aubergine,
                          letterSpacing: showOwner ? 0 : 0.3,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${collection.placeCount} place${collection.placeCount == 1 ? "" : "s"}',
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

  Widget _buildImage(
      String? assetPath, String? coverColor, String? networkPhoto) {
    final svgAsset = _kCollectionSvgAssets[collection.name];
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
    // coverColor may hold a user-uploaded photo URL
    final photoUrl = coverColor ?? networkPhoto;
    if (photoUrl != null) {
      return CachedNetworkImage(
        imageUrl: photoUrl,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }
    // Fallback: placeholder
    return Container(
      color: PinitColors.creamDeep,
      child: const Center(
        child: Icon(FeatherIcons.bookmark, size: 28, color: PinitColors.mute),
      ),
    );
  }
}

class _EmptyCollections extends StatelessWidget {
  final VoidCallback onCreateTap;

  const _EmptyCollections({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        children: [
          SvgPicture.asset(
            'lib/assets/illustrations/Beep Beep - Large Vehicle.svg',
            height: 180,
          ),
          const SizedBox(height: 24),
          const Text(
            'Waiting for your first eat-list...',
            style: TextStyle(
              fontFamily: 'Rova',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: PinitColors.aubergine,
              letterSpacing: 1.0,
              height: 1.05,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'We know you have great taste - Create an eat-list to organise your saved places and share them with your friends!',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: PinitColors.aubergineSoft,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onCreateTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: PinitColors.aubergine,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Create an eat-list',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: PinitColors.cream,
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
//  Collection detail bottom sheet
// ─────────────────────────────────────────────────────────────

class CollectionDetailSheet extends StatefulWidget {
  final CollectionModel collection;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;
  const CollectionDetailSheet({
    required this.collection,
    this.onEdit,
    this.onDeleted,
  });

  @override
  State<CollectionDetailSheet> createState() => CollectionDetailSheetState();
}

// Auto-generated collections that the user is not allowed to delete.
const Set<String> _kUndeletableCollectionNames = {'Been To', 'Shared Finds'};

class CollectionDetailSheetState extends State<CollectionDetailSheet> {
  final CollectionsHelper _helper = CollectionsHelper();
  List<LocationModel> _locations = [];
  bool _isLoading = true;
  bool _showingOnMap = false;
  bool _isDeleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final locs =
          await _helper.getLocationsForCollection(widget.collection.id);
      if (mounted)
        setState(() {
          _locations = locs;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
    }
  }

  Future<void> _confirmAndDelete() async {
    if (_isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete eat-list?'),
        content: Text(
          'This will permanently delete "${widget.collection.name}" and remove all its places from the eat-list. Your saved places themselves are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await _helper.deleteCollection(widget.collection.id);
      if (!mounted) return;
      context
          .read<LocationListManager>()
          .invalidateCollectionCache(widget.collection.id);
      Navigator.of(context).pop();
      widget.onDeleted?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      unawaited(
        AppFeedback.showError(
          context,
          title: 'Couldn’t delete',
          message: 'Failed to delete eat-list.',
        ),
      );
    }
  }

  Future<void> _showInMap() async {
    if (_showingOnMap || _isLoading) return;

    final validLocations =
        _locations.where((location) => location.position != null).toList();

    if (validLocations.isEmpty) {
      unawaited(
        AppFeedback.showError(
          context,
          title: 'Nothing to map',
          message: 'No mappable places in this eat-list yet.',
        ),
      );
      return;
    }

    setState(() => _showingOnMap = true);
    try {
      final locationListManager = context.read<LocationListManager>();
      final mapStateProvider = context.read<MapStateProvider>();
      final navigationProvider = context.read<NavigationProvider>();

      final shown = await locationListManager.showCollectionLocations(
        widget.collection.id,
        () async => validLocations,
      );
      final toFocus = shown.isNotEmpty ? shown : validLocations;
      mapStateProvider.setSelectedMarkerId(
        toFocus.first.locationId.toString(),
      );
      await mapStateProvider.focusOnLocations(toFocus);

      if (!mounted) return;
      navigationProvider.navigateToTab(0);
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _showingOnMap = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: PinitColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle + header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: PinitColors.textMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (widget.collection.emoji != null)
                        Text(widget.collection.emoji!,
                            style: const TextStyle(fontSize: 28)),
                      if (widget.collection.emoji != null)
                        const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.collection.name,
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: PinitColors.aubergine,
                                letterSpacing: -0.3,
                                height: 1.2,
                              ),
                            ),
                            Text(
                              '${widget.collection.placeCount} place${widget.collection.placeCount == 1 ? "" : "s"}',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: PinitColors.aubergineSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onEdit != null)
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            widget.onEdit!();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: PinitColors.creamSunk,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: PinitColors.aubergine
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Icon(
                              FeatherIcons.edit2,
                              size: 15,
                              color: PinitColors.aubergine,
                            ),
                          ),
                        ),
                      if (widget.onDeleted != null &&
                          !_kUndeletableCollectionNames
                              .contains(widget.collection.name)) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _isDeleting ? null : _confirmAndDelete,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: PinitColors.creamSunk,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.35),
                              ),
                            ),
                            child: _isDeleting
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.red,
                                    ),
                                  )
                                : const Icon(
                                    FeatherIcons.trash2,
                                    size: 15,
                                    color: Colors.red,
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _showInMap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: PinitColors.aubergine,
                              borderRadius: BorderRadius.circular(999),
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
                            child: Center(
                              child: _showingOnMap
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          PinitColors.cream,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'SHOW IN MAP',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: PinitColors.cream,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(
                      color: PinitColors.textMuted.withValues(alpha: 0.12),
                      height: 1),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                  color: PinitColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _locations.isEmpty
                          ? const Center(
                              child: Text(
                                'No places in this eat-list yet.',
                                style:
                                    TextStyle(color: PinitColors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: EdgeInsets.fromLTRB(
                                  20, 16, 20, 20 + bottomPadding),
                              itemCount: _locations.length,
                              itemBuilder: (_, i) =>
                                  _LocationRow(location: _locations[i]),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Location row — mirrors _TrendingCard in trending_now_section
// ─────────────────────────────────────────────────────────────

class _LocationRow extends StatelessWidget {
  final LocationModel location;
  const _LocationRow({required this.location});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showGeneralDialog(
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
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: PinitColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: PinitColors.cardShadow,
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImage(context),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.45),
                            ],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                    if (location.openNow != null)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: location.openNow!
                                ? const Color(0xFF00B894)
                                : const Color(0xFFE17055),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: const TextStyle(
                        fontFamily: 'Rova',
                        fontSize: 16,
                        fontWeight: FontWeight.w100,
                        color: PinitColors.aubergine,
                        letterSpacing: 0.5,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_summary != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        _summary!,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: PinitColors.aubergineSoft,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (location.priceLevel != null &&
                            location.priceLevel! > 0) ...[
                          _Pill(
                            text: '£' * location.priceLevel!,
                            bgColor:
                                const Color(0xFF00B894).withValues(alpha: 0.12),
                            textColor: const Color(0xFF00B894),
                            fontWeight: FontWeight.w800,
                          ),
                          const SizedBox(width: 5),
                        ],
                        if (location.cuisine != null &&
                            location.cuisine!.isNotEmpty)
                          _Pill(
                            text: location.cuisine!,
                            bgColor: PinitColors.surfaceLight,
                            textColor: PinitColors.textSecondary,
                          ),
                        const Spacer(),
                        if (location.rating != null)
                          _RatingChip(rating: location.rating!),
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

  String? get _summary {
    if (location.generatedSummary?.isNotEmpty == true)
      return location.generatedSummary;
    if (location.editorialSummary?.isNotEmpty == true)
      return location.editorialSummary;
    if (location.vicinity?.isNotEmpty == true) return location.vicinity;
    return null;
  }

  Widget _buildImage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = location.imageUrl ?? location.photoReference;
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: cs.surfaceContainerHighest),
        errorWidget: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
        color: PinitColors.surfaceLight,
        child: Center(
          child: Text(location.emoji ?? '📍',
              style: const TextStyle(fontSize: 28)),
        ),
      );
}

class _RatingChip extends StatelessWidget {
  final double rating;
  const _RatingChip({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: Colors.amber.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Color(0xFFF59E0B),
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(FeatherIcons.star, size: 9, color: Color(0xFFF59E0B)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;
  final FontWeight fontWeight;

  const _Pill({
    required this.text,
    required this.bgColor,
    required this.textColor,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: fontWeight,
          fontSize: 10.5,
          letterSpacing: 0.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Edit collection bottom sheet
// ─────────────────────────────────────────────────────────────

class _EditCollectionSheet extends StatefulWidget {
  final CollectionModel collection;
  final Future<void> Function() onSaved;

  const _EditCollectionSheet({required this.collection, required this.onSaved});

  @override
  State<_EditCollectionSheet> createState() => _EditCollectionSheetState();
}

class _EditCollectionSheetState extends State<_EditCollectionSheet> {
  late final TextEditingController _nameController;
  final CollectionsHelper _helper = CollectionsHelper();
  final ImagePicker _picker = ImagePicker();

  File? _pendingPhoto;
  bool _saving = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.collection.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() {
          _pendingPhoto = File(picked.path);
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load image.');
    }
  }

  Future<void> _confirmAndDelete() async {
    if (_deleting || _saving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete eat-list?'),
        content: Text(
          'This will permanently delete "${widget.collection.name}" and remove all its places from the eat-list. Your saved places themselves are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await _helper.deleteCollection(widget.collection.id);
      if (!mounted) return;
      context
          .read<LocationListManager>()
          .invalidateCollectionCache(widget.collection.id);
      Navigator.pop(context);
      await widget.onSaved();
    } catch (e) {
      debugPrint('[EditCollectionSheet] delete error: $e');
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = 'Could not delete eat-list. Please try again.';
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      String? coverUrl = widget.collection.coverColor;

      if (_pendingPhoto != null) {
        coverUrl = await _helper.uploadCollectionCover(
          widget.collection.id,
          _pendingPhoto!,
        );
      }

      await _helper.updateCollection(
        collectionId: widget.collection.id,
        name: name,
        coverColor: coverUrl,
      );

      if (mounted) {
        Navigator.pop(context);
        await widget.onSaved();
      }
    } catch (e) {
      debugPrint('[EditCollectionSheet] error: $e');
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'Something went wrong. Please try again.';
        });
    }
  }

  Widget _buildCoverPreview() {
    final assetPath = _kCollectionAssets[widget.collection.name];
    final svgAsset = _kCollectionSvgAssets[widget.collection.name];

    Widget image;
    if (_pendingPhoto != null) {
      image = Image.file(_pendingPhoto!, fit: BoxFit.cover);
    } else if (svgAsset != null) {
      image = SvgPicture.asset(svgAsset, fit: BoxFit.cover);
    } else if (assetPath != null) {
      image = Image.asset(assetPath, fit: BoxFit.cover);
    } else {
      final photoUrl = widget.collection.coverColor ?? widget.collection.photo;
      if (photoUrl != null) {
        image = CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover);
      } else {
        image = Container(
          color: PinitColors.creamDeep,
          child: const Center(
            child: Icon(FeatherIcons.image, size: 32, color: PinitColors.mute),
          ),
        );
      }
    }

    return GestureDetector(
      onTap: _saving ? null : _pickFromGallery,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 160,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(FeatherIcons.camera,
                        color: Colors.white, size: 24),
                    const SizedBox(height: 6),
                    Text(
                      _pendingPhoto != null
                          ? 'Change Photo'
                          : 'Add Cover Photo',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final canSave = _nameController.text.trim().isNotEmpty && !_saving;

    return Container(
      decoration: const BoxDecoration(
        color: PinitColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PinitColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'Edit Eat-List',
              style: TextStyle(
                fontFamily: 'Rova',
                fontSize: 28,
                fontWeight: FontWeight.w200,
                color: PinitColors.aubergine,
                letterSpacing: 1.5,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 24),

            // Cover photo
            const Text(
              'Cover Photo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PinitColors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            _buildCoverPreview(),
            const SizedBox(height: 20),

            // Name field
            const Text(
              'Name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PinitColors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                fontSize: 16,
                color: PinitColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Eat-list name',
                hintStyle: TextStyle(
                  color: PinitColors.textMuted.withValues(alpha: 0.6),
                  fontWeight: FontWeight.normal,
                ),
                filled: true,
                fillColor: PinitColors.surfaceLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: PinitColors.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: Colors.red),
              ),
            ],

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: canSave ? _save : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color:
                        canSave ? PinitColors.aubergine : PinitColors.creamDeep,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: PinitColors.cream,
                            ),
                          )
                        : Text(
                            'Save',
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: canSave
                                  ? PinitColors.cream
                                  : PinitColors.mute,
                            ),
                          ),
                  ),
                ),
              ),
            ),

            // Delete button (hidden for auto-generated collections)
            if (!_kUndeletableCollectionNames
                .contains(widget.collection.name)) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: (_saving || _deleting) ? null : _confirmAndDelete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: _deleting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  FeatherIcons.trash2,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Delete Eat-List',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
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
  }
}

class _FillClipper extends CustomClipper<Rect> {
  final double progress;
  _FillClipper(this.progress);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress, size.height);

  @override
  bool shouldReclip(_FillClipper old) => old.progress != progress;
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:login/models/locations.dart';
import 'package:login/supabase/helpers/collections.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/widgets/home/expanded_location_card.dart';
import 'pinit_colors.dart';

// Maps auto-generated collection labels to their bundled asset paths.
const Map<String, String> _kCollectionAssets = {
  'Date Night 🌹':       'lib/assets/collection/date_night.png',
  'Brunch O\'Clock 🍳':  'lib/assets/collection/lunch.png',
  'On The Run 🏃':       'lib/assets/collection/lunch.png',
  'Midnight Munchies 🌙':'lib/assets/collection/midnight.png',
  'Grab A Coffee ☕':    'lib/assets/collection/coffee.png',
  'Drinks Up 🍻':        'lib/assets/collection/pub.png',
  'Outside Outside ☀️':  'lib/assets/collection/summer.png',
};

class CollectionModel {
  final String id;
  final String name;
  final int placeCount;
  final String? emoji;
  final String? coverColor;
  final String? photo;

  CollectionModel({
    required this.id,
    required this.name,
    this.placeCount = 0,
    this.emoji,
    this.coverColor,
    this.photo,
  });

  factory CollectionModel.fromItem(CollectionItem item) => CollectionModel(
        id: item.collectionId,
        name: item.name,
        placeCount: item.placeCount,
        emoji: item.emoji,
        coverColor: item.coverColor,
        photo: item.photo,
      );
}

class CollectionsGrid extends StatefulWidget {
  final bool generatedCollections;

  const CollectionsGrid({Key? key, this.generatedCollections = false})
      : super(key: key);

  @override
  State<CollectionsGrid> createState() => _CollectionsGridState();
}

class _CollectionsGridState extends State<CollectionsGrid> {
  final List<CollectionModel> _collections = [];
  final CollectionsHelper _helper = CollectionsHelper();

  bool _isLoading = false;
  bool _isGenerating = false;
  String? _loadError;
  late bool _hasGenerated;

  @override
  void initState() {
    super.initState();
    _hasGenerated = widget.generatedCollections;
    debugPrint('[CollectionsGrid] initState called, hasGenerated=$_hasGenerated');
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    debugPrint('[CollectionsGrid] _loadCollections called');
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) {
      debugPrint('[CollectionsGrid] no authenticated user, skipping');
      return;
    }
    setState(() { _isLoading = true; _loadError = null; });
    try {
      final items = await _helper.getUserCollections(userId);
      if (mounted) {
        setState(() {
          _collections.clear();
          _collections.addAll(items.map(CollectionModel.fromItem));
        });
      }
    } catch (e) {
      debugPrint('[CollectionsGrid] loadCollections error: $e');
      if (mounted) setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    try {
      final result = _hasGenerated
          ? await _helper.autoUpdateCollections(authUser.id)
          : await _helper.generateCollections(authUser.id);

      if (!_hasGenerated && mounted) setState(() => _hasGenerated = true);

      await _loadCollections();
      if (mounted) {
        final count = result.collectionsCreated;
        final label = _hasGenerated ? 'Updated' : 'Generated';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$label $count collection${count == 1 ? "" : "s"}!'),
          backgroundColor: PinitColors.primary,
        ));
      }
    } on CollectionsGenerationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      debugPrint('[CollectionsGrid] generate error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Collections',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: PinitColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              // Generate from Saved button
              GestureDetector(
                onTap: _isGenerating ? null : _onGenerateButtonTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: PinitColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: PinitColors.primary.withValues(alpha: _isGenerating ? 0.1 : 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isGenerating)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PinitColors.primary,
                          ),
                        )
                      else
                        const Icon(
                          FeatherIcons.zap,
                          size: 14,
                          color: PinitColors.primary,
                        ),
                      const SizedBox(width: 5),
                      Text(
                        _isGenerating
                            ? (_hasGenerated ? 'Updating...' : 'Generating...')
                            : (_hasGenerated ? 'Auto-update lists' : 'Generate'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PinitColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // New collection button
              GestureDetector(
                onTap: _openCreateCollectionSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: PinitColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FeatherIcons.plus, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'New',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
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
                const Icon(FeatherIcons.alertCircle, color: Colors.red, size: 28),
                const SizedBox(height: 12),
                const Text(
                  'Failed to load collections',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: PinitColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _loadError!,
                  style: const TextStyle(fontSize: 13, color: PinitColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _loadCollections,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: PinitColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          )
        else if (_collections.isEmpty)
          _EmptyCollections(onCreateTap: _openCreateCollectionSheet)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              itemCount: _collections.length,
              itemBuilder: (context, index) {
                final collection = _collections[index];
                return _CollectionCard(collection: collection);
              },
            ),
          ),
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
                  color: PinitColors.textMuted.withValues(alpha:0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'New Collection',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: PinitColors.textPrimary,
                letterSpacing: -0.4,
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
                  color: PinitColors.textMuted.withValues(alpha:0.6),
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
                    color: PinitColors.primary.withValues(alpha:0.5),
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
                  color: PinitColors.textMuted.withValues(alpha:0.15),
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
                      color: PinitColors.textMuted.withValues(alpha:0.5),
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
                    gradient: _canCreate ? PinitColors.primaryGradient : null,
                    color: _canCreate ? null : PinitColors.textMuted.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Create Collection',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _canCreate ? Colors.white : PinitColors.textMuted,
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

  const _CollectionCard({required this.collection});

  @override
  Widget build(BuildContext context) {
    final assetPath = _kCollectionAssets[collection.name];
    final networkPhoto = collection.photo;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CollectionDetailSheet(collection: collection),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background photo
            if (assetPath != null)
              Image.asset(assetPath, fit: BoxFit.cover)
            else if (networkPhoto != null)
              CachedNetworkImage(imageUrl: networkPhoto, fit: BoxFit.cover)
            else
              Container(
                decoration: BoxDecoration(
                  gradient: PinitColors.primaryGradient,
                ),
              ),

            // Dark gradient overlay for text readability
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),

            // Text at bottom
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    collection.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${collection.placeCount} place${collection.placeCount == 1 ? "" : "s"}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCollections extends StatelessWidget {
  final VoidCallback onCreateTap;

  const _EmptyCollections({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: PinitColors.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: PinitColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(
                FeatherIcons.bookmark,
                size: 28,
                color: PinitColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No collections yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: PinitColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Organise your pins into themed collections',
            style: TextStyle(
              fontSize: 14,
              color: PinitColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onCreateTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: PinitColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Create your first collection',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
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

class _CollectionDetailSheet extends StatefulWidget {
  final CollectionModel collection;
  const _CollectionDetailSheet({required this.collection});

  @override
  State<_CollectionDetailSheet> createState() => _CollectionDetailSheetState();
}

class _CollectionDetailSheetState extends State<_CollectionDetailSheet> {
  final CollectionsHelper _helper = CollectionsHelper();
  List<LocationModel> _locations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final locs = await _helper.getLocationsForCollection(widget.collection.id);
      if (mounted) setState(() { _locations = locs; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
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
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: PinitColors.textPrimary,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              '${widget.collection.placeCount} place${widget.collection.placeCount == 1 ? "" : "s"}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: PinitColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: PinitColors.textMuted.withValues(alpha: 0.12), height: 1),
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
                              style: const TextStyle(color: PinitColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _locations.isEmpty
                          ? const Center(
                              child: Text(
                                'No places in this collection yet.',
                                style: TextStyle(color: PinitColors.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPadding),
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
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
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
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PinitColors.textPrimary,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_summary != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        _summary!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PinitColors.textSecondary,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (location.priceLevel != null && location.priceLevel! > 0) ...[
                          _Pill(
                            text: '£' * location.priceLevel!,
                            bgColor: const Color(0xFF00B894).withValues(alpha: 0.12),
                            textColor: const Color(0xFF00B894),
                            fontWeight: FontWeight.w800,
                          ),
                          const SizedBox(width: 5),
                        ],
                        if (location.cuisine != null && location.cuisine!.isNotEmpty)
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
    if (location.generatedSummary?.isNotEmpty == true) return location.generatedSummary;
    if (location.editorialSummary?.isNotEmpty == true) return location.editorialSummary;
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
          child: Text(location.emoji ?? '📍', style: const TextStyle(fontSize: 28)),
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
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25), width: 0.5),
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

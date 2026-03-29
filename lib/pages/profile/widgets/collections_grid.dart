import 'package:flutter/material.dart';
import 'pinit_colors.dart';

class CollectionModel {
  final String id;
  final String name;
  final List<int> locationIds;

  CollectionModel({
    required this.id,
    required this.name,
    this.locationIds = const [],
  });
}

class CollectionsGrid extends StatefulWidget {
  const CollectionsGrid({Key? key}) : super(key: key);

  @override
  State<CollectionsGrid> createState() => _CollectionsGridState();
}

class _CollectionsGridState extends State<CollectionsGrid> {
  final List<CollectionModel> _collections = [];

  void _openCreateCollectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateCollectionSheet(
        onCreated: (name) {
          setState(() {
            _collections.add(CollectionModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
            ));
          });
        },
      ),
    );
  }

  void _generateFromSaved() {
    // TODO: implement AI-generated collections from saved pins
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
                onTap: _generateFromSaved,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: PinitColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: PinitColors.primary.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 15,
                        color: PinitColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Generate',
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add, size: 15, color: Colors.white),
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
        if (_collections.isEmpty)
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
  bool get _canCreate => _nameController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context);
    widget.onCreated(name);
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
                  color: PinitColors.textMuted.withOpacity(0.3),
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
                  color: PinitColors.textMuted.withOpacity(0.6),
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
                    color: PinitColors.primary.withOpacity(0.5),
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
                  color: PinitColors.textMuted.withOpacity(0.15),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    size: 18,
                    color: PinitColors.textMuted.withOpacity(0.5),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Search restaurants — coming soon',
                    style: TextStyle(
                      fontSize: 15,
                      color: PinitColors.textMuted.withOpacity(0.5),
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
                    color: _canCreate ? null : PinitColors.textMuted.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
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
    return GestureDetector(
      onTap: () {
        // TODO: navigate to collection detail
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: PinitColors.surfaceLight,
          boxShadow: PinitColors.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: PinitColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.bookmark_rounded, color: Colors.white, size: 22),
                ),
              ),
              const Spacer(),
              Text(
                collection.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PinitColors.textPrimary,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                '${collection.locationIds.length} places',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: PinitColors.textSecondary,
                ),
              ),
            ],
          ),
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
              child: Text('📚', style: TextStyle(fontSize: 28)),
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

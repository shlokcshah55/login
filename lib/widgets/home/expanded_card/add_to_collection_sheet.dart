import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/supabase/helpers/collections.dart';
import 'package:login/supabase/supabase_client.dart';

/// Bottom sheet that lists the user's collections and lets them add the
/// current location to one. Mirrors the styling of the rest of the
/// expanded location card (cream surfaces, aubergine type, pill chrome).
class AddToCollectionSheet extends StatefulWidget {
  final int locationId;
  final String locationName;

  const AddToCollectionSheet({
    super.key,
    required this.locationId,
    required this.locationName,
  });

  @override
  State<AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends State<AddToCollectionSheet> {
  List<CollectionItem> _collections = [];
  Set<String> _alreadyAdded = {};
  bool _loading = true;
  String? _addingId;

  @override
  void initState() {
    super.initState();
    _fetchCollections();
  }

  Future<void> _fetchCollections() async {
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final items = await CollectionsHelper().getUserCollections(userId);
      if (mounted) {
        setState(() {
          _collections = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // Fetch which collections already contain this location.
    // Runs after collections are shown — failure is silent.
    try {
      final addedRaw = await SupabaseClientManager().client.rpc(
        'get_location_collection_ids',
        params: {'p_location_id': widget.locationId},
      ) as List;
      final addedIds = addedRaw.map((row) => row['collection_id'] as String).toSet();
      if (mounted) setState(() => _alreadyAdded = addedIds);
    } catch (_) {
      // RPC not yet deployed — collections still show, just without greying out
    }
  }

  Future<void> _addToCollection(String collectionId) async {
    if (_addingId != null) return;
    setState(() => _addingId = collectionId);
    try {
      final result = await SupabaseClientManager().client.rpc(
        'add_location_to_collection',
        params: {
          'p_collection_id': collectionId,
          'p_location_id': widget.locationId,
        },
      );
      final success = (result as Map)['success'] == true;
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Added to collection'
                  : (result['message'] ?? 'Already in collection'),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _addingId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add to collection')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PinitColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 24),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: PinitColors.creamDeep,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAVE TO',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PinitColors.aubergineSoft,
                    letterSpacing: 0.12 * 11,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add to Collection',
                  style: TextStyle(
                    fontFamily: 'Rova',
                    fontSize: 28,
                    fontWeight: FontWeight.w100,
                    color: PinitColors.aubergine,
                    letterSpacing: 1.3,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.locationName,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: PinitColors.mute,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Collections list
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(PinitColors.aubergine),
                ),
              ),
            )
          else if (_collections.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: PinitColors.creamSunk,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: PinitColors.creamDeep, width: 1.5),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.collections_bookmark_rounded,
                        size: 36, color: PinitColors.aubergineSoft),
                    const SizedBox(height: 14),
                    const Text(
                      'No collections yet',
                      style: TextStyle(
                        fontFamily: 'Rova',
                        fontSize: 22,
                        fontWeight: FontWeight.w100,
                        color: PinitColors.aubergine,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create a collection from your profile',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: PinitColors.mute,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _collections.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: PinitColors.creamDeep,
                ),
                itemBuilder: (context, i) {
                  final c = _collections[i];
                  final isAdding = _addingId == c.collectionId;
                  final alreadyIn = _alreadyAdded.contains(c.collectionId);
                  final disabled = isAdding || alreadyIn;
                  return Opacity(
                    opacity: alreadyIn ? 0.45 : 1.0,
                    child: GestureDetector(
                      onTap: disabled ? null : () => _addToCollection(c.collectionId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: PinitColors.creamSunk,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: PinitColors.creamDeep, width: 1.5),
                              ),
                              child: Center(
                                child: c.emoji != null && c.emoji!.isNotEmpty
                                    ? Text(c.emoji!,
                                        style: const TextStyle(fontSize: 20))
                                    : const Icon(
                                        Icons.collections_bookmark_rounded,
                                        size: 20,
                                        color: PinitColors.aubergineSoft,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: PinitColors.aubergine,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    alreadyIn
                                        ? 'Already added'
                                        : '${c.placeCount} ${c.placeCount == 1 ? 'place' : 'places'}',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: PinitColors.mute,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isAdding)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      PinitColors.aubergine),
                                ),
                              )
                            else if (alreadyIn)
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 22,
                                color: PinitColors.aubergineSoft,
                              )
                            else
                              const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 22,
                                color: PinitColors.aubergineSoft,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

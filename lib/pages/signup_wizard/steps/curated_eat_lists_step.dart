import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/supabase/helpers/collections.dart';
import 'package:login/supabase/supabase_client.dart';
import 'package:login/widgets/feedback/app_feedback.dart';
import 'curated_eat_list_detail_page.dart';

class CuratedEatListsStep extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onComplete;
  final bool isCompleting;

  const CuratedEatListsStep({
    super.key,
    required this.onBack,
    required this.onComplete,
    required this.isCompleting,
  });

  @override
  State<CuratedEatListsStep> createState() => _CuratedEatListsStepState();
}

class _CuratedEatListsStepState extends State<CuratedEatListsStep> {
  static const List<String> _majorCities = [
    'All',
    'London',
    'New York',
    'Los Angeles',
    'San Francisco',
    'Paris',
    'Berlin',
    'Barcelona',
    'Rome',
    'Amsterdam',
  ];

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

  static const Map<String, String> _curatedDescriptions = {
    'e9f50774-b41a-4712-b230-2700aad37ebd':
        'Romantic, intimate, atmospheric — places that set the mood',
    '33df0d5e-1a26-4cbe-8356-9ea2b46ddece':
        'Great food without the guilt trip on your wallet',
    '9e352f72-96b2-45dc-ae65-97e66a661262':
        'Plant-forward spots that convert even the most committed carnivore',
    'f1e64a86-ff68-4a95-a2c6-7d755bdd8485':
        'Fine dining & Michelin stars for when cost is no object',
    '17ce4d6a-8239-45fc-b129-7e03241c77a3':
        'Loud, lively, made for big tables and celebrations',
    '85eedbc1-69cc-4d67-99e6-9b898e026628':
        'Beloved by locals, under-discussed by tourists',
    '12c325c0-d0b5-4ee3-8327-838f0b7615cf':
        'The spots you return to again and again',
    'a897ae62-6ec0-4096-8e28-641554d8ab7e':
        'The restaurants every Londoner has an opinion on — and usually loves',
  };

  final CollectionsHelper _collectionsHelper = CollectionsHelper();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  String? _savingCollectionId;
  List<CollectionItem> _collections = const [];
  String _selectedCity = 'All';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isLoading) return;
    final userId = SupabaseClientManager().currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final items =
          await _collectionsHelper.getCollectionsByIds(_curatedCollectionIds, userId);
      if (!mounted) return;
      setState(() {
        _collections = items;
        if (_selectedCity == 'All') {
          final firstCity = items
              .map((c) => (c.curatedCity ?? '').trim())
              .firstWhere((c) => c.isNotEmpty, orElse: () => '');
          if (firstCity.isNotEmpty) _selectedCity = firstCity;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _collections = const []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<CollectionItem> get _filteredCollections {
    final q = _searchController.text.trim().toLowerCase();
    final city = _selectedCity.trim().toLowerCase();
    return _collections.where((c) {
      if (city.isNotEmpty && city != 'all') {
        final curated = (c.curatedCity ?? '').trim().toLowerCase();
        if (curated != city) return false;
      }
      final name = c.name.toLowerCase();
      final desc = (_curatedDescriptions[c.collectionId] ?? '').toLowerCase();
      if (q.isEmpty) return true;
      return name.contains(q) || desc.contains(q);
    }).toList(growable: false);
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
        final idx =
            _collections.indexWhere((c) => c.collectionId == collection.collectionId);
        if (idx == -1) return;
        final current = _collections[idx];
        final nextSaved = !current.isSaved;
        final nextCount = nextSaved
            ? current.saveCount + 1
            : (current.saveCount - 1) < 0
                ? 0
                : current.saveCount - 1;
        _collections = List<CollectionItem>.from(_collections)
          ..[idx] = current.copyWith(isSaved: nextSaved, saveCount: nextCount);
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

  void _openDetail(CollectionItem collection) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CuratedEatListDetailPage(collection: collection),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCollections;

    return Container(
      color: PinitColors.surfaceLight,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pick a few eat-lists to start with',
                    style: TextStyle(
                      fontFamily: 'Rova',
                      fontSize: 22,
                      fontWeight: FontWeight.w100,
                      color: PinitColors.aubergine,
                      letterSpacing: 1.2,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'You can add or remove these later.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: PinitColors.aubergineSoft,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CityPills(
                    cities: _majorCities,
                    selected: _selectedCity,
                    onSelected: (city) {
                      setState(() => _selectedCity = city);
                    },
                  ),
                  const SizedBox(height: 12),
                  _SearchField(controller: _searchController),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  PinitColors.aubergine),
                            ),
                          )
                        : filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No matches.',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: PinitColors.aubergineSoft,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final c = filtered[i];
                                  final saving =
                                      _savingCollectionId == c.collectionId;
                                  final desc =
                                      _curatedDescriptions[c.collectionId] ?? '';
                                  return _CuratedRow(
                                    collection: c,
                                    cityLabel: c.curatedCity,
                                    description: desc,
                                    saving: saving,
                                    onToggle: () => _toggleSaveCollection(c),
                                    onTap: () => _openDetail(c),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PinitColors.surfaceLight,
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
                    onPressed: widget.isCompleting ? null : widget.onBack,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PinitColors.aubergine,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: widget.isCompleting ? null : widget.onComplete,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: PinitColors.aubergine,
                      foregroundColor: PinitColors.cream,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: widget.isCompleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  PinitColors.cream),
                            ),
                          )
                        : Text(
                            'Finish',
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: PinitColors.cream,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: PinitColors.aubergine,
      ),
      decoration: InputDecoration(
        hintText: 'Search eat-lists',
        hintStyle: GoogleFonts.dmSans(color: PinitColors.mute),
        prefixIcon:
            Icon(Icons.search_rounded, size: 20, color: PinitColors.mute),
        filled: true,
        fillColor: PinitColors.creamSunk,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: PinitColors.primary.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _CuratedRow extends StatelessWidget {
  final CollectionItem collection;
  final String? cityLabel;
  final String description;
  final bool saving;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _CuratedRow({
    required this.collection,
    required this.cityLabel,
    required this.description,
    required this.saving,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = collection.isSaved;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? PinitColors.creamSunk : PinitColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? PinitColors.aubergine : PinitColors.creamDeep,
            width: 1.5,
          ),
          boxShadow: PinitColors.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PinitColors.cream,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: PinitColors.creamDeep,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  collection.emoji ?? '📌',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: PinitColors.aubergine,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description.isEmpty
                        ? '${collection.placeCount} place${collection.placeCount == 1 ? '' : 's'}'
                        : description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: PinitColors.aubergineSoft,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${collection.placeCount} place${collection.placeCount == 1 ? '' : 's'}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: PinitColors.mute,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if ((cityLabel ?? '').trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          (cityLabel ?? '').toUpperCase(),
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: PinitColors.aubergineSoft,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: saving ? null : onToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? PinitColors.aubergine : PinitColors.cream,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: PinitColors.aubergine,
                    width: 1.5,
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(PinitColors.aubergine),
                        ),
                      )
                    : Icon(
                        selected ? Icons.check_rounded : Icons.add_rounded,
                        size: 18,
                        color: selected ? PinitColors.cream : PinitColors.aubergine,
                      ),
              ),
            ),
            ],
          ),
        ),
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
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final city = cities[i];
          final isActive = city == selected;
          return GestureDetector(
            onTap: () => onSelected(city),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? PinitColors.aubergine : PinitColors.creamSunk,
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
              child: Center(
                child: Text(
                  city.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isActive ? PinitColors.cream : PinitColors.aubergine,
                    letterSpacing: 1.0,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

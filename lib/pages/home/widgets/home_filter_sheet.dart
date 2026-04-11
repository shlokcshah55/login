import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/supabase/helpers/tags.dart';
import 'package:login/themes/app_typography.dart';
import 'package:login/widgets/home/expanded_card/helpers/vibe_display.dart';

class HomeFilterSheetResult {
  const HomeFilterSheetResult({
    required this.vibeTagIds,
    required this.cuisineTagIds,
  });

  final Set<String> vibeTagIds;
  final Set<String> cuisineTagIds;

  int get totalSelectedCount => vibeTagIds.length + cuisineTagIds.length;
}

enum _HomeFilterCategory {
  vibe(
    title: 'Vibe',
    eyebrow: 'MOOD',
    icon: FeatherIcons.sun,
    emptyTitle: 'No vibe tags yet',
    emptySubtitle: 'Try cuisine for now and wire vibe data in when ready.',
  ),
  cuisine(
    title: 'Cuisine',
    eyebrow: 'FOOD',
    icon: FeatherIcons.coffee,
    emptyTitle: 'No cuisine tags yet',
    emptySubtitle: 'Add tags later and the selection UI is already in place.',
  );

  const _HomeFilterCategory({
    required this.title,
    required this.eyebrow,
    required this.icon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final String title;
  final String eyebrow;
  final IconData icon;
  final String emptyTitle;
  final String emptySubtitle;
}

class HomeFilterSheet extends StatefulWidget {
  const HomeFilterSheet({
    super.key,
    required this.initialVibeTagIds,
    required this.initialCuisineTagIds,
  });

  final Set<String> initialVibeTagIds;
  final Set<String> initialCuisineTagIds;

  static Future<HomeFilterSheetResult?> show(
    BuildContext context, {
    required Set<String> initialVibeTagIds,
    required Set<String> initialCuisineTagIds,
  }) {
    return showModalBottomSheet<HomeFilterSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: PinitColors.aubergine.withValues(alpha: 0.18),
      builder: (_) => HomeFilterSheet(
        initialVibeTagIds: initialVibeTagIds,
        initialCuisineTagIds: initialCuisineTagIds,
      ),
    );
  }

  @override
  State<HomeFilterSheet> createState() => _HomeFilterSheetState();
}

class _HomeFilterSheetState extends State<HomeFilterSheet> {
  static const List<Map<String, String>> _staticCuisineTags = [
    {'tag_id': 'italian', 'text': 'italian'},
    {'tag_id': 'indian', 'text': 'indian'},
    {'tag_id': 'american', 'text': 'american'},
    {'tag_id': 'turkish', 'text': 'turkish'},
    {'tag_id': 'pub', 'text': 'pub'},
    {'tag_id': 'chinese', 'text': 'chinese'},
    {'tag_id': 'british', 'text': 'british'},
    {'tag_id': 'japanese', 'text': 'japanese'},
    {'tag_id': 'french', 'text': 'french'},
    {'tag_id': 'middle_eastern', 'text': 'middle_eastern'},
  ];

  static const Map<String, IconData> _cuisineIcons = {
    'italian': Icons.local_pizza_rounded,
    'indian': Icons.dinner_dining_rounded,
    'american': Icons.lunch_dining_rounded,
    'turkish': Icons.kebab_dining_rounded,
    'pub': Icons.sports_bar_rounded,
    'chinese': Icons.ramen_dining_rounded,
    'british': Icons.bakery_dining_rounded,
    'japanese': Icons.set_meal_rounded,
    'french': Icons.egg_alt_rounded,
    'middle_eastern': Icons.kebab_dining_rounded,
  };

  final TagsHelper _tagsHelper = TagsHelper();

  late Set<String> _selectedVibeTagIds;
  late Set<String> _selectedCuisineTagIds;

  List<Map<String, dynamic>> _vibeTags = const [];
  List<Map<String, dynamic>> _cuisineTags = const [];
  bool _loading = true;
  _HomeFilterCategory _activeCategory = _HomeFilterCategory.vibe;

  @override
  void initState() {
    super.initState();
    _selectedVibeTagIds = Set<String>.from(widget.initialVibeTagIds);
    _selectedCuisineTagIds = Set<String>.from(widget.initialCuisineTagIds);
    _loadTags();
  }

  Future<void> _loadTags() async {
    final results = await Future.wait([
      _tagsHelper.getVibeTags(),
    ]);
    if (!mounted) return;
    setState(() {
      _vibeTags = results[0];
      _cuisineTags = _staticCuisineTags;
      _loading = false;
      if (_vibeTags.isEmpty && _cuisineTags.isNotEmpty) {
        _activeCategory = _HomeFilterCategory.cuisine;
      }
    });
  }

  Set<String> _selectedFor(_HomeFilterCategory category) {
    return switch (category) {
      _HomeFilterCategory.vibe => _selectedVibeTagIds,
      _HomeFilterCategory.cuisine => _selectedCuisineTagIds,
    };
  }

  List<Map<String, dynamic>> _tagsFor(_HomeFilterCategory category) {
    return switch (category) {
      _HomeFilterCategory.vibe => _vibeTags,
      _HomeFilterCategory.cuisine => _cuisineTags,
    };
  }

  void _toggleTag(_HomeFilterCategory category, String tagId) {
    final selected = _selectedFor(category);
    setState(() {
      if (selected.contains(tagId)) {
        selected.remove(tagId);
      } else {
        selected.add(tagId);
      }
    });
  }

  void _clearSelections() {
    setState(() {
      _selectedVibeTagIds.clear();
      _selectedCuisineTagIds.clear();
    });
  }

  String _tagId(Map<String, dynamic> tag) => (tag['tag_id'] ?? '').toString();

  String _tagLabel(Map<String, dynamic> tag) => (tag['text'] ?? '').toString();

  String _displayLabel(_HomeFilterCategory category, Map<String, dynamic> tag) {
    final rawLabel = _tagLabel(tag);
    return switch (category) {
      _HomeFilterCategory.vibe => vibeDisplayName(rawLabel),
      _HomeFilterCategory.cuisine => rawLabel
          .replaceAll('_', ' ')
          .split(' ')
          .map(
            (word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}',
          )
          .join(' '),
    };
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final totalSelectedCount =
        _selectedVibeTagIds.length + _selectedCuisineTagIds.length;
    final activeTags = _tagsFor(_activeCategory);
    final activeSelected = _selectedFor(_activeCategory);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: PinitColors.cream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: PinitColors.creamDeep,
          width: 1.5,
        ),
        boxShadow: PinitColors.elevatedShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PinitColors.creamDeep,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FILTERS',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: PinitColors.aubergineSoft,
                            letterSpacing: 1.5,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Refine the map.',
                          style: AppTypography.brand(
                            fontSize: 30,
                            fontWeight: FontWeight.w100,
                            color: PinitColors.aubergine,
                            height: 0.98,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pick a vibe or cuisine, then apply when you are ready.',
                          style: AppTypography.sans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: PinitColors.aubergineSoft,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: PinitColors.creamSunk,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          FeatherIcons.x,
                          size: 18,
                          color: PinitColors.aubergine,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: PinitColors.creamSunk,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: PinitColors.creamDeep,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: _HomeFilterCategory.values.map((category) {
                    final isSelected = _activeCategory == category;
                    final count = _selectedFor(category).length;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _activeCategory = category);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? PinitColors.cream
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isSelected
                                ? const [
                                    BoxShadow(
                                      color: Color(0x1441133D),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                category.icon,
                                size: 15,
                                color: PinitColors.aubergine,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                category.title,
                                style: AppTypography.sans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: PinitColors.aubergine,
                                ),
                              ),
                              if (count > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PinitColors.accent,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: AppTypography.sans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: PinitColors.cream,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_activeCategory.eyebrow} TAGS',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: PinitColors.aubergineSoft,
                        letterSpacing: 1.4,
                        height: 1.0,
                      ),
                    ),
                  ),
                  if (totalSelectedCount > 0)
                    TextButton(
                      onPressed: _clearSelections,
                      style: TextButton.styleFrom(
                        foregroundColor: PinitColors.aubergine,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        'Clear',
                        style: AppTypography.sans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: PinitColors.aubergine,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              PinitColors.aubergine,
                            ),
                          ),
                        ),
                      )
                    : activeTags.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 28,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: PinitColors.creamSunk,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: PinitColors.creamDeep,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Icon(
                                      _activeCategory.icon,
                                      color: PinitColors.aubergineSoft,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _activeCategory.emptyTitle,
                                    style: AppTypography.sans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: PinitColors.aubergine,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _activeCategory.emptySubtitle,
                                    textAlign: TextAlign.center,
                                    style: AppTypography.sans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: PinitColors.aubergineSoft,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: activeTags.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final tag = activeTags[index];
                              final tagId = _tagId(tag);
                              final rawLabel = _tagLabel(tag);
                              final icon =
                                  _activeCategory == _HomeFilterCategory.vibe
                                      ? vibeIcons[rawLabel] ??
                                          Icons.local_offer_rounded
                                      : _cuisineIcons[rawLabel] ??
                                          Icons.restaurant_rounded;
                              return _SelectableFilterRow(
                                label: _displayLabel(
                                  _activeCategory,
                                  tag,
                                ),
                                icon: icon,
                                isSelected: activeSelected.contains(tagId),
                                onTap: () => _toggleTag(_activeCategory, tagId),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      HomeFilterSheetResult(
                        vibeTagIds: Set<String>.from(_selectedVibeTagIds),
                        cuisineTagIds: Set<String>.from(_selectedCuisineTagIds),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PinitColors.aubergine,
                    foregroundColor: PinitColors.cream,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(
                        color: PinitColors.aubergine,
                        width: 1.4,
                      ),
                    ),
                  ),
                  child: Text(
                    totalSelectedCount > 0
                        ? 'Apply $totalSelectedCount filter${totalSelectedCount == 1 ? '' : 's'}'
                        : 'Apply filters',
                    style: AppTypography.sans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: PinitColors.cream,
                    ),
                  ),
                ),
              ),
              SizedBox(height: bottomInset),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectableFilterRow extends StatelessWidget {
  const _SelectableFilterRow({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? PinitColors.cream : PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? PinitColors.aubergine : PinitColors.creamDeep,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? PinitColors.aubergine.withValues(alpha: 0.08)
                      : PinitColors.creamDeep,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: PinitColors.aubergine),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PinitColors.aubergine,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected ? PinitColors.aubergine : PinitColors.cream,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? PinitColors.aubergine
                        : PinitColors.creamDeep,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isSelected ? Icons.check_rounded : Icons.add_rounded,
                  size: 16,
                  color: isSelected ? PinitColors.cream : PinitColors.aubergine,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

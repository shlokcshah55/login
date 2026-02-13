import 'package:flutter/material.dart';
import 'package:login/themes/app_colors.dart';

class TagSelectionPopover extends StatefulWidget {
  final String title;
  final IconData titleIcon;
  final List<Map<String, dynamic>> tags;
  final Set<String> initialSelectedTagIds;
  final Function(Set<String>) onApply;

  const TagSelectionPopover({
    Key? key,
    required this.title,
    required this.titleIcon,
    required this.tags,
    required this.initialSelectedTagIds,
    required this.onApply,
  }) : super(key: key);

  @override
  State<TagSelectionPopover> createState() => _TagSelectionPopoverState();
}

class _TagSelectionPopoverState extends State<TagSelectionPopover> {
  late Set<String> _selectedTagIds;

  @override
  void initState() {
    super.initState();
    _selectedTagIds = Set.from(widget.initialSelectedTagIds);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.7; // Max 70% of screen height

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fixed header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header row
                  Row(
                    children: [
                      Icon(
                        widget.titleIcon,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      // Clear all button (only show if selections exist)
                      if (_selectedTagIds.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedTagIds.clear();
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('Clear all'),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Subtitle with selection count
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select all that apply',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (_selectedTagIds.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_selectedTagIds.length} selected',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Scrollable tag chips
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: widget.tags.map((tag) {
                    final tagId = tag['id'] as String;
                    final tagName = tag['name'] as String;
                    final isSelected = _selectedTagIds.contains(tagId);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedTagIds.remove(tagId);
                            } else {
                              _selectedTagIds.add(tagId);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                Icon(
                                  Icons.check_circle,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                tagName,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Fixed bottom button
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_selectedTagIds);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _selectedTagIds.isEmpty
                      ? 'Clear Filters'
                      : 'Apply ${_selectedTagIds.length} Filter${_selectedTagIds.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

import 'package:flutter/material.dart';
import 'package:login/themes/app_colors.dart';

class FilterCategoryListPopover extends StatelessWidget {
  final VoidCallback onVibeSelected;
  final VoidCallback onCuisineSelected;
  final bool hasVibeFilters;
  final bool hasCuisineFilters;

  const FilterCategoryListPopover({
    Key? key,
    required this.onVibeSelected,
    required this.onCuisineSelected,
    required this.hasVibeFilters,
    required this.hasCuisineFilters,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Filter By',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Filter category options
              _FilterCategoryTile(
                icon: Icons.emoji_emotions_outlined,
                label: 'Vibe',
                hasActiveFilters: hasVibeFilters,
                onTap: () {
                  Navigator.pop(context);
                  onVibeSelected();
                },
              ),
              const SizedBox(height: 12),
              _FilterCategoryTile(
                icon: Icons.restaurant_menu_outlined,
                label: 'Cuisine',
                hasActiveFilters: hasCuisineFilters,
                onTap: () {
                  Navigator.pop(context);
                  onCuisineSelected();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterCategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasActiveFilters;
  final VoidCallback onTap;

  const _FilterCategoryTile({
    required this.icon,
    required this.label,
    required this.hasActiveFilters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: hasActiveFilters
            ? AppColors.primary.withValues(alpha: 0.05)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasActiveFilters ? AppColors.primary : Colors.grey[300]!,
          width: hasActiveFilters ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (hasActiveFilters)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

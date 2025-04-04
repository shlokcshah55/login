import 'package:flutter/material.dart';
import 'package:login/providers/location_list_manager.dart'; 

class FilterBar extends StatelessWidget {
  // Input: The currently active list type from the manager
  final LocationListType currentListType;
  // Output: Callback function to update the list type in the manager
  final ValueChanged<LocationListType> onListTypeChanged;

  const FilterBar({
    Key? key,
    required this.currentListType,
    required this.onListTypeChanged,
  }) : super(key: key);

  // Helper method to build an individual filter chip
  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required LocationListType listType, // The type this chip represents
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Determine if this chip represents the currently selected list type
    final bool isSelected = currentListType == listType;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label),
        showCheckmark: false,
        avatar: Icon(
          icon,
          size: 18,
          // Change the icon color based on selection state for visual feedback
          color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
        ),
        selected: isSelected,
        onSelected: (selected) {
          // We only care about the tap action itself to trigger the change.
          if (selected) { // Only trigger if it's being selected
            onListTypeChanged(listType);
          }
        },
        // ----- Styling -----
        backgroundColor: colorScheme.surface,
        // Use a primary-based color for the single selection
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
        shape: const StadiumBorder(), // Pill shape
        side: isSelected
            ? BorderSide.none // No border when selected (filled look)
            : BorderSide(color: colorScheme.outline.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        elevation: 0,
        pressElevation: 0,
        selectedShadowColor: Colors.transparent,
        // ----- End Styling -----
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFilterChip(
              context: context,
              label: "Saved", 
              icon: Icons.bookmark_rounded,
              listType: LocationListType.saved,
            ),
            _buildFilterChip(
              context: context,
              label: "Recommended", 
              icon: Icons.recommend_rounded,
              listType: LocationListType.recommended,
            ),
            _buildFilterChip(
              context: context,
              label: "Search", 
              icon: Icons.search_rounded,
              listType: LocationListType.search,
            ),
          ],
        ),
      ),
    );
  }
}
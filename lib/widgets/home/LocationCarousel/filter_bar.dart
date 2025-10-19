import 'package:flutter/material.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:google_fonts/google_fonts.dart'; // For font consistency

class FilterBar extends StatelessWidget {
  final LocationListType currentListType;
  final ValueChanged<LocationListType> onListTypeChanged;

  const FilterBar({
    Key? key,
    required this.currentListType,
    required this.onListTypeChanged,
  }) : super(key: key);

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required LocationListType listType,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isSelected = currentListType == listType;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label),
        avatar: Icon(
          icon,
          size: 18,
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant, // Use onPrimary for selected icon
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            onListTypeChanged(listType);
          }
        },
        backgroundColor: isSelected ? colorScheme.primary.withOpacity(0.15) : colorScheme.surface.withOpacity(0.8), // Subtle background
        selectedColor: colorScheme.primary, // Solid primary color when selected
        labelStyle: GoogleFonts.poppins( // Using Poppins for consistency
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant, // Use onPrimary for selected text
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder( // Slightly less rounded, more modern
            borderRadius: BorderRadius.circular(20.0),
        ),
        side: isSelected
            ? BorderSide(color: colorScheme.primary, width: 1.5) // Border for selected chip
            : BorderSide(color: colorScheme.outline.withOpacity(0.3)), // Subtle border for unselected
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 9.0), // Adjusted padding
        elevation: isSelected ? 1.0 : 0, // Slight elevation for selected
        pressElevation: 0,
        showCheckmark: false, // Usually not needed if visual distinction is clear
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The FilterBar itself no longer needs its own Padding if the parent handles it.
    // Its background is determined by the _buildFloatingHeaderControls container.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12.0), // Padding for scroll content
      child: Row(
        // No MainAxisAlignment.center needed if it's part of a full-width header that scrolls
        children: [
          _buildFilterChip(
            context: context,
            label: "Saved",
            icon: Icons.bookmark_rounded, // Kept, good icon
            listType: LocationListType.saved,
          ),
          _buildFilterChip(
            context: context,
            label: "Recommended",
            icon: Icons.recommend_rounded, // Kept, good icon
            listType: LocationListType.recommended,
          ),
          _buildFilterChip(
            context: context,
            label: "Near Me", // Changed from "Search" as search is now global
            icon: Icons.near_me_rounded, // More appropriate icon
            listType: LocationListType.search, // Assuming 'search' type means 'nearby' or 'current results'
          ),
          // You could add more filters here if needed
        ],
      ),
    );
  }
}
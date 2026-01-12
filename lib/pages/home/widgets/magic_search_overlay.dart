import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/themes/app_colors.dart';

class MagicSearchOverlay extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClose;
  final ValueChanged<String> onSubmit;

  const MagicSearchOverlay({
    Key? key,
    required this.controller,
    required this.onClose,
    required this.onSubmit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ),
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: AppColors.secondary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Magic Search",
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Search in natural language like 'cozy Italian place with outdoor seating' or 'best ramen near me'",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: onSubmit,
                    decoration: InputDecoration(
                      hintText: "Your next adventure...",
                      hintStyle: GoogleFonts.poppins(
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      icon: Icon(
                        Icons.search,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    style: GoogleFonts.poppins(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => onSubmit(controller.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      elevation: 0,
                    ),
                    child: Text(
                      "Search",
                      style: GoogleFonts.poppins(
                        fontSize: 16.0,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

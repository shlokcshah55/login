import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// "THE PLACE" label + display name + tappable address row.
class NameLocationSection extends StatelessWidget {
  const NameLocationSection({
    super.key,
    required this.name,
    required this.vicinity,
    required this.onAddressTap,
  });

  final String name;
  final String? vicinity;
  final VoidCallback onAddressTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THE PLACE',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: PinitColors.aubergineSoft,
            letterSpacing: 0.12 * 11,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            fontFamily: 'Rova',
            fontSize: 36,
            fontWeight: FontWeight.w100,
            color: PinitColors.aubergine,
            height: 1.05,
            letterSpacing: 1.4,
          ),
        ),
        if (vicinity != null) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onAddressTap,
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 16, color: PinitColors.aubergineSoft),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    vicinity!,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: PinitColors.aubergineSoft,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.open_in_new_rounded,
                    size: 13, color: PinitColors.mute),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

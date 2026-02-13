import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GavelOverlay extends StatelessWidget {
  final double selectedMinutes;
  final ValueChanged<double> onMinutesChanged;
  final VoidCallback onClose;
  final ValueChanged<double> onSubmit;

  const GavelOverlay({
    Key? key,
    required this.selectedMinutes,
    required this.onMinutesChanged,
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
                      Icons.explore_rounded,
                      color: const Color.fromARGB(255, 68, 95, 12),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Just decide",
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
                  "Do you just want a place to go without the effort of making a decision, just decide how far you want to walk from where you are and we will give you 5 good options to go to!",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "${selectedMinutes.round()} minutes walk",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "~${(selectedMinutes * 5 / 60).toStringAsFixed(1)} km",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color.fromARGB(255, 68, 95, 12),
                    inactiveTrackColor: const Color.fromARGB(255, 68, 95, 12).withOpacity(0.3),
                    thumbColor: const Color.fromARGB(255, 68, 95, 12),
                    overlayColor: const Color.fromARGB(255, 68, 95, 12).withOpacity(0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0),
                    trackHeight: 4.0,
                  ),
                  child: Slider(
                    value: selectedMinutes,
                    min: 5,
                    max: 30,
                    divisions: 25,
                    onChanged: onMinutesChanged,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "5 min",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                      ),
                    ),
                    Text(
                      "30 min",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      print('🎲 JUST DECIDE BUTTON PRESSED with minutes: $selectedMinutes');
                      onSubmit(selectedMinutes);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 68, 95, 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      elevation: 0,
                    ),
                    child: Text(
                      "Let's decide!",
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

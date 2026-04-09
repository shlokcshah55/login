import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// Bottom sheet shown when the user taps "Been to" on a location card and
/// has fewer than 6 prior been-to reviews. Captures a 0–10 rating, optional
/// notes, and a gatekeep toggle that hides the review from followers.
class BeenToReviewSheet extends StatefulWidget {
  const BeenToReviewSheet({
    super.key,
    required this.locationName,
    required this.onSubmit,
  });

  final String locationName;
  final Future<void> Function(double rating, String? notes, bool gatekeep)
      onSubmit;

  @override
  State<BeenToReviewSheet> createState() => _BeenToReviewSheetState();
}

class _BeenToReviewSheetState extends State<BeenToReviewSheet> {
  double _rating = 5.0;
  final TextEditingController _notesController = TextEditingController();
  bool _gatekeep = false;
  bool _submitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _bumpRating(double delta) {
    setState(() {
      _rating = (_rating + delta).clamp(0.0, 10.0);
    });
  }

  Future<void> _handleSubmit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final notes = _notesController.text.trim();
      await widget.onSubmit(
        _rating,
        notes.isEmpty ? null : notes,
        _gatekeep,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log visit: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: PinitColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PinitColors.creamDeep,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'BEEN TO',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: PinitColors.aubergineSoft,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.locationName,
                style: const TextStyle(
                  fontFamily: 'Rova',
                  fontSize: 28,
                  height: 1.1,
                  color: PinitColors.aubergine,
                ),
              ),
              const SizedBox(height: 24),
              _RatingControl(
                rating: _rating,
                onMinus: () => _bumpRating(-0.5),
                onPlus: () => _bumpRating(0.5),
                onChanged: (v) => setState(() => _rating = v),
              ),
              const SizedBox(height: 24),
              _NotesField(controller: _notesController),
              const SizedBox(height: 20),
              _GatekeepRow(
                value: _gatekeep,
                onChanged: (v) => setState(() => _gatekeep = v),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PinitColors.aubergine,
                    foregroundColor: PinitColors.cream,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PinitColors.cream,
                          ),
                        )
                      : Text(
                          'Log visit',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
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

class _RatingControl extends StatelessWidget {
  const _RatingControl({
    required this.rating,
    required this.onMinus,
    required this.onPlus,
    required this.onChanged,
  });

  final double rating;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StepperButton(icon: Icons.remove_rounded, onTap: onMinus),
            const SizedBox(width: 24),
            SizedBox(
              width: 110,
              child: Text(
                rating.toStringAsFixed(1),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: PinitColors.aubergine,
                ),
              ),
            ),
            const SizedBox(width: 24),
            _StepperButton(icon: Icons.add_rounded, onTap: onPlus),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: PinitColors.aubergine,
            inactiveTrackColor: PinitColors.creamDeep,
            thumbColor: PinitColors.aubergine,
            overlayColor: PinitColors.aubergine.withValues(alpha: 0.12),
            valueIndicatorColor: PinitColors.aubergine,
          ),
          child: Slider(
            min: 0,
            max: 10,
            divisions: 20,
            value: rating,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: PinitColors.creamSunk,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: PinitColors.creamDeep, width: 1.5),
        ),
        child: Icon(icon, size: 20, color: PinitColors.aubergine),
      ),
    );
  }
}

class _NotesField extends StatelessWidget {
  const _NotesField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 4,
      minLines: 3,
      style: GoogleFonts.dmSans(fontSize: 14, color: PinitColors.aubergine),
      decoration: InputDecoration(
        hintText: 'Notes (optional)',
        hintStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: PinitColors.mute,
        ),
        filled: true,
        fillColor: PinitColors.creamSunk,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: PinitColors.aubergine,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _GatekeepRow extends StatelessWidget {
  const _GatekeepRow({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gatekeep',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: PinitColors.aubergine,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Hide from followers',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: PinitColors.mute,
              ),
            ),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: PinitColors.aubergine,
        ),
      ],
    );
  }
}

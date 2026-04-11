import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

class BeenToReviewSheet extends StatefulWidget {
  final String locationName;
  final Future<void> Function(double rating, String? notes, bool gatekeep)
      onSubmit;

  const BeenToReviewSheet({
    Key? key,
    required this.locationName,
    required this.onSubmit,
  }) : super(key: key);

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

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        _rating,
        _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        _gatekeep,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to log visit')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        16;

    return Container(
      decoration: BoxDecoration(
        color: PinitColors.cream,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Header label
              Text(
                'BEEN TO',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: PinitColors.aubergineSoft,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              // Location name
              Text(
                widget.locationName,
                style: const TextStyle(
                  fontFamily: 'Rova',
                  fontSize: 28,
                  fontWeight: FontWeight.w100,
                  color: PinitColors.aubergine,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 24),

              // Rating section
              Text(
                'Your rating',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PinitColors.aubergine,
                ),
              ),
              const SizedBox(height: 12),

              // Rating controls
              Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        setState(() => _rating = (_rating - 0.1).clamp(1.0, 10.0)),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: PinitColors.creamSunk,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: PinitColors.creamDeep,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.remove,
                        color: PinitColors.aubergine,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _rating.toStringAsFixed(1),
                      style: GoogleFonts.dmSans(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: PinitColors.aubergine,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _rating = (_rating + 0.1).clamp(1.0, 10.0)),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: PinitColors.creamSunk,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: PinitColors.creamDeep,
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: PinitColors.aubergine,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Slider
              Slider(
                value: _rating,
                min: 1.0,
                max: 10.0,
                divisions: 90,
                activeColor: PinitColors.aubergine,
                inactiveColor: PinitColors.creamDeep,
                onChanged: (value) => setState(() => _rating = value),
              ),
              const SizedBox(height: 20),

              // Notes section
              Text(
                'Notes (optional)',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PinitColors.aubergine,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                minLines: 1,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: PinitColors.aubergine,
                ),
                decoration: InputDecoration(
                  hintText: 'What did you think?',
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: PinitColors.mute,
                  ),
                  filled: true,
                  fillColor: PinitColors.creamSunk,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: PinitColors.creamDeep,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: PinitColors.aubergine,
                      width: 1.5,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Gatekeep toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gatekeep',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PinitColors.aubergine,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hide this from your followers',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: PinitColors.mute,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _gatekeep,
                    activeThumbColor: PinitColors.aubergine,
                    onChanged: (value) => setState(() => _gatekeep = value),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: _submitting
                    ? Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PinitColors.aubergine,
                          ),
                        ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PinitColors.aubergine,
                          foregroundColor: PinitColors.cream,
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        onPressed: _submit,
                        child: Text(
                          'Log visit',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
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

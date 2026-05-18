import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/providers/referral_rewards_provider.dart';

import '../../pages/profile/widgets/pinit_colors.dart';

class ReferralCodePromptSheet extends StatefulWidget {
  const ReferralCodePromptSheet({
    super.key,
    required this.onApply,
    this.skipForNow = true,
  });

  final Future<void> Function(String code) onApply;
  final bool skipForNow;

  @override
  State<ReferralCodePromptSheet> createState() =>
      _ReferralCodePromptSheetState();
}

class _ReferralCodePromptSheetState extends State<ReferralCodePromptSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _applyCode() async {
    final code = _controller.text.trim().toUpperCase();
    debugPrint(
      '[ReferralCodePromptSheet] Apply tapped with code="$code" length=${code.length}',
    );
    if (code.isEmpty) {
      debugPrint('[ReferralCodePromptSheet] Empty referral code, aborting.');
      setState(() => _errorText = 'Enter a referral code or skip for now.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      debugPrint('[ReferralCodePromptSheet] Calling onApply.');
      await widget.onApply(code);
      debugPrint('[ReferralCodePromptSheet] onApply succeeded.');
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, stackTrace) {
      debugPrint('[ReferralCodePromptSheet] onApply failed: $e');
      debugPrintStack(
        label: '[ReferralCodePromptSheet] onApply stack',
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = _buildReferralErrorMessage(e);
      });
    }
  }

  String _buildReferralErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains(invalidReferralCodeMessage.toLowerCase()) ||
        text.contains('postgrest')) {
      return invalidReferralCodeMessage;
    }
    if (text.contains('invalid referral code') ||
        text.contains('referral code is invalid')) {
      return invalidReferralCodeMessage;
    }
    if (text.contains('own referral code') || text.contains('self')) {
      return "You can't use your own referral code.";
    }
    return "We couldn't apply that referral code. You can edit it and try again.";
  }

  void _normalizeInput(String value) {
    final normalized = value.trim().toUpperCase();
    if (value != normalized) {
      _controller.value = _controller.value.copyWith(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
        composing: TextRange.empty,
      );
    }
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PinitColors.aubergineSoft.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: PinitColors.creamSunk,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_outlined,
                      color: PinitColors.aubergine,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Have you been referred?',
                      style: GoogleFonts.dmSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: PinitColors.aubergine,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the referral code you were given to unlock your signup reward.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  height: 1.4,
                  color: PinitColors.aubergineSoft,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                enabled: !_isSubmitting,
                onChanged: _normalizeInput,
                onSubmitted: (_) => _isSubmitting ? null : _applyCode(),
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PinitColors.aubergine,
                ),
                decoration: InputDecoration(
                  hintText: 'Referral Code',
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: PinitColors.aubergineSoft.withValues(alpha: 0.65),
                  ),
                  prefixIcon: Icon(
                    Icons.local_offer_outlined,
                    color: PinitColors.aubergineSoft.withValues(alpha: 0.65),
                  ),
                  filled: true,
                  fillColor: PinitColors.creamSunk,
                  errorText: _errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _applyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PinitColors.aubergine,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Apply Code'),
                ),
              ),
              const SizedBox(height: 10),
              if (widget.skipForNow)
                Center(
                  child: TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(
                      'Skip for now',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PinitColors.aubergineSoft,
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

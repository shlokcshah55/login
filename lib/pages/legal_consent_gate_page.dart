import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/auth/legal_consent_section.dart';
import 'profile/widgets/pinit_colors.dart';

class LegalConsentGatePage extends StatefulWidget {
  const LegalConsentGatePage({
    super.key,
    required this.onAccept,
  });

  final Future<void> Function() onAccept;

  @override
  State<LegalConsentGatePage> createState() => _LegalConsentGatePageState();
}

class _LegalConsentGatePageState extends State<LegalConsentGatePage> {
  bool _isChecked = false;
  bool _isSubmitting = false;
  String? _errorText;

  Future<void> _handleContinue() async {
    if (!_isChecked) {
      setState(() {
        _errorText =
            'Please agree to the Terms and Conditions and Privacy Policy.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await widget.onAccept();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorText = 'Failed to save consent. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PinitColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: PinitColors.creamSunk,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: PinitColors.cardShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'One more thing',
                      style: GoogleFonts.dmSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: PinitColors.aubergine,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Before using Pinit, please accept the Terms and Conditions and Privacy Policy.',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        height: 1.45,
                        color: PinitColors.aubergineSoft,
                      ),
                    ),
                    const SizedBox(height: 20),
                    LegalConsentSection(
                      value: _isChecked,
                      onChanged: (value) {
                        setState(() {
                          _isChecked = value;
                          if (value) {
                            _errorText = null;
                          }
                        });
                      },
                      errorText: _errorText,
                      textColor: PinitColors.aubergine,
                      linkColor: PinitColors.aubergine,
                      checkboxActiveColor: PinitColors.aubergine,
                      checkboxCheckColor: PinitColors.cream,
                      checkboxSideColor: PinitColors.aubergineSoft,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PinitColors.aubergine,
                          foregroundColor: PinitColors.cream,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: PinitColors.cream,
                                ),
                              )
                            : Text(
                                'Continue',
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

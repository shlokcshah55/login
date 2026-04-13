import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../pages/profile/widgets/pinit_colors.dart';

class LegalConsentSection extends StatelessWidget {
  const LegalConsentSection({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.textColor = Colors.white,
    this.linkColor = Colors.white,
    this.checkboxActiveColor = Colors.white,
    this.checkboxCheckColor = PinitColors.aubergine,
    this.checkboxSideColor = Colors.white70,
  });

  static final Uri _privacyPolicyUri =
      Uri.parse('https://www.get-pinit.co.uk/privacy-policy');
  static final Uri _termsUri =
      Uri.parse('https://www.get-pinit.co.uk/terms-and-conditions');

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? errorText;
  final Color textColor;
  final Color linkColor;
  final Color checkboxActiveColor;
  final Color checkboxCheckColor;
  final Color checkboxSideColor;

  Future<void> _openLink(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open link right now.'),
        ),
      );
    }
  }

  Widget _buildLink(
    BuildContext context, {
    required String label,
    required Uri uri,
  }) {
    return GestureDetector(
      onTap: () => _openLink(context, uri),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          color: linkColor,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Transform.translate(
              offset: const Offset(-10, -6),
              child: Checkbox(
                value: value,
                onChanged: (newValue) => onChanged(newValue ?? false),
                activeColor: checkboxActiveColor,
                checkColor: checkboxCheckColor,
                side: BorderSide(color: checkboxSideColor, width: 1.5),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    Text(
                      'I agree to the',
                      style: GoogleFonts.dmSans(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    _buildLink(
                      context,
                      label: 'Terms and Conditions',
                      uri: _termsUri,
                    ),
                    Text(
                      'and',
                      style: GoogleFonts.dmSans(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    _buildLink(
                      context,
                      label: 'Privacy Policy',
                      uri: _privacyPolicyUri,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Text(
              errorText!,
              style: GoogleFonts.dmSans(
                color: const Color(0xFFFFB3B3),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

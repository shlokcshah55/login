import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

class ReferralCodeDialog extends StatefulWidget {
  const ReferralCodeDialog({
    super.key,
    required this.onApply,
    required this.onDismiss,
    this.onViewRewards,
  });

  final Future<bool> Function(String code) onApply;
  final Future<void> Function() onDismiss;
  final Future<void> Function()? onViewRewards;

  @override
  State<ReferralCodeDialog> createState() => _ReferralCodeDialogState();
}

class _ReferralCodeDialogState extends State<ReferralCodeDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;
  bool _isApplied = false;
  String? _submitError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final code = _codeController.text.trim();
    debugPrint(
      '[ReferralCodeDialog] Apply tapped with code="$code" length=${code.length}',
    );
    final ok = await widget.onApply(code);
    if (!mounted) return;

    if (ok) {
      debugPrint('[ReferralCodeDialog] onApply returned success.');
      HapticFeedback.mediumImpact();
      setState(() {
        _isSubmitting = false;
        _isApplied = true;
      });
      return;
    }

    debugPrint('[ReferralCodeDialog] onApply returned failure.');
    setState(() {
      _isSubmitting = false;
      _submitError = 'Could not apply that code. Please try again.';
    });
  }

  Future<void> _dismiss() async {
    setState(() => _isSubmitting = true);
    await widget.onDismiss();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _viewRewards() async {
    setState(() => _isSubmitting = true);
    if (widget.onViewRewards != null) {
      await widget.onViewRewards!();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: PinitColors.cream,
              borderRadius: BorderRadius.circular(22),
              border: Border(
                right: BorderSide(color: PinitColors.aubergine, width: 5),
                bottom: BorderSide(color: PinitColors.aubergine, width: 5),
              ),
              boxShadow: PinitColors.cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
              child: _isApplied ? _buildSuccessState() : _buildEntryForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Referral code?',
            style: const TextStyle(
              fontFamily: 'Rova',
              fontSize: 28,
              fontWeight: FontWeight.w100,
              color: PinitColors.aubergine,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You can apply a referral code now.',
            style: GoogleFonts.dmSans(
              color: PinitColors.aubergineSoft,
              fontSize: 15,
              height: 1.35,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _codeController,
            enabled: !_isSubmitting,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[A-Za-z0-9_-]'),
              ),
              LengthLimitingTextInputFormatter(64),
            ],
            validator: (value) {
              final code = value?.trim() ?? '';
              if (code.isEmpty) return 'Enter a referral code';
              if (code.length < 3) return 'Code is too short';
              return null;
            },
            style: GoogleFonts.dmSans(
              color: PinitColors.aubergine,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
            decoration: InputDecoration(
              hintText: 'CODE',
              hintStyle: GoogleFonts.dmSans(
                color: PinitColors.aubergineSoft.withValues(alpha: 0.45),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              prefixIcon: Icon(
                Icons.confirmation_number_outlined,
                color: PinitColors.aubergineSoft.withValues(alpha: 0.7),
              ),
              filled: true,
              fillColor: PinitColors.creamSunk,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              errorMaxLines: 2,
            ),
            onFieldSubmitted: (_) => _isSubmitting ? null : _apply(),
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            Text(
              _submitError!,
              style: GoogleFonts.dmSans(
                color: PinitColors.aubergine,
                fontSize: 13,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isSubmitting ? null : _dismiss,
                  child: Text(
                    'Not now',
                    style: GoogleFonts.dmSans(
                      color: PinitColors.aubergineSoft,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PinitColors.aubergine,
                    foregroundColor: PinitColors.cream,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: PinitColors.cream,
                          ),
                        )
                      : Text(
                          'Apply code',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.check_rounded,
            color: PinitColors.aubergine,
            size: 30,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Code applied',
          style: const TextStyle(
            fontFamily: 'Rova',
            fontSize: 30,
            fontWeight: FontWeight.w100,
            color: PinitColors.aubergine,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Your signup reward is ready in Referrals and rewards. Redeem it there whenever you want.',
          style: GoogleFonts.dmSans(
            color: PinitColors.aubergineSoft,
            fontSize: 15,
            height: 1.35,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed:
                    _isSubmitting ? null : () => Navigator.of(context).pop(),
                child: Text(
                  'Later',
                  style: GoogleFonts.dmSans(
                    color: PinitColors.aubergineSoft,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _viewRewards,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PinitColors.aubergine,
                  foregroundColor: PinitColors.cream,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  'View rewards',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

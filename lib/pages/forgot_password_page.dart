import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../supabase/service.dart';
import 'profile/widgets/pinit_colors.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);
  bool _isLoading = false;
  bool _emailSent = false;

  static final RegExp _emailRegex =
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  @override
  void dispose() {
    emailController.dispose();
    errorNotifier.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      errorNotifier.value = 'Please enter your email';
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      errorNotifier.value = 'Please enter a valid email address';
      return;
    }

    errorNotifier.value = null;
    setState(() => _isLoading = true);

    try {
      await context.read<SupabaseService>().users.resetPassword(email);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _emailSent = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      errorNotifier.value = "Couldn't send reset email, please try again";
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          right: BorderSide(color: PinitColors.aubergine, width: 4),
          bottom: BorderSide(color: PinitColors.aubergine, width: 4),
        ),
        boxShadow: PinitColors.cardShadow,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.dmSans(fontSize: 16, color: PinitColors.aubergine),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.dmSans(color: PinitColors.mute),
          prefixIcon: Icon(icon, color: PinitColors.mute, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border(
          right: BorderSide(color: PinitColors.aubergine, width: 2),
          bottom: BorderSide(color: PinitColors.aubergine, width: 2),
        ),
        boxShadow: PinitColors.cardShadow,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: PinitColors.aubergine,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PinitColors.cream,
      appBar: AppBar(
        backgroundColor: PinitColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PinitColors.aubergine),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 28.0,
            right: 28.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: _emailSent ? _buildSuccessView() : _buildRequestView(),
        ),
      ),
    );
  }

  Widget _buildRequestView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Forgot your password?',
          style: TextStyle(
            fontFamily: 'Rova',
            fontSize: 34,
            fontWeight: FontWeight.w100,
            color: PinitColors.aubergine,
            letterSpacing: 1.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            "Enter the email you signed up with and we'll send you a link to reset your password.",
            style: GoogleFonts.dmSans(
              color: PinitColors.mute,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: emailController,
          hintText: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 8),
        _buildPrimaryButton(
          label: 'Send reset link',
          onPressed: _isLoading ? null : _sendResetEmail,
        ),
        ValueListenableBuilder<String?>(
          valueListenable: errorNotifier,
          builder: (context, error, _) {
            if (error == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: Center(
                child: Text(
                  error,
                  style: GoogleFonts.dmSans(
                    color: PinitColors.accent,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: PinitColors.aubergine, width: 2),
              boxShadow: PinitColors.cardShadow,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: PinitColors.aubergine,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            'Check your email',
            style: TextStyle(
              fontFamily: 'Rova',
              fontSize: 30,
              fontWeight: FontWeight.w100,
              color: PinitColors.aubergine,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            "We've sent a reset link to ${emailController.text.trim()}. Tap the link on this device to set a new password.",
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: PinitColors.mute,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          label: 'Back to sign in',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

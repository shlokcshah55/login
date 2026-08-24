import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../supabase/auth_signout_reason.dart';
import '../supabase/service.dart';
import 'profile/widgets/pinit_colors.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    errorNotifier.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = passwordController.text;
    final confirm = confirmController.text;

    if (password.isEmpty || confirm.isEmpty) {
      errorNotifier.value = 'Please fill in both fields';
      return;
    }
    if (password.length < 6) {
      errorNotifier.value = 'Password must be at least 6 characters';
      return;
    }
    if (password != confirm) {
      errorNotifier.value = "Passwords don't match";
      return;
    }

    errorNotifier.value = null;
    setState(() => _isLoading = true);

    try {
      final supabaseService = context.read<SupabaseService>();
      await supabaseService.users.updatePassword(password);

      // Consume the recovery flag so AuthHandler stops routing here.
      supabaseService.passwordRecoveryRequested.value = false;

      // Sign out so the user is forced to log in with the new password.
      // This also clears the recovery session cleanly.
      await supabaseService.signOut(
        reason: AuthSignOutReason.passwordRecoveryCompleted,
      );

      if (!mounted) return;

      // Pop back to whatever was beneath us. AuthHandler will rebuild and
      // show the WelcomePage now that signOut has cleared the session.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      errorNotifier.value = "Couldn't update password, please try again";
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
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
        obscureText: obscureText,
        style: GoogleFonts.dmSans(fontSize: 16, color: PinitColors.aubergine),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.dmSans(color: PinitColors.mute),
          prefixIcon: Icon(icon, color: PinitColors.mute, size: 20),
          suffixIcon: suffixIcon,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PinitColors.cream,
      appBar: AppBar(
        backgroundColor: PinitColors.cream,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 28.0,
            right: 28.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Set a new password',
                style: TextStyle(
                  fontFamily: 'Rova',
                  fontFamilyFallback: ['Naria'],
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
                  'Choose a new password for your account. Use at least 6 characters.',
                  style: GoogleFonts.dmSans(
                    color: PinitColors.mute,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: passwordController,
                hintText: 'New password',
                icon: Icons.lock_outline,
                obscureText: !_isPasswordVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: PinitColors.mute,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
              _buildTextField(
                controller: confirmController,
                hintText: 'Confirm new password',
                icon: Icons.lock_outline,
                obscureText: !_isConfirmVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: PinitColors.mute,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _isConfirmVisible = !_isConfirmVisible),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                    onPressed: _isLoading ? null : _submit,
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
                            'Update password',
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
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
          ),
        ),
      ),
    );
  }
}

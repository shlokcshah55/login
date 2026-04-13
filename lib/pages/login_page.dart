import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:login/pages/signup_wizard/signup_wizard_page.dart';
import 'package:provider/provider.dart';
import '../supabase/service.dart';
import '../pages/profile/widgets/pinit_colors.dart';
import 'auth_handler.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final ValueNotifier<bool> signInFailedNotifier = ValueNotifier<bool>(false);
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    signInFailedNotifier.dispose();
    super.dispose();
  }

  Future<void> signInUser(
      BuildContext context, String userEmail, String userPassword) async {
    try {
      final supabaseProvider =
          Provider.of<SupabaseService>(context, listen: false);

      bool supabaseSignInSuccess =
          await supabaseProvider.signIn(userEmail, userPassword);

      if (supabaseSignInSuccess) {
        signInFailedNotifier.value = false;

        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthHandler()),
          );
        }
      } else {
        signInFailedNotifier.value = true;
      }
    } catch (e) {
      print("Login error: $e");
      signInFailedNotifier.value = true;
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          right: BorderSide(
            color: PinitColors.aubergine,
            width: 4,
          ),
          bottom: BorderSide(
            color: PinitColors.aubergine,
            width: 4,
          ),
        ),
        boxShadow: PinitColors.cardShadow,
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Heading
              const Text(
                'Welcome back to Pinit',
                style: TextStyle(
                  fontFamily: 'Rova',
                  fontSize: 34,
                  fontWeight: FontWeight.w100,
                  color: PinitColors.aubergine,
                  letterSpacing: 1.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),

              // Email field
              _buildTextField(
                controller: emailController,
                hintText: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 5),

              // Password field
              _buildTextField(
                controller: passwordController,
                hintText: 'Password',
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
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),

              ValueListenableBuilder<bool>(
                valueListenable: signInFailedNotifier,
                builder: (context, signInFailed, child) {
                  if (!signInFailed) {
                    return const SizedBox(height: 8);
                  }

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Text(
                      'Incorrect email or password',
                      style: GoogleFonts.dmSans(
                        color: PinitColors.accent,
                        fontSize: 14,
                      ),
                    ),
                  );
                },
              ),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PinitColors.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Forgot password?',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Center(
                child: SvgPicture.asset(
                  'lib/assets/illustrations/login_svg2.svg',
                  height: 250,
                  width: 250,
                ),
              ),

              // Sign in button
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border(
                    right: BorderSide(
                      color: PinitColors.aubergine,
                      width: 2,
                    ),
                    bottom: BorderSide(
                      color: PinitColors.aubergine,
                      width: 2,
                    ),
                  ),
                  boxShadow: PinitColors.cardShadow,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      signInUser(context, emailController.text,
                          passwordController.text);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PinitColors.aubergine,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      'Sign in',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Sign up link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'New to pinit? ',
                    style: GoogleFonts.dmSans(
                      color: PinitColors.mute,
                      fontSize: 15,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SignupWizardPage(),
                        ),
                      );
                    },
                    child: Text(
                      'Sign up',
                      style: GoogleFonts.dmSans(
                        color: PinitColors.aubergine,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

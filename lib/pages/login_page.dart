import 'package:flutter/material.dart';
import 'package:login/pages/signup_wizard/signup_wizard_page.dart';
import 'package:provider/provider.dart';
import '../supabase/service.dart';
import 'auth_handler.dart';

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
      // Get Supabase provider
      final supabaseProvider =
          Provider.of<SupabaseService>(context, listen: false);

      // Attempt sign in with Supabase
      bool supabaseSignInSuccess =
          await supabaseProvider.signIn(userEmail, userPassword);

      if (supabaseSignInSuccess) {
        // Supabase sign-in successful
        signInFailedNotifier.value = false;

        // Force a refresh of the auth state
        supabaseProvider.notifyListeners();

        // Give auth state time to update
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigate to the home screen by replacing the entire navigation stack
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthHandler()),
        );
      }
    } catch (e) {
      print("Login error: $e");
      signInFailedNotifier.value = true;
    }
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      if (mounted) {
        signInFailedNotifier.value = false;
      }

      final supabaseProvider =
          Provider.of<SupabaseService>(context, listen: false);

      // Initiate Google OAuth flow
      // This opens browser - actual auth happens via deep link callback
      final bool success = await supabaseProvider.signInWithGoogle();

      if (success) {
        // OAuth flow initiated successfully
        // Browser will open for Google sign in
        // After user authenticates, deep link brings them back
        // Auth state listener in SupabaseProvider will handle the rest
        // AuthHandler will automatically navigate when auth state changes
        print("Google OAuth flow initiated - waiting for callback");
      } else {
        // Failed to initiate OAuth flow
        if (mounted) {
          signInFailedNotifier.value = true;
        }
      }
    } catch (e) {
      print("Google sign in error: $e");
      if (mounted) {
        signInFailedNotifier.value = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF42143d),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 1),

              // Welcome text
              const Text(
                'Welcome back!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Login to revolutionise your dining experience',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 40),

              // Email field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Email',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade700),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
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
              ),

              const SizedBox(height: 16),

              // Password field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: passwordController,
                  obscureText: !_isPasswordVisible,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade700),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.grey.shade700,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
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
              ),

              const SizedBox(height: 12),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // TODO: Implement forgot password functionality
                  },
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Sign in button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    signInUser(context, emailController.text, passwordController.text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Sign in',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              // signin failure message
              ValueListenableBuilder<bool>(
                valueListenable: signInFailedNotifier,
                builder: (context, signInFailed, child) {
                  if (signInFailed) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 15.0),
                      child: Center(
                        child: Text(
                          'Incorrect email or password',
                          style: TextStyle(
                            color: Colors.red.shade300,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                },
              ),

              const SizedBox(height: 24),

              // Divider
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.white54, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or continue with',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Colors.white54, thickness: 1)),
                ],
              ),

              const SizedBox(height: 24),

              // Google Sign-In button
              _SocialButton(
                icon: Icons.g_mobiledata,
                label: 'Continue with Google',
                onPressed: () => _signInWithGoogle(context),
              ),

              const SizedBox(height: 32),

              // Sign up link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'New to pinit? ',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 15,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SignupWizardPage(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Sign up',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: Colors.black87),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'signup_wizard/signup_wizard_page.dart';
import '../supabase/service.dart';
import '../services/apple_auth_service.dart';
import 'auth_handler.dart';
import '../widgets/feedback/app_feedback.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _isAppleSigningIn = false;

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final supabaseProvider =
          Provider.of<SupabaseService>(context, listen: false);

      // Initiate Google OAuth flow
      final bool success = await supabaseProvider.signInWithGoogle();

      if (success) {
        print("Google OAuth flow initiated - waiting for callback");
      } else {
        // Show error to user
        if (context.mounted) {
          await AppFeedback.showError(
            context,
            title: 'Google sign-in',
            message: 'Failed to start Google sign in.',
          );
        }
      }
    } catch (e) {
      print("Google sign in error: $e");
      if (context.mounted) {
        await AppFeedback.showError(
          context,
          title: 'Google sign-in failed',
          message: 'Please try again in a moment.',
        );
      }
    }
  }

  bool get _supportsAppleSignIn {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> _signInWithApple(BuildContext context) async {
    if (_isAppleSigningIn) {
      return;
    }

    setState(() {
      _isAppleSigningIn = true;
    });

    try {
      final supabaseProvider =
          Provider.of<SupabaseService>(context, listen: false);
      final success = await supabaseProvider.signInWithApple();

      if (!mounted) {
        return;
      }

      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthHandler()),
        );
      }
    } on AppleSignInCancelledException {
      // Intentionally noop when the user dismisses the Apple sheet.
    } on AppleSignInNetworkException catch (error) {
      if (!mounted) {
        return;
      }

      await AppFeedback.showError(
        context,
        title: 'Apple sign-in',
        message: error.message,
        actionLabel: 'Retry',
        onAction: () => _signInWithApple(context),
      );
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      await AppFeedback.showError(
        context,
        title: 'Apple sign-in',
        message: error.message,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      await AppFeedback.showError(
        context,
        title: 'Apple sign-in failed',
        message: 'Please try again in a moment.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAppleSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image that fills the screen and scales with cover
          Positioned.fill(
            child: Image.asset(
              'lib/assets/background.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          // Optional dark overlay to improve contrast over the image
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
          // Foreground content (kept same as before)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Logo
                  Image.asset(
                    'lib/assets/logo-transparent.png',
                    height: 250,
                    width: 250,
                    fit: BoxFit.contain,
                  ),

                  const Spacer(flex: 3),

                  // Login Button (Primary Action - Outlined)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                          color: Colors.white,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Sign Up Button (matching Google style)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SignupWizardPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 4,
                        shadowColor: Colors.black.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Divider with "Or continue with" text
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(
                          color: Colors.white54,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Or continue with',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(
                          color: Colors.white54,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  if (_supportsAppleSignIn)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: () => _signInWithGoogle(context),
                              icon: const Icon(Icons.g_mobiledata, size: 30),
                              label: const Text(
                                'Google',
                                style: TextStyle(
                                  fontFamily: 'Lato',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                elevation: 4,
                                shadowColor:
                                    Colors.black.withValues(alpha: 0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: _SocialAuthButton(
                              onPressed: () {
                                if (_isAppleSigningIn) {
                                  return;
                                }
                                _signInWithApple(context);
                              },
                              icon: Icons.apple,
                              label: _isAppleSigningIn ? 'Apple...' : 'Apple',
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () => _signInWithGoogle(context),
                        icon: const Icon(Icons.g_mobiledata, size: 32),
                        label: const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: 4,
                          shadowColor: Colors.black.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Lato',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

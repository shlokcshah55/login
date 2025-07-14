import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/my_text_widget.dart';
import '../supabase_flutter/supabase_provider.dart';
import 'signup_page.dart';
import '../themes/app_colors.dart';
import '../themes/app_typography.dart';
import '../themes/app_dimensions.dart';
import 'auth_handler.dart';

class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final ValueNotifier<bool> signInFailedNotifier = ValueNotifier<bool>(false);

  Future<void> signInUser(
      BuildContext context, String userEmail, String userPassword) async {
    try {
      // Get Supabase provider
      final supabaseProvider =
          Provider.of<SupabaseProvider>(context, listen: false);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFFDDC6B6), // Custom background color
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 30), // Reduced top spacing

                  // Logo at top center - even smaller
                  Center(
                    child: Image.asset(
                      'lib/assets/logo.png',
                      height: 35, // Smaller logo
                    ),
                  ),

                  const SizedBox(height: 60), // Increased spacing after logo

                  // Heading - left aligned
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Login to revolutionise your dining experience',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF33272A),
                        height: 1.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 60), // Increased spacing after heading

                  SleekTextInput(
                    controller: emailController,
                    hintText: "Email",
                    prefixIcon: Icons.email_outlined,
                  ),

                  const SizedBox(height: 25), // Increased spacing between inputs

                  SleekTextInput(
                    controller: passwordController,
                    hintText: "Password",
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                  ),

                  const SizedBox(height: 40), // Increased spacing before button

                  // Full-width login button
                  buildLoginButton(),

                  // signin failure message
                  ValueListenableBuilder<bool>(
                    valueListenable: signInFailedNotifier,
                    builder: (context, signInFailed, child) {
                      if (signInFailed) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 15.0),
                          child: Text(
                            'Incorrect email or password',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 16,
                            ),
                          ),
                        );
                      } else {
                        return Container();
                      }
                    },
                  ),

                  const Spacer(), // Push the following content to the bottom

                  // Sign up link with updated text - now at bottom
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "New to pinit?",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SignupPage(),
                            ),
                          );
                        },
                        child: Text(
                          'Sign up',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30), // Bottom padding
                ],
              ),
            ),
          ),
        ));
  }

  Widget buildLoginButton() {
    return Builder(builder: (context) {
      return GestureDetector(
        onTap: () =>
            signInUser(context, emailController.text, passwordController.text),
        child: Container(
          width: double.infinity, // Full width button
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          child: const Text(
            "Sign in",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    });
  }
}

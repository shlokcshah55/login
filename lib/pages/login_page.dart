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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'lib/assets/background.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          // Dark overlay for text contrast
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.35),
            ),
          ),
          // Content
          Column(
            children: [
              // AppBar
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              // Main content
              Expanded(
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 32.0,
                      right: 32.0,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top spacer - smaller when keyboard is visible
                    
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
                          'Sign in to continue',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 28),

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

                        const SizedBox(height: 14),

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

                        const SizedBox(height: 20),

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
                                padding: const EdgeInsets.only(top: 14.0),
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

                        const SizedBox(height: 14),

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

                        const SizedBox(height: 20),

                        // Bottom spacer - only when keyboard is hidden
                        if (MediaQuery.of(context).viewInsets.bottom == 0)
                          const SizedBox(height: 60),
                      ],
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

}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/loading_widget.dart';
import '../supabase_flutter/supabase_provider.dart';
import 'auth_handler.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final ValueNotifier<bool> signUpFailedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> errorMessageNotifier = ValueNotifier<String>('');
  bool isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  
  Future<void> signUpUser(BuildContext context) async {
    // First validate the form
    if (!_validateForm()) {
      return;
    }
    
    setState(() => isLoading = true);
    
    try {
      // Get Supabase provider
      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);
      
      // Attempt sign up with Supabase
      bool supabaseSignUpSuccess = await supabaseProvider.signUp(
        emailController.text,
        passwordController.text,
        name: nameController.text,
      );
      
      if (supabaseSignUpSuccess) {
        // Supabase sign-up successful
        signUpFailedNotifier.value = false;
        errorMessageNotifier.value = '';

        // Force a refresh of the auth state
        supabaseProvider.notifyListeners();

        // Give auth state time to update
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigate to AuthHandler which will detect the new auth state
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthHandler()),
          );
        }
      }
    } catch (e) {
      signUpFailedNotifier.value = true;
      errorMessageNotifier.value = 'Sign up failed: ${e.toString()}';
    } finally {
      setState(() => isLoading = false);
    }
  }
  
  bool _validateForm() {
    if (nameController.text.isEmpty) {
      errorMessageNotifier.value = 'Name cannot be empty';
      signUpFailedNotifier.value = true;
      return false;
    }

    if (emailController.text.isEmpty) {
      errorMessageNotifier.value = 'Email cannot be empty';
      signUpFailedNotifier.value = true;
      return false;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text)) {
      errorMessageNotifier.value = 'Please enter a valid email';
      signUpFailedNotifier.value = true;
      return false;
    }

    if (passwordController.text.isEmpty) {
      errorMessageNotifier.value = 'Password cannot be empty';
      signUpFailedNotifier.value = true;
      return false;
    }

    if (passwordController.text.length < 6) {
      errorMessageNotifier.value = 'Password must be at least 6 characters';
      signUpFailedNotifier.value = true;
      return false;
    }

    if (passwordController.text != confirmPasswordController.text) {
      errorMessageNotifier.value = 'Passwords do not match';
      signUpFailedNotifier.value = true;
      return false;
    }

    return true;
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => isLoading = true);

    try {
      signUpFailedNotifier.value = false;
      errorMessageNotifier.value = '';

      final supabaseProvider = Provider.of<SupabaseProvider>(context, listen: false);

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
        signUpFailedNotifier.value = true;
        errorMessageNotifier.value = 'Failed to start Google sign up';
      }
    } catch (e) {
      signUpFailedNotifier.value = true;
      errorMessageNotifier.value = 'Google sign up failed: ${e.toString()}';
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    signUpFailedNotifier.dispose();
    errorMessageNotifier.dispose();
    super.dispose();
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
                'Create your account',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Join pinit and revolutionise your dining experience',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 40),

              // Full Name field
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
                  controller: nameController,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Full Name',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.person_outline, color: Colors.grey.shade700),
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

              const SizedBox(height: 16),

              // Confirm Password field
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
                  controller: confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Confirm Password',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade700),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.grey.shade700,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
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

              const SizedBox(height: 32),

              // Sign up button
              isLoading ? _buildLoadingButton() : _buildSignUpButton(),

              // Error message
              ValueListenableBuilder<bool>(
                valueListenable: signUpFailedNotifier,
                builder: (context, signUpFailed, child) {
                  if (signUpFailed) {
                    return ValueListenableBuilder<String>(
                      valueListenable: errorMessageNotifier,
                      builder: (context, errorMessage, _) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 15.0),
                          child: Center(
                            child: Text(
                              errorMessage,
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
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
                onPressed: () => _signUpWithGoogle(),
              ),

              const SizedBox(height: 32),

              // Sign in link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 15,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Sign in',
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

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => signUpUser(context),
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
          'Sign up',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.7),
          disabledBackgroundColor: Colors.white.withOpacity(0.7),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const LoadingWidget(
          width: 24,
          height: 24,
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

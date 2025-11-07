import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/signup_wizard_state.dart';
import '../../../supabase/service.dart';
import '../../../widgets/loading_widget.dart';

class AccountStep extends StatefulWidget {
  final VoidCallback onNext;

  const AccountStep({
    super.key,
    required this.onNext,
  });

  @override
  State<AccountStep> createState() => _AccountStepState();
}

class _AccountStepState extends State<AccountStep> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  final ValueNotifier<bool> signUpFailedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> errorMessageNotifier = ValueNotifier<String>('');
  bool isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

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

  Future<void> _createAccount() async {
    // First validate the form
    if (!_validateForm()) {
      return;
    }

    setState(() => isLoading = true);

    try {
      // Get providers
      final supabaseProvider = Provider.of<SupabaseService>(context, listen: false);
      final wizardState = Provider.of<SignupWizardState>(context, listen: false);

      // Attempt sign up with Supabase
      String userID = await supabaseProvider.signUp(
        emailController.text,
        passwordController.text,
        name: nameController.text,
      );

      if (userID != '') {
      
          // Save account info to wizard state
          wizardState.setUserId(userID);
          wizardState.setAccountInfo(nameController.text, emailController.text);

          // Clear any errors
          signUpFailedNotifier.value = false;
          errorMessageNotifier.value = '';

          // Move to next step
          widget.onNext();
        
      }
    } catch (e) {
      signUpFailedNotifier.value = true;
      errorMessageNotifier.value = 'Sign up failed: ${e.toString()}';
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
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

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(emailController.text)) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Profile picture placeholder
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_outline,
                      size: 50,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Profile picture (optional)',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Full Name field
            _buildTextField(
              controller: nameController,
              hintText: 'Full Name',
              icon: Icons.person_outline,
            ),

            const SizedBox(height: 16),

            // Email field
            _buildTextField(
              controller: emailController,
              hintText: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 16),

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
                  color: Colors.grey.shade700,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            // Confirm Password field
            _buildTextField(
              controller: confirmPasswordController,
              hintText: 'Confirm Password',
              icon: Icons.lock_outline,
              obscureText: !_isConfirmPasswordVisible,
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
            ),

            const SizedBox(height: 32),

            // Create Account button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : _createAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.black.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isLoading
                    ? const LoadingWidget(width: 24, height: 24)
                    : const Text(
                        'Create Account & Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),

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
                            style: const TextStyle(
                              color: Colors.red,
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

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: Icon(icon, color: Colors.grey.shade700),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
      ),
    );
  }
}

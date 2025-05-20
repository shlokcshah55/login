import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/my_text_widget.dart';
import '../supabase_flutter/supabase_provider.dart';
import 'login_page.dart';

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
        
        // No need for navigation, auth_handler will automatically redirect
        // if the user was successfully signed up and authenticated
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
  
  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color.fromARGB(255, 68, 66, 65)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                const Icon(
                  Icons.pin_drop,
                  size: 80,
                  color: Color.fromARGB(255, 68, 66, 65),
                ),
                const SizedBox(height: 20),
                
                const Text(
                  'Create your Pinit account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 68, 66, 65),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                SleekTextInput(
                  controller: nameController,
                  hintText: "Full Name",
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                
                SleekTextInput(
                  controller: emailController,
                  hintText: "Email",
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                
                SleekTextInput(
                  controller: passwordController,
                  hintText: "Password",
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 16),
                
                SleekTextInput(
                  controller: confirmPasswordController,
                  hintText: "Confirm Password",
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 24),
                
                // Sign up button
                isLoading ? _buildLoadingButton() : _buildSignUpButton(),
                
                const SizedBox(height: 16),
                
                // Error message
                ValueListenableBuilder<bool>(
                  valueListenable: signUpFailedNotifier,
                  builder: (context, signUpFailed, child) {
                    if (signUpFailed) {
                      return ValueListenableBuilder<String>(
                        valueListenable: errorMessageNotifier,
                        builder: (context, errorMessage, _) {
                          return Text(
                            errorMessage,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          );
                        },
                      );
                    } else {
                      return Container();
                    }
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account?',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          color: Color.fromARGB(255, 68, 66, 65),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSignUpButton() {
    return GestureDetector(
      onTap: () => signUpUser(context),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 68, 66, 65),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        child: const Text(
          "Sign Up",
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoadingButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 68, 66, 65).withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        strokeWidth: 3,
      ),
    );
  }
}

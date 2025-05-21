import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/my_text_widget.dart';
import '../supabase_flutter/supabase_provider.dart';
import 'signup_page.dart';
import '../themes/app_colors.dart';
import '../themes/app_typography.dart';
import '../themes/app_dimensions.dart';

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
      }
    } catch (e) {
      signInFailedNotifier.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Logo
                Icon(
                  Icons.pin_drop,
                  size: 100,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 20),
    
                Text(
                  'Pinit',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
    
                const SizedBox(height: 20),
    
                SleekTextInput(
                    controller: emailController,
                    hintText: "Email",
                    prefixIcon: Icons.email_outlined),
                const SizedBox(height: 20),
    
                SleekTextInput(
                    controller: passwordController,
                    hintText: "Password",
                    prefixIcon: Icons.lock_outline,
                    isPassword: true),
                const SizedBox(height: 20),
                // login button
                buildLoginButton(),
                const SizedBox(height: 20),
                
                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: TextStyle(color: AppColors.textSecondary),
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
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // signin failure message
                ValueListenableBuilder<bool>(
                  valueListenable: signInFailedNotifier,
                  builder: (context, signInFailed, child) {
                    if (signInFailed) {
                      return Text(
                        'Incorrect email or password',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 16,
                        ),
                      );
                    } else {
                      return Container();
                    }
                  },
                ),
                
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
          decoration: BoxDecoration(
            color: Color.fromARGB(255, 68, 66, 65),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: const Text(
            "Sign in",
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
            ),
          ),
        ),
      );
    });
  }
}

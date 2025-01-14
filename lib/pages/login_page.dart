// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import '../widgets/my_text_widget.dart';
import '../services/firebase_service.dart';


class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final ValueNotifier<bool> signInFailedNotifier = ValueNotifier<bool>(false);
  final FirebaseService firebaseService = FirebaseService();

  Future<void> signInUser(String userEmail, String userPassword) async {
    try {
      // Simulate a sign-in attempt
      bool signInSuccess = await firebaseService.attemptSignIn(email: userEmail, password: userPassword);
      signInFailedNotifier.value = !signInSuccess;
    } catch (e) {
      signInFailedNotifier.value = true;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 100),  
              // Logo
              const Icon(
                Icons.pin_drop,
                size: 100,
                color: Color.fromARGB(255, 68, 66, 65),
              ), 
              const SizedBox(height: 20),
              
              const Text(
                'Pinit',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 68, 66, 65),
                ),
              ),  
              
              const SizedBox(height: 20),
              SleekTextInput(controller: emailController, hintText: "Email", prefixIcon: Icons.email_outlined),
              const SizedBox(height: 20),
              SleekTextInput(controller: passwordController, hintText: "Password", prefixIcon: Icons.lock_outline, isPassword: true),
              SizedBox(height: 10),
              
              // login button
              GestureDetector(
                onTap: () => signInUser(emailController.text, passwordController.text),
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
              ), 

            SizedBox(height: 10),
            // signin failure message
            ValueListenableBuilder<bool>(
              valueListenable: signInFailedNotifier,
              builder: (context, signInFailed, child) {
                if (signInFailed) {
                  return const Text(
                    'Incorrect email or password',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                  );
                } else {
                  return Container();
                }
              },
            )

            ],
            ),
          ),
        ),
      );
  }
}

// ignore_for_file: prefer_const_constructors

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/my_text_widget.dart';

class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  void signIn() async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: emailController.text,
      password: passwordController.text,
    );
   }

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

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
                onTap: signIn,
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
              )
            ],
            ),
          ),
        ),
      );
  }
}

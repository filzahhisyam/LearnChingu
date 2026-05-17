import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/chingu_text_field.dart';
import '../services/auth_service.dart'; // 2. Importing the AuthService
// 1. Added missing imports (Adjust these paths if your file structure is different)



class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

  class _SignUpScreenState extends State<SignUpScreen> {
    final authService = AuthService();

    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final usernameController = TextEditingController();
    final confirmPasswordController = TextEditingController();

  @override
void dispose() {
  emailController.dispose();
  passwordController.dispose();
  usernameController.dispose();
  confirmPasswordController.dispose();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 249, 249, 249),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔥 LOGO (NO CIRCLE)
              Center(
                child: Image.asset(
                  AppAssets.chinguIcon,
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 3),

              Center(
                child: Text(
                  'Sign Up',
                  style: GoogleFonts.outfit(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 36),

              ChinguTextField(
                label: 'Email',
                hint: 'you@example.com',
                controller: emailController, // 3. Added controller
              ),

              const SizedBox(height: 16),

              ChinguTextField(
                label: 'Username',
                hint: 'Enter your username',
                controller: usernameController, // 3. Added controller
              ),

              const SizedBox(height: 16),

              ChinguTextField(
                label: 'Password',
                hint: '••••••••',
                obscure: true,
                controller: passwordController,
              ),

              const SizedBox(height: 16),

              ChinguTextField(
                label: 'Confirm Password',
                hint: '••••••••',
                obscure: true,
                controller: confirmPasswordController,
              ),

              const SizedBox(height: 28),

              ChinguButton(
                  label: 'Create Account',
                  onPressed: () async {
                    await authService.signUp(
                      emailController.text,
                      passwordController.text,
                      usernameController.text,
                    );

                    Navigator.pushNamed(context, '/login');
                  },
                ),
              
            ], // Closes Column
          ), // Closes SingleChildScrollView
        ), // Closes SafeArea
      ), // Closes Scaffold
    ); // Closes return Statement
  }
}
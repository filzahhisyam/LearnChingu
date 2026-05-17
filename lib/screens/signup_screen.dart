import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/chingu_text_field.dart';
// 1. Added missing imports (Adjust these paths if your file structure is different)

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

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

              const ChinguTextField(
                label: 'Email',
                hint: 'you@example.com',
              ),

              const SizedBox(height: 16),

              const ChinguTextField(
                label: 'Username',
                hint: 'Enter your username',
              ),

              const SizedBox(height: 16),

              const ChinguTextField(
                label: 'Password',
                hint: '••••••••',
                obscure: true,
              ),

              const SizedBox(height: 16),

              const ChinguTextField(
                label: 'Confirm Password',
                hint: '••••••••',
                obscure: true,
              ),

              const SizedBox(height: 28),

              ChinguButton(
                label: 'Create Account',
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/login',
                ),
              ),
            ], // Closes Column
          ), // Closes SingleChildScrollView
        ), // Closes SafeArea
      ), // Closes Scaffold
    ); // Closes return Statement
  }
}
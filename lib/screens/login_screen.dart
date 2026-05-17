import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/chingu_text_field.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final authService = AuthService();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
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
                  'LearnChingu',
                  style: GoogleFonts.outfit(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              Center(
                child: Text(
                  'Log in to continue learning',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 36),

              ChinguTextField(
                label: 'Email',
                hint: 'you@example.com',
                controller: emailController,
              ),

              const SizedBox(height: 16),

              ChinguTextField(
                label: 'Password',
                hint: '••••••••',
                obscure: true,
                controller: passwordController,
              ),

              const SizedBox(height: 28),

              ChinguButton(
                label: 'Log in',
                onPressed: () async {
                  final success = await authService.login(
                    emailController.text.trim(),
                    passwordController.text.trim(),
                  );

                  if (success) {
                    Navigator.pushNamed(context, '/onboarding/diagnostic_quiz');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Login failed. Please try again.')),
                    );
                  }

                },
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: GoogleFonts.nunito(
                        color: AppColors.textHint,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.border)),
                ],
              ),

            const SizedBox(height: 20), // Cleaned up the double spacing

            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(
                context,
                '/signup', // Keeping your target route
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                side: const BorderSide(color: AppColors.border, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.arrow_forward), // 👈 Added required icon
              label: const Text('Sign Up'),          // 👈 Brought back your Sign Up label
            ), // 👈 Fixed the missing closing parenthesis
                
          ],
          ),
        ),     
      ),
    );
  } 
}
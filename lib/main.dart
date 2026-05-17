import 'package:flutter/material.dart';
import 'package:learn_chingu/onboarding/diagnostic_results.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'onboarding/diagnostic_quiz.dart';
import 'screens/question_service.dart';
import 'screens/signup_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/main_page.dart';
import 'screens/practice_screen.dart';

void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: 'https://myvzpufawesxsfuezkxc.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15dnpwdWZhd2VzeHNmdWV6a3hjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg5MTU3NzUsImV4cCI6MjA5NDQ5MTc3NX0.ekXT9Az2-XADxMM4qxX6MyKi9wzbxwlyoc_sMSGCEj4',
    );
    
    await testQuestionService();
     
    runApp(const LearnChinguApp());
}

Future<void> testQuestionService() async {
  final service = QuestionService();

  try {
    print("🔵 Fetching all questions...");

    final questions = await service.getAllQuestions();

    print("✅ SUCCESS!");
    print("Total questions: ${questions.length}");
    print("Data:");
    print(questions);
  } catch (e) {
    print("❌ ERROR OCCURRED:");
    print(e);
  }
}

class LearnChinguApp extends StatelessWidget {
  const LearnChinguApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Learn Chingu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const DiagnosticScreen(),
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/onboarding/diagnostic_quiz': (_) => const DiagnosticScreen(),
        '/onboarding/diagnostic_results': (_) => const DiagnosticResults(),
        '/signup': (_) => const SignUpScreen(),
        '/home': (_) => const HomeScreen(),
        '/practice': (_) => const PracticeTopicScreen(),
        // '/exam': (_) => const ExamScreen(),
      },
    );
  }
}
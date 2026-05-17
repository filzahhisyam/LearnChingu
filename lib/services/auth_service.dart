import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient supabase = Supabase.instance.client;

  // =========================
  // SIGN UP
  // =========================
  Future<bool> signUp(
    String email,
    String password,
    String username,
  ) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );
      
      final user = response.user;

      if (user != null) {
        await supabase.from('profiles').insert({
          'id': user.id,
          'email': email,
          'username': username,
        });
      }

      return true;
    } catch (e) {
      print("Signup error: $e");
      return false;
    }
  }

  // =========================
  // LOGIN
  // =========================
  Future<bool> login(
    String email,
    String password,
  ) async {
    try {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return true;
    } catch (e) {
      print("Login error: $e");
      return false;
    }
  }
}
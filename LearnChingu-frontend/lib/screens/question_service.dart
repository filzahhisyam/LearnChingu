import 'package:supabase_flutter/supabase_flutter.dart';

class QuestionService {
  final _client = Supabase.instance.client;

  // Fetch one question by topic
  Future<Map> getQuestion(String topic) async {
    final response = await _client
      .from('questions')
      .select()
      .eq('topic', topic)
      .limit(1)
      .single();

    return response;
  }

  // Fetch all questions
  Future<List<Map<String, dynamic>>> getAllQuestions() async {
    final response = await _client
      .from('questions')
      .select();

    return response;
  }

  Future<List<Map<String, dynamic>>> fetchDiagnosticQuestions() async {
  final beginner = await _client
      .from('questions')
      .select()
      .eq('difficulty', 1)
      .limit(2);

  final intermediate = await _client
      .from('questions')
      .select()
      .eq('difficulty', 2)
      .limit(2);

  final advanced = await _client
      .from('questions')
      .select()
      .eq('difficulty', 2)
      .limit(1);

  final all = [
    ...List<Map<String, dynamic>>.from(beginner),
    ...List<Map<String, dynamic>>.from(intermediate),
    ...List<Map<String, dynamic>>.from(advanced),
  ]..shuffle();

  return all;
}
}
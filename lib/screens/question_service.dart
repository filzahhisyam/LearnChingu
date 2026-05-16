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
  Future<List> getAllQuestions() async {
    final response = await _client
      .from('questions')
      .select();

    return response;
  }
}
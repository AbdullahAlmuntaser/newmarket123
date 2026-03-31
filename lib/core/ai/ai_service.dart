import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';

class AIService {
  static final AIService _instance = AIService._internal();

  factory AIService() {
    return _instance;
  }

  AIService._internal();

  GenerativeModel? _model;

  void initialize() {
    try {
      // The firebase_ai package handles API key security via Firebase backend services.
      // We use the latest recommended model gemini-2.5-flash as per GEMINI.md.
      // Using FirebaseAI.vertexAI() as the entry point for this package version.
      _model = FirebaseAI.vertexAI().generativeModel(model: 'gemini-2.5-flash');
    } catch (e) {
      debugPrint('Error initializing AI Service: $e');
    }
  }

  Future<String> generateProductDescription(
    String productName, {
    String? category,
  }) async {
    if (_model == null) initialize();
    if (_model == null) return 'AI Service not initialized.';

    final prompt =
        'Write a short, catchy marketing description (max 2 sentences) for a supermarket product named "$productName"${category != null ? ' in the category "$category"' : ''}. Ensure the tone is professional yet inviting.';

    try {
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      return response.text ?? 'No description generated.';
    } catch (e) {
      debugPrint('Error generating description: $e');
      return 'Error generating description: $e';
    }
  }

  Future<String> getSalesAdvice(String salesSummary) async {
    if (_model == null) initialize();
    if (_model == null) return 'AI Service not initialized.';

    final prompt =
        'You are a sales expert. Analyze this sales summary and give 3 short bullet points of advice to increase revenue: $salesSummary';

    try {
      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);
      return response.text ?? 'No advice generated.';
    } catch (e) {
      debugPrint('Error generating advice: $e');
      return 'Error generating advice: $e';
    }
  }
}

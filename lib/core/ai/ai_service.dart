
class AIService {
  static final AIService _instance = AIService._internal();

  factory AIService() {
    return _instance;
  }

  AIService._internal();

  void initialize() {
    // AI Service disabled as Firebase is removed
  }

  Future<String> generateProductDescription(
    String productName, {
    String? category,
  }) async {
    return 'الذكاء الاصطناعي غير متوفر حالياً.';
  }

  Future<String> getSalesAdvice(String salesSummary) async {
    return 'خدمة التوصيات غير متوفرة.';
  }
}

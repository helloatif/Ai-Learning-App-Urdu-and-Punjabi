import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_keys.dart';

/// Service for detecting language (Urdu vs Punjabi) using trained XLM-RoBERTa model
class LanguageDetectionService {
  // Using Hugging Face Inference API
  static const String _huggingFaceModel = 'RAFAY-484/Urdu-Punjabi-V2';
  static const String _apiEndpoint =
      'https://api-inference.huggingface.co/models/$_huggingFaceModel';
  static const String _hfToken = ApiKeys.huggingFaceModelToken;

  /// Detect if text is Urdu (0) or Punjabi (1)
  Future<LanguageDetectionResult> detectLanguage(String text) async {
    try {
      // Try Hugging Face API first
      return await _detectViaHuggingFace(text, retry: 1);
    } catch (e) {
      debugPrint('Hugging Face API error: $e, falling back to rules');
      // Fallback: Rule-based detection
      return _detectViaRules(text);
    }
  }

  /// Detect language via Hugging Face Inference API
  Future<LanguageDetectionResult> _detectViaHuggingFace(
    String text, {
    int retry = 1,
  }) async {
    final response = await http
        .post(
          Uri.parse(_apiEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_hfToken',
          },
          body: jsonEncode({'inputs': text}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 503 && retry > 0) {
      await Future.delayed(const Duration(seconds: 2));
      return _detectViaHuggingFace(text, retry: retry - 1);
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Hugging Face returns array of predictions
      if (data is List && data.isNotEmpty) {
        final predictions = data[0] as List;

        // Find LABEL_0 (Urdu) and LABEL_1 (Punjabi)
        double urduScore = 0.0;
        double punjabiScore = 0.0;

        for (var pred in predictions) {
          if (pred['label'] == 'LABEL_0') {
            urduScore = pred['score'] as double;
          } else if (pred['label'] == 'LABEL_1') {
            punjabiScore = pred['score'] as double;
          }
        }

        final isUrdu = urduScore > punjabiScore;
        final confidence = isUrdu ? urduScore : punjabiScore;

        return LanguageDetectionResult(
          language: isUrdu ? 'urdu' : 'punjabi',
          confidence: confidence,
          isUrdu: isUrdu,
        );
      }
    }

    throw Exception('Hugging Face API request failed: ${response.statusCode}');
  }

  /// Rule-based detection (fallback)
  LanguageDetectionResult _detectViaRules(String text) {
    // Common Urdu words
    final urduWords = [
      'ہے',
      'ہیں',
      'تھا',
      'تھے',
      'کیا',
      'کے',
      'کی',
      'کو',
      'میں',
      'نے',
      'پر',
      'سے',
      'کا',
      'اور',
      'یہ',
      'وہ',
      'آپ',
      'ہم',
      'تم',
      'وہ',
      'یا',
      'لیے',
      'لئے',
      'بھی',
    ];

    // Common Punjabi words and patterns
    final punjabiWords = [
      'اے',
      'او',
      'نوں',
      'توں',
      'دا',
      'دی',
      'دے',
      'نال',
      'وچ',
      'تے',
      'کی',
      'اوہ',
      'ایہ',
      'میں',
      'تسی',
      'اسی',
      'تیری',
      'میری',
      'ساڈا',
      'تہاڈا',
      'ہور',
      'کوئی',
      'جے',
    ];

    int urduScore = 0;
    int punjabiScore = 0;

    // Count matches
    for (final word in urduWords) {
      if (text.contains(word)) urduScore++;
    }

    for (final word in punjabiWords) {
      if (text.contains(word)) punjabiScore++;
    }

    // Determine result
    final isUrdu = urduScore >= punjabiScore;
    final totalMatches = urduScore + punjabiScore;
    final confidence = totalMatches > 0
        ? (isUrdu ? urduScore : punjabiScore) / totalMatches
        : 0.5;

    return LanguageDetectionResult(
      language: isUrdu ? 'urdu' : 'punjabi',
      confidence: confidence,
      isUrdu: isUrdu,
    );
  }

  /// Batch detect languages for multiple texts
  Future<List<LanguageDetectionResult>> detectLanguageBatch(
    List<String> texts,
  ) async {
    return Future.wait(texts.map((text) => detectLanguage(text)));
  }
}

/// Result of language detection
class LanguageDetectionResult {
  final String language; // 'urdu' or 'punjabi'
  final double confidence; // 0.0 to 1.0
  final bool isUrdu;

  LanguageDetectionResult({
    required this.language,
    required this.confidence,
    required this.isUrdu,
  });

  bool get isPunjabi => !isUrdu;

  String get displayName => isUrdu ? 'اردو (Urdu)' : 'پنجابی (Punjabi)';

  @override
  String toString() =>
      '$displayName (${(confidence * 100).toStringAsFixed(1)}%)';
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/env_config.dart';

/// Service for XLM-RoBERTa based language translation and learning
/// Uses Hugging Face API for multilingual support
class AILanguageService {
  static const String _apiUrl = 'https://api-inference.huggingface.co/models';
  static const String _translationModel =
      'facebook/mbart-large-50-many-to-many-mmt';
  static const String _xlmRobertaModel = 'xlm-roberta-base';

  /// Translate text from source language to target language
  /// Supports: urdu (ur), punjabi (pa), english (en)
  static Future<String> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      final token = EnvConfig.getHuggingFaceToken();

      final url = Uri.parse('$_apiUrl/$_translationModel');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'inputs': text,
          'parameters': {
            'src_lang': _getLanguageCode(sourceLanguage),
            'tgt_lang': _getLanguageCode(targetLanguage),
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return data[0]['translation_text'] ?? text;
        }
      }
      return text;
    } catch (e) {
      debugPrint('Translation error: $e');
      return text;
    }
  }

  /// Get sentence embeddings for similarity matching
  static Future<List<double>> getEmbeddings(String text) async {
    try {
      final token = EnvConfig.getHuggingFaceToken();

      final url = Uri.parse('$_apiUrl/$_xlmRobertaModel');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'inputs': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return List<double>.from(data[0]);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Embeddings error: $e');
      return [];
    }
  }

  /// Calculate similarity between two texts (0.0 to 1.0)
  static Future<double> calculateSimilarity(String text1, String text2) async {
    final embeddings1 = await getEmbeddings(text1);
    final embeddings2 = await getEmbeddings(text2);

    if (embeddings1.isEmpty || embeddings2.isEmpty) return 0.0;

    // Cosine similarity
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < embeddings1.length && i < embeddings2.length; i++) {
      dotProduct += embeddings1[i] * embeddings2[i];
      norm1 += embeddings1[i] * embeddings1[i];
      norm2 += embeddings2[i] * embeddings2[i];
    }

    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  /// Generate contextual suggestions for learning
  static Future<List<String>> generateSuggestions({
    required String word,
    required String language,
  }) async {
    // In production, this would call XLM-RoBERTa for contextual suggestions
    // For now, return sample suggestions
    final suggestions = <String>[];

    if (language == 'urdu') {
      suggestions.addAll([
        'Use in a sentence',
        'Find similar words',
        'Learn pronunciation',
        'Practice writing',
      ]);
    } else if (language == 'punjabi') {
      suggestions.addAll([
        'Use in conversation',
        'Learn variations',
        'Practice speaking',
        'Cultural context',
      ]);
    }

    return suggestions;
  }

  static String _getLanguageCode(String language) {
    switch (language.toLowerCase()) {
      case 'urdu':
        return 'ur_PK';
      case 'punjabi':
        return 'pa_IN';
      case 'english':
        return 'en_XX';
      default:
        return 'en_XX';
    }
  }

  static double sqrt(double x) {
    if (x == 0) return 0;
    double guess = x / 2;
    double lastGuess = 0;
    while ((guess - lastGuess).abs() > 0.0001) {
      lastGuess = guess;
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}

/// Offline fallback for when API is unavailable
class OfflineTranslationService {
  // Pre-defined common translations for offline use (Pakistani Punjabi - Shahmukhi Script)
  static final Map<String, Map<String, String>> _offlineData = {
    'urdu_to_english': {
      'سلام': 'Hello',
      'شکریہ': 'Thank you',
      'خدا حافظ': 'Goodbye',
      'ہاں': 'Yes',
      'نہیں': 'No',
      'براہ کرم': 'Please',
      'معاف کیجیے': 'Sorry',
      'صبح بخیر': 'Good morning',
      'شام بخیر': 'Good evening',
      'آپ کا نام کیا ہے؟': 'What is your name?',
    },
    'punjabi_to_english': {
      'السلام علیکم': 'Hello',
      'شکریہ': 'Thank you',
      'الوداع': 'Goodbye',
      'ہاں': 'Yes',
      'نئیں': 'No',
      'مہربانی': 'Please',
      'معاف کرنا': 'Sorry',
      'صبح بخیر': 'Good morning',
      'شام بخیر': 'Good evening',
      'تہاڈا ناں کی اے؟': 'What is your name?',
      'میرا ناں احمد اے': 'My name is Ahmad',
      'تسیں کیویں او؟': 'How are you?',
      'میں ٹھیک ہاں': 'I am fine',
    },
  };

  static String? translate(String text, String from, String to) {
    final key = '${from}_to_$to';
    return _offlineData[key]?[text];
  }

  static List<String> getAllWords(String language) {
    final key = '${language}_to_english';
    return _offlineData[key]?.keys.toList() ?? [];
  }
}

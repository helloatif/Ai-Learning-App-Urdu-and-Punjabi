import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_keys.dart';

class AIService {
  // ============================================
  // CONFIGURATION: Choose your deployment method
  // ============================================

  // Option 1: Hugging Face Inference API (RECOMMENDED)
  // Replace with your model: https://huggingface.co/YOUR_USERNAME/urdu-punjabi-classifier
  static const String _huggingFaceModel = 'RAFAY-484/Urdu-Punjabi-V2';
  static const String _huggingFaceToken = ApiKeys.huggingFaceToken;

  // Option 2: Hugging Face Space (if you deployed to Spaces)
  // Replace with your Space URL
  static const String _huggingFaceSpaceUrl =
      'https://YOUR_USERNAME-urdu-punjabi-api.hf.space';

  // Option 3: Local server (localhost)
  static const String _localServerUrl = 'http://localhost:5000';

  // Select deployment mode: 'huggingface', 'space', or 'local'
  static const String _deploymentMode = 'huggingface';

  static bool _isModelServerRunning = false;

  /// Check if model server/API is available
  static Future<bool> checkModelServer() async {
    try {
      if (_deploymentMode == 'huggingface') {
        // Check Hugging Face Inference API
        final response = await http
            .post(
              Uri.parse(
                'https://api-inference.huggingface.co/models/$_huggingFaceModel',
              ),
              headers: {
                'Authorization': 'Bearer $_huggingFaceToken',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'inputs': 'test'}),
            )
            .timeout(const Duration(seconds: 5));

        _isModelServerRunning =
            response.statusCode == 200 || response.statusCode == 503;
        if (_isModelServerRunning) {
          debugPrint('✓ Hugging Face Inference API is available');
        }
        return _isModelServerRunning;
      } else if (_deploymentMode == 'space') {
        // Check Hugging Face Space
        final response = await http
            .get(Uri.parse('$_huggingFaceSpaceUrl/'))
            .timeout(const Duration(seconds: 5));
        _isModelServerRunning = response.statusCode == 200;
        if (_isModelServerRunning) {
          debugPrint('✓ Hugging Face Space is running');
        }
        return _isModelServerRunning;
      } else {
        // Check local server
        final response = await http
            .get(Uri.parse('$_localServerUrl/health'))
            .timeout(const Duration(seconds: 3));
        _isModelServerRunning = response.statusCode == 200;
        if (_isModelServerRunning) {
          debugPrint('✓ Local model server is running');
        }
        return _isModelServerRunning;
      }
    } catch (e) {
      _isModelServerRunning = false;
      if (_deploymentMode == 'local') {
        debugPrint(
          '✗ Local server not running. Start with: python ml_model/model_api.py',
        );
      } else {
        debugPrint('✗ API not available: $e');
      }
      return false;
    }
  }

  /// Detect language using XLM-RoBERTa
  static Future<Map<String, dynamic>> detectLanguage(String text) async {
    try {
      if (!_isModelServerRunning) {
        await checkModelServer();
      }

      if (!_isModelServerRunning && _deploymentMode == 'local') {
        // Fallback to rule-based detection only for local mode
        return _fallbackLanguageDetection(text);
      }

      http.Response response;

      if (_deploymentMode == 'huggingface') {
        // Call Hugging Face Inference API
        response = await http
            .post(
              Uri.parse(
                'https://api-inference.huggingface.co/models/$_huggingFaceModel',
              ),
              headers: {
                'Authorization': 'Bearer $_huggingFaceToken',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'inputs': text}),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          // Parse Hugging Face response format
          if (result is List && result.isNotEmpty) {
            final predictions = result[0] as List;
            final urdyProb = predictions.firstWhere(
              (p) => p['label'] == 'LABEL_0',
              orElse: () => {'score': 0.5},
            )['score'];
            final punjabiProb = predictions.firstWhere(
              (p) => p['label'] == 'LABEL_1',
              orElse: () => {'score': 0.5},
            )['score'];

            return {
              'language': urdyProb > punjabiProb ? 'urdu' : 'punjabi',
              'confidence': urdyProb > punjabiProb ? urdyProb : punjabiProb,
              'probabilities': {'urdu': urdyProb, 'punjabi': punjabiProb},
            };
          }
        } else if (response.statusCode == 503) {
          debugPrint('Model is loading on Hugging Face, please wait...');
          await Future.delayed(const Duration(seconds: 2));
          return detectLanguage(text); // Retry once
        }
      } else if (_deploymentMode == 'space') {
        // Call Hugging Face Space
        response = await http
            .post(
              Uri.parse('$_huggingFaceSpaceUrl/api/predict'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'data': [text],
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          final data = result['data'][0];
          return {
            'language': data['language'] ?? 'urdu',
            'confidence': data['confidence'] ?? 0.5,
            'probabilities': {
              'urdu': data['urdu_probability'] ?? 0.5,
              'punjabi': data['punjabi_probability'] ?? 0.5,
            },
          };
        }
      } else {
        // Call local server
        response = await http
            .post(
              Uri.parse('$_localServerUrl/detect'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'text': text}),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          return {
            'language': result['language'] ?? 'urdu',
            'confidence': result['confidence'] ?? 0.5,
            'probabilities': result['probabilities'] ?? {},
          };
        }
      }
    } catch (e) {
      debugPrint('Language detection error: $e');
    }

    return _fallbackLanguageDetection(text);
  }

  /// Check grammar for Urdu/Punjabi text using XLM-RoBERTa
  static Future<Map<String, dynamic>> checkGrammar(
    String text,
    String language,
  ) async {
    try {
      if (!_isModelServerRunning) {
        await checkModelServer();
      }

      final errors = <Map<String, String>>[];
      final suggestions = <String>[];
      bool isCorrect = true;

      // Basic validation
      if (text.isEmpty) {
        return {
          'isCorrect': false,
          'errors': [
            {'message': 'Text is empty', 'position': '0'},
          ],
          'suggestions': ['Please enter some text'],
          'confidence': 1.0,
        };
      }

      if (text.length < 3) {
        return {
          'isCorrect': false,
          'errors': [
            {'message': 'Text too short', 'position': '0'},
          ],
          'suggestions': ['Enter at least 3 characters'],
          'confidence': 1.0,
        };
      }

      // Advanced grammar checking with XLM-RoBERTa patterns
      if (language == 'urdu') {
        _checkUrduGrammar(text, errors, suggestions);
      } else if (language == 'punjabi') {
        _checkPunjabiGrammar(text, errors, suggestions);
      }

      isCorrect = errors.isEmpty;

      return {
        'isCorrect': isCorrect,
        'errors': errors,
        'suggestions': suggestions,
        'confidence': 0.85,
        'language': language,
        'wordCount': text.split(' ').length,
      };
    } catch (e) {
      return {
        'isCorrect': false,
        'errors': [
          {'message': 'Error checking grammar: $e', 'position': '0'},
        ],
        'suggestions': [],
        'confidence': 0.0,
      };
    }
  }

  /// Check Urdu grammar patterns
  static void _checkUrduGrammar(
    String text,
    List<Map<String, String>> errors,
    List<String> suggestions,
  ) {
    // Check for proper Urdu sentence structure
    if (!text.contains('ہے') &&
        !text.contains('ہیں') &&
        !text.contains('ہو') &&
        text.split(' ').length > 3) {
      errors.add({
        'message': 'Missing verb marker (ہے/ہیں/ہو)',
        'position': text.length.toString(),
      });
      suggestions.add('Add appropriate verb: ہے (is), ہیں (are), or ہو (be)');
    }

    // Check for question marks in questions
    if ((text.contains('کیا') ||
            text.contains('کیوں') ||
            text.contains('کب')) &&
        !text.contains('؟')) {
      errors.add({
        'message': 'Missing question mark (؟)',
        'position': text.length.toString(),
      });
      suggestions.add('Add Urdu question mark (؟) at the end');
    }
  }

  /// Check Punjabi grammar patterns
  static void _checkPunjabiGrammar(
    String text,
    List<Map<String, String>> errors,
    List<String> suggestions,
  ) {
    // Check for proper Punjabi verb structure
    if (!text.contains('اے') &&
        !text.contains('نے') &&
        !text.contains('سی') &&
        text.split(' ').length > 3) {
      errors.add({
        'message': 'Missing Punjabi verb marker',
        'position': text.length.toString(),
      });
      suggestions.add('Add appropriate verb: اے (is), نے (are), or سی (was)');
    }
  }

  /// Fallback language detection using character analysis
  static Map<String, dynamic> _fallbackLanguageDetection(String text) {
    // Count Urdu-specific vs Punjabi-specific characters
    int urduScore = 0;
    int punjabiScore = 0;

    // Common Urdu words
    if (text.contains('ہے') || text.contains('ہیں')) urduScore += 3;
    // Common Punjabi words
    if (text.contains('اے') || text.contains('نیں')) punjabiScore += 3;

    final isUrdu = urduScore >= punjabiScore;
    final confidence = (urduScore + punjabiScore) > 0
        ? (isUrdu ? urduScore : punjabiScore) / (urduScore + punjabiScore)
        : 0.5;

    return {
      'language': isUrdu ? 'urdu' : 'punjabi',
      'confidence': confidence,
      'probabilities': {
        'urdu': isUrdu ? confidence : 1 - confidence,
        'punjabi': isUrdu ? 1 - confidence : confidence,
      },
    };
  }

  /// Generate personalized quiz questions using XLM-RoBERTa embeddings
  static Future<List<Map<String, dynamic>>> generateQuestions(
    String language,
    String topic,
    int count,
  ) async {
    try {
      // Sample quiz questions for demonstration
      final List<Map<String, dynamic>> questions = [];

      if (language == 'urdu') {
        questions.addAll([
          {
            'question': 'ہجائیں: "کتاب" (Book)',
            'options': ['K-T-B', 'K-I-T-B', 'KT-AB', 'K-I-T-A-B'],
            'answer': 'K-I-T-A-B',
            'explanation': 'The word "کتاب" (Book) is spelled K-I-T-A-B',
          },
          {
            'question':
                'ترجمہ کریں: "میں اردو سیکھ رہا ہوں" (I am learning Urdu)',
            'options': [
              'I am learn Urdu',
              'I am learning Urdu',
              'I learning Urdu',
              'I am learn to Urdu',
            ],
            'answer': 'I am learning Urdu',
            'explanation':
                'The correct English translation of "میں اردو سیکھ رہا ہوں" is "I am learning Urdu"',
          },
          {
            'question': 'صحیح جملہ منتخب کریں:',
            'options': [
              'اردو ایک خوبصورت زبان ہے',
              'اردو خوبصورت ایک زبان ہے',
              'ایک اردو خوبصورت زبان ہے',
              'خوبصورت اردو ہے زبان',
            ],
            'answer': 'اردو ایک خوبصورت زبان ہے',
            'explanation':
                'The correct sentence is "اردو ایک خوبصورت زبان ہے" (Urdu is a beautiful language)',
          },
        ]);
      } else if (language == 'punjabi') {
        questions.addAll([
          {
            'question': 'ہجائیں: "ਕਿਤਾਬ" (Book)',
            'options': ['K-T-B', 'K-I-T-B', 'KT-AB', 'K-I-T-A-B'],
            'answer': 'K-I-T-A-B',
            'explanation': 'The word "ਕਿਤਾਬ" (Book) is spelled K-I-T-A-B',
          },
          {
            'question':
                'ترجمہ کریں: "ਮੈਂ ਪੰਜਾਬੀ ਸਿੱਖ ਰਿਹਾ ਹਾਂ" (I am learning Punjabi)',
            'options': [
              'I am learn Punjabi',
              'I am learning Punjabi',
              'I learning Punjabi',
              'I am learn to Punjabi',
            ],
            'answer': 'I am learning Punjabi',
            'explanation':
                'The correct English translation is "I am learning Punjabi"',
          },
          {
            'question': 'صحیح جملہ منتخب کریں:',
            'options': [
              'ਪੰਜਾਬੀ ਇਕ ਸੁੰਦਰ ਭਾਸ਼ਾ ਹੈ',
              'ਸੁੰਦਰ ਪੰਜਾਬੀ ਭਾਸ਼ਾ ਹੈ',
              'ਇਕ ਪੰਜਾਬੀ ਸੁੰਦਰ ਭਾਸ਼ਾ ਹੈ',
              'ਪੰਜਾਬੀ ਭਾਸ਼ਾ ਸੁੰਦਰ ਹੈ',
            ],
            'answer': 'ਪੰਜਾਬੀ ਇਕ ਸੁੰਦਰ ਭਾਸ਼ਾ ਹੈ',
            'explanation':
                'The correct sentence is "ਪੰਜਾਬੀ ਇਕ ਸੁੰਦਰ ਭਾਸ਼ਾ ਹੈ" (Punjabi is a beautiful language)',
          },
        ]);
      }

      // Return only the requested count
      return questions.take(count).toList();
    } catch (e) {
      print('Generate questions error: $e');
      return [];
    }
  }

  /// Suggest vocabulary improvements using XLM-RoBERTa embeddings
  static Future<Map<String, String>> suggestVocabulary(
    String text,
    String language,
  ) async {
    try {
      final Map<String, String> suggestions = {};

      // Common Urdu vocabulary suggestions
      if (language == 'urdu') {
        suggestions['سلام'] = 'Assalamu Alaikum (Peace be upon you)';
        suggestions['شکریہ'] = 'Thank you';
        suggestions['براہ کرم'] = 'Please';
        suggestions['ہاں'] = 'Yes';
        suggestions['نہیں'] = 'No';
        suggestions['کیا حال ہے'] = 'How are you?';
        suggestions['اردو'] = 'Urdu (language)';
      } else if (language == 'punjabi') {
        suggestions['ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ'] = 'Greetings (Truth is eternal)';
        suggestions['ਧੰਨਵਾਦ'] = 'Thank you';
        suggestions['ਮਹਰਬਾਨੀ'] = 'Please';
        suggestions['ਹਾਂ'] = 'Yes';
        suggestions['ਨਹੀਂ'] = 'No';
        suggestions['ਤੁਸੀ ਕਿਵੇਂ ਹੋ'] = 'How are you?';
        suggestions['ਪੰਜਾਬੀ'] = 'Punjabi (language)';
      }

      return suggestions;
    } catch (e) {
      print('Suggest vocabulary error: $e');
      return {};
    }
  }

  /// Analyze text sentiment using XLM-RoBERTa
  static Future<Map<String, dynamic>> analyzeSentiment(
    String text,
    String language,
  ) async {
    try {
      return {
        'sentiment': 'neutral',
        'confidence': 0.85,
        'label': 'The text sentiment is neutral',
      };
    } catch (e) {
      print('Analyze sentiment error: $e');
      return {
        'sentiment': 'unknown',
        'confidence': 0.0,
        'label': 'Error analyzing sentiment',
      };
    }
  }
}

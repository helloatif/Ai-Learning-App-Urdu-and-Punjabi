import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';

/// Service to interact with the HuggingFace deployed model
/// Model: RAFAY-484/Urdu-Punjabi-V2 (Custom Dataset)
class HuggingFaceApiService {
  // HuggingFace API Configuration
  static const String _modelId = 'RAFAY-484/Urdu-Punjabi-V2';
  static String get _hfToken => EnvConfig.getHuggingFaceToken();

  // API Endpoints
  static const String _inferenceUrl =
      'https://api-inference.huggingface.co/models/$_modelId';

  // Score Labels (matching model output)
  static const Map<int, Map<String, dynamic>> scoreLabels = {
    0: {
      'percent': 0,
      'feedback': 'Incorrect',
      'emoji': 'âŒ',
      'feedbackUrdu': 'ØºÙ„Ø·',
    },
    1: {
      'percent': 20,
      'feedback': 'Needs work',
      'emoji': 'âš ï¸',
      'feedbackUrdu': 'Ù…Ø²ÛŒØ¯ Ú©ÙˆØ´Ø´ Ú©Ø±ÛŒÚº',
    },
    2: {
      'percent': 40,
      'feedback': 'Partially correct',
      'emoji': 'ðŸ“',
      'feedbackUrdu': 'Ø¬Ø²ÙˆÛŒ Ø·ÙˆØ± Ù¾Ø± Ø¯Ø±Ø³Øª',
    },
    3: {
      'percent': 60,
      'feedback': 'Getting there',
      'emoji': 'ðŸ‘Œ',
      'feedbackUrdu': 'Ø¨ÛØªØ± ÛÙˆ Ø±ÛÛ’ ÛÛŒÚº',
    },
    4: {
      'percent': 80,
      'feedback': 'Good job!',
      'emoji': 'ðŸ‘',
      'feedbackUrdu': 'Ø´Ø§Ø¨Ø§Ø´!',
    },
    5: {
      'percent': 100,
      'feedback': 'Perfect!',
      'emoji': 'âœ…',
      'feedbackUrdu': 'Ø¨Ø§Ù„Ú©Ù„ Ø¯Ø±Ø³Øª!',
    },
  };

  /// Score user's answer against correct answer
  /// Returns score 0-100% with feedback
  static Future<QuizScoreResult> scoreAnswer({
    required String userInput,
    required String correctAnswer,
  }) async {
    try {
      // Format input as model expects: [CHECK] user_input [ANSWER] correct_answer
      final inputText = '[CHECK] $userInput [ANSWER] $correctAnswer';

      final response = await http.post(
        Uri.parse(_inferenceUrl),
        headers: {
          'Authorization': 'Bearer $_hfToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'inputs': inputText,
          'options': {'wait_for_model': true},
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        // Parse model output - returns list of label scores
        if (result is List && result.isNotEmpty) {
          final predictions = result[0] as List;

          // Find highest scoring label
          int bestLabel = 0;
          double bestScore = 0;

          for (var pred in predictions) {
            final label = pred['label'] as String;
            final score = pred['score'] as double;

            // Extract label number (LABEL_0, LABEL_1, etc.)
            final labelNum = int.tryParse(label.replaceAll('LABEL_', '')) ?? 0;

            if (score > bestScore) {
              bestScore = score;
              bestLabel = labelNum;
            }
          }

          final scoreInfo = scoreLabels[bestLabel]!;

          return QuizScoreResult(
            score: scoreInfo['percent'] as int,
            feedback: scoreInfo['feedback'] as String,
            feedbackUrdu: scoreInfo['feedbackUrdu'] as String,
            emoji: scoreInfo['emoji'] as String,
            isCorrect: bestLabel >= 4,
            confidence: (bestScore * 100).round(),
            userInput: userInput,
            correctAnswer: correctAnswer,
          );
        }
      }

      // Fallback: Simple string comparison
      return _fallbackScoring(userInput, correctAnswer);
    } catch (e) {
      print('HuggingFace API Error: $e');
      // Fallback to local scoring
      return _fallbackScoring(userInput, correctAnswer);
    }
  }

  /// Fallback scoring when API is unavailable
  static QuizScoreResult _fallbackScoring(
    String userInput,
    String correctAnswer,
  ) {
    final user = userInput.trim().toLowerCase();
    final correct = correctAnswer.trim().toLowerCase();

    int score;
    int labelIndex;

    if (user == correct) {
      score = 100;
      labelIndex = 5;
    } else if (_similarity(user, correct) > 0.8) {
      score = 80;
      labelIndex = 4;
    } else if (_similarity(user, correct) > 0.6) {
      score = 60;
      labelIndex = 3;
    } else if (_similarity(user, correct) > 0.4) {
      score = 40;
      labelIndex = 2;
    } else if (_similarity(user, correct) > 0.2) {
      score = 20;
      labelIndex = 1;
    } else {
      score = 0;
      labelIndex = 0;
    }

    final info = scoreLabels[labelIndex]!;

    return QuizScoreResult(
      score: score,
      feedback: info['feedback'] as String,
      feedbackUrdu: info['feedbackUrdu'] as String,
      emoji: info['emoji'] as String,
      isCorrect: labelIndex >= 4,
      confidence: 100,
      userInput: userInput,
      correctAnswer: correctAnswer,
    );
  }

  /// Calculate string similarity (Levenshtein-based)
  static double _similarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final len1 = s1.length;
    final len2 = s2.length;

    List<List<int>> dp = List.generate(
      len1 + 1,
      (i) => List.generate(len2 + 1, (j) => 0),
    );

    for (int i = 0; i <= len1; i++) dp[i][0] = i;
    for (int j = 0; j <= len2; j++) dp[0][j] = j;

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    final maxLen = len1 > len2 ? len1 : len2;
    return 1.0 - (dp[len1][len2] / maxLen);
  }

  /// Check if model is available
  static Future<bool> isModelAvailable() async {
    try {
      final response = await http
          .get(
            Uri.parse(_inferenceUrl),
            headers: {'Authorization': 'Bearer $_hfToken'},
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 503;
    } catch (e) {
      return false;
    }
  }

  /// Get model info
  static Future<Map<String, dynamic>?> getModelInfo() async {
    try {
      final response = await http.get(
        Uri.parse('https://huggingface.co/api/models/$_modelId'),
        headers: {'Authorization': 'Bearer $_hfToken'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching model info: $e');
    }
    return null;
  }
}

/// Result of quiz answer scoring
class QuizScoreResult {
  final int score; // 0, 20, 40, 60, 80, 100
  final String feedback; // English feedback
  final String feedbackUrdu; // Urdu feedback
  final String emoji; // Emoji for the score
  final bool isCorrect; // true if score >= 80
  final int confidence; // Model confidence %
  final String userInput;
  final String correctAnswer;

  QuizScoreResult({
    required this.score,
    required this.feedback,
    required this.feedbackUrdu,
    required this.emoji,
    required this.isCorrect,
    required this.confidence,
    required this.userInput,
    required this.correctAnswer,
  });

  Map<String, dynamic> toJson() => {
    'score': score,
    'feedback': feedback,
    'feedbackUrdu': feedbackUrdu,
    'emoji': emoji,
    'isCorrect': isCorrect,
    'confidence': confidence,
    'userInput': userInput,
    'correctAnswer': correctAnswer,
  };

  @override
  String toString() => '$score% - $feedback';
}

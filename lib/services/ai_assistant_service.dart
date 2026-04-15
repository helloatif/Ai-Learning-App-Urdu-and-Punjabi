import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_keys.dart';
import 'translation_service.dart';
import 'word_recommendation_service.dart';
import 'ml_vocabulary_service.dart';

/// AI Assistant for language learning help
/// Enhanced with ML features for translation, word recommendations, and grammar
class AIAssistantService {
  static const String _apiUrl =
      'https://api-inference.huggingface.co/models/facebook/blenderbot-400M-distill';
  static const String _apiToken = ApiKeys.huggingFaceToken;

  static final List<Map<String, String>> _conversationHistory = [];
  static final TranslationService _translationService = TranslationService();
  static final WordRecommendationService _recommendationService =
      WordRecommendationService();

  // Current language context
  static String _currentLanguage = 'urdu';

  /// Set the current language context
  static void setLanguage(String language) {
    _currentLanguage = language;
  }

  /// Get AI response for user query - Enhanced with ML features
  static Future<String> getResponse(String userMessage) async {
    // First, detect intent and handle with ML if applicable
    final intent = _detectIntent(userMessage);

    switch (intent) {
      case AssistantIntent.translate:
        return await _handleTranslation(userMessage);

      case AssistantIntent.findSimilar:
        return await _handleSimilarWords(userMessage);

      case AssistantIntent.checkGrammar:
        return await _handleGrammarCheck(userMessage);

      case AssistantIntent.explain:
        return await _handleExplanation(userMessage);

      case AssistantIntent.pronunciation:
        return _handlePronunciation(userMessage);

      case AssistantIntent.general:
      default:
        return await _getGeneralResponse(userMessage);
    }
  }

  /// Detect user intent from message
  static AssistantIntent _detectIntent(String message) {
    final lowerMessage = message.toLowerCase();

    // Translation intent
    if (lowerMessage.contains('translate') ||
        lowerMessage.contains('ترجمہ') ||
        lowerMessage.contains('how do you say') ||
        lowerMessage.contains('what is') && lowerMessage.contains('in urdu') ||
        lowerMessage.contains('what is') &&
            lowerMessage.contains('in punjabi')) {
      return AssistantIntent.translate;
    }

    // Similar words intent
    if (lowerMessage.contains('similar') ||
        lowerMessage.contains('like') && lowerMessage.contains('word') ||
        lowerMessage.contains('related') ||
        lowerMessage.contains('synonym')) {
      return AssistantIntent.findSimilar;
    }

    // Grammar check intent
    if (lowerMessage.contains('grammar') ||
        lowerMessage.contains('correct') ||
        lowerMessage.contains('check') && lowerMessage.contains('sentence') ||
        lowerMessage.contains('is this right')) {
      return AssistantIntent.checkGrammar;
    }

    // Explanation intent
    if (lowerMessage.contains('explain') ||
        lowerMessage.contains('what does') ||
        lowerMessage.contains('meaning of') ||
        lowerMessage.contains('کیا مطلب')) {
      return AssistantIntent.explain;
    }

    // Pronunciation intent
    if (lowerMessage.contains('pronounce') ||
        lowerMessage.contains('pronunciation') ||
        lowerMessage.contains('say') ||
        lowerMessage.contains('speak')) {
      return AssistantIntent.pronunciation;
    }

    return AssistantIntent.general;
  }

  /// Handle translation requests using ML
  static Future<String> _handleTranslation(String message) async {
    try {
      // Extract text to translate
      String textToTranslate = '';
      String targetLanguage = _currentLanguage;

      // Parse the request
      final patterns = [
        RegExp(
          r'''translate\s+["']?(.+?)["']?(?:\s+to\s+(\w+))?$''',
          caseSensitive: false,
        ),
        RegExp(
          r'''how do you say\s+["']?(.+?)["']?\s+in\s+(\w+)''',
          caseSensitive: false,
        ),
        RegExp(
          r'''what is\s+["']?(.+?)["']?\s+in\s+(\w+)''',
          caseSensitive: false,
        ),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(message);
        if (match != null) {
          textToTranslate = match.group(1)?.trim() ?? '';
          if (match.groupCount >= 2) {
            targetLanguage = match.group(2) ?? _currentLanguage;
          }
          break;
        }
      }

      if (textToTranslate.isEmpty) {
        return 'Please tell me what you want to translate. For example:\n'
            '• "Translate hello to Urdu"\n'
            '• "How do you say thank you in Punjabi?"';
      }

      // Detect source language
      final sourceLanguage = _detectSourceLanguage(textToTranslate);

      // Perform translation
      final result = await _translationService.translate(
        text: textToTranslate,
        from: sourceLanguage,
        to: targetLanguage.toLowerCase(),
      );

      final pronunciation = _translationService.getPronunciationGuide(
        result.translatedText,
        targetLanguage.toLowerCase(),
      );

      return 'Translation:\n\n'
          '"$textToTranslate"\n'
          '→\n'
          '"${result.translatedText}"\n\n'
          'Pronunciation: $pronunciation\n'
          'Confidence: ${(result.confidence * 100).round()}%';
    } catch (e) {
      debugPrint('Translation error: $e');
      return 'I couldn\'t translate that. Please try again with a different phrase.';
    }
  }

  /// Handle similar word requests using ML
  static Future<String> _handleSimilarWords(String message) async {
    try {
      // Extract the word
      final patterns = [
        RegExp(
          r'''similar\s+(?:to\s+|words?\s+(?:to|for)\s+)?["']?(\S+)["']?''',
          caseSensitive: false,
        ),
        RegExp(r'''words?\s+like\s+["']?(\S+)["']?''', caseSensitive: false),
        RegExp(
          r'''related\s+(?:to\s+)?["']?(\S+)["']?''',
          caseSensitive: false,
        ),
      ];

      String word = '';
      for (final pattern in patterns) {
        final match = pattern.firstMatch(message);
        if (match != null) {
          word = match.group(1)?.trim() ?? '';
          break;
        }
      }

      if (word.isEmpty) {
        return 'Please specify a word. For example:\n'
            '• "Find words similar to خوشی"\n'
            '• "Words like happy"';
      }

      // Find similar words
      final similar = await _recommendationService.findSimilarWords(
        word: word,
        language: _currentLanguage,
        count: 5,
      );

      if (similar.isEmpty) {
        return 'I couldn\'t find similar words for "$word". Try a different word.';
      }

      final buffer = StringBuffer('🔗 Words similar to "$word":\n\n');
      for (int i = 0; i < similar.length; i++) {
        final rec = similar[i];
        buffer.writeln('${i + 1}. ${rec.word.urdu} (${rec.word.english})');
        buffer.writeln('   📊 Similarity: ${(rec.similarity * 100).round()}%');
        buffer.writeln('   💡 ${rec.reason}');
        buffer.writeln('');
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('Similar words error: $e');
      return 'I couldn\'t find similar words. Please try again.';
    }
  }

  /// Handle grammar check requests using ML
  static Future<String> _handleGrammarCheck(String message) async {
    try {
      // Extract the sentence to check
      final patterns = [
        RegExp(
          r'''(?:check|is)\s+(?:this\s+)?(?:grammar|correct|right)[:\s]+["']?(.+?)["']?$''',
          caseSensitive: false,
        ),
        RegExp(
          r'''(?:grammar|check)\s+["']?(.+?)["']?$''',
          caseSensitive: false,
        ),
      ];

      String sentenceToCheck = '';
      for (final pattern in patterns) {
        final match = pattern.firstMatch(message);
        if (match != null) {
          sentenceToCheck = match.group(1)?.trim() ?? '';
          break;
        }
      }

      if (sentenceToCheck.isEmpty) {
        return 'Please provide a sentence to check. For example:\n'
            '• "Check grammar: میں کھانا کھاتا ہے"\n'
            '• "Is this correct: میں سکول جاتا ہوں"';
      }

      // Perform grammar check
      final result = await MLVocabularyService.checkGrammarEnhanced(
        userInput: sentenceToCheck,
        expectedText: sentenceToCheck, // Self-check mode
        language: _currentLanguage,
      );

      final buffer = StringBuffer('✏️ Grammar Check:\n\n');
      buffer.writeln('"$sentenceToCheck"');
      buffer.writeln('');
      buffer.writeln('📊 Score: ${result.score}%');
      buffer.writeln('${result.feedback}');

      if (result.hasViolations) {
        buffer.writeln('\n⚠️ Issues found:');
        for (final violation in result.ruleViolations) {
          buffer.writeln('• ${violation.message}');
        }
      }

      if (result.suggestions.isNotEmpty) {
        buffer.writeln('\n💡 Suggestions:');
        for (final suggestion in result.suggestions) {
          buffer.writeln('• $suggestion');
        }
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('Grammar check error: $e');
      return 'I couldn\'t check the grammar. Please try again.';
    }
  }

  /// Handle word/phrase explanation requests
  static Future<String> _handleExplanation(String message) async {
    // Extract the word to explain
    final patterns = [
      RegExp(
        r'''(?:explain|meaning of|what does)\s+["']?(.+?)["']?(?:\s+mean)?$''',
        caseSensitive: false,
      ),
      RegExp(r'کیا مطلب\s+(.+)', caseSensitive: false),
    ];

    String word = '';
    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        word = match.group(1)?.trim() ?? '';
        break;
      }
    }

    if (word.isEmpty) {
      return 'Please specify what you want me to explain.';
    }

    // Try to find the word in vocabulary
    final similar = await _recommendationService.findSimilarWords(
      word: word,
      language: _currentLanguage,
      count: 1,
      minSimilarity: 0.8,
    );

    if (similar.isNotEmpty) {
      final found = similar.first;
      return '\"$word\"\n\n'
          'Translation: ${found.word.english}\n'
          '🔊 Pronunciation: ${found.word.pronunciation}\n'
          '📌 Example: ${found.word.exampleSentence ?? "N/A"}\n'
          '   (${found.word.exampleEnglish ?? ""})';
    }

    // If not found, translate
    final translation = await _translationService.autoTranslate(
      text: word,
      targetLanguage: _detectSourceLanguage(word) == 'english'
          ? _currentLanguage
          : 'english',
    );

    return '\"$word\"\n\n'
        'Meaning: ${translation.translatedText}\n'
        '🔊 Pronunciation: ${_translationService.getPronunciationGuide(word, _currentLanguage)}';
  }

  /// Handle pronunciation requests
  static String _handlePronunciation(String message) {
    // Extract word
    final match = RegExp(
      r'''(?:pronounce|pronunciation|say|speak)\s+["']?(.+?)["']?$''',
      caseSensitive: false,
    ).firstMatch(message);

    if (match != null) {
      final word = match.group(1)?.trim() ?? '';
      final pronunciation = _translationService.getPronunciationGuide(
        word,
        _currentLanguage,
      );

      return '🔊 Pronunciation for "$word":\n\n'
          'romanized: $pronunciation\n\n'
          '💡 Tips:\n'
          '• Break it into syllables\n'
          '• Practice each sound slowly\n'
          '• Use the audio playback feature';
    }

    return 'Please specify a word to pronounce. For example:\n'
        '• "How to pronounce شکریہ"';
  }

  /// Get general response (fallback to original behavior)
  static Future<String> _getGeneralResponse(String userMessage) async {
    try {
      // Add user message to history
      _conversationHistory.add({'role': 'user', 'content': userMessage});

      // Build conversation context
      final context = _buildContext();

      final url = Uri.parse(_apiUrl);
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_apiToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'inputs': context,
          'parameters': {
            'max_length': 150,
            'temperature': 0.7,
            'do_sample': true,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String aiResponse = '';

        if (data is List && data.isNotEmpty) {
          aiResponse =
              data[0]['generated_text'] ?? 'I\'m here to help you learn!';
        }

        // Add AI response to history
        _conversationHistory.add({'role': 'assistant', 'content': aiResponse});

        // Keep only last 10 messages
        if (_conversationHistory.length > 10) {
          _conversationHistory.removeRange(0, _conversationHistory.length - 10);
        }

        return aiResponse;
      } else {
        return _getOfflineResponse(userMessage);
      }
    } catch (e) {
      debugPrint('AI Assistant Error: $e');
      return _getOfflineResponse(userMessage);
    }
  }

  /// Detect source language from text
  static String _detectSourceLanguage(String text) {
    final englishPattern = RegExp(r'[a-zA-Z]');
    final urduPattern = RegExp(r'[\u0600-\u06FF]');

    final englishCount = englishPattern.allMatches(text).length;
    final urduCount = urduPattern.allMatches(text).length;

    if (englishCount > urduCount) {
      return 'english';
    }
    return _currentLanguage;
  }

  /// Build conversation context
  static String _buildContext() {
    final buffer = StringBuffer();
    buffer.writeln(
      'You are a helpful language learning assistant specializing in Urdu and Punjabi languages.',
    );
    buffer.writeln(
      'Help users learn vocabulary, grammar, pronunciation, and cultural context.',
    );
    buffer.writeln('');

    for (final message in _conversationHistory) {
      if (message['role'] == 'user') {
        buffer.writeln('User: ${message['content']}');
      } else {
        buffer.writeln('Assistant: ${message['content']}');
      }
    }

    return buffer.toString();
  }

  /// Get offline response when API is unavailable
  static String _getOfflineResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    // Greeting responses
    if (lowerMessage.contains('hello') ||
        lowerMessage.contains('hi') ||
        lowerMessage.contains('سلام')) {
      return 'Hello! I\'m your language learning assistant. How can I help you today with Urdu or Punjabi?';
    }

    // Help with pronunciation
    if (lowerMessage.contains('pronounce') ||
        lowerMessage.contains('pronunciation')) {
      return 'To practice pronunciation:\n1. Listen to the audio carefully\n2. Tap the microphone to record\n3. Compare your pronunciation\n4. Practice multiple times!';
    }

    // Translation help
    if (lowerMessage.contains('translate') ||
        lowerMessage.contains('meaning')) {
      return 'I can help you translate! Just ask me "What does [word] mean?" or "How do you say [word] in Urdu/Punjabi?"';
    }

    // Grammar help
    if (lowerMessage.contains('grammar') || lowerMessage.contains('sentence')) {
      return 'Urdu and Punjabi follow Subject-Object-Verb (SOV) word order. For example:\n"I eat food" becomes "میں کھانا کھاتا ہوں" (Main khana khata hoon)';
    }

    // Learning tips
    if (lowerMessage.contains('learn') ||
        lowerMessage.contains('study') ||
        lowerMessage.contains('practice')) {
      return 'Great tips for learning:\n• Practice 15 minutes daily\n• Use flashcards\n• Watch movies/shows\n• Speak with native speakers\n• Don\'t fear mistakes!';
    }

    // Cultural context
    if (lowerMessage.contains('culture') ||
        lowerMessage.contains('tradition')) {
      return 'Language and culture are deeply connected! Understanding Pakistani culture helps you use words in proper context. Would you like to learn about specific traditions?';
    }

    // Default response
    return 'I\'m here to help you learn Urdu and Punjabi! You can ask me about:\n• Word meanings\n• Pronunciation\n• Grammar rules\n• Cultural context\n• Learning tips';
  }

  /// Get learning suggestions based on user level
  static List<String> getSuggestions(int userLevel) {
    if (userLevel <= 3) {
      return [
        'Start with basic greetings',
        'Learn common phrases',
        'Practice pronunciation daily',
        'Use flashcards for vocabulary',
      ];
    } else if (userLevel <= 7) {
      return [
        'Build conversational sentences',
        'Learn verb conjugations',
        'Practice with native speakers',
        'Watch movies with subtitles',
      ];
    } else {
      return [
        'Read Urdu/Punjabi literature',
        'Write short essays',
        'Engage in debates',
        'Teach others what you\'ve learned',
      ];
    }
  }

  /// Get contextual hints for exercises
  static String getHint(String question, String language) {
    // Analyze question and provide contextual hint
    if (question.contains('translate')) {
      return 'Think about the word order: $language uses SOV structure';
    } else if (question.contains('pronounce')) {
      return 'Break the word into syllables and practice each part';
    } else {
      return 'Take your time and think about what you\'ve learned';
    }
  }

  /// Clear conversation history
  static void clearHistory() {
    _conversationHistory.clear();
  }

  /// Get conversation history
  static List<Map<String, String>> getHistory() {
    return List.from(_conversationHistory);
  }
}

/// Chatbot UI message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

/// Smart learning recommendations
class LearningRecommendationService {
  /// Get personalized recommendations based on user progress
  static List<String> getRecommendations({
    required int completedLessons,
    required int totalPoints,
    required int streak,
    required String weakestArea,
  }) {
    final recommendations = <String>[];

    // Streak recommendations
    if (streak == 0) {
      recommendations.add('Start a daily learning streak today!');
    } else if (streak < 7) {
      recommendations.add('Keep going! $streak day streak - aim for 7 days!');
    } else {
      recommendations.add(
        'Amazing! $streak day streak! You\'re making great progress!',
      );
    }

    // Points recommendations
    if (totalPoints < 100) {
      recommendations.add('Complete more lessons to earn XP points!');
    } else if (totalPoints < 500) {
      recommendations.add('Great progress! Keep earning points!');
    }

    // Weak area focus
    if (weakestArea.isNotEmpty) {
      recommendations.add('Focus on $weakestArea to improve faster');
    }

    // Practice recommendations
    if (completedLessons % 5 == 0 && completedLessons > 0) {
      recommendations.add('Time to practice what you\'ve learned!');
    }

    return recommendations;
  }

  /// Get adaptive difficulty level
  static String getDifficultyLevel(double accuracy) {
    if (accuracy >= 0.9) return 'Expert';
    if (accuracy >= 0.75) return 'Advanced';
    if (accuracy >= 0.6) return 'Intermediate';
    if (accuracy >= 0.4) return 'Beginner';
    return 'Novice';
  }
}

/// Intent types for AI assistant
enum AssistantIntent {
  translate,
  findSimilar,
  checkGrammar,
  explain,
  pronunciation,
  general,
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../config/env_config.dart';
import '../data/vocabulary_data.dart';
import 'embedding_cache_service.dart';
import 'ai_language_service.dart';

/// ML-powered service using the deployed XLM-RoBERTa model on Hugging Face
/// Model: RAFAY-484/Urdu-Punjabi-V2 (trained on 996 custom words with lessons)
class MLVocabularyService {
  // Hugging Face Inference API endpoint for your deployed model
  static const String _hfModelId = 'RAFAY-484/Urdu-Punjabi-V2';
  static const String _hfApiUrl =
      'https://api-inference.huggingface.co/models/$_hfModelId';

  // API token loaded from environment config
  static String get _hfToken => EnvConfig.getHuggingFaceToken();

  // Cached curriculum data (loaded from assets)
  static Map<String, dynamic>? _curriculumCache;
  static bool _isInitialized = false;

  /// Initialize the service - load vocabulary data
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final curriculumJson = await rootBundle.loadString(
        'assets/data/combined_training_dataset_with_lessons.json',
      );
      _curriculumCache = jsonDecode(curriculumJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Could not load curriculum lesson dataset: $e');
      _curriculumCache = null;
    }

    _isInitialized = true;
  }

  /// Generate vocabulary using the trained XLM-RoBERTa model data
  /// This uses the same 4000+ words the model was trained on
  static Future<List<VocabularyPrediction>> generateVocabularyWithML({
    required String chapterId,
    required int lessonIndex,
    required String language,
    int count = 10,
  }) async {
    await initialize();

    final chapterExistsInCurriculum = _chapterExistsInCurriculum(
      chapterId: chapterId,
      language: language,
    );

    final curriculumWords = _getCurriculumLessonWords(
      chapterId: chapterId,
      lessonIndex: lessonIndex,
      language: language,
    );

    if (curriculumWords.isNotEmpty) {
      debugPrint(
        'Using curriculum dataset rows for $chapterId lesson ${lessonIndex + 1}: ${curriculumWords.length} entries',
      );
      return _toPredictions(curriculumWords, count, chapterId, lessonIndex);
    }

    // If chapter exists in curriculum but lesson rows are missing, do not leak
    // unrelated language-wide fallback words into this chapter.
    if (chapterExistsInCurriculum) {
      debugPrint(
        'Curriculum chapter found but lesson rows missing for $chapterId lesson ${lessonIndex + 1}; returning empty set to avoid unrelated content',
      );
      return const [];
    }

    // Curriculum-only mode: never emit unrelated fallback words.
    return const [];
  }

  static bool _chapterExistsInCurriculum({
    required String chapterId,
    required String language,
  }) {
    final root = _curriculumCache;
    if (root == null) return false;

    final chaptersNode = root['chapters'];
    if (chaptersNode is! Map<String, dynamic>) return false;

    final chapterList = chaptersNode[language];
    if (chapterList is! List) return false;

    return chapterList.cast<dynamic>().cast<Map<String, dynamic>>().any(
      (c) => (c['chapter_id'] as String?) == chapterId,
    );
  }

  static List<Map<String, dynamic>> _getCurriculumLessonWords({
    required String chapterId,
    required int lessonIndex,
    required String language,
  }) {
    // Prefer curated in-app vocabulary dataset (25 words/lesson).
    final curated = _getVocabularyDataLessonWords(
      chapterId: chapterId,
      lessonIndex: lessonIndex,
      language: language,
    );
    return curated;
  }

  static List<Map<String, dynamic>> _getVocabularyDataLessonWords({
    required String chapterId,
    required int lessonIndex,
    required String language,
  }) {
    final lessonsMap = language == 'punjabi'
        ? VocabularyData.punjabiLessons
        : VocabularyData.urduLessons;

    final lessons = lessonsMap[chapterId];
    if (lessons == null || lessonIndex < 0 || lessonIndex >= lessons.length) {
      return const [];
    }

    final lesson = lessons[lessonIndex];
    return lesson.words
        .map(
          (w) => {
            'text': w.urdu,
            'translation': w.english,
            'pronunciation': w.pronunciation,
            'example': w.exampleSentence ?? w.urdu,
            'example_translation': w.exampleEnglish ?? w.english,
          },
        )
        .toList();
  }

  static Map<String, dynamic> _normalizeCurriculumRow(
    Map<String, dynamic> row,
  ) {
    final text = (row['word'] ?? row['text'] ?? '').toString();
    final translation = (row['translation'] ?? '').toString();
    final pronunciation = (row['pronunciation'] ?? '').toString();
    final example = (row['example'] ?? '').toString();
    final exampleTranslation = (row['example_translation'] ?? '').toString();

    return {
      'text': text,
      'translation': translation,
      'pronunciation': pronunciation,
      'example': example,
      'example_translation': exampleTranslation,
    };
  }

  static List<VocabularyPrediction> _toPredictions(
    List<Map<String, dynamic>> source,
    int count,
    String chapterId,
    int lessonIndex,
  ) {
    // Keep curated lesson order stable so numbered/sequence lessons stay natural.
    final selectedWords = source.take(count).toList();

    return selectedWords
        .map(
          (item) => VocabularyPrediction(
            word: (item['text'] as String? ?? ''),
            translation: (item['translation'] as String? ?? ''),
            pronunciation:
                (item['pronunciation'] as String?)?.trim().isNotEmpty == true
                ? item['pronunciation'] as String
                : _generatePronunciation(item['text'] as String? ?? ''),
            confidence: 0.95,
            example: (item['example'] as String?)?.trim().isNotEmpty == true
                ? item['example'] as String
                : item['text'] as String? ?? '',
          ),
        )
        .toList();
  }

  /// Detect language using Hugging Face Inference API
  static Future<LanguageDetectionResult> detectLanguage(String text) async {
    try {
      final response = await http
          .post(
            Uri.parse(_hfApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_hfToken',
            },
            body: jsonEncode({'inputs': text}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Parse XLM-RoBERTa classification output
        if (data is List && data.isNotEmpty) {
          final results = data[0] as List;
          double urduProb = 0.5;
          double punjabiProb = 0.5;

          for (var result in results) {
            final label = result['label'] as String? ?? '';
            final score = (result['score'] as num?)?.toDouble() ?? 0.5;

            if (label.contains('LABEL_0') ||
                label.toLowerCase().contains('urdu')) {
              urduProb = score;
            } else if (label.contains('LABEL_1') ||
                label.toLowerCase().contains('punjabi')) {
              punjabiProb = score;
            }
          }

          final isUrdu = urduProb > punjabiProb;
          return LanguageDetectionResult(
            text: text,
            language: isUrdu ? 'urdu' : 'punjabi',
            confidence: isUrdu ? urduProb : punjabiProb,
            urduProbability: urduProb,
            punjabiProbability: punjabiProb,
          );
        }
      }

      debugPrint('âš ï¸ HF API response: ${response.statusCode}');
    } catch (e) {
      debugPrint('âš ï¸ HF API error: $e');
    }

    // Fallback: simple heuristic detection
    return _fallbackLanguageDetection(text);
  }

  /// Check grammar by comparing user input with expected answer
  /// Uses the deployed HuggingFace model for ML-powered scoring
  static Future<GrammarCheckResult> checkGrammar(
    String userInput,
    String expectedText,
    String language,
  ) async {
    try {
      // Try to use the HuggingFace model for scoring
      final mlResult = await _scoreWithHuggingFace(userInput, expectedText);
      if (mlResult != null) {
        return mlResult;
      }
    } catch (e) {
      debugPrint('âš ï¸ HuggingFace scoring failed, using fallback: $e');
    }

    // Fallback: Use local similarity comparison
    // Detect language of user input using XLM-RoBERTa
    final detection = await detectLanguage(userInput);

    // Normalize and compare
    final normalizedInput = _normalizeText(userInput);
    final normalizedExpected = _normalizeText(expectedText);

    // Calculate similarity
    final similarity = _calculateSimilarity(
      normalizedInput,
      normalizedExpected,
    );

    // Check if language matches
    final languageMatch = detection.language == language;

    // Adjust score based on language match
    double finalScore = similarity;
    if (!languageMatch && similarity > 0.5) {
      finalScore *= 0.8; // Penalty for wrong language
    }

    // Generate feedback
    String feedback;
    List<String> corrections = [];

    if (finalScore > 0.9) {
      feedback = 'ðŸŽ‰ Perfect! Excellent work!';
    } else if (finalScore > 0.7) {
      feedback = 'ðŸ‘ Good job! Almost there.';
      if (normalizedInput != normalizedExpected) {
        corrections.add('Expected: $expectedText');
      }
    } else if (finalScore > 0.5) {
      feedback = 'ðŸ“ Keep practicing! Here\'s the correct answer:';
      corrections.add(expectedText);
    } else {
      feedback = 'ðŸ’ª Don\'t give up! The correct answer is:';
      corrections.add(expectedText);
    }

    if (!languageMatch) {
      feedback += '\nâš ï¸ Make sure you\'re writing in $language';
    }

    return GrammarCheckResult(
      isCorrect: finalScore > 0.85,
      score: (finalScore * 100).round(),
      feedback: feedback,
      corrections: corrections,
      detectedLanguage: detection.language,
      confidence: detection.confidence,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ENHANCED GRAMMAR CHECKING WITH ML
  // Uses embeddings for semantic similarity and improved rule checking
  // ═══════════════════════════════════════════════════════════════════

  /// Enhanced grammar checking with ML scoring + semantic similarity + rules
  static Future<EnhancedGrammarResult> checkGrammarEnhanced({
    required String userInput,
    required String expectedText,
    required String language,
  }) async {
    final embeddingService = EmbeddingCacheService();
    final ruleViolations = <GrammarViolation>[];

    // 1. Get ML score from HuggingFace model
    double mlScore = 0.5;
    try {
      final mlResult = await _scoreWithHuggingFace(userInput, expectedText);
      if (mlResult != null) {
        mlScore = mlResult.score / 100.0;
      }
    } catch (e) {
      debugPrint('ML score failed: $e');
    }

    // 2. Calculate semantic similarity using embeddings
    double semanticScore = 0.5;
    try {
      semanticScore = await embeddingService.calculateSimilarity(
        userInput,
        expectedText,
      );
    } catch (e) {
      debugPrint('Semantic similarity failed: $e');
      // Fallback to string similarity
      semanticScore = _calculateSimilarity(
        _normalizeText(userInput),
        _normalizeText(expectedText),
      );
    }

    // 3. Apply language-specific grammar rules
    ruleViolations.addAll(_applyGrammarRules(userInput, language));

    // 4. Calculate rule penalty
    final rulePenalty = (ruleViolations.length * 0.1).clamp(0.0, 0.3);

    // 5. Combine scores (ML: 50%, Semantic: 30%, Rules: 20%)
    final combinedScore =
        (mlScore * 0.5) + (semanticScore * 0.3) + ((1.0 - rulePenalty) * 0.2);

    // 6. Generate detailed feedback
    final feedback = _generateDetailedFeedback(
      score: combinedScore,
      mlScore: mlScore,
      semanticScore: semanticScore,
      ruleViolations: ruleViolations,
      language: language,
    );

    // 7. Get suggestions for improvement
    final suggestions = await _generateSuggestions(
      userInput: userInput,
      expectedText: expectedText,
      language: language,
      ruleViolations: ruleViolations,
    );

    return EnhancedGrammarResult(
      isCorrect: combinedScore > 0.8,
      score: (combinedScore * 100).round(),
      mlScore: (mlScore * 100).round(),
      semanticScore: (semanticScore * 100).round(),
      feedback: feedback,
      detailedFeedback: _getDetailedFeedbackText(combinedScore, language),
      ruleViolations: ruleViolations,
      suggestions: suggestions,
      language: language,
    );
  }

  /// Apply language-specific grammar rules
  static List<GrammarViolation> _applyGrammarRules(
    String text,
    String language,
  ) {
    final violations = <GrammarViolation>[];

    if (language == 'urdu') {
      // Urdu grammar rules

      // Rule 1: Check for verb endings (ہے، ہیں، ہو)
      if (text.length > 20 &&
          !text.contains('ہے') &&
          !text.contains('ہیں') &&
          !text.contains('ہو') &&
          !text.contains('گا') &&
          !text.contains('گی') &&
          !text.contains('گے')) {
        violations.add(
          GrammarViolation(
            type: GrammarViolationType.missingVerbEnding,
            message: 'Missing verb marker (ہے/ہیں/ہو)',
            messageUrdu: 'فعل کی علامت غائب ہے (ہے/ہیں/ہو)',
            severity: GrammarSeverity.warning,
          ),
        );
      }

      // Rule 2: Check for question mark in questions
      if ((text.contains('کیا') ||
              text.contains('کون') ||
              text.contains('کہاں') ||
              text.contains('کب') ||
              text.contains('کیوں') ||
              text.contains('کیسے')) &&
          !text.contains('؟')) {
        violations.add(
          GrammarViolation(
            type: GrammarViolationType.missingPunctuation,
            message: 'Missing question mark (؟)',
            messageUrdu: 'سوالیہ نشان غائب ہے (؟)',
            severity: GrammarSeverity.minor,
          ),
        );
      }

      // Rule 3: Check for postposition after nouns
      if (text.contains('کو') && !text.contains(' کو')) {
        violations.add(
          GrammarViolation(
            type: GrammarViolationType.postpositionError,
            message: 'Postposition "کو" needs space before it',
            messageUrdu: '"کو" سے پہلے فاصلہ چاہیے',
            severity: GrammarSeverity.minor,
          ),
        );
      }

      // Rule 4: Check for gender agreement patterns
      if ((text.contains('لڑکا') && text.contains('کی')) ||
          (text.contains('لڑکی') && text.contains('کا'))) {
        violations.add(
          GrammarViolation(
            type: GrammarViolationType.genderAgreement,
            message: 'Possible gender agreement error (کا/کی)',
            messageUrdu: 'مذکر/مؤنث کی غلطی ہو سکتی ہے',
            severity: GrammarSeverity.warning,
          ),
        );
      }
    } else if (language == 'punjabi') {
      // Punjabi grammar rules

      // Rule 1: Check for Punjabi verb endings
      if (text.length > 20 &&
          !text.contains('اے') &&
          !text.contains('نیں') &&
          !text.contains('ہاں') &&
          !text.contains('سی')) {
        violations.add(
          GrammarViolation(
            type: GrammarViolationType.missingVerbEnding,
            message: 'Missing Punjabi verb ending (اے/نیں/ہاں)',
            messageUrdu: 'پنجابی فعل کی علامت غائب ہے',
            severity: GrammarSeverity.warning,
          ),
        );
      }

      // Rule 2: Check for question patterns
      if ((text.contains('کی') ||
              text.contains('کیویں') ||
              text.contains('کدھر')) &&
          !text.contains('؟')) {
        violations.add(
          GrammarViolation(
            type: GrammarViolationType.missingPunctuation,
            message: 'Missing question mark',
            messageUrdu: 'سوالیہ نشان غائب ہے',
            severity: GrammarSeverity.minor,
          ),
        );
      }
    }

    return violations;
  }

  /// Generate detailed feedback based on scores
  static String _generateDetailedFeedback({
    required double score,
    required double mlScore,
    required double semanticScore,
    required List<GrammarViolation> ruleViolations,
    required String language,
  }) {
    final buffer = StringBuffer();

    if (score >= 0.9) {
      buffer.write('Excellent score! Perfect performance!');
    } else if (score >= 0.8) {
      buffer.write('Great job! Very close to perfect.');
    } else if (score >= 0.7) {
      buffer.write('Good effort! Keep practicing.');
    } else if (score >= 0.5) {
      buffer.write('🔄 Needs improvement. Review the grammar rules.');
    } else {
      buffer.write('Keep studying! Practice makes perfect.');
    }

    if (ruleViolations.isNotEmpty) {
      buffer.write('\n\nGrammar issues found:');
      for (final violation in ruleViolations) {
        buffer.write('\n• ${violation.message}');
      }
    }

    return buffer.toString();
  }

  /// Get detailed feedback text
  static String _getDetailedFeedbackText(double score, String language) {
    if (score >= 0.9) {
      return language == 'urdu'
          ? 'شاندار! آپ نے بہت اچھا کیا'
          : 'ਵਧੀਆ! ਤੁਸੀਂ ਬਹੁਤ ਵਧੀਆ ਕੀਤਾ';
    } else if (score >= 0.7) {
      return language == 'urdu'
          ? 'اچھی کوشش! تھوڑی اور مشق کریں'
          : 'ਚੰਗੀ ਕੋਸ਼ਿਸ਼! ਹੋਰ ਅਭਿਆਸ ਕਰੋ';
    } else {
      return language == 'urdu'
          ? 'مشق جاری رکھیں، آپ بہتر ہو رہے ہیں'
          : 'ਅਭਿਆਸ ਜਾਰੀ ਰੱਖੋ, ਤੁਸੀਂ ਬਿਹਤਰ ਹੋ ਰਹੇ ਹੋ';
    }
  }

  /// Generate suggestions for improvement
  static Future<List<String>> _generateSuggestions({
    required String userInput,
    required String expectedText,
    required String language,
    required List<GrammarViolation> ruleViolations,
  }) async {
    final suggestions = <String>[];

    // Add suggestions based on rule violations
    for (final violation in ruleViolations) {
      switch (violation.type) {
        case GrammarViolationType.missingVerbEnding:
          suggestions.add(
            language == 'urdu'
                ? 'Add appropriate verb ending (ہے for singular, ہیں for plural)'
                : 'Add appropriate verb ending (اے for present tense)',
          );
          break;
        case GrammarViolationType.missingPunctuation:
          suggestions.add('Add the missing punctuation mark');
          break;
        case GrammarViolationType.genderAgreement:
          suggestions.add(
            language == 'urdu'
                ? 'Use کا with masculine nouns, کی with feminine nouns'
                : 'Check gender agreement in your sentence',
          );
          break;
        default:
          break;
      }
    }

    // Add general suggestion if needed
    if (suggestions.isEmpty && userInput != expectedText) {
      suggestions.add('Compare your answer with: $expectedText');
    }

    return suggestions;
  }

  /// Score answer using HuggingFace deployed model
  static Future<GrammarCheckResult?> _scoreWithHuggingFace(
    String userInput,
    String expectedAnswer,
  ) async {
    try {
      // Format input for the model: [CHECK] user_input [ANSWER] correct_answer
      final inputText = '[CHECK] $userInput [ANSWER] $expectedAnswer';

      final response = await http
          .post(
            Uri.parse(_hfApiUrl),
            headers: {
              'Authorization': 'Bearer $_hfToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'inputs': inputText,
              'options': {'wait_for_model': true},
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result is List && result.isNotEmpty) {
          final predictions = result[0] as List;

          // Find highest scoring label
          int bestLabel = 0;
          double bestScore = 0;

          for (var pred in predictions) {
            final label = pred['label'] as String;
            final score = pred['score'] as double;
            final labelNum = int.tryParse(label.replaceAll('LABEL_', '')) ?? 0;

            if (score > bestScore) {
              bestScore = score;
              bestLabel = labelNum;
            }
          }

          // Map label to percentage score
          final scoreMap = {0: 0, 1: 20, 2: 40, 3: 60, 4: 80, 5: 100};

          final feedbackMap = {
            0: 'âŒ Incorrect. The correct answer is:',
            1: 'âš ï¸ Needs more work. Try again:',
            2: 'ðŸ“ Partially correct. Keep practicing:',
            3: 'ðŸ‘Œ Getting there! Almost correct:',
            4: 'ðŸ‘ Good job! Very close!',
            5: 'âœ… Perfect! Excellent work!',
          };

          final percentage = scoreMap[bestLabel] ?? 0;
          final isCorrect = percentage >= 80;

          return GrammarCheckResult(
            isCorrect: isCorrect,
            score: percentage,
            feedback: feedbackMap[bestLabel] ?? '',
            corrections: isCorrect ? [] : [expectedAnswer],
            detectedLanguage: 'detected',
            confidence: bestScore,
          );
        }
      }
    } catch (e) {
      debugPrint('HuggingFace API error: $e');
    }

    return null; // Return null to trigger fallback
  }

  /// Generate pronunciation guide
  static String _generatePronunciation(String text) {
    final Map<String, String> translitMap = {
      'Ø§': 'a', 'Ø¢': 'aa', 'Ø¨': 'b', 'Ù¾': 'p', 'Øª': 't', 'Ù¹': 't',
      'Ø«': 's', 'Ø¬': 'j', 'Ú†': 'ch', 'Ø­': 'h', 'Ø®': 'kh', 'Ø¯': 'd',
      'Úˆ': 'd', 'Ø°': 'z', 'Ø±': 'r', 'Ú‘': 'r', 'Ø²': 'z', 'Ú˜': 'zh',
      'Ø³': 's', 'Ø´': 'sh', 'Øµ': 's', 'Ø¶': 'z', 'Ø·': 't', 'Ø¸': 'z',
      'Ø¹': 'a', 'Øº': 'gh', 'Ù': 'f', 'Ù‚': 'q', 'Ú©': 'k', 'Ú¯': 'g',
      'Ù„': 'l', 'Ù…': 'm', 'Ù†': 'n', 'Úº': 'n', 'Ùˆ': 'o', 'Û': 'h',
      'Ú¾': 'h', 'Ø¡': '', 'ÛŒ': 'i', 'Û’': 'e', 'Ø¦': 'i', 'Ø¤': 'o',
      'Ù°': 'a', 'Ù‹': 'an', 'Ù‘': '', ' ': ' ',
      // Punjabi specific (Shahmukhi)
      'Ý¨': 'n', 'Ú„': 'j', 'Úƒ': 'n', 'Ú»': 'n', 'Û»': 'r',
    };

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(translitMap[char] ?? '');
    }

    String result = buffer.toString().trim();
    if (result.isEmpty) result = 'pronunciation';
    return result;
  }

  /// Fallback language detection using character analysis
  static LanguageDetectionResult _fallbackLanguageDetection(String text) {
    // Punjabi-specific characters in Shahmukhi
    final punjabiMarkers = ['Ý¨', 'Ú„', 'Úƒ', 'Ú»', 'Û»', 'à©³', 'à¨…', 'à©²'];

    int punjabiScore = 0;
    for (var marker in punjabiMarkers) {
      if (text.contains(marker)) punjabiScore++;
    }

    // Common Punjabi words/patterns
    final punjabiWords = [
      'Ú©ÛŒ',
      'Ø¯Ø§',
      'Ø¯ÛŒ',
      'Ù†ÙˆÚº',
      'ØªÙˆÚº',
      'Ø§Û’',
      'Ù†Û’',
      'Ø³ÛŒ',
      'ÛÛ’',
    ];
    for (var word in punjabiWords) {
      if (text.contains(word)) punjabiScore++;
    }

    final isPunjabi = punjabiScore >= 2;
    final confidence = isPunjabi ? 0.7 + (punjabiScore * 0.05) : 0.75;

    return LanguageDetectionResult(
      text: text,
      language: isPunjabi ? 'punjabi' : 'urdu',
      confidence: confidence.clamp(0.5, 0.95),
      urduProbability: isPunjabi ? 1 - confidence : confidence,
      punjabiProbability: isPunjabi ? confidence : 1 - confidence,
    );
  }

  /// Normalize text for comparison
  static String _normalizeText(String text) {
    return text
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('Û”', '.')
        .replaceAll('ØŒ', ',')
        .replaceAll('ØŸ', '?');
  }

  /// Calculate similarity using Levenshtein distance
  static double _calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final m = a.length;
    final n = b.length;

    List<List<int>> dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] =
              1 +
              [
                dp[i - 1][j],
                dp[i][j - 1],
                dp[i - 1][j - 1],
              ].reduce((a, b) => a < b ? a : b);
        }
      }
    }

    final maxLen = m > n ? m : n;
    return 1.0 - (dp[m][n] / maxLen);
  }
}

/// Vocabulary prediction from XLM-RoBERTa training data
class VocabularyPrediction {
  final String word;
  final String translation;
  final String pronunciation;
  final double confidence;
  final String? example;

  VocabularyPrediction({
    required this.word,
    required this.translation,
    required this.pronunciation,
    required this.confidence,
    this.example,
  });
}

/// Language detection result from XLM-RoBERTa model
class LanguageDetectionResult {
  final String text;
  final String language;
  final double confidence;
  final double urduProbability;
  final double punjabiProbability;

  LanguageDetectionResult({
    required this.text,
    required this.language,
    required this.confidence,
    required this.urduProbability,
    required this.punjabiProbability,
  });
}

/// Grammar check result
class GrammarCheckResult {
  final bool isCorrect;
  final int score;
  final String feedback;
  final List<String> corrections;
  final String detectedLanguage;
  final double confidence;

  GrammarCheckResult({
    required this.isCorrect,
    required this.score,
    required this.feedback,
    required this.corrections,
    this.detectedLanguage = 'urdu',
    this.confidence = 0.5,
  });
}

/// Enhanced grammar check result with detailed ML analysis
class EnhancedGrammarResult {
  final bool isCorrect;
  final int score;
  final int mlScore;
  final int semanticScore;
  final String feedback;
  final String detailedFeedback;
  final List<GrammarViolation> ruleViolations;
  final List<String> suggestions;
  final String language;

  EnhancedGrammarResult({
    required this.isCorrect,
    required this.score,
    required this.mlScore,
    required this.semanticScore,
    required this.feedback,
    required this.detailedFeedback,
    required this.ruleViolations,
    required this.suggestions,
    required this.language,
  });

  /// Get a summary of the result
  String get summary => '$feedback (Score: $score%)';

  /// Check if any grammar violations exist
  bool get hasViolations => ruleViolations.isNotEmpty;
}

/// Grammar violation found during checking
class GrammarViolation {
  final GrammarViolationType type;
  final String message;
  final String messageUrdu;
  final GrammarSeverity severity;
  final int? position;

  GrammarViolation({
    required this.type,
    required this.message,
    required this.messageUrdu,
    required this.severity,
    this.position,
  });
}

/// Types of grammar violations
enum GrammarViolationType {
  missingVerbEnding,
  missingPunctuation,
  genderAgreement,
  postpositionError,
  pluralAgreement,
  tenseInconsistency,
  wordOrderError,
  spellingError,
  other,
}

/// Severity levels for grammar violations
enum GrammarSeverity {
  minor, // Doesn't affect meaning
  warning, // Could cause confusion
  error, // Incorrect grammar
}

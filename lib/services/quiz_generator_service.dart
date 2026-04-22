import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/vocabulary_data.dart';
import 'ml_vocabulary_service.dart';
import 'huggingface_api_service.dart';
import 'word_recommendation_service.dart';
import 'personalization_service.dart';

const int chapterQuizQuestionCount = 10;

/// Quiz types supported by the system
enum QuizType {
  vocabulary, // Word translation quizzes
  grammar, // Grammar correction quizzes
  comprehension, // Reading comprehension
  listening, // Audio-based quizzes
  typing, // Type the translation
  matching, // Match pairs
}

/// Quiz question model
class QuizQuestion {
  final String id;
  final QuizType type;
  final String subtype;
  final String question;
  final String? questionUrdu;
  final List<String>? options;
  final String correctAnswer;
  final int? correctIndex;
  final String language;
  final String difficulty;
  final String? hint;
  final String? audioUrl;

  // For scoring
  String? userAnswer;
  QuizScoreResult? scoreResult;
  bool isAnswered = false;

  QuizQuestion({
    required this.id,
    required this.type,
    this.subtype = '',
    required this.question,
    this.questionUrdu,
    this.options,
    required this.correctAnswer,
    this.correctIndex,
    required this.language,
    this.difficulty = 'easy',
    this.hint,
    this.audioUrl,
  });

  bool get isMultipleChoice => options != null && options!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'subtype': subtype,
    'question': question,
    'options': options,
    'correctAnswer': correctAnswer,
    'correctIndex': correctIndex,
    'language': language,
    'difficulty': difficulty,
  };
}

/// Quiz result for a complete quiz session
class QuizSessionResult {
  final String chapterId;
  final int lessonIndex;
  final List<QuizQuestion> questions;
  final int totalQuestions;
  final int correctAnswers;
  final int totalScore;
  final double averageScore;
  final Duration timeTaken;
  final List<String> weakWords;
  final List<String> masteredWords;

  QuizSessionResult({
    required this.chapterId,
    required this.lessonIndex,
    required this.questions,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.totalScore,
    required this.averageScore,
    required this.timeTaken,
    required this.weakWords,
    required this.masteredWords,
  });

  bool get passed => averageScore >= 60;

  String get grade {
    if (averageScore >= 90) return 'A+';
    if (averageScore >= 80) return 'A';
    if (averageScore >= 70) return 'B';
    if (averageScore >= 60) return 'C';
    if (averageScore >= 50) return 'D';
    return 'F';
  }
}

/// Service to generate chapter-wise quizzes using HuggingFace model
class QuizGeneratorService {
  static final Random _random = Random();

  /// Generate quiz for a specific lesson
  static Future<List<QuizQuestion>> generateLessonQuiz({
    required String chapterId,
    required int lessonIndex,
    required String language,
    int questionCount = 10,
    List<QuizType>? types,
    bool useMLEnhancements = true,
  }) async {
    if (useMLEnhancements) {
      return generateMLEnhancedQuiz(
        chapterId: chapterId,
        lessonIndex: lessonIndex,
        language: language,
        questionCount: questionCount,
        useSemanticDistractors: true,
      );
    }

    final questions = <QuizQuestion>[];
    final vocabulary = await _getVocabulary(chapterId, lessonIndex, language);

    if (vocabulary == null || vocabulary.words.isEmpty) {
      return questions;
    }

    types ??= [QuizType.vocabulary, QuizType.typing, QuizType.matching];

    // Distribute questions across types
    final questionsPerType = (questionCount / types.length).ceil();

    for (var type in types) {
      switch (type) {
        case QuizType.vocabulary:
          questions.addAll(
            _generateVocabularyQuestions(
              vocabulary,
              language,
              questionsPerType,
            ),
          );
          break;
        case QuizType.typing:
          questions.addAll(
            _generateTypingQuestions(vocabulary, language, questionsPerType),
          );
          break;
        case QuizType.matching:
          questions.addAll(
            _generateMatchingQuestions(vocabulary, language, questionsPerType),
          );
          break;
        case QuizType.grammar:
          questions.addAll(
            _generateGrammarQuestions(vocabulary, language, questionsPerType),
          );
          break;
        default:
          break;
      }
    }

    // Shuffle and limit
    questions.shuffle();
    return questions.take(questionCount).toList();
  }

  /// Generate vocabulary quiz (multiple choice)
  static List<QuizQuestion> _generateVocabularyQuestions(
    LessonVocabulary vocabulary,
    String language,
    int count,
  ) {
    final questions = <QuizQuestion>[];
    final words = vocabulary.words;

    for (int i = 0; i < count && i < words.length; i++) {
      final word = words[i];

      // Type 1: English to Native
      final wrongOptions =
          words.where((w) => w.urdu != word.urdu).map((w) => w.urdu).toList()
            ..shuffle();

      final options = [word.urdu, ...wrongOptions.take(3)];
      options.shuffle();

      questions.add(
        QuizQuestion(
          id: 'vocab_${DateTime.now().millisecondsSinceEpoch}_$i',
          type: QuizType.vocabulary,
          subtype: 'english_to_native',
          question:
              'What is "${word.english}" in ${language == 'urdu' ? 'Urdu' : 'Punjabi'}?',
          options: options,
          correctAnswer: word.urdu,
          correctIndex: options.indexOf(word.urdu),
          language: language,
          difficulty: 'easy',
          hint: word.pronunciation,
        ),
      );

      // Type 2: Native to English
      if (i + 1 < count) {
        final wrongEnglish =
            words
                .where((w) => w.english != word.english)
                .map((w) => w.english)
                .toList()
              ..shuffle();

        final engOptions = [word.english, ...wrongEnglish.take(3)];
        engOptions.shuffle();

        questions.add(
          QuizQuestion(
            id: 'vocab_${DateTime.now().millisecondsSinceEpoch}_${i}_rev',
            type: QuizType.vocabulary,
            subtype: 'native_to_english',
            question: 'What does "${word.urdu}" mean?',
            questionUrdu: word.urdu,
            options: engOptions,
            correctAnswer: word.english,
            correctIndex: engOptions.indexOf(word.english),
            language: language,
            difficulty: 'easy',
          ),
        );
      }
    }

    return questions;
  }

  /// Generate typing questions (user types the answer)
  static List<QuizQuestion> _generateTypingQuestions(
    LessonVocabulary vocabulary,
    String language,
    int count,
  ) {
    final questions = <QuizQuestion>[];
    final words = vocabulary.words.toList()..shuffle();

    for (int i = 0; i < count && i < words.length; i++) {
      final word = words[i];

      questions.add(
        QuizQuestion(
          id: 'typing_${DateTime.now().millisecondsSinceEpoch}_$i',
          type: QuizType.typing,
          subtype: 'translate',
          question:
              'Type "${word.english}" in ${language == 'urdu' ? 'Urdu' : 'Punjabi'}:',
          correctAnswer: word.urdu,
          language: language,
          difficulty: 'medium',
          hint: 'Pronunciation: ${word.pronunciation}',
        ),
      );
    }

    return questions;
  }

  /// Generate pronunciation questions (speech input expected).
  static List<QuizQuestion> _generatePronunciationQuestions(
    LessonVocabulary vocabulary,
    String language,
    int count,
  ) {
    final questions = <QuizQuestion>[];
    final words = vocabulary.words.toList()..shuffle();

    for (int i = 0; i < count && i < words.length; i++) {
      final word = words[i];

      questions.add(
        QuizQuestion(
          id: 'listen_${DateTime.now().millisecondsSinceEpoch}_$i',
          type: QuizType.listening,
          subtype: 'pronunciation',
          question:
              'Pronounce this word: "${word.urdu}" (English: ${word.english})',
          questionUrdu: word.urdu,
          correctAnswer: word.urdu,
          language: language,
          difficulty: 'medium',
          hint: word.pronunciation,
        ),
      );
    }

    return questions;
  }

  /// Generate matching questions
  static List<QuizQuestion> _generateMatchingQuestions(
    LessonVocabulary vocabulary,
    String language,
    int count,
  ) {
    final questions = <QuizQuestion>[];
    final words = vocabulary.words.toList()..shuffle();

    // Create match pairs
    final pairs = words.take(4).toList();
    final nativeWords = pairs.map((w) => w.urdu).toList();
    final englishWords = pairs.map((w) => w.english).toList()..shuffle();

    questions.add(
      QuizQuestion(
        id: 'match_${DateTime.now().millisecondsSinceEpoch}',
        type: QuizType.matching,
        subtype: 'pairs',
        question: 'Match the words:',
        options: [...nativeWords, ...englishWords],
        correctAnswer: pairs.map((w) => '${w.urdu}:${w.english}').join(','),
        language: language,
        difficulty: 'medium',
      ),
    );

    return questions;
  }

  /// Generate grammar questions
  static List<QuizQuestion> _generateGrammarQuestions(
    LessonVocabulary vocabulary,
    String language,
    int count,
  ) {
    final questions = <QuizQuestion>[];

    // Find sentences in vocabulary
    final sentences = vocabulary.words
        .where((w) => w.urdu.split(' ').length > 2)
        .toList();

    for (int i = 0; i < count && i < sentences.length; i++) {
      final sentence = sentences[i];

      // Alternate between true (correct) and false (incorrect) statements
      // True statements: use actual curriculum sentences (they're all valid)
      // False statements: add deliberate error or use modified versions
      final isCorrectStatement = i % 2 == 0; // Alternate true/false

      String questionSentence = sentence.urdu;
      String correctAnswer = 'Yes';

      if (!isCorrectStatement) {
        // Create a false statement by modifying the sentence
        // Simple approach: reverse word order or add grammatical error
        final words = sentence.urdu.split(' ');
        if (words.length > 2) {
          // Swap last two words to create grammar error
          final temp = words[words.length - 1];
          words[words.length - 1] = words[words.length - 2];
          words[words.length - 2] = temp;
          questionSentence = words.join(' ');
        }
        correctAnswer = 'No';
      }

      // Create grammar validation question
      questions.add(
        QuizQuestion(
          id: 'grammar_${DateTime.now().millisecondsSinceEpoch}_$i',
          type: QuizType.grammar,
          subtype: 'validation',
          question: 'Is this sentence correct?\n"$questionSentence"',
          questionUrdu: questionSentence,
          options: ['Yes', 'No'],
          correctAnswer: correctAnswer,
          correctIndex: correctAnswer == 'Yes' ? 0 : 1,
          language: language,
          difficulty: 'medium',
        ),
      );
    }

    return questions;
  }

  /// Score a quiz answer using HuggingFace model
  static Future<QuizScoreResult> scoreAnswer(
    QuizQuestion question,
    String userAnswer,
  ) async {
    if (question.isMultipleChoice) {
      // For MCQ, check exact match
      final isCorrect = userAnswer == question.correctAnswer;
      return QuizScoreResult(
        score: isCorrect ? 100 : 0,
        feedback: isCorrect ? 'Correct!' : 'Incorrect',
        feedbackUrdu: isCorrect ? 'درست!' : 'غلط',
        emoji: isCorrect ? '✅' : '❌',
        isCorrect: isCorrect,
        confidence: 100,
        userInput: userAnswer,
        correctAnswer: question.correctAnswer,
      );
    } else {
      // For typing questions, use HuggingFace model
      return await HuggingFaceApiService.scoreAnswer(
        userInput: userAnswer,
        correctAnswer: question.correctAnswer,
      );
    }
  }

  /// Calculate quiz session result
  static QuizSessionResult calculateResult({
    required String chapterId,
    required int lessonIndex,
    required List<QuizQuestion> questions,
    required Duration timeTaken,
  }) {
    int correctCount = 0;
    int totalScore = 0;
    final weakWords = <String>[];
    final masteredWords = <String>[];

    for (var q in questions) {
      if (q.scoreResult != null) {
        totalScore += q.scoreResult!.score;
        if (q.scoreResult!.isCorrect) {
          correctCount++;
          masteredWords.add(q.correctAnswer);
        } else {
          weakWords.add(q.correctAnswer);
        }
      }
    }

    final avgScore = questions.isNotEmpty ? totalScore / questions.length : 0.0;

    return QuizSessionResult(
      chapterId: chapterId,
      lessonIndex: lessonIndex,
      questions: questions,
      totalQuestions: questions.length,
      correctAnswers: correctCount,
      totalScore: totalScore,
      averageScore: avgScore,
      timeTaken: timeTaken,
      weakWords: weakWords,
      masteredWords: masteredWords,
    );
  }

  /// Get vocabulary for chapter/lesson
  static Future<LessonVocabulary?> _getVocabulary(
    String chapterId,
    int lessonIndex,
    String language,
  ) async {
    final predictions = await MLVocabularyService.generateVocabularyWithML(
      chapterId: chapterId,
      lessonIndex: lessonIndex,
      language: language,
      count: 25,
    );

    if (predictions.isEmpty) return null;

    return LessonVocabulary(
      lessonNumber: lessonIndex + 1,
      title: 'Lesson ${lessonIndex + 1}',
      titleEnglish: 'Lesson ${lessonIndex + 1}',
      words: predictions
          .map(
            (p) => VocabWord(
              urdu: p.word,
              english: p.translation,
              pronunciation: p.pronunciation,
              exampleSentence: p.example ?? p.word,
              exampleEnglish: p.exampleTranslation ?? p.translation,
            ),
          )
          .toList(),
    );
  }

  /// Generate a mixed quiz with all question types
  static Future<List<QuizQuestion>> generateMixedQuiz({
    required String chapterId,
    required int lessonIndex,
    required String language,
    int questionCount = 10,
  }) async {
    return generateLessonQuiz(
      chapterId: chapterId,
      lessonIndex: lessonIndex,
      language: language,
      questionCount: questionCount,
      types: [QuizType.vocabulary, QuizType.typing, QuizType.grammar],
    );
  }

  /// Generate chapter review quiz (all lessons combined)
  static Future<List<QuizQuestion>> generateChapterReviewQuiz({
    required String chapterId,
    required String language,
    int questionCount = chapterQuizQuestionCount,
  }) async {
    final questions = <QuizQuestion>[];

    // In ML-only mode, chapters expose 4 lesson slots.
    const lessonCount = 4;
    final questionsPerLesson = (questionCount / lessonCount).ceil();

    for (int i = 0; i < lessonCount; i++) {
      final lessonQuestions = await generateLessonQuiz(
        chapterId: chapterId,
        lessonIndex: i,
        language: language,
        questionCount: questionsPerLesson,
      );
      questions.addAll(lessonQuestions);
    }

    questions.shuffle();
    return questions.take(questionCount).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // ML-ENHANCED QUIZ GENERATION
  // Uses embeddings for semantic distractor generation
  // ═══════════════════════════════════════════════════════════════════

  /// Generate ML-enhanced quiz with semantic distractors
  /// Distractors are semantically similar (confusable) words
  static Future<List<QuizQuestion>> generateMLEnhancedQuiz({
    required String chapterId,
    required int lessonIndex,
    required String language,
    int questionCount = 10,
    bool useSemanticDistractors = true,
  }) async {
    final vocabulary = await _getVocabulary(chapterId, lessonIndex, language);

    if (vocabulary == null || vocabulary.words.isEmpty) {
      return [];
    }

    final questions = <QuizQuestion>[];
    final recommendationService = WordRecommendationService();

    // Generate vocabulary questions with ML distractors
    final vocabQuestions = await _generateMLVocabularyQuestions(
      vocabulary: vocabulary,
      language: language,
      count: (questionCount * 0.5).round(),
      recommendationService: recommendationService,
      useSemanticDistractors: useSemanticDistractors,
    );
    questions.addAll(vocabQuestions);

    // Add typing questions
    questions.addAll(
      _generateTypingQuestions(
        vocabulary,
        language,
        (questionCount * 0.3).round(),
      ),
    );

    // Add grammar questions
    questions.addAll(
      _generateGrammarQuestions(
        vocabulary,
        language,
        (questionCount * 0.2).round(),
      ),
    );

    questions.shuffle();
    return questions.take(questionCount).toList();
  }

  /// Generate vocabulary questions with ML-powered semantic distractors
  static Future<List<QuizQuestion>> _generateMLVocabularyQuestions({
    required LessonVocabulary vocabulary,
    required String language,
    required int count,
    required WordRecommendationService recommendationService,
    bool useSemanticDistractors = true,
  }) async {
    final questions = <QuizQuestion>[];
    final words = vocabulary.words.toList()..shuffle();

    for (int i = 0; i < count && i < words.length; i++) {
      final word = words[i];

      List<String> distractors;

      if (useSemanticDistractors) {
        // Use ML to find semantically similar (confusable) words
        try {
          distractors = await recommendationService.getConfusableWords(
            correctWord: word.urdu,
            language: language,
            count: 3,
          );
        } catch (e) {
          debugPrint(
            'QuizGeneratorService: ML distractors failed, using fallback: $e',
          );
          distractors = _getFallbackDistractors(word.urdu, vocabulary.words, 3);
        }
      } else {
        distractors = _getFallbackDistractors(word.urdu, vocabulary.words, 3);
      }

      // Ensure we have enough distractors
      if (distractors.length < 3) {
        distractors.addAll(
          _getFallbackDistractors(
            word.urdu,
            vocabulary.words,
            3 - distractors.length,
          ),
        );
      }

      final options = [word.urdu, ...distractors.take(3)];
      options.shuffle();

      questions.add(
        QuizQuestion(
          id: 'ml_vocab_${DateTime.now().millisecondsSinceEpoch}_$i',
          type: QuizType.vocabulary,
          subtype: useSemanticDistractors ? 'ml_semantic' : 'random',
          question:
              'What is "${word.english}" in ${language == 'urdu' ? 'Urdu' : 'Punjabi'}?',
          options: options,
          correctAnswer: word.urdu,
          correctIndex: options.indexOf(word.urdu),
          language: language,
          difficulty: _calculateDifficulty(distractors, word.urdu),
          hint: word.pronunciation,
        ),
      );

      // Reverse direction question
      if (i + 1 <= count ~/ 2) {
        List<String> engDistractors;

        if (useSemanticDistractors) {
          try {
            // Find confusable English words
            final confusableWords = await recommendationService
                .getConfusableWords(
                  correctWord: word.urdu,
                  language: language,
                  count: 3,
                );
            // Get English translations of confusable words
            engDistractors = confusableWords
                .map((w) {
                  final vocabWord = vocabulary.words.firstWhere(
                    (vw) => vw.urdu == w,
                    orElse: () =>
                        VocabWord(urdu: '', english: w, pronunciation: ''),
                  );
                  return vocabWord.english;
                })
                .where((e) => e.isNotEmpty && e != word.english)
                .toList();
          } catch (e) {
            engDistractors = _getEnglishFallbackDistractors(
              word.english,
              vocabulary.words,
              3,
            );
          }
        } else {
          engDistractors = _getEnglishFallbackDistractors(
            word.english,
            vocabulary.words,
            3,
          );
        }

        if (engDistractors.length < 3) {
          engDistractors.addAll(
            _getEnglishFallbackDistractors(
              word.english,
              vocabulary.words,
              3 - engDistractors.length,
            ),
          );
        }

        final engOptions = [word.english, ...engDistractors.take(3)];
        engOptions.shuffle();

        questions.add(
          QuizQuestion(
            id: 'ml_vocab_${DateTime.now().millisecondsSinceEpoch}_${i}_rev',
            type: QuizType.vocabulary,
            subtype: useSemanticDistractors
                ? 'ml_semantic_reverse'
                : 'random_reverse',
            question: 'What does "${word.urdu}" mean?',
            questionUrdu: word.urdu,
            options: engOptions,
            correctAnswer: word.english,
            correctIndex: engOptions.indexOf(word.english),
            language: language,
            difficulty: _calculateDifficulty(engDistractors, word.english),
          ),
        );
      }
    }

    return questions;
  }

  /// Generate personalized quiz based on user's weak areas
  static Future<List<QuizQuestion>> generatePersonalizedQuiz({
    required String language,
    required String userId,
    int questionCount = 10,
  }) async {
    final personalizationService = PersonalizationService();
    await personalizationService.initialize(userId);

    final recommendations = await personalizationService.getRecommendations(
      language: language,
    );

    final questions = <QuizQuestion>[];

    // Focus on weak words
    for (final weakWord in recommendations.weakWords.take(5)) {
      final vocabWord = await _findVocabWordByUrdu(weakWord, language);
      if (vocabWord != null) {
        questions.add(
          QuizQuestion(
            id: 'personalized_${DateTime.now().millisecondsSinceEpoch}_${questions.length}',
            type: QuizType.typing,
            subtype: 'weak_word_practice',
            question:
                'Practice: Type "${vocabWord.english}" in ${language == 'urdu' ? 'Urdu' : 'Punjabi'}:',
            correctAnswer: vocabWord.urdu,
            language: language,
            difficulty: 'medium',
            hint: vocabWord.pronunciation,
          ),
        );
      }
    }

    // Add review words
    for (final reviewWord in recommendations.wordsForReview.take(3)) {
      final vocabWord = await _findVocabWordByUrdu(reviewWord, language);
      if (vocabWord != null) {
        questions.add(
          QuizQuestion(
            id: 'review_${DateTime.now().millisecondsSinceEpoch}_${questions.length}',
            type: QuizType.typing,
            subtype: 'spaced_repetition',
            question:
                'Review: Type "${vocabWord.english}" in ${language == 'urdu' ? 'Urdu' : 'Punjabi'}:',
            correctAnswer: vocabWord.urdu,
            language: language,
            difficulty: 'easy',
            hint: vocabWord.pronunciation,
          ),
        );
      }
    }

    // Add new words to learn
    for (final newWord in recommendations.nextWordsToLearn.take(2)) {
      questions.add(
        QuizQuestion(
          id: 'new_${DateTime.now().millisecondsSinceEpoch}_${questions.length}',
          type: QuizType.vocabulary,
          subtype: 'new_word',
          question: 'New word: What is "${newWord.english}"?',
          options: [newWord.urdu],
          correctAnswer: newWord.urdu,
          correctIndex: 0,
          language: language,
          difficulty: 'easy',
          hint: newWord.pronunciation,
        ),
      );
    }

    questions.shuffle();
    return questions.take(questionCount).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════

  /// Get fallback distractors (random selection)
  static List<String> _getFallbackDistractors(
    String correctWord,
    List<VocabWord> allWords,
    int count,
  ) {
    final candidates =
        allWords.where((w) => w.urdu != correctWord).map((w) => w.urdu).toList()
          ..shuffle();
    return candidates.take(count).toList();
  }

  /// Get fallback English distractors
  static List<String> _getEnglishFallbackDistractors(
    String correctWord,
    List<VocabWord> allWords,
    int count,
  ) {
    final candidates =
        allWords
            .where((w) => w.english != correctWord)
            .map((w) => w.english)
            .toList()
          ..shuffle();
    return candidates.take(count).toList();
  }

  /// Calculate question difficulty based on distractor similarity
  static String _calculateDifficulty(List<String> distractors, String correct) {
    // In full implementation, would use embedding similarity
    // For now, use simple heuristics
    if (distractors.isEmpty) return 'easy';

    // Check for similar length words (harder to distinguish)
    final avgLengthDiff =
        distractors
            .map((d) => (d.length - correct.length).abs())
            .reduce((a, b) => a + b) /
        distractors.length;

    if (avgLengthDiff < 2) return 'hard';
    if (avgLengthDiff < 4) return 'medium';
    return 'easy';
  }

  /// Find a VocabWord by its Urdu text
  static Future<VocabWord?> _findVocabWordByUrdu(
    String urduWord,
    String language,
  ) async {
    for (int chapter = 1; chapter <= 15; chapter++) {
      for (int lessonIdx = 0; lessonIdx < 4; lessonIdx++) {
        final predictions = await MLVocabularyService.generateVocabularyWithML(
          chapterId: '${language}_ch$chapter',
          lessonIndex: lessonIdx,
          language: language,
          count: 25,
        );

        for (final p in predictions) {
          if (p.word == urduWord) {
            return VocabWord(
              urdu: p.word,
              english: p.translation,
              pronunciation: p.pronunciation,
              exampleSentence: p.example ?? p.word,
              exampleEnglish: p.exampleTranslation ?? p.translation,
            );
          }
        }
      }
    }

    return null;
  }
}

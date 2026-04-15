import 'dart:math';
import 'package:flutter/foundation.dart';
import '../services/content_generation_service.dart' as content;

/// Word mastery tracking for spaced repetition
class WordMastery {
  final String word;
  int level = 0; // 0-5 mastery level
  int attempts = 0;
  int correctCount = 0;
  DateTime lastReviewed = DateTime.now();
  DateTime? nextReviewDate;

  WordMastery({required this.word});

  void recordAttempt(bool isCorrect) {
    attempts++;
    if (isCorrect) {
      correctCount++;
      level = min(5, level + 1);
      // Schedule next review
      final intervalsIndex = min(level, 5);
      final intervalDays = [1, 3, 7, 14, 30, 90][intervalsIndex];
      nextReviewDate = DateTime.now().add(Duration(days: intervalDays));
    } else {
      level = max(0, level - 1);
      // Review sooner if incorrect
      nextReviewDate = DateTime.now().add(const Duration(hours: 12));
    }
    lastReviewed = DateTime.now();
  }

  bool get isDueForReview {
    if (nextReviewDate == null) return true;
    return DateTime.now().isAfter(nextReviewDate!);
  }

  double get masteryPercentage {
    if (attempts == 0) return 0.0;
    return (correctCount / attempts) * (level / 5.0);
  }
}

class AdaptiveQuizService extends ChangeNotifier {
  // User performance tracking
  int _correctAnswers = 0;
  int _totalAttempts = 0;
  double _currentDifficulty = 0.5; // 0.0 (easy) to 1.0 (hard)
  List<Map<String, dynamic>> _performanceHistory = [];

  // Word mastery tracking
  final Map<String, WordMastery> _wordMastery = {};
  double get accuracy =>
      _totalAttempts > 0 ? _correctAnswers / _totalAttempts : 0.0;
  double get currentDifficulty => _currentDifficulty;
  int get correctAnswers => _correctAnswers;
  int get totalAttempts => _totalAttempts;
  List<Map<String, dynamic>> get performanceHistory => _performanceHistory;

  /// Get adaptive quiz questions based on user's performance
  Future<List<content.QuizQuestion>> getAdaptiveQuiz({
    required String language,
    required String category,
    required int count,
  }) async {
    final allQuestions = await content.ContentGenerationService.generateQuiz(
      category,
      language,
      count * 2, // Get more to filter from
    );

    if (allQuestions.isEmpty) return []; // Filter based on difficulty
    List<content.QuizQuestion> filteredQuestions;

    if (_currentDifficulty < 0.3) {
      // Easy level - focus on basics
      filteredQuestions = allQuestions.where((q) {
        return (_wordMastery[q.question]?.level ?? 0) < 2;
      }).toList();
    } else if (_currentDifficulty < 0.7) {
      // Medium level - mix of known and new
      filteredQuestions = allQuestions.where((q) {
        final level = _wordMastery[q.question]?.level ?? 0;
        return level >= 1 && level <= 3;
      }).toList();
    } else {
      // Hard level - challenging content
      filteredQuestions = allQuestions.where((q) {
        return (_wordMastery[q.question]?.level ?? 0) >= 2;
      }).toList();
    }

    // If not enough filtered questions, use all
    if (filteredQuestions.length < count) {
      filteredQuestions = allQuestions;
    }

    // Prioritize words that need review
    filteredQuestions.sort((a, b) {
      final aMastery = _wordMastery[a.question];
      final bMastery = _wordMastery[b.question];

      if (aMastery == null && bMastery == null) return 0;
      if (aMastery == null) return -1; // New words first
      if (bMastery == null) return 1;

      // Words due for review first
      if (aMastery.isDueForReview && !bMastery.isDueForReview) return -1;
      if (!aMastery.isDueForReview && bMastery.isDueForReview) return 1;

      // Then by lower mastery level
      return aMastery.level.compareTo(bMastery.level);
    });

    // Return requested count
    return filteredQuestions.take(count).toList();
  }

  /// Record quiz result and adjust difficulty
  void recordQuizResult({
    required String question,
    required bool isCorrect,
    required double timeSpent,
    required String language,
  }) {
    _totalAttempts++;
    if (isCorrect) _correctAnswers++;

    // Update word mastery
    if (!_wordMastery.containsKey(question)) {
      _wordMastery[question] = WordMastery(word: question);
    }
    _wordMastery[question]!.recordAttempt(isCorrect);

    // Add to performance history
    _performanceHistory.add({
      'question': question,
      'isCorrect': isCorrect,
      'timeSpent': timeSpent,
      'timestamp': DateTime.now(),
      'difficulty': _currentDifficulty,
    });

    // Keep only last 100 entries
    if (_performanceHistory.length > 100) {
      _performanceHistory = _performanceHistory.sublist(
        _performanceHistory.length - 100,
      );
    }

    // Adjust difficulty based on recent performance
    _adjustDifficulty();

    notifyListeners();
  }

  /// Adjust difficulty based on recent performance (last 10 attempts)
  void _adjustDifficulty() {
    if (_totalAttempts < 5) return; // Need minimum attempts

    final recentAttempts = _performanceHistory.length >= 10
        ? _performanceHistory.sublist(_performanceHistory.length - 10)
        : _performanceHistory;

    final recentCorrect = recentAttempts
        .where((a) => a['isCorrect'] == true)
        .length;
    final recentAccuracy = recentCorrect / recentAttempts.length;

    // Adjust difficulty based on accuracy
    if (recentAccuracy >= 0.9) {
      // Too easy, increase difficulty
      _currentDifficulty = min(1.0, _currentDifficulty + 0.1);
    } else if (recentAccuracy >= 0.7) {
      // Just right, slight increase
      _currentDifficulty = min(1.0, _currentDifficulty + 0.05);
    } else if (recentAccuracy < 0.5) {
      // Too hard, decrease difficulty
      _currentDifficulty = max(0.0, _currentDifficulty - 0.15);
    } else if (recentAccuracy < 0.6) {
      // Slightly hard, small decrease
      _currentDifficulty = max(0.0, _currentDifficulty - 0.05);
    }
  }

  /// Get words that need review based on spaced repetition
  List<String> getWordsForReview() {
    return _wordMastery.entries
        .where((entry) => entry.value.isDueForReview)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get personalized recommendations
  Map<String, dynamic> getPersonalizedRecommendations() {
    final weakWords = _wordMastery.entries
        .where((e) => e.value.level < 2 && e.value.attempts >= 3)
        .map((e) => e.key)
        .toList();

    final wordsForReview = getWordsForReview();
    final masteredWords = _wordMastery.entries
        .where((e) => e.value.level >= 4)
        .map((e) => e.key)
        .toList();

    String focusArea;
    if (accuracy < 0.5) {
      focusArea = 'basics';
    } else if (accuracy < 0.7) {
      focusArea = 'intermediate';
    } else {
      focusArea = 'advanced';
    }

    return {
      'weakWords': weakWords,
      'wordsForReview': wordsForReview,
      'masteredWords': masteredWords,
      'focusArea': focusArea,
      'recommendedDifficulty': _currentDifficulty,
      'suggestedSessionLength': _getSuggestedSessionLength(),
    };
  }

  int _getSuggestedSessionLength() {
    if (accuracy < 0.5) return 5; // Short sessions for struggling users
    if (accuracy < 0.7) return 10; // Medium sessions
    return 15; // Longer sessions for advanced users
  }

  /// Reset progress (for testing or new start)
  void resetProgress() {
    _correctAnswers = 0;
    _totalAttempts = 0;
    _currentDifficulty = 0.5;
    _performanceHistory.clear();
    _wordMastery.clear();
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdaptiveLearningProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Track words that need reinforcement (now lesson-based)
  Map<String, List<String>> _weakWords = {}; // lessonId -> list of weak words
  Map<String, int> _lessonScores = {}; // lessonId -> last quiz score
  Map<String, List<String>> _reviewWords =
      {}; // lessonId -> words to review in next lesson

  Map<String, List<String>> get weakWords => _weakWords;
  Map<String, int> get lessonScores => _lessonScores;
  Map<String, int> get chapterScores => _lessonScores; // Backward compatibility
  Map<String, List<String>> get reviewWords => _reviewWords;

  // Process quiz results and determine next action (now lesson-based)
  QuizAction processQuizScore(
    String lessonId,
    int score,
    List<String> missedWords,
  ) {
    _lessonScores[lessonId] = score;

    if (score < 60) {
      // Score below 60% - must re-learn the lesson
      _weakWords[lessonId] = missedWords;
      notifyListeners();
      return QuizAction.relearn;
    } else if (score < 80) {
      // Score 60-79% - add weak words to next lesson for review
      _reviewWords[lessonId] = missedWords;
      notifyListeners();
      return QuizAction.reviewInNext;
    } else {
      // Score 80%+ - excellent, proceed normally
      _weakWords.remove(lessonId);
      _reviewWords.remove(lessonId);
      notifyListeners();
      return QuizAction.proceed;
    }
  }

  // Helper to get previous lesson ID
  String? _getPreviousLessonId(String lessonId) {
    // Parse lesson ID format: "urdu_ch1_lesson1"
    final parts = lessonId.split('_lesson');
    if (parts.length != 2) return null;

    final lessonNum = int.tryParse(parts[1]);
    if (lessonNum == null || lessonNum <= 1) return null;

    return '${parts[0]}_lesson${lessonNum - 1}';
  }

  // Get words to review in current lesson
  List<String> getReviewWordsForLesson(String lessonId) {
    // Get words from previous lesson if score was 60-79%
    List<String> wordsToReview = [];

    // Find previous lesson ID
    String? previousLessonId = _getPreviousLessonId(lessonId);
    if (previousLessonId != null &&
        _reviewWords.containsKey(previousLessonId)) {
      wordsToReview.addAll(_reviewWords[previousLessonId]!);
    }

    return wordsToReview;
  }

  // Backward compatibility
  List<String> getReviewWordsForChapter(String chapterId) {
    return getReviewWordsForLesson(chapterId);
  }

  // Check if lesson needs to be re-learned
  bool needsRelearning(String lessonId) {
    return _lessonScores[lessonId] != null && _lessonScores[lessonId]! < 60;
  }

  // Get difficulty level based on user performance
  DifficultyLevel getDifficultyLevel(String userId, String lessonId) {
    final score = _lessonScores[lessonId];
    if (score == null) return DifficultyLevel.normal;

    if (score < 60) return DifficultyLevel.easy;
    if (score < 80) return DifficultyLevel.normal;
    return DifficultyLevel.hard;
  }

  // Reset lesson for re-learning
  void resetLessonForRelearning(String lessonId) {
    _lessonScores.remove(lessonId);
    _weakWords.remove(lessonId);
    notifyListeners();
  }

  // Backward compatibility
  void resetChapterForRelearning(String chapterId) {
    resetLessonForRelearning(chapterId);
  }

  // Save adaptive learning data to Firestore
  Future<void> saveToFirestore(String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('adaptive_learning')
          .doc('data')
          .set({
            'weakWords': _weakWords,
            'lessonScores': _lessonScores,
            'reviewWords': _reviewWords,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error saving adaptive learning data: $e');
    }
  }

  // Load adaptive learning data from Firestore
  Future<void> loadFromFirestore(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('adaptive_learning')
          .doc('data')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _weakWords = Map<String, List<String>>.from(
          (data['weakWords'] ?? {}).map(
            (key, value) => MapEntry(key, List<String>.from(value)),
          ),
        );
        _lessonScores = Map<String, int>.from(
          data['lessonScores'] ?? data['chapterScores'] ?? {},
        ); // Support both old and new format
        _reviewWords = Map<String, List<String>>.from(
          (data['reviewWords'] ?? {}).map(
            (key, value) => MapEntry(key, List<String>.from(value)),
          ),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading adaptive learning data: $e');
    }
  }
}

enum QuizAction {
  relearn, // Score < 60% - must re-learn chapter
  reviewInNext, // Score 60-79% - add words to next chapter
  proceed, // Score 80%+ - excellent, continue
}

enum DifficultyLevel { easy, normal, hard }

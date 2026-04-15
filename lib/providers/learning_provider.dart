import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

class Chapter {
  final String id;
  final String title;
  final String description; // English translation/description
  final String language; // 'urdu', 'punjabi'
  final int lessonCount;
  final bool isLocked;
  final double progress;

  Chapter({
    required this.id,
    required this.title,
    required this.description,
    required this.language,
    required this.lessonCount,
    this.isLocked = true,
    this.progress = 0,
  });
}

class Lesson {
  final String id;
  final String chapterId;
  final String title;
  final String content;
  final List<String> vocabularyWords;
  final String? audioUrl;
  final bool isCompleted;

  Lesson({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.content,
    required this.vocabularyWords,
    this.audioUrl,
    this.isCompleted = false,
  });
}

class Quiz {
  final String id;
  final String lessonId;
  final List<QuizQuestion> questions;
  final bool isCompleted;
  final int score;

  Quiz({
    required this.id,
    required this.lessonId,
    required this.questions,
    this.isCompleted = false,
    this.score = 0,
  });
}

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String selectedAnswer;

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.selectedAnswer = '',
  });
}

class LearningProvider extends ChangeNotifier {
  List<Chapter> _urduChapters = [];
  List<Chapter> _punjabiChapters = [];
  final List<Lesson> _lessons = [];
  final List<Quiz> _quizzes = [];

  // Track completed lessons per chapter (chapterId -> Set of completed lesson indices)
  final Map<String, Set<int>> _completedLessonsPerChapter = {};

  // Track chapter quiz scores (chapterId -> score percentage)
  final Map<String, double> _chapterQuizScores = {};

  List<Chapter> get urduChapters => _urduChapters;
  List<Chapter> get punjabiChapters => _punjabiChapters;
  List<Lesson> get lessons => _lessons;
  List<Quiz> get quizzes => _quizzes;
  Map<String, double> get chapterQuizScores => _chapterQuizScores;

  LearningProvider() {
    _initializeChapters();
  }

  void _initializeChapters() {
    // Initialize Urdu Chapters (10 chapters, 4 lessons each = 40 lessons)
    // Only Chapter 1 is unlocked by default, rest require 80%+ quiz score
    _urduChapters = [
      Chapter(
        id: 'urdu_ch1',
        title: 'بنیادی الفاظ',
        description: 'Basic Words & Greetings',
        language: 'urdu',
        lessonCount: 4,
        isLocked: false, // First chapter always unlocked
        progress: 0,
      ),
      Chapter(
        id: 'urdu_ch2',
        title: 'روزمرہ گفتگو',
        description: 'Daily Conversation',
        language: 'urdu',
        lessonCount: 4,
        isLocked: true, // Locked until Chapter 1 quiz passed with 80%+
        progress: 0,
      ),
      Chapter(
        id: 'urdu_ch3',
        title: 'گرامر کی بنیاد',
        description: 'Grammar Basics',
        language: 'urdu',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'urdu_ch4',
        title: 'سفر اور ٹرانسپورٹ',
        description: 'Travel & Transport',
        language: 'urdu',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'urdu_ch5',
        title: 'کھانا پینا',
        description: 'Food & Drinks',
        language: 'urdu',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'urdu_ch6',
        title: 'صحت و طب',
        description: 'Health & Body',
        language: 'urdu',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'urdu_ch7',
        title: 'تعلیم',
        description: 'Education',
        language: 'urdu',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'urdu_ch8',
        title: 'کام اور پیشے',
        description: 'Work & Professions',
        language: 'urdu',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'urdu_ch9',
        title: 'ٹیکنالوجی',
        description: 'Technology',
        language: 'urdu',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'urdu_ch10',
        title: 'ثقافت و روایات',
        description: 'Culture & Traditions',
        language: 'urdu',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'urdu_ch11',
        title: 'جذبات و احساسات',
        description: 'Emotions & Feelings',
        language: 'urdu',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'urdu_ch12',
        title: 'کھیل کود',
        description: 'Sports & Games',
        language: 'urdu',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'urdu_ch13',
        title: 'اسلامی اصطلاحات',
        description: 'Islamic Terms & Months',
        language: 'urdu',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'urdu_ch14',
        title: 'فطرت و ماحول',
        description: 'Nature & Environment',
        language: 'urdu',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'urdu_ch15',
        title: 'گھر اور فرنیچر',
        description: 'Home & Furniture',
        language: 'urdu',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
    ];

    // Initialize Punjabi Chapters (10 chapters, 4 lessons each = 40 lessons)
    _punjabiChapters = [
      Chapter(
        id: 'punjabi_ch1',
        title: 'بنیادی الفاظ',
        description: 'Basic Words & Greetings',
        language: 'punjabi',
        lessonCount: 4,
        isLocked: false, // First chapter always unlocked
        progress: 0,
      ),
      Chapter(
        id: 'punjabi_ch2',
        title: 'روزانہ گل بات',
        description: 'Daily Conversation',
        language: 'punjabi',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'punjabi_ch3',
        title: 'گرامر دی بنیاد',
        description: 'Grammar Basics',
        language: 'punjabi',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'punjabi_ch4',
        title: 'سفر تے آوا جائی',
        description: 'Travel & Transport',
        language: 'punjabi',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'punjabi_ch5',
        title: 'کھانا پینا',
        description: 'Food & Drinks',
        language: 'punjabi',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'punjabi_ch6',
        title: 'صحت تے جسم',
        description: 'Health & Body',
        language: 'punjabi',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'punjabi_ch7',
        title: 'پڑھائی',
        description: 'Education',
        language: 'punjabi',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'punjabi_ch8',
        title: 'کم کاج تے پیشے',
        description: 'Work & Professions',
        language: 'punjabi',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'punjabi_ch9',
        title: 'ٹیکنالوجی',
        description: 'Technology',
        language: 'punjabi',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'punjabi_ch10',
        title: 'سبھیاچار تے رواج',
        description: 'Culture & Traditions',
        language: 'punjabi',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'punjabi_ch11',
        title: 'جذبات تے احساسات',
        description: 'Emotions & Feelings',
        language: 'punjabi',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'punjabi_ch12',
        title: 'کھیڈاں تے کھیل',
        description: 'Sports & Games',
        language: 'punjabi',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'punjabi_ch13',
        title: 'اسلامی اصطلاحات',
        description: 'Islamic Terms & Months',
        language: 'punjabi',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'punjabi_ch14',
        title: 'فطرت تے ماحول',
        description: 'Nature & Environment',
        language: 'punjabi',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
      Chapter(
        id: 'punjabi_ch15',
        title: 'گھر تے فرنیچر',
        description: 'Home & Furniture',
        language: 'punjabi',
        lessonCount: 4,
        isLocked: true,
        progress: 0,
      ),
    ];

    // Apply any saved quiz scores to unlock chapters
    _applyChapterUnlocks();
  }

  void addLesson(Lesson lesson) {
    _lessons.add(lesson);
    notifyListeners();
  }

  void completeLesson(String lessonId) {
    final index = _lessons.indexWhere((l) => l.id == lessonId);
    if (index != -1) {
      notifyListeners();
    }
  }

  // Mark a specific lesson in a chapter as completed
  Future<void> markLessonCompleted(String chapterId, int lessonIndex) async {
    debugPrint(
      '📝 Marking lesson $lessonIndex complete for chapter $chapterId',
    );

    if (!_completedLessonsPerChapter.containsKey(chapterId)) {
      _completedLessonsPerChapter[chapterId] = {};
    }

    final wasAlreadyCompleted = _completedLessonsPerChapter[chapterId]!
        .contains(lessonIndex);
    _completedLessonsPerChapter[chapterId]!.add(lessonIndex);

    if (wasAlreadyCompleted) {
      debugPrint('ℹ️ Lesson was already completed');
    } else {
      debugPrint('✓ Lesson marked as new completion');
    }

    debugPrint(
      '📊 Total completed lessons in chapter: ${_completedLessonsPerChapter[chapterId]!.length}',
    );
    debugPrint('📊 All completed lessons: $_completedLessonsPerChapter');

    // Update chapter progress
    _updateChapterProgress(chapterId);

    // IMPORTANT: Notify listeners FIRST so UI updates immediately with local data
    notifyListeners();

    // THEN save progress to Firestore in background (await to ensure it completes)
    await _saveProgressToFirestore();
  }

  // Get count of completed lessons for a chapter
  int getCompletedLessonsCount(String chapterId) {
    return _completedLessonsPerChapter[chapterId]?.length ?? 0;
  }

  // Check if a specific lesson is completed
  bool isLessonCompleted(String chapterId, int lessonIndex) {
    return _completedLessonsPerChapter[chapterId]?.contains(lessonIndex) ??
        false;
  }

  // Update chapter progress based on completed lessons
  void _updateChapterProgress(String chapterId) {
    final completedCount = getCompletedLessonsCount(chapterId);

    // Find and update the chapter
    for (int i = 0; i < _urduChapters.length; i++) {
      if (_urduChapters[i].id == chapterId) {
        final totalLessons = _urduChapters[i].lessonCount;
        final newProgress = completedCount / totalLessons;
        _urduChapters[i] = Chapter(
          id: _urduChapters[i].id,
          title: _urduChapters[i].title,
          description: _urduChapters[i].description,
          language: _urduChapters[i].language,
          lessonCount: _urduChapters[i].lessonCount,
          isLocked: _urduChapters[i].isLocked,
          progress: newProgress,
        );
        return;
      }
    }

    for (int i = 0; i < _punjabiChapters.length; i++) {
      if (_punjabiChapters[i].id == chapterId) {
        final totalLessons = _punjabiChapters[i].lessonCount;
        final newProgress = completedCount / totalLessons;
        _punjabiChapters[i] = Chapter(
          id: _punjabiChapters[i].id,
          title: _punjabiChapters[i].title,
          description: _punjabiChapters[i].description,
          language: _punjabiChapters[i].language,
          lessonCount: _punjabiChapters[i].lessonCount,
          isLocked: _punjabiChapters[i].isLocked,
          progress: newProgress,
        );
        return;
      }
    }
  }

  void addQuiz(Quiz quiz) {
    _quizzes.add(quiz);
    notifyListeners();
  }

  void completeQuiz(String quizId, int score) {
    final index = _quizzes.indexWhere((q) => q.id == quizId);
    if (index != -1) {
      notifyListeners();
    }
  }

  /// Complete chapter quiz and unlock next chapter if score >= 80%
  Future<void> completeChapterQuiz(String chapterId, double score) async {
    debugPrint('📝 Chapter quiz completed for $chapterId with score: $score%');

    _chapterQuizScores[chapterId] = score;

    // If score >= 80%, unlock the next chapter
    if (score >= 80) {
      _unlockNextChapterAfterQuiz(chapterId);
    }

    notifyListeners();
    await _saveProgressToFirestore();
  }

  /// Get quiz score for a chapter
  double? getChapterQuizScore(String chapterId) {
    return _chapterQuizScores[chapterId];
  }

  /// Check if chapter quiz is passed (score >= 80%)
  bool isChapterQuizPassed(String chapterId) {
    final score = _chapterQuizScores[chapterId];
    return score != null && score >= 80;
  }

  /// Check if user can take the chapter quiz (all lessons completed)
  bool canTakeChapterQuiz(String chapterId) {
    // Find the chapter to get lesson count
    Chapter? chapter;
    for (final ch in _urduChapters) {
      if (ch.id == chapterId) {
        chapter = ch;
        break;
      }
    }
    if (chapter == null) {
      for (final ch in _punjabiChapters) {
        if (ch.id == chapterId) {
          chapter = ch;
          break;
        }
      }
    }

    if (chapter == null) return false;

    final completedCount = getCompletedLessonsCount(chapterId);
    return completedCount >= chapter.lessonCount;
  }

  /// Unlock the next chapter after passing quiz with 80%+
  void _unlockNextChapterAfterQuiz(String chapterId) {
    // Find current chapter index and unlock next
    for (int i = 0; i < _urduChapters.length - 1; i++) {
      if (_urduChapters[i].id == chapterId) {
        _urduChapters[i + 1] = Chapter(
          id: _urduChapters[i + 1].id,
          title: _urduChapters[i + 1].title,
          description: _urduChapters[i + 1].description,
          language: _urduChapters[i + 1].language,
          lessonCount: _urduChapters[i + 1].lessonCount,
          isLocked: false,
          progress: _urduChapters[i + 1].progress,
        );
        debugPrint('✓ Unlocked next Urdu chapter: ${_urduChapters[i + 1].id}');
        return;
      }
    }

    for (int i = 0; i < _punjabiChapters.length - 1; i++) {
      if (_punjabiChapters[i].id == chapterId) {
        _punjabiChapters[i + 1] = Chapter(
          id: _punjabiChapters[i + 1].id,
          title: _punjabiChapters[i + 1].title,
          description: _punjabiChapters[i + 1].description,
          language: _punjabiChapters[i + 1].language,
          lessonCount: _punjabiChapters[i + 1].lessonCount,
          isLocked: false,
          progress: _punjabiChapters[i + 1].progress,
        );
        debugPrint(
          '✓ Unlocked next Punjabi chapter: ${_punjabiChapters[i + 1].id}',
        );
        return;
      }
    }
  }

  /// Apply chapter unlocks based on saved quiz scores
  void _applyChapterUnlocks() {
    for (final entry in _chapterQuizScores.entries) {
      if (entry.value >= 80) {
        _unlockNextChapterAfterQuiz(entry.key);
      }
    }
  }

  void unlockNextChapter(String language) {
    if (language == 'urdu') {
      for (int i = 0; i < _urduChapters.length - 1; i++) {
        if (_urduChapters[i].progress >= 100 && _urduChapters[i + 1].isLocked) {
          _urduChapters[i + 1] = Chapter(
            id: _urduChapters[i + 1].id,
            title: _urduChapters[i + 1].title,
            description: _urduChapters[i + 1].description,
            language: _urduChapters[i + 1].language,
            lessonCount: _urduChapters[i + 1].lessonCount,
            isLocked: false,
          );
        }
      }
    } else {
      for (int i = 0; i < _punjabiChapters.length - 1; i++) {
        if (_punjabiChapters[i].progress >= 100 &&
            _punjabiChapters[i + 1].isLocked) {
          _punjabiChapters[i + 1] = Chapter(
            id: _punjabiChapters[i + 1].id,
            title: _punjabiChapters[i + 1].title,
            description: _punjabiChapters[i + 1].description,
            language: _punjabiChapters[i + 1].language,
            lessonCount: _punjabiChapters[i + 1].lessonCount,
            isLocked: false,
          );
        }
      }
    }
    notifyListeners();
  }

  /// Clear all in-memory progress and local cache on logout.
  Future<void> clearProgressOnLogout() async {
    _completedLessonsPerChapter.clear();
    _chapterQuizScores.clear();
    _initializeChapters(); // reset progress on chapter objects too
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('chapterProgress_${user.uid}');
        await prefs.remove('chapterQuizScores_${user.uid}');
      }
    } catch (_) {}
    notifyListeners();
  }

  // Save user progress to Firestore AND SharedPreferences
  Future<void> _saveProgressToFirestore() async {
    // Convert Set<int> → List<int> for serialization
    final completedLessonsData = _completedLessonsPerChapter.map(
      (key, value) => MapEntry(key, value.toList()),
    );

    // 1) Always save locally first — fast and works offline
    await _saveProgressLocally(completedLessonsData, _chapterQuizScores);

    // 2) Push to Firestore in the background (non-blocking with timeout)
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠ Cannot save to Firestore: No user logged in');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'completedLessons': completedLessonsData,
            'chapterQuizScores': _chapterQuizScores,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('⚠ Firestore save timed out (local cache is intact)');
            },
          );

      debugPrint('✓ Chapter progress saved to Firestore for ${user.uid}');
    } catch (e) {
      debugPrint('⚠ Firestore save error (local cache is intact): $e');
    }
  }

  /// Persist progress to SharedPreferences under a user-specific key.
  Future<void> _saveProgressLocally(
    Map<String, List<int>> lessonsData,
    Map<String, double> quizScores,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'chapterProgress_${user.uid}',
        jsonEncode(lessonsData),
      );
      await prefs.setString(
        'chapterQuizScores_${user.uid}',
        jsonEncode(quizScores),
      );
      debugPrint('✓ Chapter progress cached locally');
    } catch (e) {
      debugPrint('⚠ Local cache save error: $e');
    }
  }

  // Load user progress from SharedPreferences (instant) then Firestore (authoritative)
  Future<void> loadProgressFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠ Cannot load progress: No user logged in');
        return;
      }

      // --- Step 1: load from local cache immediately so UI responds at once ---
      try {
        final prefs = await SharedPreferences.getInstance();
        final localJson = prefs.getString('chapterProgress_${user.uid}');
        final localQuizJson = prefs.getString('chapterQuizScores_${user.uid}');

        if (localJson != null) {
          final localData = jsonDecode(localJson) as Map<String, dynamic>;
          _applyCompletedLessons(localData);
          debugPrint('✓ Chapter progress restored from local cache');
        }

        if (localQuizJson != null) {
          final quizData = jsonDecode(localQuizJson) as Map<String, dynamic>;
          _applyQuizScores(quizData);
          debugPrint('✓ Quiz scores restored from local cache');
        }

        notifyListeners();
      } catch (e) {
        debugPrint('⚠ Local cache load error: $e');
      }

      // --- Step 2: fetch from Firestore and overwrite with authoritative data ---
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('⚠ Firestore load timed out (using local cache)');
              throw TimeoutException('Firestore load timed out');
            },
          );

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        if (data.containsKey('completedLessons')) {
          final completedLessonsData =
              data['completedLessons'] as Map<String, dynamic>;
          _applyCompletedLessons(completedLessonsData);
        }

        if (data.containsKey('chapterQuizScores')) {
          final quizScoresData =
              data['chapterQuizScores'] as Map<String, dynamic>;
          _applyQuizScores(quizScoresData);
        }

        // Keep local cache in sync with what Firestore returned
        final normalizedLessons = _completedLessonsPerChapter.map(
          (key, value) => MapEntry(key, value.toList()),
        );
        await _saveProgressLocally(normalizedLessons, _chapterQuizScores);

        debugPrint(
          '✓ Chapter progress loaded from Firestore: $_completedLessonsPerChapter',
        );
        debugPrint('✓ Quiz scores loaded: $_chapterQuizScores');
        notifyListeners();
      } else {
        debugPrint('ℹ️ No Firestore document for user yet');
      }
    } catch (e) {
      debugPrint('⚠ Error loading chapter progress: $e');
    }
  }

  /// Apply quiz scores from saved data
  void _applyQuizScores(Map<String, dynamic> raw) {
    _chapterQuizScores.clear();
    raw.forEach((chapterId, value) {
      _chapterQuizScores[chapterId] = (value as num).toDouble();
    });

    // Re-apply chapter unlocks based on quiz scores
    _applyChapterUnlocks();
  }

  /// Apply a raw completed-lessons map (from Firestore or SharedPreferences)
  /// into [_completedLessonsPerChapter] and rebuild chapter progress values.
  ///
  /// Handles both int and double values that Firestore/JSON can return for
  /// whole numbers (e.g. 0.0 vs 0).
  void _applyCompletedLessons(Map<String, dynamic> raw) {
    _completedLessonsPerChapter.clear();
    raw.forEach((chapterId, value) {
      if (value is List) {
        _completedLessonsPerChapter[chapterId] = value
            .map((e) => (e as num).toInt())
            .toSet();
      }
    });

    for (final chapterId in _completedLessonsPerChapter.keys) {
      _updateChapterProgress(chapterId);
    }
  }
}

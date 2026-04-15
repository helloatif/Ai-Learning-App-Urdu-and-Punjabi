import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'word_recommendation_service.dart';
import 'ml_vocabulary_service.dart';
import '../data/vocabulary_data.dart';

/// ML-based personalization service for adaptive learning
/// Tracks user progress, identifies weaknesses, and generates personalized paths
class PersonalizationService {
  // Singleton pattern
  static final PersonalizationService _instance =
      PersonalizationService._internal();
  factory PersonalizationService() => _instance;
  PersonalizationService._internal();

  final WordRecommendationService _recommendationService =
      WordRecommendationService();
  final Map<String, List<VocabWord>> _mlPoolCache = {};

  // User learning profile
  UserLearningProfile? _currentProfile;

  /// Initialize or load user profile
  Future<void> initialize(String userId) async {
    _currentProfile = await _loadProfile(userId);
    debugPrint('PersonalizationService: Loaded profile for user $userId');
  }

  /// Record a word attempt (correct or incorrect)
  Future<void> recordWordAttempt({
    required String word,
    required bool isCorrect,
    required String language,
    int responseTimeMs = 0,
  }) async {
    if (_currentProfile == null) return;

    final wordStats =
        _currentProfile!.wordStats[word] ?? WordStatistics(word: word);

    wordStats.totalAttempts++;
    if (isCorrect) {
      wordStats.correctAttempts++;
      wordStats.consecutiveCorrect++;
      wordStats.consecutiveWrong = 0;
    } else {
      wordStats.consecutiveWrong++;
      wordStats.consecutiveCorrect = 0;
    }

    // Update mastery level based on performance
    wordStats.masteryLevel = _calculateMasteryLevel(wordStats);
    wordStats.lastAttemptTime = DateTime.now();
    wordStats.averageResponseTimeMs = responseTimeMs > 0
        ? ((wordStats.averageResponseTimeMs * (wordStats.totalAttempts - 1)) +
                  responseTimeMs) ~/
              wordStats.totalAttempts
        : wordStats.averageResponseTimeMs;

    _currentProfile!.wordStats[word] = wordStats;

    // Save profile
    await _saveProfile(_currentProfile!);
  }

  /// Get personalized learning recommendations
  Future<PersonalizedRecommendations> getRecommendations({
    required String language,
  }) async {
    if (_currentProfile == null) {
      return PersonalizedRecommendations.empty();
    }

    final profile = _currentProfile!;

    // Identify weak words (low mastery)
    final weakWords = profile.wordStats.values
        .where((s) => s.masteryLevel < 0.5)
        .map((s) => s.word)
        .toList();

    // Identify mastered words
    final masteredWords = profile.wordStats.values
        .where((s) => s.masteryLevel >= 0.8)
        .map((s) => s.word)
        .toList();

    // Get words due for review (spaced repetition)
    final wordsForReview = profile.wordStats.values
        .where((s) => _isDueForReview(s))
        .map((s) => s.word)
        .toList();

    // Get next words to learn using ML recommendations
    final nextWordsToLearn = await _recommendationService.getNextWordsToLearn(
      masteredWords: masteredWords,
      language: language,
      count: 10,
    );

    // Calculate focus area
    final focusArea = _determineFocusArea(profile);

    // Get recommended difficulty
    final recommendedDifficulty = _calculateRecommendedDifficulty(profile);

    return PersonalizedRecommendations(
      weakWords: weakWords,
      masteredWords: masteredWords,
      wordsForReview: wordsForReview,
      nextWordsToLearn: nextWordsToLearn,
      focusArea: focusArea,
      recommendedDifficulty: recommendedDifficulty,
      overallProgress: await _calculateOverallProgress(profile, language),
      streakDays: profile.currentStreak,
      totalWordsLearned: masteredWords.length,
    );
  }

  /// Generate a personalized learning path
  Future<LearningPath> generateLearningPath({
    required String language,
    int durationDays = 7,
    int minutesPerDay = 15,
  }) async {
    if (_currentProfile == null) {
      return LearningPath.default_(language);
    }

    final recommendations = await getRecommendations(language: language);
    final dailyPlans = <DailyLearningPlan>[];

    // Calculate words per day based on time available
    final wordsPerDay = (minutesPerDay ~/ 2).clamp(5, 20); // ~2 min per word

    for (int day = 0; day < durationDays; day++) {
      final dayWords = <VocabWord>[];
      final dayActivities = <LearningActivity>[];

      // Mix of review and new words
      final reviewCount = (wordsPerDay * 0.4).round();
      final newCount = wordsPerDay - reviewCount;

      // Add review words
      for (
        int i = 0;
        i < reviewCount && i < recommendations.wordsForReview.length;
        i++
      ) {
        final wordStr = recommendations.wordsForReview[i];
        final vocabWord = await _findVocabWord(wordStr, language);
        if (vocabWord != null) dayWords.add(vocabWord);
      }

      // Add new words
      for (
        int i = 0;
        i < newCount && i < recommendations.nextWordsToLearn.length;
        i++
      ) {
        dayWords.add(recommendations.nextWordsToLearn[i]);
      }

      // Create activities
      dayActivities.add(
        LearningActivity(
          type: ActivityType.vocabulary,
          words: dayWords,
          estimatedMinutes: (dayWords.length * 1.5).round(),
        ),
      );

      if (recommendations.weakWords.isNotEmpty) {
        dayActivities.add(
          LearningActivity(
            type: ActivityType.practiceQuiz,
            words: dayWords.take(5).toList(),
            estimatedMinutes: 5,
          ),
        );
      }

      dailyPlans.add(
        DailyLearningPlan(
          day: day + 1,
          activities: dayActivities,
          estimatedMinutes: minutesPerDay,
          focusWords: dayWords,
        ),
      );
    }

    return LearningPath(
      language: language,
      dailyPlans: dailyPlans,
      totalDays: durationDays,
      focusAreas: [recommendations.focusArea],
      estimatedWordsToLearn: wordsPerDay * durationDays,
    );
  }

  /// Get adaptive quiz difficulty
  double getAdaptiveDifficulty() {
    if (_currentProfile == null) return 0.5;

    final recentAttempts = _currentProfile!.wordStats.values
        .where(
          (s) =>
              s.lastAttemptTime != null &&
              DateTime.now().difference(s.lastAttemptTime!).inDays < 7,
        )
        .toList();

    if (recentAttempts.isEmpty) return 0.5;

    final avgMastery =
        recentAttempts.map((s) => s.masteryLevel).reduce((a, b) => a + b) /
        recentAttempts.length;

    // If doing well, increase difficulty; if struggling, decrease
    if (avgMastery > 0.8) {
      return (_currentProfile!.currentDifficulty + 0.1).clamp(0.0, 1.0);
    } else if (avgMastery < 0.5) {
      return (_currentProfile!.currentDifficulty - 0.1).clamp(0.0, 1.0);
    }

    return _currentProfile!.currentDifficulty;
  }

  /// Update user streak
  Future<void> updateStreak() async {
    if (_currentProfile == null) return;

    final now = DateTime.now();
    final lastActivity = _currentProfile!.lastActivityDate;

    if (lastActivity != null) {
      final daysDiff = now.difference(lastActivity).inDays;

      if (daysDiff == 1) {
        // Consecutive day - increase streak
        _currentProfile!.currentStreak++;
        if (_currentProfile!.currentStreak > _currentProfile!.longestStreak) {
          _currentProfile!.longestStreak = _currentProfile!.currentStreak;
        }
      } else if (daysDiff > 1) {
        // Streak broken
        _currentProfile!.currentStreak = 1;
      }
      // Same day - no change
    } else {
      _currentProfile!.currentStreak = 1;
    }

    _currentProfile!.lastActivityDate = now;
    await _saveProfile(_currentProfile!);
  }

  /// Get user's learning style based on performance patterns
  LearningStyle getLearningStyle() {
    if (_currentProfile == null) return LearningStyle.balanced;

    final wordStats = _currentProfile!.wordStats.values.toList();
    if (wordStats.isEmpty) return LearningStyle.balanced;

    // Analyze performance patterns
    final avgResponseTime =
        wordStats.map((s) => s.averageResponseTimeMs).reduce((a, b) => a + b) /
        wordStats.length;

    final accuracy =
        wordStats
            .map(
              (s) => s.totalAttempts > 0
                  ? s.correctAttempts / s.totalAttempts
                  : 0.0,
            )
            .reduce((a, b) => a + b) /
        wordStats.length;

    if (avgResponseTime < 2000 && accuracy > 0.8) {
      return LearningStyle.quickLearner;
    } else if (avgResponseTime > 5000 && accuracy > 0.7) {
      return LearningStyle.deliberate;
    } else if (accuracy < 0.5) {
      return LearningStyle.needsRepetition;
    }

    return LearningStyle.balanced;
  }

  // Private helper methods

  double _calculateMasteryLevel(WordStatistics stats) {
    if (stats.totalAttempts == 0) return 0.0;

    final accuracy = stats.correctAttempts / stats.totalAttempts;
    final recencyBonus = stats.lastAttemptTime != null
        ? (1.0 -
                  (DateTime.now().difference(stats.lastAttemptTime!).inDays /
                      30))
              .clamp(0.0, 0.3)
        : 0.0;
    final streakBonus = (stats.consecutiveCorrect * 0.05).clamp(0.0, 0.2);

    return (accuracy * 0.6 + recencyBonus + streakBonus).clamp(0.0, 1.0);
  }

  bool _isDueForReview(WordStatistics stats) {
    if (stats.lastAttemptTime == null) return false;

    // Spaced repetition intervals based on mastery
    final intervals = [1, 3, 7, 14, 30, 60]; // days
    final intervalIndex = (stats.masteryLevel * 5).floor().clamp(0, 5);
    final interval = intervals[intervalIndex];

    return DateTime.now().difference(stats.lastAttemptTime!).inDays >= interval;
  }

  String _determineFocusArea(UserLearningProfile profile) {
    final weakWords = profile.wordStats.values
        .where((s) => s.masteryLevel < 0.5)
        .toList();

    if (weakWords.isEmpty) return 'advanced';
    if (weakWords.length > 50) return 'basics';
    if (weakWords.length > 20) return 'intermediate';

    return 'consolidation';
  }

  double _calculateRecommendedDifficulty(UserLearningProfile profile) {
    final recentStats = profile.wordStats.values
        .where(
          (s) =>
              s.lastAttemptTime != null &&
              DateTime.now().difference(s.lastAttemptTime!).inDays < 7,
        )
        .toList();

    if (recentStats.isEmpty) return 0.5;

    final avgAccuracy =
        recentStats
            .map(
              (s) => s.totalAttempts > 0
                  ? s.correctAttempts / s.totalAttempts
                  : 0.5,
            )
            .reduce((a, b) => a + b) /
        recentStats.length;

    if (avgAccuracy > 0.85) return 0.7;
    if (avgAccuracy > 0.7) return 0.5;
    if (avgAccuracy > 0.5) return 0.3;

    return 0.2;
  }

  Future<List<VocabWord>> _getMlVocabularyPool(String language) async {
    if (_mlPoolCache.containsKey(language)) {
      return _mlPoolCache[language]!;
    }

    final allWords = <VocabWord>[];
    for (int chapter = 1; chapter <= 15; chapter++) {
      for (int lessonIdx = 0; lessonIdx < 4; lessonIdx++) {
        final predictions = await MLVocabularyService.generateVocabularyWithML(
          chapterId: '${language}_ch$chapter',
          lessonIndex: lessonIdx,
          language: language,
          count: 25,
        );

        for (final p in predictions) {
          allWords.add(
            VocabWord(
              urdu: p.word,
              english: p.translation,
              pronunciation: p.pronunciation,
              exampleSentence: p.example ?? p.word,
              exampleEnglish: p.translation,
            ),
          );
        }
      }
    }

    final dedup = <String, VocabWord>{};
    for (final w in allWords) {
      dedup[w.urdu] = w;
    }

    final result = dedup.values.toList();
    _mlPoolCache[language] = result;
    return result;
  }

  Future<double> _calculateOverallProgress(
    UserLearningProfile profile,
    String language,
  ) async {
    final totalWords = (await _getMlVocabularyPool(language)).length;

    if (totalWords == 0) return 0.0;

    final masteredCount = profile.wordStats.values
        .where((s) => s.masteryLevel >= 0.8)
        .length;

    return masteredCount / totalWords;
  }

  Future<VocabWord?> _findVocabWord(String word, String language) async {
    final allWords = await _getMlVocabularyPool(language);
    for (final vocabWord in allWords) {
      if (vocabWord.urdu == word) return vocabWord;
    }
    return null;
  }

  Future<UserLearningProfile> _loadProfile(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('learning_profile_$userId');

      if (json != null) {
        return UserLearningProfile.fromJson(jsonDecode(json));
      }
    } catch (e) {
      debugPrint('PersonalizationService: Error loading profile: $e');
    }

    return UserLearningProfile(userId: userId);
  }

  Future<void> _saveProfile(UserLearningProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'learning_profile_${profile.userId}',
        jsonEncode(profile.toJson()),
      );
    } catch (e) {
      debugPrint('PersonalizationService: Error saving profile: $e');
    }
  }
}

/// User's learning profile
class UserLearningProfile {
  final String userId;
  final Map<String, WordStatistics> wordStats;
  double currentDifficulty;
  int currentStreak;
  int longestStreak;
  DateTime? lastActivityDate;

  UserLearningProfile({
    required this.userId,
    Map<String, WordStatistics>? wordStats,
    this.currentDifficulty = 0.5,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActivityDate,
  }) : wordStats = wordStats ?? {};

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'wordStats': wordStats.map((k, v) => MapEntry(k, v.toJson())),
    'currentDifficulty': currentDifficulty,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastActivityDate': lastActivityDate?.toIso8601String(),
  };

  factory UserLearningProfile.fromJson(Map<String, dynamic> json) {
    return UserLearningProfile(
      userId: json['userId'],
      wordStats:
          (json['wordStats'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, WordStatistics.fromJson(v)),
          ) ??
          {},
      currentDifficulty: json['currentDifficulty'] ?? 0.5,
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      lastActivityDate: json['lastActivityDate'] != null
          ? DateTime.parse(json['lastActivityDate'])
          : null,
    );
  }
}

/// Statistics for a single word
class WordStatistics {
  final String word;
  int totalAttempts;
  int correctAttempts;
  int consecutiveCorrect;
  int consecutiveWrong;
  double masteryLevel;
  DateTime? lastAttemptTime;
  int averageResponseTimeMs;

  WordStatistics({
    required this.word,
    this.totalAttempts = 0,
    this.correctAttempts = 0,
    this.consecutiveCorrect = 0,
    this.consecutiveWrong = 0,
    this.masteryLevel = 0.0,
    this.lastAttemptTime,
    this.averageResponseTimeMs = 0,
  });

  Map<String, dynamic> toJson() => {
    'word': word,
    'totalAttempts': totalAttempts,
    'correctAttempts': correctAttempts,
    'consecutiveCorrect': consecutiveCorrect,
    'consecutiveWrong': consecutiveWrong,
    'masteryLevel': masteryLevel,
    'lastAttemptTime': lastAttemptTime?.toIso8601String(),
    'averageResponseTimeMs': averageResponseTimeMs,
  };

  factory WordStatistics.fromJson(Map<String, dynamic> json) {
    return WordStatistics(
      word: json['word'],
      totalAttempts: json['totalAttempts'] ?? 0,
      correctAttempts: json['correctAttempts'] ?? 0,
      consecutiveCorrect: json['consecutiveCorrect'] ?? 0,
      consecutiveWrong: json['consecutiveWrong'] ?? 0,
      masteryLevel: json['masteryLevel'] ?? 0.0,
      lastAttemptTime: json['lastAttemptTime'] != null
          ? DateTime.parse(json['lastAttemptTime'])
          : null,
      averageResponseTimeMs: json['averageResponseTimeMs'] ?? 0,
    );
  }
}

/// Personalized recommendations
class PersonalizedRecommendations {
  final List<String> weakWords;
  final List<String> masteredWords;
  final List<String> wordsForReview;
  final List<VocabWord> nextWordsToLearn;
  final String focusArea;
  final double recommendedDifficulty;
  final double overallProgress;
  final int streakDays;
  final int totalWordsLearned;

  PersonalizedRecommendations({
    required this.weakWords,
    required this.masteredWords,
    required this.wordsForReview,
    required this.nextWordsToLearn,
    required this.focusArea,
    required this.recommendedDifficulty,
    required this.overallProgress,
    required this.streakDays,
    required this.totalWordsLearned,
  });

  factory PersonalizedRecommendations.empty() => PersonalizedRecommendations(
    weakWords: [],
    masteredWords: [],
    wordsForReview: [],
    nextWordsToLearn: [],
    focusArea: 'basics',
    recommendedDifficulty: 0.5,
    overallProgress: 0.0,
    streakDays: 0,
    totalWordsLearned: 0,
  );
}

/// Learning path with daily plans
class LearningPath {
  final String language;
  final List<DailyLearningPlan> dailyPlans;
  final int totalDays;
  final List<String> focusAreas;
  final int estimatedWordsToLearn;

  LearningPath({
    required this.language,
    required this.dailyPlans,
    required this.totalDays,
    required this.focusAreas,
    required this.estimatedWordsToLearn,
  });

  factory LearningPath.default_(String language) => LearningPath(
    language: language,
    dailyPlans: [],
    totalDays: 7,
    focusAreas: ['basics'],
    estimatedWordsToLearn: 50,
  );
}

/// Daily learning plan
class DailyLearningPlan {
  final int day;
  final List<LearningActivity> activities;
  final int estimatedMinutes;
  final List<VocabWord> focusWords;

  DailyLearningPlan({
    required this.day,
    required this.activities,
    required this.estimatedMinutes,
    required this.focusWords,
  });
}

/// Learning activity
class LearningActivity {
  final ActivityType type;
  final List<VocabWord> words;
  final int estimatedMinutes;

  LearningActivity({
    required this.type,
    required this.words,
    required this.estimatedMinutes,
  });
}

/// Activity types
enum ActivityType { vocabulary, practiceQuiz, review, listening, speaking }

/// Learning styles
enum LearningStyle { quickLearner, deliberate, needsRepetition, balanced }

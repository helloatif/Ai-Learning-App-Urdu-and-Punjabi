import 'dart:convert';
import 'package:flutter/services.dart';

/// Service to load and manage vocabulary from custom dataset
/// Loads from combined_training_dataset_with_lessons.json
class CustomVocabularyService {
  static Map<String, dynamic>? _cachedDataset;
  static bool _isLoaded = false;

  /// Load the combined dataset
  static Future<Map<String, dynamic>> loadDataset() async {
    if (_isLoaded && _cachedDataset != null) {
      return _cachedDataset!;
    }

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/combined_training_dataset_with_lessons.json',
      );
      _cachedDataset = jsonDecode(jsonString);
      _isLoaded = true;
      print('CustomVocabularyService: Loaded dataset successfully');
      return _cachedDataset!;
    } catch (e) {
      print('CustomVocabularyService: Error loading dataset - $e');
      return _getEmptyDataset();
    }
  }

  /// Get all chapters for a language
  static Future<List<Map<String, dynamic>>> getChapters(String language) async {
    final dataset = await loadDataset();
    final chapters = dataset['chapters']?[language.toLowerCase()] as List?;

    if (chapters == null) return [];

    return chapters.map((c) => c as Map<String, dynamic>).toList();
  }

  /// Get a specific chapter by ID
  static Future<Map<String, dynamic>?> getChapter(
    String language,
    String chapterId,
  ) async {
    final chapters = await getChapters(language);

    try {
      return chapters.firstWhere((c) => c['chapter_id'] == chapterId);
    } catch (e) {
      return null;
    }
  }

  /// Get all lessons for a specific chapter
  static Future<List<Map<String, dynamic>>> getChapterLessons(
    String language,
    String chapterId,
  ) async {
    final chapter = await getChapter(language, chapterId);
    if (chapter == null) return [];

    final lessons = chapter['lessons'] as List?;
    if (lessons == null) return [];

    return lessons.map((l) => l as Map<String, dynamic>).toList();
  }

  /// Get a specific lesson
  static Future<Map<String, dynamic>?> getLesson(
    String language,
    String chapterId,
    int lessonNumber,
  ) async {
    final lessons = await getChapterLessons(language, chapterId);

    try {
      return lessons.firstWhere((l) => l['lesson_number'] == lessonNumber);
    } catch (e) {
      return null;
    }
  }

  /// Get vocabulary for a specific lesson
  static Future<List<Map<String, dynamic>>> getLessonVocabulary(
    String language,
    String chapterId,
    int lessonNumber,
  ) async {
    final lesson = await getLesson(language, chapterId, lessonNumber);
    if (lesson == null) return [];

    final vocab = lesson['vocabulary'] as List?;
    if (vocab == null) return [];

    return vocab.map((v) => v as Map<String, dynamic>).toList();
  }

  /// Get all vocabulary for a chapter (from all lessons)
  static Future<List<Map<String, dynamic>>> getChapterVocabulary(
    String language,
    String chapterId,
  ) async {
    final lessons = await getChapterLessons(language, chapterId);
    final List<Map<String, dynamic>> allVocab = [];

    for (final lesson in lessons) {
      final vocab = lesson['vocabulary'] as List? ?? [];
      allVocab.addAll(vocab.map((v) => v as Map<String, dynamic>));
    }

    return allVocab;
  }

  /// Get MCQ quiz for a chapter
  static Future<List<Map<String, dynamic>>> getChapterMCQ(
    String language,
    String chapterId,
  ) async {
    final chapter = await getChapter(language, chapterId);
    if (chapter == null) return [];

    final mcq = chapter['quiz']?['mcq'] as List?;
    if (mcq == null) return [];

    return mcq.map((q) => q as Map<String, dynamic>).toList();
  }

  /// Get user input quiz for a chapter
  static Future<List<Map<String, dynamic>>> getChapterUserInputQuiz(
    String language,
    String chapterId,
  ) async {
    final chapter = await getChapter(language, chapterId);
    if (chapter == null) return [];

    final userInput = chapter['quiz']?['user_input'] as List?;
    if (userInput == null) return [];

    return userInput.map((q) => q as Map<String, dynamic>).toList();
  }

  /// Get all vocabulary pairs for training/lookup
  static Future<List<Map<String, dynamic>>> getAllVocabularyPairs() async {
    final dataset = await loadDataset();
    final pairs = dataset['training_data']?['vocabulary_pairs'] as List?;

    if (pairs == null) return [];

    return pairs.map((p) => p as Map<String, dynamic>).toList();
  }

  /// Get vocabulary by word (for lookup)
  static Future<Map<String, dynamic>?> lookupWord(String word) async {
    final pairs = await getAllVocabularyPairs();

    try {
      return pairs.firstWhere(
        (p) => p['source_text'] == word || p['target_text'] == word,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get chapter list with summary info (with lessons)
  static Future<List<Map<String, dynamic>>> getChapterSummaries(
    String language,
  ) async {
    final chapters = await getChapters(language);

    return chapters.map((c) {
      final lessons = c['lessons'] as List? ?? [];
      final mcq = c['quiz']?['mcq'] as List? ?? [];
      final userInput = c['quiz']?['user_input'] as List? ?? [];

      // Count total vocabulary from all lessons
      int totalVocab = 0;
      for (final lesson in lessons) {
        final vocab = lesson['vocabulary'] as List? ?? [];
        totalVocab += vocab.length;
      }

      return {
        'chapter_id': c['chapter_id'],
        'chapter_name': c['chapter_name'],
        'chapter_name_native': language.toLowerCase() == 'urdu'
            ? c['chapter_name_urdu']
            : c['chapter_name_punjabi'],
        'description': c['description'],
        'lesson_count': lessons.length,
        'vocabulary_count': totalVocab,
        'mcq_count': mcq.length,
        'user_input_count': userInput.length,
        'total_quiz_count': mcq.length + userInput.length,
      };
    }).toList();
  }

  /// Get dataset statistics
  static Future<Map<String, dynamic>> getStatistics() async {
    final dataset = await loadDataset();
    return dataset['statistics'] ?? {};
  }

  /// Get metadata
  static Future<Map<String, dynamic>> getMetadata() async {
    final dataset = await loadDataset();
    return dataset['metadata'] ?? {};
  }

  /// Search vocabulary
  static Future<List<Map<String, dynamic>>> searchVocabulary(
    String query, {
    String? language,
  }) async {
    final pairs = await getAllVocabularyPairs();
    final queryLower = query.toLowerCase();

    return pairs.where((p) {
      if (language != null && p['language'] != language.toLowerCase()) {
        return false;
      }

      final sourceText = (p['source_text'] ?? '').toString().toLowerCase();
      final targetText = (p['target_text'] ?? '').toString().toLowerCase();
      final pronunciation = (p['pronunciation'] ?? '').toString().toLowerCase();

      return sourceText.contains(queryLower) ||
          targetText.contains(queryLower) ||
          pronunciation.contains(queryLower);
    }).toList();
  }

  /// Get vocabulary by difficulty
  static Future<List<Map<String, dynamic>>> getVocabularyByDifficulty(
    String language,
    String difficulty, // 'easy', 'medium', 'hard'
  ) async {
    final chapters = await getChapters(language);
    final List<Map<String, dynamic>> result = [];

    for (final chapter in chapters) {
      final vocab = chapter['vocabulary'] as List? ?? [];
      for (final v in vocab) {
        if (v['difficulty'] == difficulty) {
          result.add({
            ...v as Map<String, dynamic>,
            'chapter_id': chapter['chapter_id'],
            'chapter_name': chapter['chapter_name'],
          });
        }
      }
    }

    return result;
  }

  /// Get random quiz question (MCQ or user input)
  static Future<Map<String, dynamic>?> getRandomQuizQuestion(
    String language, {
    String? quizType, // 'mcq' or 'user_input'
  }) async {
    final chapters = await getChapters(language);
    if (chapters.isEmpty) return null;

    // Get random chapter
    final chapter = chapters[DateTime.now().millisecond % chapters.length];

    if (quizType == 'mcq' || quizType == null) {
      final mcq = chapter['quiz']?['mcq'] as List? ?? [];
      if (mcq.isNotEmpty) {
        final question = mcq[DateTime.now().microsecond % mcq.length];
        return {
          ...question as Map<String, dynamic>,
          'type': 'mcq',
          'chapter_id': chapter['chapter_id'],
        };
      }
    }

    if (quizType == 'user_input' || quizType == null) {
      final userInput = chapter['quiz']?['user_input'] as List? ?? [];
      if (userInput.isNotEmpty) {
        final question =
            userInput[DateTime.now().microsecond % userInput.length];
        return {
          ...question as Map<String, dynamic>,
          'type': 'user_input',
          'chapter_id': chapter['chapter_id'],
        };
      }
    }

    return null;
  }

  /// Get empty dataset structure (fallback)
  static Map<String, dynamic> _getEmptyDataset() {
    return {
      'metadata': {
        'name': 'Empty Dataset',
        'version': '0.0.0',
        'languages': ['urdu', 'punjabi'],
      },
      'chapters': {'urdu': [], 'punjabi': []},
      'training_data': {
        'vocabulary_pairs': [],
        'quiz_mcq': [],
        'quiz_user_input': [],
        'grammar_examples': [],
      },
      'statistics': {
        'total_urdu_chapters': 0,
        'total_punjabi_chapters': 0,
        'total_vocabulary_pairs': 0,
      },
    };
  }
}

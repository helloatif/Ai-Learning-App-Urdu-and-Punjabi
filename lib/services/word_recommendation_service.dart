import 'package:flutter/foundation.dart';
import 'embedding_cache_service.dart';
import 'ml_vocabulary_service.dart';
import '../data/vocabulary_data.dart';

/// Service for recommending related words using semantic similarity
/// Powers "Related Words" feature and personalized learning paths
class WordRecommendationService {
  // Singleton pattern
  static final WordRecommendationService _instance =
      WordRecommendationService._internal();
  factory WordRecommendationService() => _instance;
  WordRecommendationService._internal();

  final EmbeddingCacheService _embeddingService = EmbeddingCacheService();
  final Map<String, List<VocabWord>> _mlPoolCache = {};

  Future<List<VocabWord>> _getMlVocabularyPool(String language) async {
    if (_mlPoolCache.containsKey(language)) {
      return _mlPoolCache[language]!;
    }

    final allWords = <VocabWord>[];
    for (int chapter = 1; chapter <= 15; chapter++) {
      for (int lessonIdx = 0; lessonIdx < 4; lessonIdx++) {
        final chapterId = '${language}_ch$chapter';
        final predictions = await MLVocabularyService.generateVocabularyWithML(
          chapterId: chapterId,
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

    // Deduplicate by script word for stable recommendation behavior.
    final dedup = <String, VocabWord>{};
    for (final w in allWords) {
      dedup[w.urdu] = w;
    }

    final result = dedup.values.toList();
    _mlPoolCache[language] = result;
    return result;
  }

  /// Find semantically similar words from vocabulary
  Future<List<WordRecommendation>> findSimilarWords({
    required String word,
    required String language,
    int count = 5,
    double minSimilarity = 0.3,
  }) async {
    try {
      final allWords = await _getMlVocabularyPool(language);

      // Find similar words using embeddings
      final candidateWords = allWords.map((w) => w.urdu).toList();

      final similarResults = await _embeddingService.findMostSimilar(
        targetWord: word,
        candidateWords: candidateWords,
        topK: count,
        minSimilarity: minSimilarity,
      );

      // Map results back to VocabWord objects
      final recommendations = <WordRecommendation>[];
      for (final result in similarResults) {
        final vocabWord = allWords.firstWhere(
          (w) => w.urdu == result.word,
          orElse: () =>
              VocabWord(urdu: result.word, english: '', pronunciation: ''),
        );

        recommendations.add(
          WordRecommendation(
            word: vocabWord,
            similarity: result.similarity,
            reason: _getRecommendationReason(result.similarity),
          ),
        );
      }

      return recommendations;
    } catch (e) {
      debugPrint('WordRecommendationService: Error finding similar words: $e');
      return [];
    }
  }

  /// Find words user should learn next based on their mastered words
  Future<List<VocabWord>> getNextWordsToLearn({
    required List<String> masteredWords,
    required String language,
    int count = 10,
  }) async {
    try {
      final allWords = await _getMlVocabularyPool(language);

      if (masteredWords.isEmpty) {
        return allWords.take(count).toList();
      }

      // Filter out already mastered words
      final unlearnedWords = allWords
          .where((w) => !masteredWords.contains(w.urdu))
          .toList();

      if (unlearnedWords.isEmpty) {
        return [];
      }

      // Find words similar to mastered content (progressive learning)
      final recommendations = <VocabWord>[];
      final processedWords = <String>{};

      for (final masteredWord in masteredWords.take(10)) {
        final similar = await _embeddingService.findWordsInSimilarityRange(
          targetWord: masteredWord,
          candidateWords: unlearnedWords.map((w) => w.urdu).toList(),
          minSimilarity: 0.4,
          maxSimilarity: 0.85,
          count: 3,
        );

        for (final result in similar) {
          if (!processedWords.contains(result.word)) {
            final vocabWord = unlearnedWords.firstWhere(
              (w) => w.urdu == result.word,
            );
            recommendations.add(vocabWord);
            processedWords.add(result.word);
          }
        }

        if (recommendations.length >= count) break;
      }

      return recommendations.take(count).toList();
    } catch (e) {
      debugPrint('WordRecommendationService: Error getting next words: $e');
      return [];
    }
  }

  /// Get word clusters (groups of semantically related words)
  Future<List<WordCluster>> getWordClusters({
    required String language,
    int clusterCount = 5,
    int wordsPerCluster = 10,
  }) async {
    try {
      final allWords = await _getMlVocabularyPool(language);
      final clusters = <WordCluster>[];

      for (int i = 0; i < clusterCount; i++) {
        final start = i * wordsPerCluster;
        if (start >= allWords.length) break;
        final end = (start + wordsPerCluster) > allWords.length
            ? allWords.length
            : (start + wordsPerCluster);
        final chunk = allWords.sublist(start, end);

        clusters.add(
          WordCluster(
            name: 'ML Cluster ${i + 1}',
            words: chunk,
            category: 'ml-generated',
          ),
        );
      }

      return clusters;
    } catch (e) {
      debugPrint('WordRecommendationService: Error getting clusters: $e');
      return [];
    }
  }

  /// Get confusable words (for generating quiz distractors)
  Future<List<String>> getConfusableWords({
    required String correctWord,
    required String language,
    int count = 3,
  }) async {
    try {
      final allWords = (await _getMlVocabularyPool(
        language,
      )).map((w) => w.urdu).toList();

      // Find words in the "confusable" similarity range
      final confusable = await _embeddingService.findWordsInSimilarityRange(
        targetWord: correctWord,
        candidateWords: allWords,
        minSimilarity: 0.35,
        maxSimilarity: 0.75,
        count: count,
      );

      return confusable.map((r) => r.word).toList();
    } catch (e) {
      debugPrint(
        'WordRecommendationService: Error getting confusable words: $e',
      );
      return [];
    }
  }

  /// Get opposite/contrasting words
  Future<List<WordRecommendation>> getContrastingWords({
    required String word,
    required String language,
    int count = 3,
  }) async {
    // For now, use low similarity as a proxy for contrasting
    // In production, you'd train a model specifically for antonyms
    try {
      final allWords = await _getMlVocabularyPool(language);

      final candidateWords = allWords.map((w) => w.urdu).toList();

      // Find words with low similarity (potentially contrasting)
      final targetEmbedding = await _embeddingService.getEmbeddings(word);
      if (targetEmbedding.isEmpty) return [];

      final results = <WordRecommendation>[];

      for (final candidate in candidateWords) {
        if (candidate == word) continue;

        final similarity = await _embeddingService.calculateSimilarity(
          word,
          candidate,
        );

        // Low similarity might indicate contrasting meaning
        if (similarity > 0.1 && similarity < 0.3) {
          final vocabWord = allWords.firstWhere((w) => w.urdu == candidate);
          results.add(
            WordRecommendation(
              word: vocabWord,
              similarity: 1.0 - similarity, // Invert for "contrast score"
              reason: 'Contrasting word',
            ),
          );
        }

        if (results.length >= count * 2) break;
      }

      results.shuffle();
      return results.take(count).toList();
    } catch (e) {
      debugPrint(
        'WordRecommendationService: Error getting contrasting words: $e',
      );
      return [];
    }
  }

  /// Preload embeddings for frequently used words
  Future<void> preloadCommonEmbeddings(String language) async {
    final commonWords = (await _getMlVocabularyPool(
      language,
    )).take(100).map((w) => w.urdu).toList();

    await _embeddingService.precomputeEmbeddings(commonWords);
  }

  String _getRecommendationReason(double similarity) {
    if (similarity > 0.8) {
      return 'Very similar meaning';
    } else if (similarity > 0.6) {
      return 'Related concept';
    } else if (similarity > 0.4) {
      return 'Same category';
    } else {
      return 'Loosely related';
    }
  }

  String _categorizeLesson(String lessonTitle) {
    final title = lessonTitle.toLowerCase();

    if (title.contains('emotion') || title.contains('feeling')) {
      return 'emotions';
    } else if (title.contains('sport') || title.contains('game')) {
      return 'sports';
    } else if (title.contains('animal') || title.contains('pet')) {
      return 'animals';
    } else if (title.contains('shop') || title.contains('market')) {
      return 'shopping';
    } else if (title.contains('home') || title.contains('furniture')) {
      return 'home';
    } else if (title.contains('food') || title.contains('drink')) {
      return 'food';
    } else if (title.contains('travel') || title.contains('transport')) {
      return 'travel';
    } else if (title.contains('health') || title.contains('body')) {
      return 'health';
    } else {
      return 'general';
    }
  }
}

/// Word recommendation with similarity score and reason
class WordRecommendation {
  final VocabWord word;
  final double similarity;
  final String reason;

  WordRecommendation({
    required this.word,
    required this.similarity,
    required this.reason,
  });

  @override
  String toString() =>
      'WordRecommendation('
      'word: ${word.urdu}, '
      'english: ${word.english}, '
      'similarity: ${(similarity * 100).toStringAsFixed(0)}%, '
      'reason: $reason)';
}

/// Cluster of related words
class WordCluster {
  final String name;
  final List<VocabWord> words;
  final String category;

  WordCluster({
    required this.name,
    required this.words,
    required this.category,
  });
}

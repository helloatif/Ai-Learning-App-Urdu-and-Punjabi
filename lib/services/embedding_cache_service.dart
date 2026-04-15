import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'ai_language_service.dart';

/// Service for caching embeddings to avoid repeated API calls
/// Uses LRU eviction for memory management
class EmbeddingCacheService {
  // Singleton pattern
  static final EmbeddingCacheService _instance =
      EmbeddingCacheService._internal();
  factory EmbeddingCacheService() => _instance;
  EmbeddingCacheService._internal();

  // LRU cache with max size
  static const int _maxCacheSize = 2000;
  final LinkedHashMap<String, List<double>> _cache = LinkedHashMap();

  // Track API calls for analytics
  int _cacheHits = 0;
  int _cacheMisses = 0;
  bool _isPrecomputing = false;

  /// Get embeddings with caching
  /// Returns cached embeddings if available, otherwise fetches from API
  Future<List<double>> getEmbeddings(String text) async {
    final cacheKey = _generateCacheKey(text);

    // Check cache first
    if (_cache.containsKey(cacheKey)) {
      _cacheHits++;
      // Move to end for LRU
      final value = _cache.remove(cacheKey)!;
      _cache[cacheKey] = value;
      return value;
    }

    _cacheMisses++;

    // Fetch from API
    try {
      final embeddings = await AILanguageService.getEmbeddings(text);

      if (embeddings.isNotEmpty) {
        _addToCache(cacheKey, embeddings);
      }

      return embeddings;
    } catch (e) {
      debugPrint('EmbeddingCacheService: Error getting embeddings: $e');
      return [];
    }
  }

  /// Calculate similarity between two texts using cached embeddings
  Future<double> calculateSimilarity(String text1, String text2) async {
    final embeddings1 = await getEmbeddings(text1);
    final embeddings2 = await getEmbeddings(text2);

    if (embeddings1.isEmpty || embeddings2.isEmpty) {
      // Fallback to string similarity
      return _fallbackStringSimilarity(text1, text2);
    }

    return _cosineSimilarity(embeddings1, embeddings2);
  }

  /// Calculate cosine similarity between two embedding vectors
  double _cosineSimilarity(List<double> vec1, List<double> vec2) {
    if (vec1.length != vec2.length || vec1.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < vec1.length; i++) {
      dotProduct += vec1[i] * vec2[i];
      norm1 += vec1[i] * vec1[i];
      norm2 += vec2[i] * vec2[i];
    }

    final magnitude = _sqrt(norm1) * _sqrt(norm2);
    if (magnitude == 0) return 0.0;

    return dotProduct / magnitude;
  }

  /// Precompute embeddings for a list of words in background
  /// Useful for preloading vocabulary embeddings
  Future<void> precomputeEmbeddings(
    List<String> words, {
    Duration delayBetweenCalls = const Duration(milliseconds: 100),
    Function(int current, int total)? onProgress,
  }) async {
    if (_isPrecomputing) {
      debugPrint('EmbeddingCacheService: Already precomputing');
      return;
    }

    _isPrecomputing = true;

    try {
      for (int i = 0; i < words.length; i++) {
        final word = words[i];

        // Skip if already cached
        if (_cache.containsKey(_generateCacheKey(word))) {
          continue;
        }

        await getEmbeddings(word);
        onProgress?.call(i + 1, words.length);

        // Rate limiting to avoid API throttling
        if (i < words.length - 1) {
          await Future.delayed(delayBetweenCalls);
        }
      }
    } finally {
      _isPrecomputing = false;
    }
  }

  /// Find most similar words from a list
  Future<List<SimilarWordResult>> findMostSimilar({
    required String targetWord,
    required List<String> candidateWords,
    int topK = 5,
    double minSimilarity = 0.3,
  }) async {
    final targetEmbedding = await getEmbeddings(targetWord);

    if (targetEmbedding.isEmpty) {
      return [];
    }

    final results = <SimilarWordResult>[];

    for (final candidate in candidateWords) {
      if (candidate == targetWord) continue;

      final candidateEmbedding = await getEmbeddings(candidate);

      if (candidateEmbedding.isEmpty) continue;

      final similarity = _cosineSimilarity(targetEmbedding, candidateEmbedding);

      if (similarity >= minSimilarity) {
        results.add(SimilarWordResult(word: candidate, similarity: similarity));
      }
    }

    // Sort by similarity descending
    results.sort((a, b) => b.similarity.compareTo(a.similarity));

    return results.take(topK).toList();
  }

  /// Find words in a specific similarity range (useful for quiz distractors)
  Future<List<SimilarWordResult>> findWordsInSimilarityRange({
    required String targetWord,
    required List<String> candidateWords,
    double minSimilarity = 0.4,
    double maxSimilarity = 0.8,
    int count = 3,
  }) async {
    final targetEmbedding = await getEmbeddings(targetWord);

    if (targetEmbedding.isEmpty) {
      return [];
    }

    final results = <SimilarWordResult>[];

    for (final candidate in candidateWords) {
      if (candidate == targetWord) continue;

      final candidateEmbedding = await getEmbeddings(candidate);

      if (candidateEmbedding.isEmpty) continue;

      final similarity = _cosineSimilarity(targetEmbedding, candidateEmbedding);

      // Only include words in the "confusable" range
      if (similarity >= minSimilarity && similarity <= maxSimilarity) {
        results.add(SimilarWordResult(word: candidate, similarity: similarity));
      }
    }

    // Shuffle and take requested count
    results.shuffle();
    return results.take(count).toList();
  }

  /// Get cache statistics
  CacheStats getStats() {
    return CacheStats(
      cacheSize: _cache.length,
      maxCacheSize: _maxCacheSize,
      cacheHits: _cacheHits,
      cacheMisses: _cacheMisses,
      hitRate: _cacheHits + _cacheMisses > 0
          ? _cacheHits / (_cacheHits + _cacheMisses)
          : 0.0,
    );
  }

  /// Clear the cache
  void clearCache() {
    _cache.clear();
    _cacheHits = 0;
    _cacheMisses = 0;
  }

  // Private helper methods

  String _generateCacheKey(String text) {
    // Normalize text for consistent caching
    return text.trim().toLowerCase();
  }

  void _addToCache(String key, List<double> value) {
    // LRU eviction if cache is full
    while (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    double lastGuess = 0;
    while ((guess - lastGuess).abs() > 0.0001) {
      lastGuess = guess;
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  /// Fallback string similarity using Levenshtein distance
  double _fallbackStringSimilarity(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    if (s1 == s2) return 1.0;

    final maxLen = s1.length > s2.length ? s1.length : s2.length;
    final distance = _levenshteinDistance(s1, s2);

    return 1.0 - (distance / maxLen);
  }

  int _levenshteinDistance(String s1, String s2) {
    final m = s1.length;
    final n = s2.length;

    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return dp[m][n];
  }
}

/// Result class for similar word searches
class SimilarWordResult {
  final String word;
  final double similarity;

  SimilarWordResult({required this.word, required this.similarity});

  @override
  String toString() =>
      'SimilarWordResult(word: $word, similarity: ${(similarity * 100).toStringAsFixed(1)}%)';
}

/// Cache statistics class
class CacheStats {
  final int cacheSize;
  final int maxCacheSize;
  final int cacheHits;
  final int cacheMisses;
  final double hitRate;

  CacheStats({
    required this.cacheSize,
    required this.maxCacheSize,
    required this.cacheHits,
    required this.cacheMisses,
    required this.hitRate,
  });

  @override
  String toString() =>
      'CacheStats(size: $cacheSize/$maxCacheSize, hits: $cacheHits, misses: $cacheMisses, hitRate: ${(hitRate * 100).toStringAsFixed(1)}%)';
}

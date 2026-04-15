import 'package:flutter/foundation.dart';
import 'ai_language_service.dart';

/// Unified translation service using mBART-50 model
/// Supports Urdu ↔ Punjabi ↔ English translations
class TranslationService {
  // Singleton pattern
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  // Cache for recent translations
  final Map<String, TranslationResult> _cache = {};
  static const int _maxCacheSize = 500;

  /// Translate text between Urdu, Punjabi, and English
  Future<TranslationResult> translate({
    required String text,
    required String from,
    required String to,
  }) async {
    // Check cache first
    final cacheKey = _getCacheKey(text, from, to);
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      // Primary: Use mBART model via AILanguageService
      final translated = await AILanguageService.translateText(
        text: text,
        sourceLanguage: from,
        targetLanguage: to,
      );

      final result = TranslationResult(
        originalText: text,
        translatedText: translated,
        sourceLanguage: from,
        targetLanguage: to,
        confidence: translated != text ? 0.9 : 0.5,
        source: TranslationSource.mbart,
      );

      _addToCache(cacheKey, result);
      return result;
    } catch (e) {
      debugPrint('TranslationService: Primary translation failed: $e');

      // Fallback: Use offline dictionary
      final offlineResult = OfflineTranslationService.translate(text, from, to);

      final result = TranslationResult(
        originalText: text,
        translatedText: offlineResult ?? text,
        sourceLanguage: from,
        targetLanguage: to,
        confidence: offlineResult != null ? 0.7 : 0.0,
        source: offlineResult != null
            ? TranslationSource.offline
            : TranslationSource.failed,
      );

      if (offlineResult != null) {
        _addToCache(cacheKey, result);
      }

      return result;
    }
  }

  /// Batch translate multiple texts
  Future<List<TranslationResult>> translateBatch(
    List<String> texts,
    String from,
    String to, {
    Duration delayBetweenCalls = const Duration(milliseconds: 50),
  }) async {
    final results = <TranslationResult>[];

    for (int i = 0; i < texts.length; i++) {
      final result = await translate(text: texts[i], from: from, to: to);
      results.add(result);

      // Rate limiting
      if (i < texts.length - 1) {
        await Future.delayed(delayBetweenCalls);
      }
    }

    return results;
  }

  /// Detect language automatically and translate to target
  Future<TranslationResult> autoTranslate({
    required String text,
    required String targetLanguage,
  }) async {
    // Detect source language
    final detectedLanguage = _detectLanguage(text);

    if (detectedLanguage == targetLanguage) {
      return TranslationResult(
        originalText: text,
        translatedText: text,
        sourceLanguage: detectedLanguage,
        targetLanguage: targetLanguage,
        confidence: 1.0,
        source: TranslationSource.noTranslationNeeded,
      );
    }

    return translate(text: text, from: detectedLanguage, to: targetLanguage);
  }

  /// Get reverse translation (useful for verification)
  Future<TranslationVerification> verifyTranslation({
    required String originalText,
    required String translatedText,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    // Translate back to original language
    final backTranslation = await translate(
      text: translatedText,
      from: targetLanguage,
      to: sourceLanguage,
    );

    // Calculate similarity between original and back-translated text
    final similarity = _calculateSimpleSimilarity(
      originalText,
      backTranslation.translatedText,
    );

    return TranslationVerification(
      originalText: originalText,
      translatedText: translatedText,
      backTranslatedText: backTranslation.translatedText,
      verificationScore: similarity,
      isReliable: similarity > 0.7,
    );
  }

  /// Get pronunciation guide for translated text
  String getPronunciationGuide(String text, String language) {
    // Basic romanization rules for Urdu/Punjabi
    final Map<String, String> romanizationMap = {
      'ا': 'a',
      'آ': 'aa',
      'ب': 'b',
      'پ': 'p',
      'ت': 't',
      'ٹ': 't',
      'ث': 's',
      'ج': 'j',
      'چ': 'ch',
      'ح': 'h',
      'خ': 'kh',
      'د': 'd',
      'ڈ': 'd',
      'ذ': 'z',
      'ر': 'r',
      'ڑ': 'r',
      'ز': 'z',
      'ژ': 'zh',
      'س': 's',
      'ش': 'sh',
      'ص': 's',
      'ض': 'z',
      'ط': 't',
      'ظ': 'z',
      'ع': 'a',
      'غ': 'gh',
      'ف': 'f',
      'ق': 'q',
      'ک': 'k',
      'گ': 'g',
      'ل': 'l',
      'م': 'm',
      'ن': 'n',
      'ں': 'n',
      'و': 'w',
      'ہ': 'h',
      'ھ': 'h',
      'ی': 'y',
      'ے': 'e',
      'ئ': 'i',
      'ؤ': 'o',
      'ء': '',
    };

    final buffer = StringBuffer();
    for (final char in text.split('')) {
      buffer.write(romanizationMap[char] ?? char);
    }

    return buffer.toString();
  }

  /// Clear translation cache
  void clearCache() {
    _cache.clear();
  }

  // Private helper methods

  String _getCacheKey(String text, String from, String to) {
    return '${from}_${to}_${text.hashCode}';
  }

  void _addToCache(String key, TranslationResult result) {
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entry
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = result;
  }

  /// Simple language detection based on character patterns
  String _detectLanguage(String text) {
    // Check for English characters
    final englishPattern = RegExp(r'[a-zA-Z]');
    final englishCount = englishPattern.allMatches(text).length;

    // Check for Urdu/Punjabi characters
    final urduPattern = RegExp(r'[\u0600-\u06FF]');
    final urduCount = urduPattern.allMatches(text).length;

    if (englishCount > urduCount) {
      return 'english';
    }

    // Distinguish Urdu from Punjabi using specific markers
    // Punjabi often uses: ਰ (ڑ), ਟ (ٹ), specific verb endings
    final punjabiMarkers = ['نئیں', 'ہاں', 'اے', 'دا', 'دی', 'دے'];
    for (final marker in punjabiMarkers) {
      if (text.contains(marker)) {
        return 'punjabi';
      }
    }

    return 'urdu';
  }

  double _calculateSimpleSimilarity(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    if (s1 == s2) return 1.0;

    final words1 = s1.split(' ').toSet();
    final words2 = s2.split(' ').toSet();

    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;

    return union > 0 ? intersection / union : 0.0;
  }
}

/// Translation result class
class TranslationResult {
  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final double confidence;
  final TranslationSource source;

  TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.confidence,
    required this.source,
  });

  bool get isSuccessful => source != TranslationSource.failed;

  @override
  String toString() =>
      'TranslationResult('
      'from: $sourceLanguage, to: $targetLanguage, '
      'confidence: ${(confidence * 100).toStringAsFixed(0)}%, '
      'source: ${source.name})';
}

/// Translation verification result
class TranslationVerification {
  final String originalText;
  final String translatedText;
  final String backTranslatedText;
  final double verificationScore;
  final bool isReliable;

  TranslationVerification({
    required this.originalText,
    required this.translatedText,
    required this.backTranslatedText,
    required this.verificationScore,
    required this.isReliable,
  });
}

/// Source of translation
enum TranslationSource { mbart, offline, failed, noTranslationNeeded }

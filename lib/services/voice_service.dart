import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';
import 'ai_language_service.dart';

/// Service for Text-to-Speech and Speech-to-Text
class VoiceService {
  static final FlutterTts _flutterTts = FlutterTts();
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static bool _isInitialized = false;
  static final Map<String, String> _ttsLocaleCache = {};
  static final Map<String, Map<String, String>> _ttsVoiceCache = {};

  /// Initialize TTS and STT
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize TTS
      await _flutterTts.setLanguage('ur-PK');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.awaitSpeakCompletion(true);

      // Initialize STT
      _isInitialized = await _speech.initialize(
        onError: (error) => debugPrint('STT Error: $error'),
        onStatus: (status) => debugPrint('STT Status: $status'),
      );

      debugPrint('Voice Service initialized: $_isInitialized');
    } catch (e) {
      debugPrint('Voice Service initialization error: $e');
    }
  }

  /// Speak text in specified language
  static Future<void> speak(String text, String language) async {
    try {
      // Auto-initialize if not already done
      if (!_isInitialized) {
        await initialize();
      }
      
      await _configureTtsForLanguage(language);
      await _flutterTts.setSpeechRate(0.4); // Slower for learning
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  /// Stop speaking
  static Future<void> stop() async {
    await _flutterTts.stop();
  }

  /// Listen to user speech
  static Future<String?> listen({
    required String language,
    required Function(String) onResult,
    required Function() onStart,
    required Function() onStop,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_speech.isAvailable) {
      debugPrint('Speech recognition not available');
      return null;
    }

    String? recognizedText;

    final localeId = await _resolveBestLocale(language);

    await _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords.trim();
        if (words.isNotEmpty) {
          recognizedText = words;
          onResult(words);
        }
      },
      localeId: localeId,
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      pauseFor: const Duration(seconds: 2),
      listenFor: const Duration(seconds: 12),
      cancelOnError: true,
    );

    onStart();

    // Poll until the recognizer stops naturally or timeout reached.
    var waitedMs = 0;
    while (_speech.isListening && waitedMs < 13000) {
      await Future.delayed(const Duration(milliseconds: 250));
      waitedMs += 250;
    }

    if (_speech.isListening) {
      await _speech.stop();
    }
    onStop();

    return recognizedText;
  }

  /// Check if currently listening
  static bool get isListening => _speech.isListening;

  /// Get available languages for STT
  static Future<List<String>> getAvailableLanguages() async {
    final locales = await _speech.locales();
    return locales.map((locale) => locale.name).toList();
  }

  /// Set speech rate (0.0 to 1.0)
  static Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  /// Set volume (0.0 to 1.0)
  static Future<void> setVolume(double volume) async {
    await _flutterTts.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Get TTS language code
  static String _getLanguageCode(String language) {
    switch (_normalizeLanguage(language)) {
      case 'urdu':
        return 'ur-PK';
      case 'punjabi':
        // Prefer Punjabi voices when available, fallback to Urdu for Shahmukhi.
        return 'pa-PK';
      case 'english':
        return 'en-US';
      default:
        return 'ur-PK';
    }
  }

  /// Get STT locale ID
  static String _getLocaleId(String language) {
    switch (_normalizeLanguage(language)) {
      case 'urdu':
        return 'ur_PK';
      case 'punjabi':
        // Use Urdu locale for Shahmukhi Punjabi speech recognition
        return 'ur_PK';
      case 'english':
        return 'en_US';
      default:
        return 'en_US';
    }
  }

  static Future<String> _resolveBestLocale(String language) async {
    final preferred = _getLocaleId(language);

    try {
      final locales = await _speech.locales();
      if (locales.any((l) => l.localeId == preferred)) {
        return preferred;
      }

      // Fallbacks for Urdu/Punjabi speech if the exact locale is unavailable.
      if (language.toLowerCase() == 'urdu' ||
          language.toLowerCase() == 'punjabi') {
        const candidates = ['ur_PK', 'ur_IN', 'hi_IN', 'en_US'];
        for (final candidate in candidates) {
          if (locales.any((l) => l.localeId == candidate)) {
            return candidate;
          }
        }
      }

      if (locales.isNotEmpty) {
        return locales.first.localeId;
      }
    } catch (e) {
      debugPrint('STT locale resolution error: $e');
    }

    return preferred;
  }

  static String _normalizeLanguage(String language) {
    final value = language.trim().toLowerCase();
    if (value.contains('urdu') || value.startsWith('ur')) return 'urdu';
    if (value.contains('punjabi') || value.startsWith('pa')) return 'punjabi';
    if (value.contains('english') || value.startsWith('en')) return 'english';
    return 'urdu';
  }

  static List<String> _preferredTtsLocales(String language) {
    switch (_normalizeLanguage(language)) {
      case 'urdu':
        return const ['ur-PK', 'ur-IN', 'pa-PK', 'pa-IN', 'hi-IN', 'en-US'];
      case 'punjabi':
        return const ['pa-PK', 'pa-IN', 'ur-PK', 'ur-IN', 'hi-IN', 'en-US'];
      case 'english':
        return const ['en-US', 'en-GB'];
      default:
        return const ['ur-PK', 'en-US'];
    }
  }

  static Future<void> _configureTtsForLanguage(String language) async {
    final normalized = _normalizeLanguage(language);

    if (_ttsLocaleCache.containsKey(normalized)) {
      await _flutterTts.setLanguage(_ttsLocaleCache[normalized]!);
      final cachedVoice = _ttsVoiceCache[normalized];
      if (cachedVoice != null) {
        await _flutterTts.setVoice(cachedVoice);
      }
      return;
    }

    final preferred = _preferredTtsLocales(normalized);
    final availableLanguages = await _safeGetLanguages();
    final matchedLocale = _pickBestLocale(availableLanguages, preferred);
    await _flutterTts.setLanguage(matchedLocale);

    final voice = await _pickBestVoice(preferred);
    if (voice != null) {
      await _flutterTts.setVoice(voice);
      _ttsVoiceCache[normalized] = voice;
      debugPrint('TTS voice selected for $normalized: ${voice['name']} (${voice['locale']})');
    }

    _ttsLocaleCache[normalized] = matchedLocale;
    debugPrint('TTS locale selected for $normalized: $matchedLocale');
  }

  static Future<List<String>> _safeGetLanguages() async {
    try {
      final raw = await _flutterTts.getLanguages;
      if (raw is List) {
        return raw
            .whereType<String>()
            .map((e) => e.replaceAll('_', '-'))
            .toList();
      }
    } catch (e) {
      debugPrint('TTS getLanguages error: $e');
    }
    return const [];
  }

  static String _pickBestLocale(List<String> available, List<String> preferred) {
    if (available.isEmpty) return preferred.first;

    for (final candidate in preferred) {
      if (available.any((item) => item.toLowerCase() == candidate.toLowerCase())) {
        return candidate;
      }
    }

    // Script/region-flexible match, e.g. ur-XX or pa-XX.
    for (final candidate in preferred) {
      final base = candidate.split('-').first.toLowerCase();
      final match = available.firstWhere(
        (item) => item.toLowerCase().startsWith('$base-') || item.toLowerCase() == base,
        orElse: () => '',
      );
      if (match.isNotEmpty) {
        return match;
      }
    }

    return available.first;
  }

  static Future<Map<String, String>?> _pickBestVoice(List<String> preferredLocales) async {
    try {
      final rawVoices = await _flutterTts.getVoices;
      if (rawVoices is! List || rawVoices.isEmpty) {
        return null;
      }

      final parsedVoices = rawVoices
          .whereType<Map>()
          .map((voice) {
            final locale = (voice['locale']?.toString() ?? '').replaceAll('_', '-');
            final name = voice['name']?.toString() ?? '';
            return {'name': name, 'locale': locale};
          })
          .where((voice) => voice['name']!.isNotEmpty && voice['locale']!.isNotEmpty)
          .toList();

      for (final locale in preferredLocales) {
        final exact = parsedVoices.firstWhere(
          (voice) => voice['locale']!.toLowerCase() == locale.toLowerCase(),
          orElse: () => const {'name': '', 'locale': ''},
        );
        if (exact['name']!.isNotEmpty) {
          return exact;
        }
      }

      for (final locale in preferredLocales) {
        final base = locale.split('-').first.toLowerCase();
        final byBase = parsedVoices.firstWhere(
          (voice) => voice['locale']!.toLowerCase().startsWith('$base-'),
          orElse: () => const {'name': '', 'locale': ''},
        );
        if (byBase['name']!.isNotEmpty) {
          return byBase;
        }
      }

      return parsedVoices.first;
    } catch (e) {
      debugPrint('TTS getVoices error: $e');
      return null;
    }
  }

  /// Dispose resources
  static void dispose() {
    _flutterTts.stop();
    _speech.stop();
  }
}

/// Pronunciation scoring service
class PronunciationService {
  /// Analyze pronunciation with ML semantic similarity + phoneme-level matching.
  static Future<PronunciationAnalysis> analyzePronunciation({
    required String expected,
    required String spoken,
    required String language,
  }) async {
    final normalizedExpected = _normalize(expected);
    final normalizedSpoken = _normalize(spoken);

    if (normalizedExpected.isEmpty || normalizedSpoken.isEmpty) {
      return PronunciationAnalysis(
        score: 0,
        mlSimilarity: 0,
        phonemeAccuracy: 0,
        lexicalSimilarity: 0,
        feedback: 'Please speak clearly and try again.',
        mismatchedUnits: const [],
      );
    }

    double mlSimilarity = 0.0;
    try {
      mlSimilarity = await AILanguageService.calculateSimilarity(
        normalizedExpected,
        normalizedSpoken,
      );
      if (mlSimilarity.isNaN || mlSimilarity.isInfinite) {
        mlSimilarity = 0.0;
      }
      mlSimilarity = mlSimilarity.clamp(0.0, 1.0);
    } catch (_) {
      mlSimilarity = 0.0;
    }

    final lexical = _stringSimilarity(normalizedExpected, normalizedSpoken);

    final expectedUnits = _phonemeUnits(normalizedExpected, language);
    final spokenUnits = _phonemeUnits(normalizedSpoken, language);
    final unitComparison = _compareUnits(expectedUnits, spokenUnits);

    // Improved scoring with confidence boost for near-matches
    double finalScore =
        ((mlSimilarity * 0.40) +
            (unitComparison.accuracy * 0.40) +
            (lexical * 0.20)) *
        100;

    // Confidence boost: if both lexical + phoneme are >75%, boost score
    final combinedConfidence = (lexical + unitComparison.accuracy) / 2;
    if (combinedConfidence > 0.75) {
      finalScore = finalScore * 1.1; // 10% boost for high confidence
    }

    // Short word tolerance: shorter words get slightly more credit
    if (normalizedExpected.length <= 3 && lexical > 0.65) {
      finalScore = finalScore * 1.08;
    }

    final score = finalScore.round().clamp(0, 100);
    final feedback = _buildFeedback(
      score: score,
      language: language,
      mismatches: unitComparison.mismatches,
    );

    return PronunciationAnalysis(
      score: score,
      mlSimilarity: (mlSimilarity * 100).round(),
      phonemeAccuracy: (unitComparison.accuracy * 100).round(),
      lexicalSimilarity: (lexical * 100).round(),
      feedback: feedback,
      mismatchedUnits: unitComparison.mismatches,
    );
  }

  /// Compare user pronunciation with expected text
  static Future<double> scorePronunciation({
    required String expected,
    required String spoken,
    String language = 'urdu',
  }) async {
    final analysis = await analyzePronunciation(
      expected: expected,
      spoken: spoken,
      language: language,
    );
    return analysis.score.toDouble();
  }

  /// Calculate Levenshtein distance between two strings
  static int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    final matrix = List.generate(len1 + 1, (i) => List.filled(len2 + 1, 0));

    for (var i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }

    for (var j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= len1; i++) {
      for (var j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[len1][len2];
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'''[\.,!?;:"'()\[\]]'''), '');
  }

  static double _stringSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final distance = _levenshteinDistance(a, b);
    final maxLength = a.length > b.length ? a.length : b.length;
    if (maxLength == 0) return 0.0;
    return (1.0 - (distance / maxLength)).clamp(0.0, 1.0);
  }

  static List<String> _phonemeUnits(String text, String language) {
    if (language == 'english') {
      return text.split('').where((c) => c.trim().isNotEmpty).toList();
    }

    // Shahmukhi/Urdu approximate grapheme units.
    final cleaned = text.replaceAll(' ', '');
    return cleaned.split('').where((c) => c.trim().isNotEmpty).toList();
  }

  static _UnitComparison _compareUnits(
    List<String> expected,
    List<String> spoken,
  ) {
    if (expected.isEmpty || spoken.isEmpty) {
      return const _UnitComparison(accuracy: 0.0, mismatches: []);
    }

    final maxLen = expected.length > spoken.length
        ? expected.length
        : spoken.length;
    int matches = 0;
    final mismatches = <String>[];

    for (int i = 0; i < maxLen; i++) {
      final e = i < expected.length ? expected[i] : '∅';
      final s = i < spoken.length ? spoken[i] : '∅';
      if (e == s) {
        matches++;
      } else if (mismatches.length < 6) {
        mismatches.add('$e -> $s');
      }
    }

    return _UnitComparison(
      accuracy: (matches / maxLen).clamp(0.0, 1.0),
      mismatches: mismatches,
    );
  }

  static String _buildFeedback({
    required int score,
    required String language,
    required List<String> mismatches,
  }) {
    final base = getFeedback(score.toDouble());
    if (mismatches.isEmpty) return base;

    final hints = mismatches.take(3).join(', ');
    if (language == 'urdu' || language == 'punjabi') {
      return '$base\nFocus sounds: $hints';
    }
    return '$base\nSound mismatches: $hints';
  }

  /// Get pronunciation feedback
  static String getFeedback(double score) {
    if (score >= 90) return 'Excellent! Perfect pronunciation! 🎉';
    if (score >= 75) return 'Great job! Very good pronunciation! 👍';
    if (score >= 60) return 'Good effort! Keep practicing! 💪';
    if (score >= 40) return 'Not bad! Try again for better results! 🔄';
    return 'Keep practicing! Listen carefully and try again! 📚';
  }
}

class PronunciationAnalysis {
  final int score;
  final int mlSimilarity;
  final int phonemeAccuracy;
  final int lexicalSimilarity;
  final String feedback;
  final List<String> mismatchedUnits;

  const PronunciationAnalysis({
    required this.score,
    required this.mlSimilarity,
    required this.phonemeAccuracy,
    required this.lexicalSimilarity,
    required this.feedback,
    required this.mismatchedUnits,
  });
}

class _UnitComparison {
  final double accuracy;
  final List<String> mismatches;

  const _UnitComparison({required this.accuracy, required this.mismatches});
}

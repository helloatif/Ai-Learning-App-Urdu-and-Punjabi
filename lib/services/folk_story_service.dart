import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_keys.dart';
import '../config/env_config.dart';
import 'ai_language_service.dart';
import 'translation_service.dart';

class FolkStoryResult {
  final String urduStory;
  final String englishTranslation;

  const FolkStoryResult({
    required this.urduStory,
    required this.englishTranslation,
  });
}

class FolkStoryService {
  static final Random _random = Random();
  static const String _routerChatUrl =
      'https://router.huggingface.co/v1/chat/completions';
  static const String _hfInferenceBaseUrl =
    'https://api-inference.huggingface.co/models';
  static const String _punjabiStoryModel = 'sarvamai/sarvam-2b-v0.5';
  static const String _gurmukhiToShahmukhiModel =
    'SLPG/Punjabi_Gurmukhi_to_Shahmukhi_Transliteration';
  static const List<String> _storyModels = [
    'meta-llama/Llama-3.3-70B-Instruct',
    'Qwen/Qwen2.5-7B-Instruct',
    'meta-llama/Llama-3.1-8B-Instruct',
    'openai/gpt-oss-20b',
    'openai/gpt-oss-120b',
  ];

  // Remove punctuation that TTS can read awkwardly.
  static final RegExp _forbiddenPunctuation = RegExp(
    r'''[.,:;"'{}\[\]()|?/\\!@#\$%\^&*،۔؛؟«»“”‘’]''',
  );

  static final TranslationService _translationService = TranslationService();
  static int _fallbackCursor = 0;
  static int _punjabiFallbackCursor = 0;
  static String? _lastReturnedStory;
  static String? _lastReturnedPunjabiStory;
  static final List<String> _recentUrduStories = [];
  static final List<String> _recentPunjabiStories = [];
  static const int _recentWindow = 12;

  static const List<FolkStoryResult> _fallbackStories = [
    FolkStoryResult(
      urduStory:
          'ایک گاؤں میں ایک بچہ رہتا تھا\nوہ ہر روز دریا کے کنارے جاتا تھا\nایک دن اسے ایک پرانا چراغ ملا\nاس نے چراغ گھر لا کر اپنی ماں کو دیا\nسب نے مل کر شکر ادا کیا',
      englishTranslation:
          'A child lived in a village\nHe went to the river bank every day\nOne day he found an old lamp\nHe brought the lamp home and gave it to his mother\nEveryone thanked God together',
    ),
    FolkStoryResult(
      urduStory:
          'ایک کسان کے پاس ایک چھوٹا کھیت تھا\nوہ صبح سویرے بیج بوتا تھا\nبارش آئی تو فصل ہری ہو گئی\nگاؤں والوں نے اس کی محنت کو سراہا',
      englishTranslation:
          'A farmer had a small field\nHe planted seeds early in the morning\nWhen rain came the crop turned green\nThe villagers praised his hard work',
    ),
    FolkStoryResult(
      urduStory:
          'ایک لکڑہارا جنگل میں کام کرتا تھا\nاس کی کلہاڑی دریا میں گر گئی\nاس نے سچ بولا اور صبر کیا\nآخر اسے اپنی کلہاڑی واپس مل گئی',
      englishTranslation:
          'A woodcutter worked in the forest\nHis axe fell into the river\nHe spoke the truth and stayed patient\nIn the end he got his axe back',
    ),
  ];

  static const List<FolkStoryResult> _fallbackPunjabiStories = [
    FolkStoryResult(
      urduStory:
          'اک پنڈ وچ اک بچہ رہندا سی\nاوہ ہر سویرے سکول جاندا سی\nاک دن اوہنے اک بوٹا لایا\nسارے بچیاں نال مل کے پانی دتا\nآخر اوہ بوٹا وڈا درخت بن گیا',
      englishTranslation:
          'In a village, a child used to live\nHe went to school every morning\nOne day he planted a sapling\nHe watered it together with all children\nIn the end that sapling became a big tree',
    ),
    FolkStoryResult(
      urduStory:
          'اک محنتی کڑی اپنی دادی کول بیٹھی سی\nدادی اوہدے نوں سچ دی گل سکھاؤندی سی\nاک دن کڑی نے دوست دی مدد کیتی\nپنڈ دے لوکاں نے اوہدے دی تعریف کیتی\nسارے خوشی نال گھر ول مڑ گئے',
      englishTranslation:
          'A hardworking girl sat with her grandmother\nGrandmother taught her the value of truth\nOne day the girl helped a friend\nPeople of the village praised her\nEveryone returned home happily',
    ),
  ];

  static Future<FolkStoryResult> generateFolkStory({
    required String language,
    String? variationSeed,
    String? previousStory,
  }) async {
    final normalizedLanguage = language.trim().toLowerCase();
    if (normalizedLanguage == 'punjabi') {
      return _generatePunjabiShahmukhiStory(
        variationSeed: variationSeed,
        previousStory: previousStory,
      );
    }

    return generateUrduFolkStory(
      variationSeed: variationSeed,
      previousStory: previousStory,
    );
  }

  static Future<FolkStoryResult> generateUrduFolkStory({
    String? variationSeed,
    String? previousStory,
  }) async {
    for (int round = 0; round < 2; round++) {
      try {
        final generatedByRouter = await _generateViaRouterChat(
          variationSeed: '${variationSeed ?? DateTime.now().millisecondsSinceEpoch}_$round',
          previousStory: previousStory,
        );
        if (generatedByRouter != null) {
          _lastReturnedStory = generatedByRouter.urduStory;
          _rememberStory(generatedByRouter.urduStory);
          return generatedByRouter;
        }
      } catch (e) {
        debugPrint('Router story generation failed: $e');
      }
    }

    final fallback = _nextFallback(previousStory);
    _lastReturnedStory = fallback.urduStory;
    _rememberStory(fallback.urduStory);
    return fallback;
  }

  static Future<FolkStoryResult> _generatePunjabiShahmukhiStory({
    String? variationSeed,
    String? previousStory,
  }) async {
    for (int round = 0; round < 2; round++) {
      try {
        final generated = await _generatePunjabiViaSarvam(
          variationSeed:
              '${variationSeed ?? DateTime.now().millisecondsSinceEpoch}_$round',
          previousStory: previousStory,
        );
        if (generated != null) {
          _lastReturnedPunjabiStory = generated.urduStory;
          _rememberStory(generated.urduStory, language: 'punjabi');
          return generated;
        }
      } catch (e) {
        debugPrint('Punjabi story generation failed: $e');
      }
    }

    final fallback = _nextPunjabiFallback(previousStory);
    _lastReturnedPunjabiStory = fallback.urduStory;
    _rememberStory(fallback.urduStory, language: 'punjabi');
    return fallback;
  }

  static String cleanTextForTts(String text) {
    final noPunctuation = text.replaceAll(_forbiddenPunctuation, ' ');

    final cleanedLines = noPunctuation
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return cleanedLines.join('\n');
  }

  static String _extractGeneratedText(String rawBody) {
    final decoded = jsonDecode(rawBody);

    if (decoded is List && decoded.isNotEmpty) {
      final first = decoded.first;
      if (first is Map<String, dynamic>) {
        final generated = first['generated_text'];
        if (generated is String && generated.trim().isNotEmpty) {
          return generated;
        }

        final translation = first['translation_text'];
        if (translation is String && translation.trim().isNotEmpty) {
          return translation;
        }
      }
    }

    if (decoded is Map<String, dynamic>) {
      final generated = decoded['generated_text'];
      if (generated is String && generated.trim().isNotEmpty) {
        return generated;
      }
    }

    return '';
  }

  static Future<FolkStoryResult?> _generateViaRouterChat({
    String? variationSeed,
    String? previousStory,
  }) async {
    try {
      final token = _resolveHuggingFaceToken();
      final avoidBlock = _recentStoriesForPrompt(previousStory);
      var creditsExhausted = false;

      for (final model in _storyModels) {
        if (creditsExhausted) {
          break;
        }

        final response = await http.post(
          Uri.parse(_routerChatUrl),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'temperature': 0.45,
            'top_p': 0.95,
            'max_tokens': 450,
            'messages': [
              {
                'role': 'system',
                'content':
                    'You are an expert Urdu children story writer. Return strict JSON only with keys urdu_story and english_translation.'
              },
              {
                'role': 'user',
                'content':
                    'Generate a NEW coherent Urdu folk story for children with 3 to 5 short lines. Use only natural Urdu words and simple grammar. No punctuation marks in Urdu lines. Each line should be meaningful and easy to read aloud. Also provide matching English translation with the same number of lines. Do not mix Roman Urdu. Never repeat these stories or close variants:\n$avoidBlock\nVariant ${variationSeed ?? 'default'}. Return JSON only: {"urdu_story":"...","english_translation":"..."}'
              }
            ]
          }),
        );

        if (response.statusCode != 200) {
          final snippet = response.body.length > 220
              ? '${response.body.substring(0, 220)}...'
              : response.body;
          debugPrint(
            'Router chat API non-200 with $model: ${response.statusCode} | $snippet',
          );

          if (response.statusCode == 402 ||
              response.body.toLowerCase().contains('depleted')) {
            creditsExhausted = true;
          }

          continue;
        }

        final decoded = jsonDecode(response.body);
        String content = '';
        if (decoded is Map<String, dynamic>) {
          final choices = decoded['choices'];
          if (choices is List && choices.isNotEmpty) {
            final first = choices.first;
            if (first is Map<String, dynamic>) {
              final message = first['message'];
              if (message is Map<String, dynamic>) {
                final raw = message['content'];
                if (raw is String) {
                  content = raw;
                }
              }
            }
          }
        }

        if (content.trim().isEmpty) {
          continue;
        }

        final parsed = _parseRouterJsonContent(content);
        if (parsed == null) {
          continue;
        }

        var urduStory = _normalizeStoryLines(parsed.urduStory);
        if (urduStory.trim().isEmpty) {
          continue;
        }

        if (!_isReadableUrduStory(urduStory)) {
          final refined = await _refineUrduStory(
            model: model,
            urduStory: urduStory,
          );
          if (refined != null) {
            urduStory = _normalizeStoryLines(refined);
          }
        }

        if (!_isReadableUrduStory(urduStory)) {
          debugPrint('Rejected low-readability Urdu story from $model');
          continue;
        }

        List<String> englishLines =
            _normalizeEnglishLines(parsed.englishTranslation);
        final isEnglishValid = _isLikelyEnglish(englishLines.join(' '));
        if (englishLines.isEmpty || !isEnglishValid) {
          final translated = await _translateStoryToEnglish(urduStory);
          englishLines = _normalizeEnglishLines(translated);
        }
        if (englishLines.isEmpty) {
          continue;
        }

        if (previousStory != null && urduStory.trim() == previousStory.trim()) {
          continue;
        }
        if (_lastReturnedStory != null &&
            urduStory.trim() == _lastReturnedStory!.trim()) {
          continue;
        }
        if (_isRecentlyUsed(urduStory)) {
          continue;
        }

        return FolkStoryResult(
          urduStory: urduStory,
          englishTranslation: englishLines.join('\n'),
        );
      }

      return null;
    } catch (e) {
      debugPrint('Router chat parse failed: $e');
      return null;
    }
  }

  static Future<FolkStoryResult?> _generatePunjabiViaSarvam({
    String? variationSeed,
    String? previousStory,
  }) async {
    try {
      final token = _resolveHuggingFaceToken();
      final avoidBlock = _recentStoriesForPrompt(
        previousStory,
        language: 'punjabi',
      );

      final prompt =
          'You are a Punjabi children folk-story writer. '
          'Generate a NEW coherent Punjabi folk story for children in Gurmukhi script only. '
          'Use 3 to 5 short lines. Avoid Roman Punjabi. '
          'Also provide matching English translation with same number of lines. '
          'Never repeat these stories or close variants:\n$avoidBlock\n'
          'Variant ${variationSeed ?? 'default'}.\n'
          'Return strict JSON only: {"gurmukhi_story":"...","english_translation":"..."}';

      final response = await http.post(
        Uri.parse('$_hfInferenceBaseUrl/$_punjabiStoryModel'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'inputs': prompt,
          'parameters': {
            'max_new_tokens': 380,
            'temperature': 0.55,
            'top_p': 0.95,
            'return_full_text': false,
          },
          'options': {
            'wait_for_model': true,
          },
        }),
      );

      if (response.statusCode != 200) {
        final snippet = response.body.length > 220
            ? '${response.body.substring(0, 220)}...'
            : response.body;
        debugPrint(
          'Punjabi inference API non-200: ${response.statusCode} | $snippet',
        );
        return null;
      }

      String content = _extractGeneratedText(response.body);

      if (content.trim().isEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          content = (decoded['generated_text'] ?? '').toString();
        }
      }

      if (content.trim().isEmpty) {
        return null;
      }

      final parsed = _parseRouterJsonContentWithKeys(
        content,
        sourceStoryKey: 'gurmukhi_story',
      );
      if (parsed == null) {
        return null;
      }

      final gurmukhiStory = _normalizeGurmukhiStoryLines(parsed.urduStory);
      if (!_isReadableGurmukhiStory(gurmukhiStory)) {
        return null;
      }

      final shahmukhiRaw = await _transliterateGurmukhiToShahmukhi(
        gurmukhiStory,
      );
      if (shahmukhiRaw == null || shahmukhiRaw.trim().isEmpty) {
        return null;
      }

      final shahmukhiStory = _normalizeStoryLines(shahmukhiRaw);
      if (!_isReadablePunjabiShahmukhiStory(shahmukhiStory)) {
        return null;
      }

      List<String> englishLines =
          _normalizeEnglishLines(parsed.englishTranslation);
      if (englishLines.isEmpty ||
          !_isLikelyEnglish(englishLines.join(' '))) {
        final translated = await _translatePunjabiStoryToEnglish(shahmukhiStory);
        englishLines = _normalizeEnglishLines(translated);
      }
      if (englishLines.isEmpty) {
        return null;
      }

      if (previousStory != null && shahmukhiStory.trim() == previousStory.trim()) {
        return null;
      }
      if (_lastReturnedPunjabiStory != null &&
          shahmukhiStory.trim() == _lastReturnedPunjabiStory!.trim()) {
        return null;
      }
      if (_isRecentlyUsed(shahmukhiStory, language: 'punjabi')) {
        return null;
      }

      return FolkStoryResult(
        urduStory: shahmukhiStory,
        englishTranslation: englishLines.join('\n'),
      );
    } catch (e) {
      debugPrint('Punjabi generation parse failed: $e');
      return null;
    }
  }

  static FolkStoryResult? _parseRouterJsonContent(String content) {
    return _parseRouterJsonContentWithKeys(
      content,
      sourceStoryKey: 'urdu_story',
    );
  }

  static FolkStoryResult? _parseRouterJsonContentWithKeys(
    String content, {
    required String sourceStoryKey,
  }) {
    final trimmed = content.trim();

    Map<String, dynamic>? parsed;
    try {
      final direct = jsonDecode(trimmed);
      if (direct is Map<String, dynamic>) {
        parsed = direct;
      }
    } catch (_) {
      final jsonBlock = RegExp(r'\{[\s\S]*\}').firstMatch(trimmed)?.group(0);
      if (jsonBlock != null) {
        try {
          final block = jsonDecode(jsonBlock);
          if (block is Map<String, dynamic>) {
            parsed = block;
          }
        } catch (_) {}
      }
    }

    if (parsed == null) {
      return null;
    }

    final urdu = (parsed[sourceStoryKey] ?? '').toString().trim();
    final english = (parsed['english_translation'] ?? '').toString().trim();
    if (urdu.isEmpty || english.isEmpty) {
      return null;
    }

    return FolkStoryResult(
      urduStory: urdu,
      englishTranslation: english,
    );
  }

  static Future<FolkStoryResult?> _generateViaTextModel({
    String? variationSeed,
    String? previousStory,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_routerChatUrl),
        headers: {
          'Authorization': 'Bearer ${_resolveHuggingFaceToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _storyModels.first,
          'temperature': 0.9,
          'top_p': 0.95,
          'max_tokens': 260,
          'messages': [
            {
              'role': 'user',
              'content':
                  'Write a short folk style story in simple English with 3 to 5 short lines. One sentence per line. Keep it unique. Variant ${variationSeed ?? 'default'}'
            }
          ]
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('Text model router API non-200: ${response.statusCode}');
        return null;
      }

      final decoded = jsonDecode(response.body);
      String englishRaw = '';
      if (decoded is Map<String, dynamic>) {
        final choices = decoded['choices'];
        if (choices is List && choices.isNotEmpty) {
          final first = choices.first;
          if (first is Map<String, dynamic>) {
            final message = first['message'];
            if (message is Map<String, dynamic>) {
              final raw = message['content'];
              if (raw is String) {
                englishRaw = raw;
              }
            }
          }
        }
      }

      final englishLines = _normalizeEnglishLines(englishRaw);
      if (englishLines.isEmpty) {
        return null;
      }

      final englishTranslation = englishLines.join('\n');

      final urduTranslated = await AILanguageService.translateText(
        text: englishTranslation,
        sourceLanguage: 'english',
        targetLanguage: 'urdu',
      );

      final urduStory = _normalizeStoryLines(urduTranslated);

      if (urduStory.trim().isEmpty) {
        return null;
      }

      if (previousStory != null && urduStory.trim() == previousStory.trim()) {
        return null;
      }

      return FolkStoryResult(
        urduStory: urduStory,
        englishTranslation: englishTranslation,
      );
    } catch (e) {
      debugPrint('Text model generation fallback failed: $e');
      return null;
    }
  }

  static Future<String?> _refineUrduStory({
    required String model,
    required String urduStory,
  }) async {
    try {
      final token = _resolveHuggingFaceToken();
      final response = await http.post(
        Uri.parse(_routerChatUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'temperature': 0.2,
          'top_p': 0.9,
          'max_tokens': 260,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You rewrite Urdu text for clarity. Return strict JSON only with key urdu_story.'
            },
            {
              'role': 'user',
              'content':
                  'Rewrite this Urdu story into clear and simple Urdu for children. Keep 3 to 5 short lines. Keep meaning similar. No punctuation. Return JSON only: {"urdu_story":"..."}\n\n$urduStory'
            }
          ]
        }),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        return null;
      }

      final first = choices.first;
      if (first is! Map<String, dynamic>) {
        return null;
      }

      final message = first['message'];
      if (message is! Map<String, dynamic>) {
        return null;
      }

      final content = (message['content'] ?? '').toString().trim();
      if (content.isEmpty) {
        return null;
      }

      try {
        final parsed = jsonDecode(content);
        if (parsed is Map<String, dynamic>) {
          final refined = (parsed['urdu_story'] ?? '').toString().trim();
          if (refined.isNotEmpty) {
            return refined;
          }
        }
      } catch (_) {
        final jsonBlock = RegExp(r'\{[\s\S]*\}').firstMatch(content)?.group(0);
        if (jsonBlock != null) {
          try {
            final parsed = jsonDecode(jsonBlock);
            if (parsed is Map<String, dynamic>) {
              final refined = (parsed['urdu_story'] ?? '').toString().trim();
              if (refined.isNotEmpty) {
                return refined;
              }
            }
          } catch (_) {}
        }
      }

      return null;
    } catch (e) {
      debugPrint('Urdu refinement failed: $e');
      return null;
    }
  }

  static String _normalizeGurmukhiStoryLines(String raw) {
    final lines = raw
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'[\n\.\!\?\:\;]+'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.length < 3) {
      return '';
    }

    return lines.take(5).join('\n');
  }

  static bool _isReadableGurmukhiStory(String story) {
    final normalized = story.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return false;

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.length < 3 || lines.length > 5) return false;

    final stripped = normalized.replaceAll(RegExp(r'\s+'), '');
    if (stripped.isEmpty) return false;

    final gurmukhiChars = RegExp(r'[\u0A00-\u0A7F]').allMatches(stripped).length;
    final latinChars = RegExp(r'[A-Za-z]').allMatches(stripped).length;

    if (gurmukhiChars < 24) return false;
    if (latinChars > 3) return false;

    for (final line in lines) {
      final wordCount = line
          .split(RegExp(r'\s+'))
          .where((w) => w.trim().isNotEmpty)
          .length;
      if (wordCount < 3 || wordCount > 18) return false;
    }

    return true;
  }

  static Future<String?> _transliterateGurmukhiToShahmukhi(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$_hfInferenceBaseUrl/$_gurmukhiToShahmukhiModel'),
        headers: {
          'Authorization': 'Bearer ${_resolveHuggingFaceToken()}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'inputs': text,
          'options': {'wait_for_model': true},
        }),
      );

      if (response.statusCode != 200) {
        final snippet = response.body.length > 220
            ? '${response.body.substring(0, 220)}...'
            : response.body;
        debugPrint(
          'Punjabi transliteration API non-200: ${response.statusCode} | $snippet',
        );
        return null;
      }

      final transliterated = _extractGeneratedText(response.body).trim();
      if (transliterated.isNotEmpty) {
        return transliterated;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final direct = (decoded['translation_text'] ?? decoded['generated_text'])
            ?.toString()
            .trim();
        if (direct != null && direct.isNotEmpty) {
          return direct;
        }
      }
    } catch (e) {
      debugPrint('Punjabi transliteration failed: $e');
    }

    return null;
  }

  static List<String> _normalizeEnglishLines(String raw) {
    final lines = raw
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'[\n\.!?;:]+'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) return const [];
    if (lines.length < 3) return const [];

    return lines.take(5).toList();
  }

  static String _normalizeStoryLines(String raw) {
    final byBreakOrStops = raw
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'[\n\.\!\?\u06d4\u061f\u060c\:\;]+'))
        .map((line) => cleanTextForTts(line))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (byBreakOrStops.isEmpty) {
      return '';
    }

    final lines = byBreakOrStops.take(5).toList();

    if (lines.length < 3) {
      return '';
    }

    return lines.join('\n');
  }

  static bool _isReadableUrduStory(String story) {
    final normalized = story.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return false;

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.length < 3 || lines.length > 5) return false;

    final stripped = normalized.replaceAll(RegExp(r'\s+'), '');
    if (stripped.isEmpty) return false;

    final urduChars = RegExp(r'[\u0600-\u06FF]').allMatches(stripped).length;
    final latinChars = RegExp(r'[A-Za-z]').allMatches(stripped).length;

    // Ensure output is primarily Urdu script and not romanized mix.
    if (urduChars < 24) return false;
    if (latinChars > 3) return false;

    int linesWithVerbPattern = 0;
    for (final line in lines) {
      final wordCount = line
          .split(RegExp(r'\s+'))
          .where((w) => w.trim().isNotEmpty)
          .length;
      if (wordCount < 3 || wordCount > 18) return false;

      if (RegExp(
        r'(ہے|ہیں|تھا|تھی|تھے|گیا|گئی|گئے|رہا|رہی|رہے|کرتا|کرتی|کرتے|چلا|چلی|چلے)',
      ).hasMatch(line)) {
        linesWithVerbPattern++;
      }
    }

    return linesWithVerbPattern >= 2;
  }

  static bool _isReadablePunjabiShahmukhiStory(String story) {
    final normalized = story.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) return false;

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.length < 3 || lines.length > 5) return false;

    final stripped = normalized.replaceAll(RegExp(r'\s+'), '');
    if (stripped.isEmpty) return false;

    final shahmukhiChars = RegExp(r'[\u0600-\u06FF]').allMatches(stripped).length;
    final latinChars = RegExp(r'[A-Za-z]').allMatches(stripped).length;

    if (shahmukhiChars < 20) return false;
    if (latinChars > 3) return false;

    for (final line in lines) {
      final wordCount = line
          .split(RegExp(r'\s+'))
          .where((w) => w.trim().isNotEmpty)
          .length;
      if (wordCount < 3 || wordCount > 18) return false;
    }

    return true;
  }

  static String _resolveHuggingFaceToken() {
    if (EnvConfig.huggingFaceToken.trim().isNotEmpty) {
      return EnvConfig.huggingFaceToken.trim();
    }

    final primaryApiKey = ApiKeys.huggingFaceToken.trim();
    if (primaryApiKey.isNotEmpty && !primaryApiKey.startsWith('YOUR_')) {
      return primaryApiKey;
    }

    final modelApiKey = ApiKeys.huggingFaceModelToken.trim();
    if (modelApiKey.isNotEmpty && !modelApiKey.startsWith('YOUR_')) {
      return modelApiKey;
    }

    throw Exception(
      'HuggingFace API token not configured. Set HUGGINGFACE_TOKEN dart-define or api_keys.dart token.',
    );
  }

  static Future<String> _translateStoryToEnglish(String urduStory) async {
    try {
      final translated = await _translationService.translate(
        text: urduStory,
        from: 'urdu',
        to: 'english',
      );

      final candidate = translated.translatedText.trim();
      if (_isLikelyEnglish(candidate) && candidate != urduStory.trim()) {
        return candidate;
      }
    } catch (e) {
      debugPrint('Primary translation path failed: $e');
    }

    try {
      final fallback = await AILanguageService.translateText(
        text: urduStory,
        sourceLanguage: 'urdu',
        targetLanguage: 'english',
      );
      final candidate = fallback.trim();
      if (_isLikelyEnglish(candidate) && candidate != urduStory.trim()) {
        return candidate;
      }
    } catch (e) {
      debugPrint('Fallback translation path failed: $e');
    }

    return 'Translation unavailable at the moment';
  }

  static Future<String> _translatePunjabiStoryToEnglish(String punjabiStory) async {
    try {
      final translated = await _translationService.translate(
        text: punjabiStory,
        from: 'punjabi',
        to: 'english',
      );

      final candidate = translated.translatedText.trim();
      if (_isLikelyEnglish(candidate) && candidate != punjabiStory.trim()) {
        return candidate;
      }
    } catch (e) {
      debugPrint('Punjabi primary translation path failed: $e');
    }

    try {
      final fallback = await AILanguageService.translateText(
        text: punjabiStory,
        sourceLanguage: 'punjabi',
        targetLanguage: 'english',
      );
      final candidate = fallback.trim();
      if (_isLikelyEnglish(candidate) && candidate != punjabiStory.trim()) {
        return candidate;
      }
    } catch (e) {
      debugPrint('Punjabi fallback translation path failed: $e');
    }

    return 'Translation unavailable at the moment';
  }

  static bool _isLikelyEnglish(String text) {
    if (text.trim().isEmpty) return false;

    final hasUrduScript = RegExp(r'[\u0600-\u06FF]').hasMatch(text);
    if (hasUrduScript) return false;

    final latinChars = RegExp(r'[A-Za-z]').allMatches(text).length;
    return latinChars >= 12;
  }

  static FolkStoryResult _nextFallback([String? previousStory]) {
    if (_fallbackStories.isEmpty) {
      return const FolkStoryResult(
        urduStory:
            'ایک استاد بچوں کو سبق پڑھاتا تھا\nبچے روز محنت کرتے تھے\nسب نے مل کر کامیابی حاصل کی',
        englishTranslation:
            'A teacher taught lessons to children\nThe children worked hard every day\nTogether they achieved success',
      );
    }

    for (int i = 0; i < _fallbackStories.length; i++) {
      final candidate = _fallbackStories[_fallbackCursor % _fallbackStories.length];
      _fallbackCursor++;
      if ((previousStory == null || candidate.urduStory.trim() != previousStory.trim()) &&
          !_isRecentlyUsed(candidate.urduStory)) {
        return candidate;
      }
    }

    // When API credits are exhausted, generate varied local stories
    // instead of looping over the same fixed fallback entries.
    for (int i = 0; i < 20; i++) {
      final generated = _buildProceduralFallbackStory();
      if ((previousStory == null || generated.urduStory.trim() != previousStory.trim()) &&
          !_isRecentlyUsed(generated.urduStory)) {
        return generated;
      }
    }

    return _buildProceduralFallbackStory();
  }

  static FolkStoryResult _nextPunjabiFallback([String? previousStory]) {
    if (_fallbackPunjabiStories.isEmpty) {
      return const FolkStoryResult(
        urduStory:
            'اک محنتی لڑکا ہر روز سبق پڑھدا سی\nاک دن اوہنے دوست دی مدد کیتی\nسارے اوہدے نال خوش ہو گئے',
        englishTranslation:
            'A hardworking boy studied every day\nOne day he helped a friend\nEveryone became happy with him',
      );
    }

    for (int i = 0; i < _fallbackPunjabiStories.length; i++) {
      final candidate =
          _fallbackPunjabiStories[_punjabiFallbackCursor % _fallbackPunjabiStories.length];
      _punjabiFallbackCursor++;
      if ((previousStory == null ||
              candidate.urduStory.trim() != previousStory.trim()) &&
          !_isRecentlyUsed(candidate.urduStory, language: 'punjabi')) {
        return candidate;
      }
    }

    for (int i = 0; i < 20; i++) {
      final generated = _buildProceduralPunjabiFallbackStory();
      if ((previousStory == null || generated.urduStory.trim() != previousStory.trim()) &&
          !_isRecentlyUsed(generated.urduStory, language: 'punjabi')) {
        return generated;
      }
    }

    return _buildProceduralPunjabiFallbackStory();
  }

  static FolkStoryResult _buildProceduralFallbackStory() {
    const subjects = [
      {'ur': 'ایک چھوٹا بچہ', 'en': 'A small child'},
      {'ur': 'ایک محنتی لڑکی', 'en': 'A hardworking girl'},
      {'ur': 'ایک ایماندار کسان', 'en': 'An honest farmer'},
      {'ur': 'ایک سمجھدار لڑکا', 'en': 'A thoughtful boy'},
      {'ur': 'ایک نرم دل استاد', 'en': 'A kind teacher'},
    ];

    const places = [
      {'ur': 'گاؤں میں', 'en': 'in a village'},
      {'ur': 'کھیت کے پاس', 'en': 'near a field'},
      {'ur': 'ندی کے کنارے', 'en': 'by the river bank'},
      {'ur': 'باغ کے اندر', 'en': 'inside a garden'},
      {'ur': 'مدرسے کے قریب', 'en': 'near the school'},
    ];

    const actions = [
      {
        'ur': 'روز صبح محنت کرتا تھا',
        'en': 'worked hard every morning',
      },
      {
        'ur': 'اپنے دوستوں کی مدد کرتا تھا',
        'en': 'helped friends',
      },
      {
        'ur': 'چپ چاپ سبق یاد کرتا تھا',
        'en': 'quietly memorized lessons',
      },
      {
        'ur': 'درختوں کو پانی دیتا تھا',
        'en': 'watered the trees',
      },
      {
        'ur': 'سچ بولنے کی عادت رکھتا تھا',
        'en': 'kept a habit of speaking truth',
      },
    ];

    const events = [
      {
        'ur': 'ایک دن اسے ایک مشکل کام ملا',
        'en': 'One day a difficult task came to them',
      },
      {
        'ur': 'ایک دن اس کے سامنے نئی آزمائش آئی',
        'en': 'One day a new challenge appeared',
      },
      {
        'ur': 'ایک دن موسم بدل گیا',
        'en': 'One day the weather suddenly changed',
      },
      {
        'ur': 'ایک دن سب لوگ پریشان ہو گئے',
        'en': 'One day everyone became worried',
      },
      {
        'ur': 'ایک دن راستہ بند ہو گیا',
        'en': 'One day the path got blocked',
      },
    ];

    const resolutions = [
      {
        'ur': 'اس نے صبر سے کام لیا اور کامیاب ہوا',
        'en': 'They acted with patience and succeeded',
      },
      {
        'ur': 'اس نے ہمت نہ ہاری اور مسئلہ حل کیا',
        'en': 'They did not lose courage and solved the problem',
      },
      {
        'ur': 'اس نے سب کو ساتھ لیا اور کام پورا کیا',
        'en': 'They united everyone and completed the work',
      },
      {
        'ur': 'اس نے سچائی سے دل جیت لیا',
        'en': 'They won hearts through honesty',
      },
      {
        'ur': 'آخر میں سب نے خوشی منائی',
        'en': 'In the end everyone celebrated',
      },
    ];

    const morals = [
      {
        'ur': 'محنت اور سچائی ہمیشہ فائدہ دیتی ہے',
        'en': 'Hard work and honesty always bring benefit',
      },
      {
        'ur': 'صبر کرنے والا کبھی خالی نہیں رہتا',
        'en': 'The patient person is never left empty-handed',
      },
      {
        'ur': 'مل جل کر کام کرنے سے آسانی آتی ہے',
        'en': 'Working together makes things easier',
      },
      {
        'ur': 'نیکی کا پھل اچھا ہی ہوتا ہے',
        'en': 'Good deeds always give good results',
      },
      {
        'ur': 'ہمت کرنے والوں کی مدد ہوتی ہے',
        'en': 'Those who stay brave receive help',
      },
    ];

    final subject = subjects[_random.nextInt(subjects.length)];
    final place = places[_random.nextInt(places.length)];
    final action = actions[_random.nextInt(actions.length)];
    final event = events[_random.nextInt(events.length)];
    final resolution = resolutions[_random.nextInt(resolutions.length)];
    final moral = morals[_random.nextInt(morals.length)];

    final urduLines = [
      '${subject['ur']} ${place['ur']} رہتا تھا',
      '${subject['ur']} ${action['ur']}',
      event['ur']!,
      resolution['ur']!,
      moral['ur']!,
    ];

    final englishLines = [
      '${subject['en']} lived ${place['en']}',
      '${subject['en']} ${action['en']}',
      event['en']!,
      resolution['en']!,
      moral['en']!,
    ];

    return FolkStoryResult(
      urduStory: urduLines.join('\n'),
      englishTranslation: englishLines.join('\n'),
    );
  }

  static FolkStoryResult _buildProceduralPunjabiFallbackStory() {
    const subjects = [
      {'pa': 'اک ننھا بچہ', 'en': 'A little child'},
      {'pa': 'اک محنتی کڑی', 'en': 'A hardworking girl'},
      {'pa': 'اک دانا استاد', 'en': 'A wise teacher'},
      {'pa': 'اک سچا کسان', 'en': 'An honest farmer'},
      {'pa': 'اک ہمت والا لڑکا', 'en': 'A brave boy'},
    ];

    const places = [
      {'pa': 'پنڈ وچ', 'en': 'in a village'},
      {'pa': 'کھیت دے کول', 'en': 'near the fields'},
      {'pa': 'ندی دے کنارے', 'en': 'by the river side'},
      {'pa': 'باغ اندر', 'en': 'inside a garden'},
      {'pa': 'سکول دے اگے', 'en': 'in front of the school'},
    ];

    const actions = [
      {'pa': 'روز سویرے محنت کردا سی', 'en': 'worked hard every morning'},
      {'pa': 'دوستاں دی مدد کردا سی', 'en': 'helped friends'},
      {'pa': 'سچ بولن دی عادت رکھدا سی', 'en': 'had a habit of speaking truth'},
      {'pa': 'بوٹے نوں پانی دیندا سی', 'en': 'watered the plants'},
      {'pa': 'سبق دھیان نال پڑھدا سی', 'en': 'studied lessons with focus'},
    ];

    const events = [
      {'pa': 'اک دن اک اوکھا کم سامنے آیا', 'en': 'One day a difficult task appeared'},
      {'pa': 'اک دن موسم اچانک بدل گیا', 'en': 'One day the weather changed suddenly'},
      {'pa': 'اک دن سارے لوک پریشان ہو گئے', 'en': 'One day everyone became worried'},
      {'pa': 'اک دن رستہ بند ہو گیا', 'en': 'One day the path got blocked'},
      {'pa': 'اک دن اوہدے نوں نواں امتحان مل گیا', 'en': 'One day a new test came to them'},
    ];

    const resolutions = [
      {'pa': 'اوہنے صبر نال مسئلہ حل کر لیا', 'en': 'They solved the problem with patience'},
      {'pa': 'اوہنے ہمت نئیں ہاری تے کامیاب ہو گیا', 'en': 'They stayed brave and succeeded'},
      {'pa': 'اوہنے سب نوں نال لیا تے کم پورا ہو گیا', 'en': 'They united everyone and finished the task'},
      {'pa': 'اوہدی سچائی نال سب خوش ہو گئے', 'en': 'Everyone became happy with their honesty'},
      {'pa': 'آخر سارے خوشی نال گھر گئے', 'en': 'In the end everyone went home happily'},
    ];

    const morals = [
      {'pa': 'محنت دا پھل ہمیشہ میٹھا ہوندا اے', 'en': 'The fruit of hard work is always sweet'},
      {'pa': 'سچ تے صبر نال کامیابی ملدی اے', 'en': 'Truth and patience bring success'},
      {'pa': 'مل جل کے کم کرن نال آسانی ہوندی اے', 'en': 'Working together makes things easier'},
      {'pa': 'نیکی دا نتیجہ ہمیشہ چنگا ہوندا اے', 'en': 'Good deeds always lead to good outcomes'},
      {'pa': 'ہمت والے لوک آگے ودھدے نیں', 'en': 'Brave people move forward'},
    ];

    final subject = subjects[_random.nextInt(subjects.length)];
    final place = places[_random.nextInt(places.length)];
    final action = actions[_random.nextInt(actions.length)];
    final event = events[_random.nextInt(events.length)];
    final resolution = resolutions[_random.nextInt(resolutions.length)];
    final moral = morals[_random.nextInt(morals.length)];

    final punjabiLines = [
      '${subject['pa']} ${place['pa']} رہندا سی',
      '${subject['pa']} ${action['pa']}',
      event['pa']!,
      resolution['pa']!,
      moral['pa']!,
    ];

    final englishLines = [
      '${subject['en']} lived ${place['en']}',
      '${subject['en']} ${action['en']}',
      event['en']!,
      resolution['en']!,
      moral['en']!,
    ];

    return FolkStoryResult(
      urduStory: punjabiLines.join('\n'),
      englishTranslation: englishLines.join('\n'),
    );
  }

  static void _rememberStory(String story, {String language = 'urdu'}) {
    final normalized = story.trim();
    if (normalized.isEmpty) return;

    final target = language == 'punjabi' ? _recentPunjabiStories : _recentUrduStories;

    target.removeWhere((entry) => entry.trim() == normalized);
    target.add(normalized);
    if (target.length > _recentWindow) {
      target.removeRange(0, target.length - _recentWindow);
    }
  }

  static bool _isRecentlyUsed(String story, {String language = 'urdu'}) {
    final normalized = story.trim();
    if (normalized.isEmpty) return false;
    final target = language == 'punjabi' ? _recentPunjabiStories : _recentUrduStories;
    return target.any((entry) => entry.trim() == normalized);
  }

  static String _recentStoriesForPrompt(
    String? previousStory, {
    String language = 'urdu',
  }) {
    final candidates = <String>[];

    final lastReturned =
        language == 'punjabi' ? _lastReturnedPunjabiStory : _lastReturnedStory;
    final recentStories =
        language == 'punjabi' ? _recentPunjabiStories : _recentUrduStories;

    if (previousStory != null && previousStory.trim().isNotEmpty) {
      candidates.add(previousStory.trim());
    }

    if (lastReturned != null && lastReturned.trim().isNotEmpty) {
      candidates.add(lastReturned.trim());
    }

    candidates.addAll(recentStories.reversed.take(6));

    final unique = <String>[];
    for (final story in candidates) {
      if (!unique.any((existing) => existing == story)) {
        unique.add(story);
      }
    }

    if (unique.isEmpty) {
      return 'none';
    }

    return unique
        .take(6)
        .map((story) => '- ${story.replaceAll('\n', ' | ')}')
        .join('\n');
  }

  static String _englishForFallbackStory(String urduStory) {
    for (final entry in _fallbackStories) {
      if (entry.urduStory.trim() == urduStory.trim()) {
        return entry.englishTranslation;
      }
    }
    return 'Translation unavailable at the moment';
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/env_config.dart';
import 'ml_vocabulary_service.dart';

class AIAssistantService {
  // Models tried in order. Each model has its OWN free-tier daily quota, so if
  // one returns 429 (quota exhausted) we automatically fall back to the next,
  // which multiplies the number of free requests available per day.
  // 2.5 models support disabling "thinking"; 2.0 does not.
  static const List<String> _geminiModels = [
    'gemini-2.5-flash',
    'gemini-flash-lite-latest',
    'gemini-2.0-flash-lite',
    'gemini-2.0-flash',
  ];

  static final List<Map<String, String>> _conversationHistory = [];
  static String _currentLanguage = 'urdu';

  static void setLanguage(String language) {
    _currentLanguage = language.trim().isEmpty ? 'urdu' : language.trim();
  }

  static Future<String> getResponse(String userMessage) async {
    final classification = await _classifyMessage(userMessage);

    try {
      final response = await _generateGeminiResponse(
        userMessage: userMessage,
        classification: classification,
      );

      // History intentionally not retained: feeding prior turns back into the
      // prompt caused Gemini to hallucinate context for short or ambiguous
      // inputs (e.g. answering "we" with the previous "main theek hoon"
      // explanation). Each question is now independent.
      return response;
    } catch (e) {
      debugPrint('AI Assistant error: $e');
      return _offlineResponse(error: e.toString());
    }
  }

  static Future<_AssistantClassification> _classifyMessage(
    String userMessage,
  ) async {
    final language = await _detectLanguage(userMessage);
    final intent = _detectIntent(userMessage);
    final normalizedLanguage = _normalizeLanguage(language.language);
    final targetLanguage = _inferTargetLanguage(
      userMessage: userMessage,
      detectedLanguage: normalizedLanguage,
    );

    return _AssistantClassification(
      intent: intent,
      detectedLanguage: normalizedLanguage,
      targetLanguage: targetLanguage,
      confidence: language.confidence,
    );
  }

  static Future<LanguageDetectionResult> _detectLanguage(String text) async {
    try {
      return await MLVocabularyService.detectLanguage(text);
    } catch (e) {
      debugPrint('Language classification fallback: $e');
      return _fallbackLanguageDetection(text);
    }
  }

  static LanguageDetectionResult _fallbackLanguageDetection(String text) {
    final hasArabicScript = RegExp(r'[\u0600-\u06FF]').hasMatch(text);
    final hasPunjabiScript = RegExp(r'[\u0A00-\u0A7F]').hasMatch(text);

    if (hasPunjabiScript) {
      return LanguageDetectionResult(
        text: text,
        language: 'punjabi',
        confidence: 0.82,
        urduProbability: 0.18,
        punjabiProbability: 0.82,
      );
    }

    if (hasArabicScript) {
      return LanguageDetectionResult(
        text: text,
        language: 'urdu',
        confidence: 0.78,
        urduProbability: 0.78,
        punjabiProbability: 0.22,
      );
    }

    return LanguageDetectionResult(
      text: text,
      language: 'english',
      confidence: 0.55,
      urduProbability: 0.0,
      punjabiProbability: 0.0,
    );
  }

  static String _normalizeLanguage(String language) {
    final value = language.trim().toLowerCase();
    if (value == 'urdu' || value == 'punjabi' || value == 'english') {
      return value;
    }
    return _currentLanguage;
  }

  static String _inferTargetLanguage({
    required String userMessage,
    required String detectedLanguage,
  }) {
    final lower = userMessage.toLowerCase();

    if (lower.contains('urdu') || lower.contains('اردو')) {
      return 'urdu';
    }

    if (lower.contains('punjabi') || lower.contains('پنجابی')) {
      return 'punjabi';
    }

    return detectedLanguage;
  }

  static AssistantIntent _detectIntent(String message) {
    final lower = message.toLowerCase().trim();

    if (lower.isEmpty) {
      return AssistantIntent.general;
    }

    if (lower.contains('translate') ||
        lower.contains('meaning') ||
        lower.contains('what does') ||
        lower.contains('how do you say') ||
        lower.contains('what is') && lower.contains('in')) {
      return AssistantIntent.translation;
    }

    if (lower.contains('grammar') ||
        lower.contains('correct') ||
        lower.contains('check sentence') ||
        lower.contains('is this right')) {
      return AssistantIntent.grammar;
    }

    if (lower.contains('explain') ||
        lower.contains('meaning of') ||
        lower.contains('define') ||
        lower.contains('what does')) {
      return AssistantIntent.explanation;
    }

    if (lower.contains('word') ||
        lower.contains('vocabulary') ||
        lower.contains('similar') ||
        lower.contains('synonym')) {
      return AssistantIntent.vocabulary;
    }

    return AssistantIntent.general;
  }

  /// Builds the ordered list of endpoints to try across ALL configured keys.
  ///
  /// Both `AIza` (AI Studio) and `AQ.` (express) keys work with the free
  /// `generativelanguage.googleapis.com` Developer API via the `x-goog-api-key`
  /// header (no billing required). With multiple keys we get a separate
  /// 20-requests/day free quota per (key × model), so two keys × three models
  /// is effectively ~120 free requests/day.
  ///
  /// Order:
  /// 1. Free Developer API for every (key × model) combination.
  /// 2. Paid Vertex / Agent Platform express endpoint per key (last resort).
  static List<_GeminiEndpoint> _buildEndpoints(List<String> apiKeys) {
    final endpoints = <_GeminiEndpoint>[];

    // Tier 1: free Developer API. Iterate models in the outer loop so we hit
    // every key's flash-lite first (the cheapest model) before stepping up to
    // larger models -- maximizes free quota usage.
    for (final model in _geminiModels) {
      for (final apiKey in apiKeys) {
        endpoints.add(
          _GeminiEndpoint(
            uri: Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/'
              '$model:generateContent',
            ),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            kind: 'developer-api',
            model: model,
          ),
        );
      }
    }

    // Tier 2: paid Vertex / Agent Platform express fallback per key (needs the
    // API enabled + billing). Only reached if every free option is exhausted.
    for (final apiKey in apiKeys) {
      endpoints.add(
        _GeminiEndpoint(
          uri: Uri.parse(
            'https://aiplatform.googleapis.com/v1/publishers/google/models/'
            '${_geminiModels.first}:generateContent?key=$apiKey',
          ),
          headers: const {'Content-Type': 'application/json'},
          kind: 'vertex-express',
          model: _geminiModels.first,
        ),
      );
    }

    return endpoints;
  }

  /// Per-model generation config. Only 2.5 models accept `thinkingConfig`;
  /// sending it to 2.0 models causes a 400, so it is omitted there.
  static Map<String, dynamic> _generationConfig(String model) {
    final config = <String, dynamic>{
      'temperature': 0.7,
      'maxOutputTokens': 600,
    };

    if (model.startsWith('gemini-2.5')) {
      // Disable "thinking" so short answers do not burn the free-tier token
      // budget (saves ~800 tokens per reply) and respond faster.
      config['thinkingConfig'] = {'thinkingBudget': 0};
    }

    return config;
  }

  static Future<String> _generateGeminiResponse({
    required String userMessage,
    required _AssistantClassification classification,
  }) async {
    final geminiApiKeys = EnvConfig.getGeminiApiKeys();
    final endpoints = _buildEndpoints(geminiApiKeys);

    final prompt = _buildPrompt(
      userMessage: userMessage,
      classification: classification,
    );

    final contents = <Map<String, dynamic>>[
      {
        'role': 'user',
        'parts': [
          {'text': prompt.systemInstruction},
        ],
      },
      {
        'role': 'model',
        'parts': [
          {
            'text':
                'Understood. I will answer in the user\'s exact language and follow the tutoring constraints.',
          },
        ],
      },
    ];

    // No conversation history: each question is treated independently to
    // prevent Gemini from hallucinating context from prior turns.

    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt.userRequest},
      ],
    });

    http.Response? response;
    // devError: first real (non-429) failure on the free Developer API - most
    //   useful for surfacing genuine bugs.
    // quotaError: first 429 - means free-tier exhausted (rotate/wait/billing).
    Object? devError;
    Object? quotaError;
    Object? lastError;

    for (final endpoint in endpoints) {
      // Build the body per model so the right generationConfig is used.
      final requestBody = jsonEncode({
        'contents': contents,
        'generationConfig': _generationConfig(endpoint.model),
      });

      try {
        final attempt = await http
            .post(
              endpoint.uri,
              headers: endpoint.headers,
              body: requestBody,
            )
            .timeout(const Duration(seconds: 25));

        if (attempt.statusCode == 200) {
          response = attempt;
          break;
        }

        final body = attempt.body.trim();
        final snippet = body.length > 400 ? body.substring(0, 400) : body;
        final error = Exception(
          'Gemini request failed [${endpoint.kind} ${endpoint.model}]: '
          '${attempt.statusCode}${snippet.isEmpty ? '' : ' | $snippet'}',
        );
        lastError = error;
        if (attempt.statusCode == 429) {
          quotaError ??= error;
        } else if (endpoint.kind == 'developer-api') {
          devError ??= error;
        }
        debugPrint('$error');
      } catch (e) {
        lastError = e;
        if (endpoint.kind == 'developer-api') {
          devError ??= e;
        }
        debugPrint('Gemini endpoint [${endpoint.kind} ${endpoint.model}] error: $e');
      }
    }

    if (response == null) {
      // Priority: a genuine Developer-API failure first, then a free-tier 429
      // (quota exhausted), then anything else. The Vertex fallback's
      // "API not enabled / billing" 403 is never the user's real path, so it is
      // only used as a last resort and never masks the quota message.
      throw devError ??
          quotaError ??
          lastError ??
          Exception('Gemini request failed');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    final content = (candidates != null && candidates.isNotEmpty)
        ? candidates.first['content'] as Map<String, dynamic>?
        : null;
    final parts = content?['parts'] as List<dynamic>?;
    final text = (parts != null && parts.isNotEmpty)
        ? parts.first['text'] as String?
        : null;

    final answer = text?.trim() ?? '';
    if (answer.isEmpty) {
      throw Exception('Gemini returned an empty response');
    }

    return _sanitizeModelText(answer);
  }

  static _AssistantPrompt _buildPrompt({
    required String userMessage,
    required _AssistantClassification classification,
  }) {
    final formatHint = _formatHintForIntent(classification.intent);
    final wantsBothTargets =
        userMessage.toLowerCase().contains('urdu') &&
        userMessage.toLowerCase().contains('punjabi');
    final targetLabel = wantsBothTargets
        ? 'Urdu and Punjabi'
        : _friendlyLanguageName(classification.targetLanguage);

    final systemInstruction = '''
You are a multilingual language tutor for Pakistani Urdu and Pakistani Punjabi.

RULE 0 (MOST IMPORTANT - REPLY LANGUAGE):
Silently detect the language the user wrote their message in, and write your ENTIRE answer in that exact same language and script. Do NOT announce, name, or comment on the language (never write things like "The user wrote in Arabic").
- If the user writes in German, answer fully in German. If Arabic, answer fully in Arabic. If Chinese, answer fully in Chinese. If English, answer in English. If Urdu, answer in Urdu.
- If the user's message is mostly in one language but quotes an Urdu/Punjabi word (even in Arabic script), reply in the language of the user's own words, not the quoted word.
- The only text that may be in another script is the Urdu/Punjabi word being taught (in its native script) plus its romanized pronunciation.
- Do NOT default to English. The classification data below is ONLY used to decide whether the learning target is Urdu or Punjabi; it does NOT tell you which language to reply in.

Other rules:
1. Punjabi MUST always be written in Shahmukhi script (Perso-Arabic, the script used in Pakistani Punjab). NEVER use Gurmukhi (ਗੁਰਮੁਖੀ) script for Punjabi. Urdu is written in its standard Nastaliq/Arabic script.
2. Use Pakistani (Muslim) vocabulary and greetings only. NEVER use Indian-Punjabi or Sikh-specific words such as "Sat Sri Akal", "Waheguru", "ji aaiyan nu". For greetings use "Assalam-o-Alaikum" (السلام علیکم); for "thank you" use "Shukriya" (شکریہ) or "Meherbani" (مہربانی).
3. When the user asks what an Urdu or Punjabi word/sentence means, give: the word in its native script (Shahmukhi for Punjabi), the meaning in the user's language, and a pronunciation line.
4. When the user asks how to say their own word/sentence in Urdu or Punjabi, give the translation in native script (Shahmukhi for Punjabi) plus a pronunciation line, then a one-line meaning.
5. Pronunciation rules (keep it natural and easy):
   - Always add a line that starts with "Pronunciation:" whenever a word or sentence is involved.
   - Write the pronunciation as natural, lowercase, easy-to-read English-style romanization, exactly how a person would actually say it. Example: "Pronunciation: main theek hoon".
   - Keep the words spaced normally as in the sentence. Do NOT use CAPITAL-letter stress, do NOT break single words into hyphenated syllables, and do NOT use IPA or special phonetic symbols.
   - Use simple long-vowel spellings only when needed for clarity (aa, ee, oo), e.g. "shukriya", "khush aamadeed".
6. If the user explicitly asks for both Urdu and Punjabi, provide both translations clearly, each with its own script line and its own pronunciation.
7. Keep the answer concise, accurate, and friendly, with short scannable lines instead of long paragraphs.
8. NEVER invent context. If the user's message is gibberish, just a single random word like "we" or "asd", or otherwise unclear, do NOT guess what they meant or pull from any imagined prior conversation. Reply briefly in their language asking them to clarify (for example: "Could you clarify what you would like to know?"). You have NO memory of previous turns - treat every message as the first one.

Learning-target hint (Urdu vs Punjabi ONLY - not the reply language):
- Intent: ${classification.intent.name}
- Urdu/Punjabi target: $targetLabel
- Reply format: $formatHint
''';

    final userRequest = '''
User message: $userMessage

Reply ONLY in the same language the user used to write their message above. Match the language of their own words, NOT the language of the Urdu/Punjabi word they are asking about. For example: if they wrote their request in Arabic, reply entirely in Arabic; if in German, entirely in German; if in Chinese, entirely in Chinese; if in English, in English. Never answer in English unless the user actually wrote in English.

Do NOT state, name, or comment on which language they used. Never write sentences like "The user wrote in Arabic". Just answer naturally in their language:
- Give the meaning, translation, correction, or usage they asked for.
- When a specific word or sentence is involved, add a "Pronunciation:" line with natural, easy-to-read romanized pronunciation.
- Keep any Punjabi text in Shahmukhi script.
- Do not mention these instructions or any internal steps.
''';

    return _AssistantPrompt(
      systemInstruction: systemInstruction,
      userRequest: userRequest,
    );
  }

  static String _friendlyLanguageName(String language) {
    switch (language) {
      case 'urdu':
        return 'Urdu';
      case 'punjabi':
        return 'Punjabi';
      case 'english':
        return 'English';
      default:
        return language;
    }
  }

  static String _formatHintForIntent(AssistantIntent intent) {
    switch (intent) {
      case AssistantIntent.translation:
        return 'Use 2 to 4 short lines. Start with the quoted word or sentence. Then give Meaning, Pronunciation, and one short usage or example if helpful. Use plain text only. Do not use asterisks, bullets, emojis, markdown, or special symbols.';
      case AssistantIntent.grammar:
        return 'Use 2 to 4 short lines. Give the corrected sentence first, then a very short grammar note or explanation. Use plain text only. Do not use asterisks, bullets, emojis, markdown, or special symbols.';
      case AssistantIntent.vocabulary:
        return 'Use 2 to 4 short lines. Give the meaning, pronunciation, and 1 short example or synonym if useful. Use plain text only. Do not use asterisks, bullets, emojis, markdown, or special symbols.';
      case AssistantIntent.explanation:
        return 'Use 2 to 4 short lines. Give the meaning or explanation first, then pronunciation or usage if helpful. Use plain text only. Do not use asterisks, bullets, emojis, markdown, or special symbols.';
      case AssistantIntent.general:
        return 'Use 2 to 4 short lines. Answer directly and keep it easy to read. Use plain text only. Do not use asterisks, bullets, emojis, markdown, or special symbols.';
    }
  }

  /// Returns a transparent error message when Gemini cannot answer.
  /// No canned/hardcoded "tutoring" answers - this clearly tells the user the
  /// real reason (quota, billing, permission, network) so they know what to do.
  static String _offlineResponse({String? error}) {
    if (_isGeminiQuotaError(error)) {
      return 'Gemini error: free-tier quota exhausted (HTTP 429) on every '
          'configured key. The daily free limit resets ~midnight US-Pacific. '
          'Add another API key in lib/config/api_keys.dart, or enable billing '
          'on the project, then try again.';
    }

    if (_isBillingDisabledError(error)) {
      return 'Gemini error: billing is not enabled for the Google Cloud '
          'project behind this key (BILLING_DISABLED). Enable billing on the '
          'project at console.cloud.google.com, or use a free AI Studio key.';
    }

    if (_isServiceDisabledError(error)) {
      return 'Gemini error: the required API is not enabled on the project '
          '(SERVICE_DISABLED). Enable "Generative Language API" or "Vertex AI '
          'API" in the Google Cloud Console for that project.';
    }

    if (_isPermissionDeniedError(error)) {
      return 'Gemini error: this API key was rejected (PERMISSION_DENIED). '
          'The project may be flagged or the key may be invalid. Generate a '
          'fresh key at aistudio.google.com/apikey.';
    }

    if (_isNetworkError(error)) {
      return 'Network error: could not reach Gemini. Check your internet '
          'connection and try again.';
    }

    final raw = (error == null || error.trim().isEmpty)
        ? 'unknown error'
        : error.trim();
    final snippet = raw.length > 300 ? '${raw.substring(0, 300)}...' : raw;
    return 'Gemini error: $snippet';
  }

  static bool _isNetworkError(String? error) {
    if (error == null || error.isEmpty) return false;
    final lower = error.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('clientexception') ||
        lower.contains('timeout') ||
        lower.contains('handshakeexception') ||
        lower.contains('connection');
  }

  static bool _isGeminiQuotaError(String? error) {
    if (error == null || error.isEmpty) {
      return false;
    }

    final lower = error.toLowerCase();
    return lower.contains('429') ||
        lower.contains('quota') ||
        lower.contains('billing') ||
        lower.contains('rate limits');
  }

  static bool _isBillingDisabledError(String? error) {
    if (error == null || error.isEmpty) {
      return false;
    }

    final lower = error.toLowerCase();
    return lower.contains('billing_disabled') ||
        lower.contains('requires billing to be enabled') ||
        lower.contains('enable billing');
  }

  static bool _isServiceDisabledError(String? error) {
    if (error == null || error.isEmpty) {
      return false;
    }

    final lower = error.toLowerCase();
    return lower.contains('service_disabled') ||
        lower.contains('has not been used in project') ||
        lower.contains('or it is disabled');
  }

  static bool _isPermissionDeniedError(String? error) {
    if (error == null || error.isEmpty) {
      return false;
    }

    final lower = error.toLowerCase();
    return lower.contains('permission_denied') ||
        lower.contains('denied access') ||
        lower.contains('403');
  }

  static void _trimHistory() {
    if (_conversationHistory.length <= 12) {
      return;
    }

    _conversationHistory.removeRange(
      0,
      _conversationHistory.length - 12,
    );
  }

  static List<Map<String, String>> _recentHistory() {
    return List<Map<String, String>>.from(_conversationHistory);
  }

  static String _sanitizeModelText(String text) {
    return text
        .replaceAll(RegExp(r'[*_`~]'), '')
        .replaceAll(RegExp(r'^[•\-–—]+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .trim();
  }

  static void clearHistory() {
    _conversationHistory.clear();
  }

  static List<Map<String, String>> getHistory() {
    return List<Map<String, String>>.from(_conversationHistory);
  }

  static List<String> getSuggestions(int userLevel) {
    if (userLevel <= 3) {
      return [
        'Start with basic greetings',
        'Learn common phrases',
        'Practice pronunciation daily',
        'Use flashcards for vocabulary',
      ];
    }

    if (userLevel <= 7) {
      return [
        'Build conversational sentences',
        'Learn verb conjugations',
        'Practice with native speakers',
        'Watch movies with subtitles',
      ];
    }

    return [
      'Read Urdu and Punjabi literature',
      'Write short essays',
      'Engage in debates',
      'Teach others what you have learned',
    ];
  }

  static String getHint(String question, String language) {
    if (question.toLowerCase().contains('translate')) {
      return 'Think about the word order: $language often uses SOV structure.';
    }

    if (question.toLowerCase().contains('pronounce')) {
      return 'Break the word into syllables and practice each part.';
    }

    return 'Take your time and think about what you have learned.';
  }
}

class _AssistantClassification {
  final AssistantIntent intent;
  final String detectedLanguage;
  final String targetLanguage;
  final double confidence;

  _AssistantClassification({
    required this.intent,
    required this.detectedLanguage,
    required this.targetLanguage,
    required this.confidence,
  });
}

class _AssistantPrompt {
  final String systemInstruction;
  final String userRequest;

  _AssistantPrompt({
    required this.systemInstruction,
    required this.userRequest,
  });
}

class _GeminiEndpoint {
  final Uri uri;
  final Map<String, String> headers;
  final String kind;
  final String model;

  _GeminiEndpoint({
    required this.uri,
    required this.headers,
    required this.kind,
    required this.model,
  });
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class LearningRecommendationService {
  static List<String> getRecommendations({
    required int completedLessons,
    required int totalPoints,
    required int streak,
    required String weakestArea,
  }) {
    final recommendations = <String>[];

    if (streak == 0) {
      recommendations.add('Start a daily learning streak today!');
    } else if (streak < 7) {
      recommendations.add('Keep going! $streak day streak - aim for 7 days!');
    } else {
      recommendations.add(
        'Amazing! $streak day streak! You are making great progress!',
      );
    }

    if (totalPoints < 100) {
      recommendations.add('Complete more lessons to earn XP points!');
    } else if (totalPoints < 500) {
      recommendations.add('Great progress! Keep earning points!');
    }

    if (weakestArea.isNotEmpty) {
      recommendations.add('Focus on $weakestArea to improve faster');
    }

    if (completedLessons % 5 == 0 && completedLessons > 0) {
      recommendations.add('Time to practice what you have learned!');
    }

    return recommendations;
  }

  static String getDifficultyLevel(double accuracy) {
    if (accuracy >= 0.9) return 'Expert';
    if (accuracy >= 0.75) return 'Advanced';
    if (accuracy >= 0.6) return 'Intermediate';
    if (accuracy >= 0.4) return 'Beginner';
    return 'Novice';
  }
}

enum AssistantIntent {
  translation,
  grammar,
  vocabulary,
  explanation,
  general,
}

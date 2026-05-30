import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with SingleTickerProviderStateMixin {
  static const String _geminiApiKey = String.fromEnvironment(
    'GCP_API_KEY',
    defaultValue: '',
  );
  static const String _systemPrompt =
      'You are a helpful, friendly multilingual language tutor. Automatically detect the user\'s input language (Urdu, Punjabi, Roman Urdu, Roman Punjabi, or English), understand their question or problem, and reply to them naturally and fluently using that exact same language and script. If they speak in Urdu, reply in Urdu. If they speak in Punjabi, reply in Punjabi. If they speak in Roman Urdu or Roman Punjabi, reply in Roman Urdu or Roman Punjabi. If they speak in English, reply in English. Keep your explanations simple, short, and clear.';

  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final List<Map<String, String>> _messages = <Map<String, String>>[];
  final ScrollController _scrollController = ScrollController();

  late final AnimationController _micAnimationController;
  late final Animation<double> _micPulseAnimation;

  bool _isListening = false;
  bool _isSending = false;
  bool _speechEnabled = false;
  String _lastFinalTranscript = '';
  String _speechLocaleId = 'en_US';

  @override
  void initState() {
    super.initState();
    _micAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _micPulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _micAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _messages.add(<String, String>{
      'role': 'assistant',
      'text': 'Assalam-o-Alaikum! Main aap ka Urdu aur Punjabi coach hoon. Mic dabaiye aur bolna shuru kijiye.',
    });

    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted) {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isListening = false);
        _showSnackBar(
          error.errorMsg.isNotEmpty
              ? error.errorMsg
              : 'Speech recognition error',
        );
      },
    );

    await _configureTtsForLanguage('en');
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _toggleListening() async {
    if (_isSending) return;

    if (_isListening) {
      await _speechToText.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      return;
    }

    if (!_speechEnabled) {
      _showSnackBar('Speech recognition is not available on this device.');
      return;
    }

    setState(() {
      _isListening = true;
      _lastFinalTranscript = '';
    });

    await _speechToText.listen(
      localeId: _speechLocaleId,
      listenFor: const Duration(seconds: 25),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) {
        if (!result.finalResult) {
          return;
        }

        final transcript = result.recognizedWords.trim();
        if (transcript.isEmpty || transcript == _lastFinalTranscript) {
          return;
        }

        _lastFinalTranscript = transcript;
        unawaited(_speechToText.stop());

        if (mounted) {
          setState(() => _isListening = false);
        }

        unawaited(_sendMessage(transcript));
      },
    );
  }

  Future<void> _sendMessage(String text) async {
    final input = text.trim();
    if (input.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _messages.add(<String, String>{'role': 'user', 'text': input});
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final responseText = await _requestGeminiResponse(input);
      if (!mounted) return;

      setState(() {
        _messages.add(<String, String>{
          'role': 'assistant',
          'text': responseText,
        });
        _isSending = false;
      });
      _scrollToBottom();

      await _applyLanguageMode(responseText);
      await _flutterTts.stop();
      await _flutterTts.speak(responseText);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _messages.add(<String, String>{
          'role': 'assistant',
          'text': 'Maaf kijiye, abhi jawab generate nahi ho saka. Dobara koshish karein.',
        });
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  Future<String> _requestGeminiResponse(String prompt) async {
    // Stable direct endpoint for gemini-2.5-flash on v1beta
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_geminiApiKey',
    );

    // 1. Build the conversation log mapping safely (No unsupported payload fields)
    final List<Map<String, dynamic>> structuredContents = [];

    // Prime the chat with the system prompt as a normal user turn so the server accepts the payload.
    structuredContents.add({
      'role': 'user',
      'parts': [
        {'text': 'System Instruction: $_systemPrompt'}
      ]
    });

    structuredContents.add({
      'role': 'model',
      'parts': [
        {'text': 'Understood. I will act as your multilingual tutor.'}
      ]
    });

    for (final msg in _messages) {
      final String textContent = (msg['text'] ?? '').trim();
      if (textContent.isEmpty) continue;

      // Skip the initial placeholder greeting message so it doesn't pollute the history context
      if (textContent.startsWith('Assalam-o-Alaikum! Main aap ka Urdu')) continue;

      structuredContents.add({
        'role': msg['role'] == 'user' ? 'user' : 'model',
        'parts': [
          {'text': textContent}
        ]
      });
    }

    // 2. Add the user's latest spoken microphone input line
    structuredContents.add({
      'role': 'user',
      'parts': [
        {'text': prompt.trim()}
      ]
    });

    // 2. Package only the contents payload; the API has rejected explicit system instruction fields.
    final Map<String, dynamic> jsonPayload = {
      'contents': structuredContents,
    };

    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(jsonPayload),
    );

    debugPrint('Gemini status: ${response.statusCode}');
    debugPrint('Gemini response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      final content = candidates?.first?['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final text = parts?.first?['text'] as String?;
      return (text == null || text.trim().isEmpty) ? 'No text generated' : text.trim();
    } else {
      throw Exception('Server rejected request with status: ${response.statusCode}');
    }
  }

  Future<void> _applyLanguageMode(String text) async {
    final languageCode = _detectLanguageCode(text);
    _speechLocaleId = languageCode == 'ur'
        ? 'ur_PK'
        : languageCode == 'pa'
            ? 'pa_IN'
            : 'en_US';
    await _configureTtsForLanguage(languageCode);
  }

  String _detectLanguageCode(String text) {
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) {
      return 'ur';
    }

    if (RegExp(r'[\u0A00-\u0A7F]').hasMatch(text)) {
      return 'pa';
    }

    final lowered = text.toLowerCase();
    if (lowered.contains('tusi') ||
        lowered.contains('tuha') ||
        lowered.contains('ki haal') ||
        lowered.contains('ki haal hai') ||
        lowered.contains('haan ji') ||
        lowered.contains('nahin')) {
      return 'pa';
    }

    if (lowered.contains('aap') ||
        lowered.contains('kya') ||
        lowered.contains('kyun') ||
        lowered.contains('main') ||
        lowered.contains('hai')) {
      return 'ur';
    }

    return 'en';
  }

  Future<void> _configureTtsForLanguage(String languageCode) async {
    final locale = languageCode == 'ur'
        ? 'ur-PK'
        : languageCode == 'pa'
            ? 'pa-IN'
            : 'en-US';

    try {
      await _flutterTts.setLanguage(locale);
    } catch (_) {
      await _flutterTts.setLanguage('en-US');
    }

    await _flutterTts.setSpeechRate(languageCode == 'ur' ? 0.47 : 0.5);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _micAnimationController.dispose();
    _scrollController.dispose();
    _speechToText.stop();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('AI Regional Tutor'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _ChatBubble(
                    text: message['text'] ?? '',
                    isUser: message['role'] == 'user',
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _micPulseAnimation,
                    builder: (context, child) {
                      final scale = _isListening ? _micPulseAnimation.value : 1.0;
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: GestureDetector(
                      onTap: _toggleListening,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isListening
                                ? const [Color(0xFFFF5A7A), Color(0xFFFF8A5B)]
                                : const [Color(0xFF4F84FF), Color(0xFF82EEFD)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening
                                      ? const Color(0xFFFF5A7A)
                                      : const Color(0xFF4F84FF))
                                  .withOpacity(0.35),
                              blurRadius: 22,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isListening ? 'Listening...' : 'Tap to speak',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (_isSending) ...<Widget>[
                    const SizedBox(height: 10),
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const _ChatBubble({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF4F84FF) : const Color(0xFFF2F6FF),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF1C2430),
            fontSize: 15,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../services/ai_assistant_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final List<_ChatItem> _messages = <_ChatItem>[];

  bool _isSending = false;
  bool _isListening = false;
  bool _speechEnabled = false;
  bool _isTyping = false;
  String _lastFinalTranscript = '';

  /// Voice input language chosen by the user. 'auto' uses the device default.
  String _voiceLanguage = 'auto';
  List<String> _availableLocaleIds = const [];

  static const Map<String, String> _voiceLanguageLabels = {
    'auto': 'Auto (device)',
    'en': 'English',
    'ur': 'Urdu',
    'pa': 'Punjabi',
    'ar': 'Arabic',
    'de': 'German',
    'zh': 'Chinese',
  };

  @override
  void initState() {
    super.initState();
    AIAssistantService.clearHistory();
    _messages.add(
      const _ChatItem(
        role: _ChatRole.assistant,
        text:
            'Asalam o Alikum Ask me in any language i am here to assist you',
      ),
    );
    _messages.add(
      const _ChatItem(
        role: _ChatRole.assistant,
        text:
            'Examples: What does "Main theek hoon" mean? | Explain this Punjabi sentence | Translate this Urdu line to Arabic | What does "i am fine" mean in Urdu and Punjabi?',
      ),
    );
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

    if (_speechEnabled) {
      try {
        final locales = await _speechToText.locales();
        _availableLocaleIds = locales.map((l) => l.localeId).toList();
      } catch (_) {
        _availableLocaleIds = const [];
      }
    }

    await _flutterTts.setPitch(1.0);
    if (mounted) setState(() {});
  }

  /// Default IETF locale id for each voice-language option. Used when the
  /// recognizer (e.g. on Chrome/web) doesn't expose an `_availableLocaleIds`
  /// list - in those cases we just pass the IETF id directly and the browser
  /// honors it if it can.
  static const Map<String, String> _defaultLocaleIds = {
    'en': 'en-US',
    'ur': 'ur-PK',
    'pa': 'pa-PK',
    'ar': 'ar-SA',
    'de': 'de-DE',
    'zh': 'zh-CN',
  };

  /// Resolve the locale id to pass to the recognizer.
  /// Returns null only for "Auto" (let the system pick).
  String? _resolveSpeechLocaleId() {
    if (_voiceLanguage == 'auto') {
      return null;
    }

    final normalized = _voiceLanguage.toLowerCase();

    // Try matching against device-installed locales first (prefers regional
    // variants users actually have, e.g. ur_PK over ur).
    if (_availableLocaleIds.isNotEmpty) {
      for (final id in _availableLocaleIds) {
        final prefix = id.toLowerCase().split(RegExp(r'[_-]')).first;
        if (prefix == normalized) {
          return id;
        }
      }
    }

    // Fall back to a sensible default IETF id - this is what makes voice work
    // on Chrome/web where the locale list is often empty even though the
    // browser supports the language.
    return _defaultLocaleIds[normalized];
  }

  Future<void> _sendText([String? override, String? ttsLanguageOverride]) async {
    final input = (override ?? _controller.text).trim();
    if (input.isEmpty || _isSending) {
      return;
    }

    // For voice input we already know the spoken language, so trust it for
    // text-to-speech (more reliable than guessing German vs English by script).
    final inputLanguageCode = ttsLanguageOverride ?? _detectLanguageCode(input);

    setState(() {
      _messages.add(_ChatItem(role: _ChatRole.user, text: input));
      _isSending = true;
      _isTyping = true;
    });
    _controller.clear();
    _focusNode.unfocus();
    _scrollToBottom();

    try {
      final responseText = await AIAssistantService.getResponse(input);
      if (!mounted) return;

      setState(() {
        _messages.add(_ChatItem(role: _ChatRole.assistant, text: responseText));
        _isSending = false;
        _isTyping = false;
      });
      _scrollToBottom();

      await _speakResponse(responseText, inputLanguageCode);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          _ChatItem(
            role: _ChatRole.assistant,
            text: 'Error: $e',
          ),
        );
        _isSending = false;
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _speakResponse(String responseText, String languageCode) async {
    final locale = switch (languageCode) {
      'ur' => 'ur-PK',
      'pa' => 'pa-IN',
      'ar' => 'ar-SA',
      'zh' => 'zh-CN',
      'de' => 'de-DE',
      _ => 'en-US',
    };

    try {
      await _flutterTts.setLanguage(locale);
    } catch (_) {
      await _flutterTts.setLanguage('en-US');
    }

    await _flutterTts.setSpeechRate(languageCode == 'ur' ? 0.47 : 0.5);
    await _flutterTts.stop();
    await _flutterTts.speak(_sanitizeForSpeech(responseText));
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
      localeId: _resolveSpeechLocaleId(),
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

        final ttsLang = _voiceLanguage == 'auto' ? null : _voiceLanguage;
        unawaited(_sendText(transcript, ttsLang));
      },
    );
  }

  void _applySuggestion(String text) {
    _controller
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
    _focusNode.requestFocus();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  String _detectLanguageCode(String text) {
    if (RegExp(r'[\u4E00-\u9FFF]').hasMatch(text)) {
      return 'zh';
    }

    if (RegExp(r'[\u0A00-\u0A7F]').hasMatch(text)) {
      return 'pa';
    }

    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) {
      if (RegExp(r'[ڑڈٹچپگھ]').hasMatch(text)) {
        return 'ur';
      }
      return 'ar';
    }

    // Best-effort German detection for Latin text (umlauts / common words).
    final lower = text.toLowerCase();
    if (RegExp(r'[äöüß]').hasMatch(lower) ||
        RegExp(r'\b(was|bedeutet|wie|sagt|ich|bin|auf|der|die|das|und|nicht|heißt)\b')
            .hasMatch(lower)) {
      return 'de';
    }

    return 'en';
  }

  String _sanitizeForSpeech(String text) {
    return text
        .replaceAll(RegExp(r'[*_`~]'), '')
        .replaceAll(RegExp(r'^[•\-–—]+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _speechToText.stop();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const suggestions = <String>[
      'What does "Main theek hoon" mean?',
      'Explain this Punjabi sentence',
      'Translate this Urdu line to Arabic',
      'Was bedeutet der Satz "tusi kithay ho"?',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F15),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('AI Regional Tutor'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Voice input language',
            icon: const Icon(Icons.record_voice_over_rounded),
            color: const Color(0xFF111827),
            onSelected: (value) => setState(() => _voiceLanguage = value),
            itemBuilder: (context) => _voiceLanguageLabels.entries
                .map(
                  (entry) => PopupMenuItem<String>(
                    value: entry.key,
                    child: Row(
                      children: [
                        Icon(
                          _voiceLanguage == entry.key
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 18,
                          color: _voiceLanguage == entry.key
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          entry.value,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF111827),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1F2937)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ask me in any language',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Examples: What does "Main theek hoon" mean? | Explain this Punjabi sentence | Translate this Urdu line to Arabic | What does "i am fine" mean in Urdu and Punjabi?',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: suggestions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return ActionChip(
                          label: Text(
                            suggestions[index],
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: const Color(0xFF1F2937),
                          side: const BorderSide(color: Color(0xFF334155)),
                          onPressed: () => _applySuggestion(suggestions[index]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isTyping && index == _messages.length) {
                    return const _TypingBubble();
                  }

                  return _ChatBubble(item: _messages[index]);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0B0F15),
                border: Border(top: BorderSide(color: Color(0xFF1F2937))),
              ),
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                    onTap: _toggleListening,
                    background: _isListening
                        ? const LinearGradient(
                            colors: [Color(0xFFFB7185), Color(0xFFF97316)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onSubmitted: (_) => _sendText(),
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        cursorColor: Colors.white,
                        // Opt out of the global inputDecorationTheme (filled +
                        // outline border) so the typed white text stays visible
                        // on the dark container in both light and dark themes.
                        decoration: const InputDecoration(
                          filled: false,
                          hintText: 'Ask meaning, usage, grammar, or translation',
                          hintStyle: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _CircleIconButton(
                    icon: Icons.send_rounded,
                    onTap: _sendText,
                    background: const LinearGradient(
                      colors: [Color(0xFF60A5FA), Color(0xFF22C55E)],
                    ),
                  ),
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
  final _ChatItem item;

  const _ChatBubble({required this.item});

  @override
  Widget build(BuildContext context) {
    final isUser = item.role == _ChatRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          item.text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF111827),
            fontSize: 14,
            height: 1.34,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Typing...',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final LinearGradient background;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: background,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

enum _ChatRole { user, assistant }

class _ChatItem {
  final _ChatRole role;
  final String text;

  const _ChatItem({required this.role, required this.text});
}

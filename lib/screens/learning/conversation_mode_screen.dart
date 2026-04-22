import 'package:flutter/material.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/language_detection_service.dart';
import '../../services/voice_service.dart';
import '../../themes/app_theme.dart';

class ConversationModeScreen extends StatefulWidget {
  const ConversationModeScreen({super.key});

  @override
  State<ConversationModeScreen> createState() => _ConversationModeScreenState();
}

class _ConversationModeScreenState extends State<ConversationModeScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final LanguageDetectionService _detector = LanguageDetectionService();
  final List<_ConversationMessage> _messages = [];

  bool _isLoading = false;
  bool _isListening = false;
  String _detected = '';

  final List<String> _scenarioPrompts = const [
    'Start a greeting conversation in Urdu',
    'Practice buying food in Punjabi',
    'Teach me polite phrases for travel',
    'Correct my sentence grammar and continue chat',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      const _ConversationMessage(
        text:
            'Conversation Mode ready. Pick a scenario or start chatting in Urdu/Punjabi/English.',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final message = text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(_ConversationMessage(text: message, isUser: true));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final detected = await _detector.detectLanguage(message);
      final response = await AIAssistantService.getResponse(message);

      if (!mounted) return;
      setState(() {
        _detected =
            'Detected: ${detected.language} (${(detected.confidence * 100).round()}%)';
        _messages.add(_ConversationMessage(text: response, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();

      final ok = await VoiceService.speak(response, detected.language);
      if (!ok && mounted && VoiceService.lastTtsError.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(VoiceService.lastTtsError)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ConversationMessage(text: 'Conversation error: $e', isUser: false),
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
    });

    final result = await VoiceService.listen(
      language: 'urdu',
      onStart: () {},
      onResult: (_) {},
      onStop: () {
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      },
    );

    if (result != null && result.trim().isNotEmpty) {
      await _send(result);
    }

    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversation Mode')),
      body: Column(
        children: [
          if (_detected.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.blue.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(_detected),
            ),
          SizedBox(
            height: 54,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _scenarioPrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return ActionChip(
                  label: Text(_scenarioPrompts[index]),
                  onPressed: () => _send(_scenarioPrompts[index]),
                );
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final item = _messages[index];
                return Align(
                  alignment: item.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: item.isUser
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(item.text),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                IconButton(
                  onPressed: _isListening ? null : _startListening,
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.red : null,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: _send,
                    cursorColor: AppTheme.primaryGreen,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.textLight
                          : AppTheme.textDark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type your conversation message...',
                      hintStyle: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryGreen,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.darkSurfaceVariant
                          : Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _send(_controller.text),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationMessage {
  final String text;
  final bool isUser;

  const _ConversationMessage({required this.text, required this.isUser});
}

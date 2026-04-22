import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/voice_service.dart';
import '../../providers/user_provider.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          text:
              'Hello! I\'m here to help you with Urdu or Punjabi. Ask me anything about the language!',
          isUser: false,
        ),
      );
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    _textController.clear();
    _scrollToBottom();

    try {
      final response = await AIAssistantService.getResponse(text);
      setState(() {
        _messages.add(ChatMessage(text: response, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();

      // Speak the response
      final ok = await VoiceService.speak(response, 'en-US');
      if (!ok && mounted && VoiceService.lastTtsError.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(VoiceService.lastTtsError)));
      }
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Sorry, I encountered an error. Please try again.',
            isUser: false,
          ),
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _startListening() async {
    setState(() => _isListening = true);

    final result = await VoiceService.listen(
      language: 'en-US',
      onStart: () {
        print('Listening started...');
      },
      onResult: (text) {
        if (text.isNotEmpty) {
          _sendMessage(text);
        }
      },
      onStop: () {
        setState(() => _isListening = false);
      },
    );

    if (result != null && result.isNotEmpty) {
      _sendMessage(result);
    }

    setState(() => _isListening = false);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() {
                _messages.clear();
                AIAssistantService.clearHistory();
                _addWelcomeMessage();
              });
            },
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Learning recommendations banner
          _buildRecommendationsBanner(userProvider),

          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),

          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildRecommendationsBanner(UserProvider userProvider) {
    final user = userProvider.currentUser;
    final recommendations = LearningRecommendationService.getRecommendations(
      completedLessons: 5, // TODO: Track from database
      totalPoints: user?.points ?? 0,
      streak: 0, // TODO: Track from database
      weakestArea: 'Pronunciation', // TODO: Calculate from user data
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade100, Colors.blue.shade100],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Learning Tips',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...recommendations
              .take(2)
              .map(
                (rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(rec, style: const TextStyle(fontSize: 12)),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue.shade500 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: message.isUser ? Colors.white70 : Colors.black45,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Quick action buttons
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _sendMessage('Give me learning tips');
            },
            tooltip: 'Get tips',
          ),

          // Text input
          Expanded(
            child: TextField(
              controller: _textController,
              cursorColor: AppTheme.primaryGreen,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.textLight
                    : AppTheme.textDark,
              ),
              decoration: InputDecoration(
                hintText: 'Ask me anything...',
                hintStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryGreen,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkSurfaceVariant
                    : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: _sendMessage,
              textInputAction: TextInputAction.send,
            ),
          ),

          const SizedBox(width: 8),

          // Voice input button
          IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? Colors.red : null,
            ),
            onPressed: _isListening ? null : _startListening,
            tooltip: 'Voice input',
          ),

          // Send button
          IconButton(
            icon: const Icon(Icons.send),
            color: Colors.blue,
            onPressed: () => _sendMessage(_textController.text),
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

/// Quick action suggestions widget
class QuickActionChips extends StatelessWidget {
  final Function(String) onActionSelected;

  const QuickActionChips({super.key, required this.onActionSelected});

  @override
  Widget build(BuildContext context) {
    final actions = [
      {'label': 'Translate', 'query': 'How do I translate this?'},
      {'label': 'Pronunciation', 'query': 'Help me with pronunciation'},
      {'label': 'Grammar', 'query': 'Explain grammar rules'},
      {'label': 'Culture', 'query': 'Tell me about Pakistani culture'},
    ];

    return Wrap(
      spacing: 8,
      children: actions.map((action) {
        return ActionChip(
          label: Text(action['label']!),
          onPressed: () => onActionSelected(action['query']!),
          backgroundColor: Colors.blue.shade50,
        );
      }).toList(),
    );
  }
}

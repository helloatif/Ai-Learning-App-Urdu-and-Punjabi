import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../services/ai_assistant_service.dart';
import '../../services/voice_service.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  bool _isListening = false;
  bool _isSpeaking = false;
  String _recognizedText = '';
  String _assistantResponse = '';
  String _targetPhrase = '';
  PronunciationAnalysis? _analysis;

  final List<Map<String, String>> _urduPhrases = const [
    {'word': 'السلام علیکم', 'english': 'Peace be upon you', 'emoji': '👋'},
    {'word': 'شکریہ', 'english': 'Thank you', 'emoji': '🙏'},
    {'word': 'براہ کرم', 'english': 'Please', 'emoji': '📍'},
    {'word': 'معافی چاہتا ہوں', 'english': 'I am sorry', 'emoji': '😔'},
    {'word': 'کیسے ہو؟', 'english': 'How are you?', 'emoji': '🤔'},
    {'word': 'میرا نام...ہے', 'english': 'My name is...', 'emoji': '📝'},
  ];

  final List<Map<String, String>> _punjabiPhrases = const [
    {'word': 'ست سری اکال', 'english': 'Hello (Sikh greeting)', 'emoji': '👋'},
    {'word': 'شکریہ', 'english': 'Thank you', 'emoji': '🙏'},
    {'word': 'مہربانی نال', 'english': 'Please', 'emoji': '📍'},
    {'word': 'معاف کرو', 'english': 'Sorry', 'emoji': '😔'},
    {'word': 'کی حال اے؟', 'english': 'How are you?', 'emoji': '🤔'},
    {'word': 'میرا ناں...اے', 'english': 'My name is...', 'emoji': '📝'},
  ];

  @override
  void initState() {
    super.initState();
    VoiceService.initialize();
  }

  @override
  void dispose() {
    VoiceService.stop();
    super.dispose();
  }

  Future<void> _startListening(String language) async {
    setState(() {
      _isListening = true;
      _recognizedText = '';
      _analysis = null;
    });

    final result = await VoiceService.listen(
      language: language,
      onStart: () {},
      onResult: (text) {
        if (!mounted) return;
        setState(() {
          _recognizedText = text;
        });
      },
      onStop: () {
        if (!mounted) return;
        setState(() {
          _isListening = false;
        });
      },
    );

    if (!mounted || result == null || result.trim().isEmpty) {
      return;
    }

    setState(() {
      _recognizedText = result;
    });

    if (_targetPhrase.isNotEmpty) {
      final analysis = await PronunciationService.analyzePronunciation(
        expected: _targetPhrase,
        spoken: result,
        language: language,
      );
      if (!mounted) return;
      setState(() {
        _analysis = analysis;
      });
    }

    await _generateResponse(language);
  }

  Future<void> _generateResponse(String language) async {
    setState(() {
      _isSpeaking = true;
      _assistantResponse = language == 'urdu'
          ? 'جواب تیار ہو رہا ہے...'
          : '...';
    });

    try {
      final response = await AIAssistantService.getResponse(_recognizedText);
      if (!mounted) return;
      setState(() {
        _assistantResponse = response;
        _isSpeaking = false;
      });
      await VoiceService.speak(response, language);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _assistantResponse = 'Could not generate response.';
        _isSpeaking = false;
      });
    }
  }

  Future<void> _speakResponse(String language) async {
    if (_assistantResponse.isEmpty) return;
    setState(() {
      _isSpeaking = true;
    });
    await VoiceService.speak(_assistantResponse, language);
    if (!mounted) return;
    setState(() {
      _isSpeaking = false;
    });
  }

  Widget _dot() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryGreen.withValues(alpha: 0.7),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language =
        Provider.of<UserProvider>(context).currentUser?.selectedLanguage ??
        'urdu';
    final phrases = language == 'urdu' ? _urduPhrases : _punjabiPhrases;

    return Scaffold(
      appBar: AppBar(title: const Text('Learn by Voice')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening
                          ? AppTheme.primaryGreen
                          : AppTheme.lightGreen,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: _isListening ? 8 : 0,
                        ),
                      ],
                    ),
                    child: Icon(Icons.mic, size: 60, color: AppTheme.white),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _recognizedText.isEmpty
                        ? 'Tap record and speak'
                        : _recognizedText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_assistantResponse.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryGreen),
                      ),
                      child: _isSpeaking
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _dot(),
                                const SizedBox(width: 8),
                                _dot(),
                                const SizedBox(width: 8),
                                _dot(),
                              ],
                            )
                          : Text(_assistantResponse),
                    ),
                ],
              ),
            ),
            if (_analysis != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pronunciation Score: ${_analysis!.score}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('ML Similarity: ${_analysis!.mlSimilarity}%'),
                    Text('Phoneme Accuracy: ${_analysis!.phonemeAccuracy}%'),
                    Text(
                      'Lexical Similarity: ${_analysis!.lexicalSimilarity}%',
                    ),
                    const SizedBox(height: 6),
                    Text(_analysis!.feedback),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isListening
                          ? null
                          : () => _startListening(language),
                      icon: Icon(_isListening ? Icons.stop : Icons.mic),
                      label: Text(_isListening ? 'Listening...' : 'Record'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_assistantResponse.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _speakResponse(language),
                        icon: const Icon(Icons.volume_up),
                        label: const Text('Listen Again'),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: phrases.length,
                itemBuilder: (context, index) {
                  final phrase = phrases[index];
                  return Card(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _targetPhrase = phrase['word']!;
                          _recognizedText = phrase['word']!;
                          _assistantResponse =
                              '${phrase['emoji']} ${phrase['english']}';
                          _analysis = null;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              phrase['emoji']!,
                              style: const TextStyle(fontSize: 30),
                            ),
                            const SizedBox(height: 8),
                            Text(phrase['word']!, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

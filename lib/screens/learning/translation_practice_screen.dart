import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../services/language_detection_service.dart';
import '../../services/translation_service.dart';
import '../../services/voice_service.dart';

class TranslationPracticeScreen extends StatefulWidget {
  const TranslationPracticeScreen({super.key});

  @override
  State<TranslationPracticeScreen> createState() =>
      _TranslationPracticeScreenState();
}

class _TranslationPracticeScreenState extends State<TranslationPracticeScreen> {
  final TextEditingController _inputController = TextEditingController();
  final TranslationService _translationService = TranslationService();
  final LanguageDetectionService _languageDetectionService =
      LanguageDetectionService();

  String _targetLanguage = 'english';
  String _detectedLanguage = 'unknown';
  double _confidence = 0.0;
  String _translatedText = '';
  String _verification = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _verification = '';
    });

    try {
      final detected = await _languageDetectionService.detectLanguage(text);
      final sourceLanguage = detected.language;

      final result = await _translationService.translate(
        text: text,
        from: sourceLanguage,
        to: _targetLanguage,
      );

      final verification = await _translationService.verifyTranslation(
        originalText: text,
        translatedText: result.translatedText,
        sourceLanguage: sourceLanguage,
        targetLanguage: _targetLanguage,
      );

      if (!mounted) return;
      setState(() {
        _detectedLanguage = sourceLanguage;
        _confidence = detected.confidence;
        _translatedText = result.translatedText;
        _verification =
            'Back-translation reliability: ${(verification.verificationScore * 100).round()}%';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _translatedText = 'Translation failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _speakOutput() async {
    if (_translatedText.isEmpty) return;
    await VoiceService.speak(_translatedText, _targetLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final userLanguage =
        Provider.of<UserProvider>(context).currentUser?.selectedLanguage ??
        'urdu';

    return Scaffold(
      appBar: AppBar(title: const Text('Translation Practice')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _inputController,
              minLines: 2,
              maxLines: 4,
              cursorColor: AppTheme.primaryGreen,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.textLight
                    : AppTheme.textDark,
              ),
              decoration: InputDecoration(
                labelText: 'Enter text to translate',
                hintStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryGreen,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Target:'),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _targetLanguage,
                  items: const [
                    DropdownMenuItem(value: 'english', child: Text('English')),
                    DropdownMenuItem(value: 'urdu', child: Text('Urdu')),
                    DropdownMenuItem(value: 'punjabi', child: Text('Punjabi')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _targetLanguage = value;
                    });
                  },
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _translate,
                  icon: const Icon(Icons.translate),
                  label: const Text('Translate'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading) const LinearProgressIndicator(),
            if (_detectedLanguage != 'unknown')
              Text(
                'Detected: $_detectedLanguage (${(_confidence * 100).round()}%)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 8),
            if (_translatedText.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _translatedText,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            if (_verification.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_verification),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _translatedText.isEmpty ? null : _speakOutput,
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Speak Translation'),
                ),
                const SizedBox(width: 8),
                Text('Learning language: $userLanguage'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

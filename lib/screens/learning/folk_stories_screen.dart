import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/user_provider.dart';
import '../../services/folk_story_service.dart';
import '../../services/voice_service.dart';
import '../../themes/app_theme.dart';

class FolkStoriesScreen extends StatefulWidget {
  const FolkStoriesScreen({super.key});

  @override
  State<FolkStoriesScreen> createState() => _FolkStoriesScreenState();
}

class _FolkStoriesScreenState extends State<FolkStoriesScreen> {
  bool _isLoading = false;
  bool _isSpeaking = false;
  String _storyText = '';
  String _englishTranslation = '';
  String _storyLanguage = 'urdu';
  int _requestId = 0;

  Future<void> _generateStory() async {
    final int currentRequestId = ++_requestId;
    final String selectedLanguage =
        context.read<UserProvider>().currentUser?.selectedLanguage ?? 'urdu';
    final String previousStoryBeforeGenerate = _storyText;

    setState(() {
      _isLoading = true;
      _storyText = '';
      _englishTranslation = '';
    });

    try {
      FolkStoryResult? result;
      String? previousForRetry = previousStoryBeforeGenerate.isEmpty
          ? null
          : previousStoryBeforeGenerate;

      for (int attempt = 0; attempt < 3; attempt++) {
        final candidate = await FolkStoryService.generateFolkStory(
          language: selectedLanguage,
          variationSeed:
              '${DateTime.now().microsecondsSinceEpoch}_${attempt + 1}',
          previousStory: previousForRetry,
        );

        result = candidate;

        final isDuplicate =
            previousForRetry != null &&
          candidate.urduStory.trim() == previousForRetry.trim();

        if (!isDuplicate) {
          break;
        }
        previousForRetry = candidate.urduStory;
      }

      if (result == null) {
        return;
      }
      final resolvedResult = result;

      if (!mounted || currentRequestId != _requestId) return;

      setState(() {
        _storyText = resolvedResult.urduStory;
        _englishTranslation = resolvedResult.englishTranslation;
        _storyLanguage = selectedLanguage;
      });
    } finally {
      if (mounted && currentRequestId == _requestId) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _speakStory() async {
    if (_storyText.isEmpty || _isSpeaking) return;

    setState(() {
      _isSpeaking = true;
    });

    try {
      final cleanForTts = FolkStoryService.cleanTextForTts(_storyText);
      await VoiceService.speak(cleanForTts, _storyLanguage);
    } finally {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLanguage =
      context.watch<UserProvider>().currentUser?.selectedLanguage ?? 'urdu';
    final isPunjabiMode = selectedLanguage == 'punjabi';
    final storyTitle = isPunjabiMode ? 'Punjabi Story (Shahmukhi)' : 'Urdu Story';
    final introText = isPunjabiMode
      ? 'Generate a short Punjabi folk story in Shahmukhi with 3 to 5 lines\nPunjabi is generated with Sarvam and transliterated from Gurmukhi to Shahmukhi'
      : 'Generate a short Urdu folk story with 3 to 5 lines\nNo punctuation is used for clean TTS playback';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightGray,
      appBar: AppBar(
        title: const Text('Folk Stories'),
        backgroundColor: isDark ? AppTheme.darkSurface : scheme.primary,
        foregroundColor: isDark ? AppTheme.textLight : Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? AppTheme.darkSurfaceVariant
                        : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  introText,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _isLoading ? null : _generateStory,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isLoading ? 'Generating...' : 'Generate Story'),
              ),
              if (_isLoading) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  'Generating new story and translation...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_storyText.isEmpty || _isSpeaking)
                          ? null
                          : _speakStory,
                      icon: Icon(_isSpeaking ? Icons.volume_off : Icons.volume_up),
                      label: Text(_isSpeaking ? 'Speaking...' : 'Speak Story'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StoryCard(
                        title: storyTitle,
                        content: _storyText.isEmpty
                            ? 'Tap Generate Story to start'
                            : _storyText,
                        isDark: isDark,
                        isRtl: true,
                      ),
                      const SizedBox(height: 12),
                      _StoryCard(
                        title: 'English Translation',
                        content: _englishTranslation.isEmpty
                            ? 'Translation will appear here'
                            : _englishTranslation,
                        isDark: isDark,
                        isRtl: false,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final String title;
  final String content;
  final bool isDark;
  final bool isRtl;

  const _StoryCard({
    required this.title,
    required this.content,
    required this.isDark,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppTheme.darkSurfaceVariant : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            content,
            style: Theme.of(context).textTheme.bodyLarge,
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}

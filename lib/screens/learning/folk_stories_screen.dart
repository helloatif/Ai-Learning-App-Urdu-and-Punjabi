import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart';

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

  // Runtime dynamic references to prevent import version mismatches
  dynamic _riveController;
  dynamic _nightInput;
  bool _forceNightMode = false; // Dedicated layout controller tracking state

  @override
  void initState() {
    super.initState();

    VoiceService.onTtsStart = () {
      if (!mounted) return;
      setState(() {
        _forceNightMode = true;
        if (_nightInput != null) {
          try {
            _nightInput.value = true;
          } catch (_) {}
        }
      });
    };

    VoiceService.onTtsComplete = () {
      if (!mounted) return;
      setState(() {
        _forceNightMode = false;
        if (_nightInput != null) {
          try {
            _nightInput.value = false;
          } catch (_) {}
        }
      });
    };
  }

  Future<void> _generateStory() async {
    final int currentRequestId = ++_requestId;
    final String selectedLanguage =
        context.read<UserProvider>().currentUser?.selectedLanguage ?? 'urdu';
    final String previousStoryBeforeGenerate = _storyText;

    setState(() {
      _isLoading = true;
      _storyText = '';
      _englishTranslation = '';
      _forceNightMode = false; // Step 2: force Day during generation
      // 2. Click Generate: ensure Night is turned off (Day layout)
      try {
        _nightInput?.value = false;
      } catch (_) {}
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
    } finally { // Fixed spelling from finaly to finally
      if (mounted && currentRequestId == _requestId) {
        setState(() {
          _isLoading = false;
          // Ensure Night input is turned off when generation finishes
          try {
            _nightInput?.value = false;
          } catch (e) {
            // ignore: avoid_print
            print('Failed to clear Night input: $e');
          }
        });
      }
    }
  }

  Future<void> _speakStory() async {
    if (_storyText.isEmpty || _isSpeaking) return;

    setState(() {
      _isSpeaking = true;
      _forceNightMode = true; // Lock layout to Night mode manually on tap
      // 3. Click Speak Story: indicate speaking state. Rive Night mode will
      // be toggled by the native TTS start/completion handlers.
    });

    try {
      final cleanForTts = FolkStoryService.cleanTextForTts(_storyText);
      final ok = await VoiceService.speak(cleanForTts, _storyLanguage);
      if (!ok && mounted && VoiceService.lastTtsError.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(VoiceService.lastTtsError)));
      }
    } finally { // Fixed spelling from finaly to finally
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          // Note: On mobile devices, native onTtsComplete will handle clearing this.
          // On Web, if you want it to drop back to Day mode only when user stops/navigates,
          // keep this flag true while audio track synthesis plays.
        });
      }
    }
  }

  @override
  void dispose() {
    // Unbind hooks to avoid leaking references if the screen is removed.
    VoiceService.onTtsStart = null;
    VoiceService.onTtsComplete = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedLanguage =
      context.watch<UserProvider>().currentUser?.selectedLanguage ?? 'urdu';
    final isPunjabiMode = selectedLanguage == 'punjabi';
    final storyTitle = isPunjabiMode ? 'Punjabi Story (Shahmukhi)' : 'Urdu Story';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightGray,
      appBar: AppBar(
        title: Text(
          'Folk Stories',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
          ),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : scheme.primary,
        foregroundColor: isDark ? AppTheme.textLight : Colors.white,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── TOP AREA: EDGE-TO-EDGE RIVE ANIMATION (NO WHITE SPACES) ───
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.35,
              width: double.infinity,
              child: RiveWidgetBuilder(
                fileLoader: FileLoader.fromAsset(
                  'assets/icons/animations/517-983-mix-it-up.riv',
                  riveFactory: Factory.rive,
                ),
                builder: (context, state) {
                  if (state is RiveLoaded) {
                    _riveController = state.controller;
                    final sm = state.controller.stateMachine;
                    if (sm != null) {
                      try {
                        final dynamic inputs = (sm as dynamic).inputs;
                        if (inputs != null) {
                          for (final i in inputs) {
                            if ((i as dynamic).name == 'Night') {
                              _nightInput = i;
                              // Aggressively bind the state to the active asset instance
                              _nightInput.value = _forceNightMode;
                              break;
                            }
                          }
                        }
                      } catch (_) {}
                    }

                    return RiveWidget(
                      controller: state.controller,
                      // Using the Rive library enum directly to scale edge-to-edge
                      // while preserving the background input listeners safely.
                      fit: Fit.cover, 
                    );
                  }
                  if (state is RiveLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return const Center(child: Icon(Icons.error));
                },
              ),
            ),

            // ─── BOTTOM AREA: ACTIONS AND SCROLLABLE CONTENT ───
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _generateStory,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        _isLoading ? 'Generating...' : 'Generate Story',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
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
                            icon: Image.asset(
                              'assets/icons/3dicons-megaphone-dynamic-color.png',
                              width: 18,
                              height: 18,
                            ),
                            label: Text(
                              _isSpeaking ? 'Speaking...' : 'Speak Story',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
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
                              // Bold+italic ONLY for:
                              // - "Punjabi Story (Shahmukhi)" (i.e., Punjbai Story) when Punjabi mode
                              // - "Tap Generate Story to start" placeholder when story is empty
                              titleBoldItalic: isPunjabiMode,
                              contentBoldItalic: _storyText.isEmpty,
                            ),
                            const SizedBox(height: 12),
                            _StoryCard(
                              title: 'English Translation',
                              content: _englishTranslation.isEmpty
                                  ? 'Translation will appear here'
                                  : _englishTranslation,
                              isDark: isDark,
                              isRtl: false,
                              titleBoldItalic: true,
                              contentBoldItalic: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

  // Only applied for the "English Translation" box per requirements
  final bool titleBoldItalic;
  final bool contentBoldItalic;

  const _StoryCard({
    required this.title,
    required this.content,
    required this.isDark,
    required this.isRtl,
    this.titleBoldItalic = false,
    this.contentBoldItalic = false,
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
              fontWeight: titleBoldItalic ? FontWeight.w700 : null,
              fontStyle: titleBoldItalic ? FontStyle.italic : null,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            content,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight:
                  contentBoldItalic ? FontWeight.w700 : null,
              fontStyle: contentBoldItalic ? FontStyle.italic : null,
            ),
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}
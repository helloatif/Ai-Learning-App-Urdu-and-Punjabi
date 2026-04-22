import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../services/chapter_service.dart';
import '../../services/voice_service.dart';
import '../../services/word_recommendation_service.dart';
import '../../services/ml_vocabulary_service.dart';
import '../../data/vocabulary_data.dart';
import '../../providers/learning_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/user_provider.dart';

/// Clean lesson screen - Teaching only with TTS (no quizzes, no user input)
/// User learns 25 words/sentences per lesson
class TeachingLessonScreen extends StatefulWidget {
  final ChapterModel chapter;
  final int lessonIndex;
  final LessonVocabulary lesson;

  const TeachingLessonScreen({
    super.key,
    required this.chapter,
    required this.lessonIndex,
    required this.lesson,
  });

  @override
  State<TeachingLessonScreen> createState() => _TeachingLessonScreenState();
}

class _TeachingLessonScreenState extends State<TeachingLessonScreen>
    with TickerProviderStateMixin {
  int _currentWordIndex = 0;
  bool _showTranslation = false;
  bool _isSpeaking = false;
  bool _lessonDone = false;
  bool _xpWasAwarded = false;
  List<VocabWord> _lessonWords = [];
  bool _isLoadingMlWords = true;
  String? _mlLoadError;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    // Initialize TTS
    VoiceService.initialize();

    // Try to replace static words with ML-generated words from XLM-RoBERTa.
    _loadLessonWordsFromMl();

    // Auto-speak first word after a delay
    Future.delayed(const Duration(milliseconds: 500), _speakWord);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    VoiceService.stop();
    super.dispose();
  }

  Future<void> _loadLessonWordsFromMl() async {
    try {
      final predictions = await MLVocabularyService.generateVocabularyWithML(
        chapterId: widget.chapter.id,
        lessonIndex: widget.lessonIndex,
        language: widget.chapter.language,
        count: 25,
      );

      if (!mounted) return;

      if (predictions.isNotEmpty) {
        final mlWords = predictions
            .map(
              (p) => VocabWord(
                urdu: p.word,
                english: p.translation,
                pronunciation: p.pronunciation,
                exampleSentence: p.example ?? p.word,
                exampleEnglish: p.exampleTranslation ?? p.translation,
              ),
            )
            .toList();

        setState(() {
          _lessonWords = mlWords;
          _currentWordIndex = 0;
          _mlLoadError = null;
          _isLoadingMlWords = false;
        });
        return;
      }

      setState(() {
        _lessonWords = [];
        _isLoadingMlWords = false;
        _mlLoadError =
            'XLM-RoBERTa did not return lesson words. Please try again.';
      });
      return;
    } catch (e) {
      debugPrint('Lesson content load failed: $e');
      if (!mounted) return;
      setState(() {
        _lessonWords = [];
        _isLoadingMlWords = false;
        _mlLoadError = 'Failed to load lesson from XLM-RoBERTa.';
      });
      return;
    }
  }

  VocabWord get _currentWord => _lessonWords[_currentWordIndex];
  double get _progress => (_currentWordIndex + 1) / _lessonWords.length;
  bool get _isLastWord => _currentWordIndex >= _lessonWords.length - 1;

  Future<void> _speakWord() async {
    if (_isSpeaking) return;
    setState(() => _isSpeaking = true);
    HapticFeedback.lightImpact();

    final ok = await VoiceService.speak(
      _currentWord.urdu,
      widget.chapter.language,
    );
    if (!ok && mounted && VoiceService.lastTtsError.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(VoiceService.lastTtsError)));
    }

    if (mounted) {
      setState(() => _isSpeaking = false);
    }
  }

  Future<void> _speakSentence() async {
    if (_isSpeaking || !_currentWord.hasSentence) return;
    setState(() => _isSpeaking = true);
    HapticFeedback.lightImpact();

    final ok = await VoiceService.speak(
      _currentWord.exampleSentence!,
      widget.chapter.language,
    );
    if (!ok && mounted && VoiceService.lastTtsError.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(VoiceService.lastTtsError)));
    }

    if (mounted) {
      setState(() => _isSpeaking = false);
    }
  }

  void _nextWord() {
    if (_currentWordIndex < _lessonWords.length - 1) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentWordIndex++;
        _showTranslation = false;
      });
      // Auto-speak the new word
      Future.delayed(const Duration(milliseconds: 300), _speakWord);
    }
  }

  void _previousWord() {
    if (_currentWordIndex > 0) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentWordIndex--;
        _showTranslation = false;
      });
    }
  }

  void _completeLesson() async {
    debugPrint('>>> _completeLesson CALLED');
    HapticFeedback.heavyImpact();

    final lp = Provider.of<LearningProvider>(context, listen: false);
    final gp = Provider.of<GamificationProvider>(context, listen: false);

    // Only award XP if this lesson hasn't been completed before
    final alreadyCompleted = lp.isLessonCompleted(
      widget.chapter.id,
      widget.lessonIndex,
    );

    if (!alreadyCompleted) {
      gp.addPoints(10);
      gp.completeLesson();
      gp.updateDailyStreak();
    }

    // Mark lesson as completed
    await lp.markLessonCompleted(widget.chapter.id, widget.lessonIndex);

    debugPrint('>>> markLessonCompleted done, mounted=$mounted');
    if (!mounted) return;

    debugPrint('>>> calling _showCompletionDialog');
    _showCompletionDialog(xpAwarded: !alreadyCompleted);
  }

  void _showCompletionDialog({bool xpAwarded = true}) {
    debugPrint('>>> _showCompletionDialog: setting _lessonDone=true');
    setState(() {
      _lessonDone = true;
      _xpWasAwarded = xpAwarded;
    });
  }

  Widget _buildCompletionOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (c, v, ch) => Transform.scale(scale: v, child: ch),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🎉', style: TextStyle(fontSize: 44)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Lesson Complete!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'You learned ${_lessonWords.length} words',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: (_xpWasAwarded ? AppTheme.orange : Colors.grey)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _xpWasAwarded ? Icons.bolt : Icons.check_circle,
                      color: _xpWasAwarded ? AppTheme.orange : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _xpWasAwarded ? '+10 XP' : 'Already completed',
                      style: TextStyle(
                        color: _xpWasAwarded ? AppTheme.orange : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    debugPrint('>>> CONTINUE BUTTON PRESSED - popping screen');
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.chapter.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingMlWords && _lessonWords.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_lessonWords.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lesson')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _mlLoadError ??
                      'No lesson content available from XLM-RoBERTa.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isLoadingMlWords = true;
                      _mlLoadError = null;
                    });
                    _loadLessonWordsFromMl();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Load'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: (d) {
                      final velocity = d.primaryVelocity ?? 0;
                      if (velocity < -200) _nextWord();
                      if (velocity > 200) _previousWord();
                    },
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildProgressIndicator(),
                          const SizedBox(height: 24),
                          _buildWordCard(),
                          const SizedBox(height: 20),
                          _buildSpeakButton(),
                          const SizedBox(height: 20),
                          _buildTranslationCard(),
                          const SizedBox(height: 20),
                          if (_currentWord.hasSentence) _buildSentenceCard(),
                          const SizedBox(height: 20),
                          _buildRelatedWordsCard(),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildNavigationBar(),
              ],
            ),
          ),
          if (_lessonDone) _buildCompletionOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userProvider = Provider.of<UserProvider>(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showExitDialog(),
            icon: Icon(
              Icons.close,
              color: isDark
                  ? AppTheme.textLight.withOpacity(0.78)
                  : Colors.black54,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.lesson.titleEnglish,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Lesson ${widget.lessonIndex + 1} • ${_currentWordIndex + 1}/${_lessonWords.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.textLight.withOpacity(0.72)
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildTopBarAvatar(userProvider),
        ],
      ),
    );
  }

  Widget _buildTopBarAvatar(UserProvider userProvider) {
    final selectedAvatar = userProvider.selectedAvatar;

    if (selectedAvatar == null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primaryGreen.withOpacity(0.12),
        ),
        child: const Icon(Icons.face, size: 22, color: AppTheme.primaryGreen),
      );
    }

    final avatarPath = selectedAvatar == 'female'
        ? 'assets/images/10491839.jpg'
        : 'assets/images/9440461.jpg';

    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: Image.asset(
          avatarPath,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) => Container(
            color: AppTheme.primaryGreen.withOpacity(0.12),
            child: const Icon(Icons.face, size: 22, color: AppTheme.primaryGreen),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: _progress,
            backgroundColor: isDark
                ? AppTheme.darkSurfaceVariant
                : Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(widget.chapter.color),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_lessonWords.length, (i) {
              final isActive = i == _currentWordIndex;
              final isPast = i < _currentWordIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: isActive ? 12 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? widget.chapter.color
                      : isPast
                      ? widget.chapter.color.withOpacity(0.5)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildWordCard() {
    return TweenAnimationBuilder<double>(
      key: ValueKey('word_$_currentWordIndex'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: 0.9 + 0.1 * value,
        child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.chapter.color,
              widget.chapter.color.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: widget.chapter.color.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              _currentWord.urdu,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'NotoNastaliqUrdu',
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _currentWord.pronunciation,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeakButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return GestureDetector(
          onTap: _speakWord,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: _isSpeaking
                  ? widget.chapter.color.withOpacity(0.1)
                  : (isDark ? AppTheme.darkSurface : Colors.white),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: widget.chapter.color.withOpacity(
                  _isSpeaking ? 0.5 + _pulseController.value * 0.3 : 0.3,
                ),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isSpeaking ? Icons.volume_up : Icons.volume_up_outlined,
                  color: widget.chapter.color,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _isSpeaking ? 'Playing...' : 'Listen to Pronunciation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.chapter.color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTranslationCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _showTranslation = !_showTranslation);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _showTranslation
              ? widget.chapter.color.withOpacity(0.08)
              : (isDark ? AppTheme.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _showTranslation
                ? widget.chapter.color.withOpacity(0.3)
                : (isDark
                      ? AppTheme.darkSurfaceVariant
                      : Colors.grey.shade200),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _showTranslation ? Icons.lightbulb : Icons.lightbulb_outline,
                  color: _showTranslation ? AppTheme.orange : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _showTranslation
                      ? 'English Translation'
                      : 'Tap to reveal meaning',
                  style: TextStyle(
                    fontSize: 14,
                    color: _showTranslation
                        ? widget.chapter.color
                        : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedCrossFade(
              firstChild: Text(
                '• • •',
                style: TextStyle(fontSize: 24, color: Colors.grey.shade300),
              ),
              secondChild: Text(
                _currentWord.english,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textLight : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              crossFadeState: _showTranslation
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentenceCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkSurfaceVariant : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.format_quote,
                  color: AppTheme.purple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Example Sentence',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.purple,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _speakSentence,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.chapter.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isSpeaking ? Icons.volume_up : Icons.volume_up_outlined,
                    color: widget.chapter.color,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currentWord.exampleSentence!,
            style: const TextStyle(
              fontSize: 20,
              fontFamily: 'NotoNastaliqUrdu',
              height: 1.6,
            ),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          Text(
            _currentWord.exampleEnglish!,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppTheme.textLight.withOpacity(0.75)
                  : Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Build related words card using semantic recommendations
  Widget _buildRelatedWordsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<List<WordRecommendation>>(
      future: WordRecommendationService().findSimilarWords(
        word: _currentWord.urdu,
        language: widget.chapter.language,
        count: 3,
        minSimilarity: 0.3,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final relatedWords = snapshot.data!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.blue.shade600,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Related Words',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: relatedWords.map((rec) {
                  return Chip(
                    label: Text(
                      rec.word.urdu,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: isDark
                        ? AppTheme.darkSurface
                        : Colors.white,
                    side: BorderSide(color: Colors.blue.shade200),
                    onDeleted: null,
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavigationBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentWordIndex > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previousWord,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.chapter.color,
                  side: BorderSide(color: widget.chapter.color),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox()),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isLastWord ? _completeLesson : _nextWord,
              icon: Icon(
                _isLastWord ? Icons.check : Icons.arrow_forward_rounded,
              ),
              label: Text(_isLastWord ? 'Complete' : 'Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.chapter.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Lesson?'),
        content: const Text('Your progress in this lesson will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }
}

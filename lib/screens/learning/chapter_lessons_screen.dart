import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../services/chapter_service.dart';
import '../../services/ml_vocabulary_service.dart';
import '../../data/vocabulary_data.dart';
import '../../providers/learning_provider.dart';
import '../../services/quiz_generator_service.dart';
import 'teaching_lesson_screen.dart';
import 'chapter_quiz_screen.dart';

/// Premium chapter lessons screen with learning path
class ChapterLessonsScreen extends StatefulWidget {
  final ChapterModel chapter;
  const ChapterLessonsScreen({super.key, required this.chapter});
  @override
  State<ChapterLessonsScreen> createState() => _ChapterLessonsScreenState();
}

class _ChapterLessonsScreenState extends State<ChapterLessonsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<LessonVocabulary> _lessons = [];
  bool _isLoadingLessons = true;
  String _loadError = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _controller.forward();
    _loadLessonsFromMl();
  }

  Future<void> _loadLessonsFromMl() async {
    setState(() {
      _isLoadingLessons = true;
      _loadError = '';
    });

    try {
      final lessonCount = widget.chapter.lessonCount;
      final generatedLessons = <LessonVocabulary>[];

      for (int lessonIdx = 0; lessonIdx < lessonCount; lessonIdx++) {
        final predictions = await MLVocabularyService.generateVocabularyWithML(
          chapterId: widget.chapter.id,
          lessonIndex: lessonIdx,
          language: widget.chapter.language,
          count: 25,
        );

        if (predictions.isEmpty) {
          continue;
        }

        final words = predictions
            .map(
              (p) => VocabWord(
                urdu: p.word,
                english: p.translation,
                pronunciation: p.pronunciation,
                exampleSentence: p.example ?? p.word,
                exampleEnglish: p.translation,
              ),
            )
            .toList();

        generatedLessons.add(
          LessonVocabulary(
            lessonNumber: lessonIdx + 1,
            title: 'ML Lesson ${lessonIdx + 1}',
            titleEnglish: widget.chapter.topics.length > lessonIdx
                ? widget.chapter.topics[lessonIdx]
                : 'Lesson ${lessonIdx + 1}',
            words: words,
          ),
        );
      }

      if (!mounted) return;

      if (generatedLessons.isEmpty) {
        setState(() {
          _lessons = [];
          _loadError =
              'XLM-RoBERTa did not return chapter lesson content. Please retry.';
          _isLoadingLessons = false;
        });
        return;
      }

      setState(() {
        _lessons = generatedLessons;
        _isLoadingLessons = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lessons = [];
        _loadError = 'Failed to load chapter lessons from XLM-RoBERTa.';
        _isLoadingLessons = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLessons) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_lessons.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.chapter.titleEnglish)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError.isNotEmpty
                      ? _loadError
                      : 'No lesson data returned by XLM-RoBERTa.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _loadLessonsFromMl,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry ML Load'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final learningProvider = Provider.of<LearningProvider>(context);
    final completedLessons = learningProvider.getCompletedLessonsCount(
      widget.chapter.id,
    );
    final progress = _lessons.isEmpty
        ? 0.0
        : (completedLessons / _lessons.length).clamp(0.0, 1.0);
    final totalWords = _lessons.fold<int>(0, (sum, l) => sum + l.words.length);
    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // ─── HEADER ───
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: widget.chapter.color,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.chapter.color,
                      widget.chapter.color.withOpacity(0.7),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            // Circular progress ring
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: CircularProgressIndicator(
                                      value: progress,
                                      strokeWidth: 5,
                                      backgroundColor: Colors.white.withOpacity(
                                        0.2,
                                      ),
                                      valueColor: const AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    widget.chapter.icon,
                                    size: 26,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.chapter.titleEnglish,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    widget.chapter.title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                      fontFamily: 'NotoNastaliqUrdu',
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${(progress * 100).toInt()}% complete • $totalWords words',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── CHAPTER STATS ───
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                children: [
                  _statCard(
                    Icons.menu_book,
                    '${_lessons.length}',
                    'Lessons',
                    widget.chapter.color,
                  ),
                  _statCard(
                    Icons.text_fields,
                    '$totalWords',
                    'Words',
                    AppTheme.blue,
                  ),
                  _divider(),
                  _statCard(
                    Icons.chat_bubble_outline,
                    '$totalWords',
                    'Sentences',
                    AppTheme.purple,
                  ),
                  _divider(),
                  _statCard(
                    Icons.timer,
                    '~${_lessons.length * 5}m',
                    'Time',
                    AppTheme.orange,
                  ),
                ],
              ),
            ),
          ),

          // ─── WHAT YOU'LL LEARN ───
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.chapter.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.lightbulb_outline,
                          color: widget.chapter.color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'What you\'ll learn',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.chapter.topics
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.chapter.color.withOpacity(0.08),
                                  widget.chapter.color.withOpacity(0.04),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: widget.chapter.color.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 13,
                                color: widget.chapter.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),

          // ─── LEARNING PATH HEADER ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.chapter.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.route,
                      color: widget.chapter.color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Learning Path',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppTheme.textLight
                          : Colors.grey.shade800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$completedLessons/${_lessons.length} done',
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.chapter.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── LESSON CARDS ───
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index >= _lessons.length) return null;
                final lesson = _lessons[index];
                final isLocked = index > 0 && completedLessons < index;
                final isCompleted = completedLessons > index;
                final isCurrent = !isLocked && !isCompleted;

                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: Duration(milliseconds: 400 + (index * 100)),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  ),
                  child: _PremiumLessonCard(
                    lesson: lesson,
                    lessonNumber: index + 1,
                    chapter: widget.chapter,
                    isLocked: isLocked,
                    isCompleted: isCompleted,
                    isCurrent: isCurrent,
                    onTap: isLocked
                        ? null
                        : () => _navigateToLesson(context, index, lesson),
                  ),
                );
              }, childCount: _lessons.length),
            ),
          ),

          // ─── CHAPTER QUIZ ───
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _buildQuizButton(progress),
            ),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark
                  ? AppTheme.textLight.withOpacity(0.72)
                  : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 1,
      height: 40,
      color: isDark ? AppTheme.darkSurfaceVariant : Colors.grey.shade200,
    );
  }

  Widget _buildQuizButton(double progress) {
    final canTakeQuiz = progress >= 0.999;
    final learningProvider = Provider.of<LearningProvider>(
      context,
      listen: false,
    );
    final quizScore = learningProvider.getChapterQuizScore(widget.chapter.id);
    final quizPassed = learningProvider.isChapterQuizPassed(widget.chapter.id);

    return GestureDetector(
      onTap: canTakeQuiz ? () => _startChapterQuiz(context) : null,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: canTakeQuiz
              ? LinearGradient(
                  colors: quizPassed
                      ? [Colors.green, Colors.green.shade600]
                      : [
                          widget.chapter.color,
                          widget.chapter.color.withOpacity(0.8),
                        ],
                )
              : null,
          color: canTakeQuiz ? null : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          boxShadow: canTakeQuiz
              ? [
                  BoxShadow(
                    color: (quizPassed ? Colors.green : widget.chapter.color)
                        .withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (canTakeQuiz ? Colors.white : Colors.grey).withOpacity(
                  0.2,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                quizPassed ? Icons.check_circle : Icons.quiz,
                color: canTakeQuiz ? Colors.white : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chapter Quiz ($chapterQuizQuestionCount Questions)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: canTakeQuiz ? Colors.white : Colors.grey,
                    ),
                  ),
                  Text(
                    quizPassed
                        ? 'Passed with ${quizScore?.toInt()}%! ✓'
                        : quizScore != null
                        ? 'Score: ${quizScore.toInt()}% - Need 80% to pass'
                        : canTakeQuiz
                        ? 'Score 80%+ to unlock next chapter'
                        : 'Complete all lessons to unlock',
                    style: TextStyle(
                      fontSize: 12,
                      color: canTakeQuiz ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              canTakeQuiz
                  ? (quizPassed ? Icons.replay : Icons.arrow_forward_rounded)
                  : Icons.lock_outline,
              color: canTakeQuiz ? Colors.white : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToLesson(
    BuildContext context,
    int index,
    LessonVocabulary lesson,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeachingLessonScreen(
          chapter: widget.chapter,
          lessonIndex: index,
          lesson: lesson,
        ),
      ),
    ).then(
      (_) => setState(() {
        // Keep ML-loaded lessons; only UI/progress state refresh is needed.
      }),
    );
  }

  void _startChapterQuiz(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterQuizScreen(chapter: widget.chapter),
      ),
    );
  }
}

/// Premium lesson card with enhanced visuals
class _PremiumLessonCard extends StatelessWidget {
  final LessonVocabulary lesson;
  final int lessonNumber;
  final ChapterModel chapter;
  final bool isLocked;
  final bool isCompleted;
  final bool isCurrent;
  final VoidCallback? onTap;

  const _PremiumLessonCard({
    required this.lesson,
    required this.lessonNumber,
    required this.chapter,
    required this.isLocked,
    required this.isCompleted,
    required this.isCurrent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isLocked
                  ? (isDark
                        ? AppTheme.darkSurfaceVariant.withOpacity(0.28)
                        : Colors.grey.shade50)
                  : (isDark ? AppTheme.darkSurface : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCompleted
                    ? AppTheme.primaryGreen
                    : isCurrent
                    ? chapter.color
                    : (isDark
                          ? AppTheme.darkSurfaceVariant
                          : Colors.grey.shade200),
                width: isCurrent
                    ? 2
                    : isCompleted
                    ? 2
                    : 1,
              ),
              boxShadow: isLocked
                  ? []
                  : [
                      BoxShadow(
                        color: (isCurrent ? chapter.color : Colors.black)
                            .withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Lesson number with status
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: isCompleted
                        ? const LinearGradient(
                            colors: [
                              AppTheme.primaryGreen,
                              AppTheme.lightGreen,
                            ],
                          )
                        : isCurrent
                        ? LinearGradient(
                            colors: [
                              chapter.color,
                              chapter.color.withOpacity(0.7),
                            ],
                          )
                        : null,
                    color: isLocked ? Colors.grey.shade200 : null,
                    shape: BoxShape.circle,
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: chapter.color.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: isLocked
                        ? const Icon(Icons.lock, color: Colors.grey, size: 20)
                        : isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 26,
                          )
                        : Text(
                            '$lessonNumber',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                // Lesson info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lesson.titleEnglish,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isLocked
                                    ? Colors.grey
                                    : (isDark ? onSurface : Colors.black87),
                              ),
                            ),
                          ),
                          if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '✓ Done',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: chapter.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Start →',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: chapter.color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lesson.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: isLocked
                              ? Colors.grey.shade400
                              : (isDark
                                    ? AppTheme.textLight.withOpacity(0.72)
                                    : Colors.black45),
                          fontFamily: 'NotoNastaliqUrdu',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _infoPill(
                            Icons.text_fields,
                            '${lesson.words.length} words',
                            isLocked ? Colors.grey : chapter.color,
                          ),
                          const SizedBox(width: 8),
                          _infoPill(
                            Icons.chat_bubble_outline,
                            '${lesson.words.where((w) => w.hasSentence).length} sentences',
                            isLocked ? Colors.grey : AppTheme.blue,
                          ),
                          const SizedBox(width: 8),
                          _infoPill(
                            Icons.timer,
                            '~5 min',
                            isLocked ? Colors.grey : AppTheme.orange,
                          ),
                        ],
                      ),
                      // Word preview
                      if (!isLocked) ...[
                        const SizedBox(height: 8),
                        Text(
                          lesson.words.take(4).map((w) => w.urdu).join(' • '),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppTheme.textLight.withOpacity(0.55)
                                : Colors.black26,
                            fontFamily: 'NotoNastaliqUrdu',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoPill(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withOpacity(0.7)),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: color.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

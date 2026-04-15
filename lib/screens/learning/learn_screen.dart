import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../providers/learning_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/chapter_service.dart';
import 'chapter_lessons_screen.dart';

/// Main Learn Screen with Chapter-wise Learning Path
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerAnimation;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );
    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LearningProvider, UserProvider>(
      builder: (context, learning, user, _) {
        final selectedLanguage = user.user?.selectedLanguage ?? 'urdu';
        final baseChapters = ChapterService.getChapters(selectedLanguage);
        final List<ChapterModel> chapters = [];

        for (int i = 0; i < baseChapters.length; i++) {
          final base = baseChapters[i];
          final completedLessons = learning.getCompletedLessonsCount(base.id);
          final progress = base.lessonCount == 0
              ? 0.0
              : (completedLessons / base.lessonCount).clamp(0.0, 1.0);

          final previousQuizPassed = i == 0
              ? true
              : learning.isChapterQuizPassed(baseChapters[i - 1].id);
          final unlocked = !base.isLocked || previousQuizPassed;

          chapters.add(
            ChapterModel(
              id: base.id,
              title: base.title,
              titleEnglish: base.titleEnglish,
              description: base.description,
              language: base.language,
              icon: base.icon,
              color: base.color,
              lessonCount: base.lessonCount,
              topics: base.topics,
              isLocked: !unlocked,
              progress: progress,
              completedLessons: completedLessons,
            ),
          );
        }

        final overallProgress = ChapterService.calculateOverallProgress(
          chapters,
        );

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // Animated Header
              SliverAppBar(
                expandedHeight: 200,
                floating: false,
                pinned: true,
                backgroundColor: AppTheme.primaryGreen,
                flexibleSpace: FlexibleSpaceBar(
                  background: AnimatedBuilder(
                    animation: _headerAnimation,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryGreen,
                              AppTheme.primaryGreen.withOpacity(0.8),
                              Colors.teal,
                            ],
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Language Badge
                                FadeTransition(
                                  opacity: _headerAnimation,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.language,
                                          size: 16,
                                          color: AppTheme.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          selectedLanguage == 'urdu'
                                              ? '🇵🇰 Learning Urdu'
                                              : '🇵🇰 Learning Punjabi',
                                          style: const TextStyle(
                                            color: AppTheme.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Title
                                SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(-0.5, 0),
                                    end: Offset.zero,
                                  ).animate(_headerAnimation),
                                  child: const Text(
                                    'Your Learning Path',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.white,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // Progress Bar
                                FadeTransition(
                                  opacity: _headerAnimation,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${(overallProgress * 100).toInt()}% Complete',
                                            style: TextStyle(
                                              color: AppTheme.white.withOpacity(
                                                0.9,
                                              ),
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            '${chapters.where((c) => c.progress == 1.0).length}/${chapters.length} Chapters',
                                            style: TextStyle(
                                              color: AppTheme.white.withOpacity(
                                                0.9,
                                              ),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: LinearProgressIndicator(
                                          value: overallProgress,
                                          backgroundColor: AppTheme.white
                                              .withOpacity(0.3),
                                          valueColor:
                                              const AlwaysStoppedAnimation(
                                                AppTheme.white,
                                              ),
                                          minHeight: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Chapter Cards
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index >= chapters.length) return null;
                    final chapter = chapters[index];
                    final isLast = index == chapters.length - 1;

                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 400 + (index * 100)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 50 * (1 - value)),
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: Column(
                        children: [
                          _ChapterCard(
                            chapter: chapter,
                            chapterNumber: index + 1,
                            language: selectedLanguage,
                            onTap: chapter.isLocked
                                ? null
                                : () => _navigateToChapter(context, chapter),
                          ),
                          if (!isLast) const _PathConnector(),
                        ],
                      ),
                    );
                  }, childCount: chapters.length),
                ),
              ),

              // Bottom padding
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        );
      },
    );
  }

  void _navigateToChapter(BuildContext context, ChapterModel chapter) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ChapterLessonsScreen(chapter: chapter),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: Curves.easeInOut));
          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}

/// Chapter Card Widget
class _ChapterCard extends StatelessWidget {
  final ChapterModel chapter;
  final int chapterNumber;
  final String language;
  final VoidCallback? onTap;

  const _ChapterCard({
    required this.chapter,
    required this.chapterNumber,
    required this.language,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = chapter.progress == 1.0;
    final isLocked = chapter.isLocked;
    final progressColor = _getProgressColor(chapter.progress);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isLocked ? Colors.grey.shade200 : AppTheme.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCompleted
                  ? AppTheme.primaryGreen
                  : progressColor.withOpacity(0.3),
              width: isCompleted ? 3 : 2,
            ),
            boxShadow: isLocked
                ? []
                : [
                    BoxShadow(
                      color: progressColor.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Chapter Icon
              _ChapterIcon(
                icon: chapter.icon,
                color: chapter.color,
                isLocked: isLocked,
                isCompleted: isCompleted,
                progress: chapter.progress,
              ),

              const SizedBox(width: 16),

              // Chapter Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chapter Number
                    Text(
                      'CHAPTER $chapterNumber',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isLocked ? Colors.grey : chapter.color,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Title
                    Text(
                      chapter.titleEnglish,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isLocked ? Colors.grey : Colors.black87,
                      ),
                    ),

                    // Native Title
                    Text(
                      chapter.title,
                      style: TextStyle(
                        fontSize: 16,
                        color: isLocked ? Colors.grey : Colors.black54,
                        fontFamily: 'NotoNastaliqUrdu',
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Description
                    Text(
                      chapter.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isLocked ? Colors.grey.shade400 : Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 12),

                    // Progress & Lessons
                    if (!isLocked) ...[
                      Row(
                        children: [
                          // Progress Bar
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: chapter.progress,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation(
                                  progressColor,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Lesson Count
                          Text(
                            '${chapter.completedLessons}/${chapter.lessonCount}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: progressColor,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Topics
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: chapter.topics.take(3).map((topic) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: chapter.color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              topic,
                              style: TextStyle(
                                fontSize: 10,
                                color: chapter.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow
              Icon(
                isLocked ? Icons.lock : Icons.chevron_right,
                color: isLocked ? Colors.grey : chapter.color,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress == 0) return Colors.grey;
    if (progress < 0.5) return Colors.orange;
    if (progress < 1.0) return Colors.blue;
    return AppTheme.primaryGreen;
  }
}

/// Chapter Icon with Progress Ring
class _ChapterIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isLocked;
  final bool isCompleted;
  final double progress;

  const _ChapterIcon({
    required this.icon,
    required this.color,
    required this.isLocked,
    required this.isCompleted,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Progress Ring
        SizedBox(
          width: 70,
          height: 70,
          child: CircularProgressIndicator(
            value: isLocked ? 0 : progress,
            strokeWidth: 4,
            backgroundColor: isLocked
                ? Colors.grey.shade300
                : Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(
              isLocked
                  ? Colors.grey
                  : (isCompleted ? AppTheme.primaryGreen : color),
            ),
          ),
        ),
        // Icon Container
        Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            color: isLocked ? Colors.grey.shade300 : color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isLocked
                ? Icons.lock
                : isCompleted
                ? Icons.check
                : icon,
            size: 28,
            color: isLocked ? Colors.grey : color,
          ),
        ),
        // Completion Badge
        if (isCompleted)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star, size: 16, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

/// Path Connector between chapters
class _PathConnector extends StatelessWidget {
  const _PathConnector();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryGreen.withOpacity(0.5),
            AppTheme.primaryGreen.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

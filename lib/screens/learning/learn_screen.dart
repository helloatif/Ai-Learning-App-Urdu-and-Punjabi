import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../providers/learning_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/chapter_service.dart';
import 'chapter_lessons_path_screen.dart';

/// Main Learn Screen with Chapter-wise Learning Path
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen>
    with TickerProviderStateMixin {
  static const String _maleAvatarPath = 'assets/images/9440461.jpg';
  static const String _femaleAvatarPath = 'assets/images/10491839.jpg';

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
        final List<Color> cardColors = [
          const Color(0xFFFF6B6B), // Soft Coral Red
          const Color(0xFFFFB84C), // Warm Orange-Yellow
          const Color(0xFFA1C298), // Sage Green
          const Color(0xFF9EA1D4), // Soft Lavender Blue
        ];

        // Choose header color per selected language and make status bar transparent
        final lang = selectedLanguage.trim().toLowerCase();
        final Color headerColor = (lang == 'punjabi') ? const Color(0xFFF06292) : AppTheme.primaryGreen;
        // Per-screen status bar style: use headerColor so system bar matches banner
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: headerColor,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: Scaffold(
          backgroundColor: const Color(0xFFF4F0FF),
          body: SafeArea(
              top: true,
              bottom: false,
              left: false,
              right: false,
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontStyle: FontStyle.italic),
                child: Stack(
                children: [
                    // add a colored bar behind the system status area to match header
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: MediaQuery.of(context).padding.top,
                        color: headerColor,
                      ),
                    ),
                  Positioned.fill(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 190, bottom: 100),
                      itemCount: chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = chapters[index];
                        final cardColor = cardColors[index % cardColors.length];
                        final imageAssetPath = _chapterImageAssetPath(index);
                        final fallbackIcon = _chapterFallbackIcon(index);

                        return Transform.translate(
                          offset: Offset(0, -18.0 * index),
                          child: _ChapterCard(
                            chapter: chapter,
                            chapterNumber: index + 1,
                            language: selectedLanguage,
                            cardColor: cardColor,
                            imageAssetPath: imageAssetPath,
                            fallbackIcon: fallbackIcon,
                            onTap: chapter.isLocked ? null : () => _navigateToChapter(context, chapter),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: headerColor,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: AnimatedBuilder(
                        animation: _headerAnimation,
                        builder: (context, child) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // language pill removed per request
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    // Rocket icon to the left of the title
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12.0),
                                      child: SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Image.asset(
                                          'assets/icons/3dicons-rocket-dynamic-color.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: SlideTransition(
                                        position: Tween<Offset>(begin: const Offset(-0.18, 0), end: Offset.zero).animate(_headerAnimation),
                                        child: Text(
                                          'Your Learning Path',
                                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.white, fontStyle: FontStyle.italic),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${(overallProgress * 100).toInt()}% Complete', style: TextStyle(color: AppTheme.white.withOpacity(0.92), fontSize: 12, fontStyle: FontStyle.italic)),
                                    Text('${chapters.where((c) => c.progress == 1.0).length}/${chapters.length} Chapters', style: TextStyle(color: AppTheme.white.withOpacity(0.92), fontSize: 12, fontStyle: FontStyle.italic)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: overallProgress,
                                    backgroundColor: AppTheme.white.withOpacity(0.28),
                                    valueColor: const AlwaysStoppedAnimation(AppTheme.white),
                                    minHeight: 9,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _buildHeaderAvatar(UserProvider user) {
    final selectedAvatar = user.selectedAvatar;

    if (selectedAvatar == null) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.white, width: 2),
          color: AppTheme.white.withOpacity(0.18),
        ),
        child: const Icon(Icons.face, color: AppTheme.white, size: 24),
      );
    }

    final avatarPath = selectedAvatar == 'female'
        ? _femaleAvatarPath
        : _maleAvatarPath;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.white, width: 2),
      ),
      child: ClipOval(
        child: Image.asset(
          avatarPath,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) => Container(
            color: AppTheme.white.withOpacity(0.18),
            child: const Icon(Icons.face, color: AppTheme.white, size: 28),
          ),
        ),
      ),
    );
  }

  void _navigateToChapter(BuildContext context, ChapterModel chapter) {
        Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ChapterLessonsPathScreen(
              chapterId: chapter.id,
              chapterTitle: chapter.titleEnglish,
              language: chapter.language,
            ),
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
  final Color cardColor;
  final String imageAssetPath;
  final IconData fallbackIcon;
  final VoidCallback? onTap;

  const _ChapterCard({
    required this.chapter,
    required this.chapterNumber,
    required this.language,
    required this.cardColor,
    required this.imageAssetPath,
    required this.fallbackIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = chapter.progress == 1.0;
    final isLocked = chapter.isLocked;
    final progressValue = isLocked ? 0.0 : chapter.progress;
    final textColor = isLocked ? Colors.white.withOpacity(0.65) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          margin: EdgeInsets.zero,
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(isLocked ? 0.18 : 0.32),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: imageAssetPath.trim().isNotEmpty
                        ? Image.asset(
                            imageAssetPath,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(
                                fallbackIcon,
                                color: Colors.black87,
                                size: 34,
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              fallbackIcon,
                              color: Colors.black87,
                              size: 34,
                            ),
                          )),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHAPTER $chapterNumber',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: textColor.withOpacity(0.95),
                        letterSpacing: 1.2,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      chapter.titleEnglish,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 21,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(
                      chapter.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.0,
                        color: textColor.withOpacity(0.92),
                        fontFamily: 'NotoNastaliqUrdu',
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progressValue,
                              backgroundColor: Colors.white.withOpacity(0.28),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${(progressValue * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (isLocked)
                Image.asset(
                  'assets/icons/3dicons-lock-dynamic-color.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.contain,
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 30,
                ),
            ],
          ),
        ),
      ),
    );
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

String _chapterImageAssetPath(int index) {
  // Map each chapter index to an icon placed in `assets/icons/`.
  // Files expected: chapter1icon.png ... chapter15icon.png
  const imageAssetPaths = <String>[
    'assets/icons/chapter1icon.png',
    'assets/icons/chapter2icon.png',
    'assets/icons/chapter3icon.png',
    'assets/icons/chapter4icon.png',
    'assets/icons/chapter5icon.png',
    'assets/icons/chapter6icon.png',
    'assets/icons/chapter7icon.png',
    'assets/icons/chapter8icon.png',
    'assets/icons/chapter9icon.png',
    'assets/icons/chapter10icon.png',
    'assets/icons/chapter11icon.png',
    'assets/icons/chapter12icon.png',
    'assets/icons/chapter13icon.png',
    'assets/icons/chapter14icon.png',
    'assets/icons/chapter15icon.png',
  ];

  if (index >= 0 && index < imageAssetPaths.length) {
    return imageAssetPaths[index];
  }

  return '';
}

IconData _chapterFallbackIcon(int index) {
  const fallbackIcons = <IconData>[
    Icons.menu_book_rounded,
    Icons.chat_bubble_outline_rounded,
    Icons.category_rounded,
    Icons.card_travel_rounded,
    Icons.restaurant_rounded,
    Icons.favorite_rounded,
    Icons.school_rounded,
    Icons.work_rounded,
    Icons.devices_rounded,
    Icons.emoji_events_rounded,
    Icons.sentiment_satisfied_alt_rounded,
    Icons.sports_soccer_rounded,
    Icons.pets_rounded,
    Icons.shopping_bag_rounded,
    Icons.home_rounded,
  ];

  return fallbackIcons[index % fallbackIcons.length];
}

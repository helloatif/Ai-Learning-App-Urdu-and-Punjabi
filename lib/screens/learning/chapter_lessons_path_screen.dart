import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../widgets/bottom_navigation.dart';
import '../../providers/learning_provider.dart';
import '../../services/chapter_service.dart';
import '../../services/lesson_service.dart';
import '../../data/vocabulary_data.dart';
import 'chapter_quiz_screen.dart';
import 'teaching_lesson_screen.dart';

class ChapterLessonsPathScreen extends StatefulWidget {
  final String chapterId;
  final String chapterTitle;
  final String language;

  const ChapterLessonsPathScreen({
    Key? key,
    required this.chapterId,
    required this.chapterTitle,
    required this.language,
  }) : super(key: key);

  @override
  State<ChapterLessonsPathScreen> createState() => _ChapterLessonsPathScreenState();
}

class _ChapterLessonsPathScreenState extends State<ChapterLessonsPathScreen>
  with TickerProviderStateMixin {
  static const int totalNodes = 5;

  List<LessonVocabulary> _lessons = const [];
  late List<_NodeData> _nodes;
  AnimationController? _quizPulseController;
  Animation<double>? _quizPulseAnim;
  AnimationController? _quizCompleteController;
  bool _lastQuizPassed = false;

  List<_NodeData> _buildNodes({List<LessonVocabulary>? lessons}) {
    final chapter = _resolveChapter();

    _nodes = List.generate(
      totalNodes,
      (index) {
        if (index == totalNodes - 1) {
          return _NodeData(
            title: 'Chapter Quiz',
            caption: 'Short test of ${_chapterDisplayName(chapter)}',
          );
        }

        return _NodeData(
          title: 'Lesson ${index + 1}',
          caption: _buildLessonCaption(
            chapter: chapter,
            lessons: lessons,
            index: index,
          ),
        );
      },
    );

    return _nodes;
  }

  Future<void> _loadLessons() async {
    final lessons = await LessonService.getLessons(widget.chapterId, widget.language);
    if (!mounted) return;

    setState(() {
      _lessons = lessons;
      _buildNodes(lessons: _lessons);
    });
  }

  @override
  void initState() {
    super.initState();
    _buildNodes();
    _loadLessons();

    _quizPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _quizPulseAnim = Tween<double>(begin: 0.98, end: 1.06).animate(
      CurvedAnimation(parent: _quizPulseController!, curve: Curves.easeInOut),
    );

    _quizCompleteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _quizCompleteController?.reverse();
        }
      });
  }

  @override
  void dispose() {
    _quizPulseController?.dispose();
    _quizCompleteController?.dispose();
    super.dispose();
  }

  void _onNodeTap(int index) async {
    final learningProvider = context.read<LearningProvider>();
    final completedLessons = learningProvider.getCompletedLessonsCount(
      widget.chapterId,
    );

    if (!_isNodeUnlocked(index, completedLessons)) return;

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Start ${_nodes[index - 1].title}'),
        content: Text(
          index == totalNodes
              ? 'Continue to the chapter quiz.'
              : _nodes[index - 1].caption,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      if (index == totalNodes) {
        _openQuiz(context);
        return;
      }

      await _openLesson(context, index);
    }
  }

  bool _isLessonCompleted(LearningProvider learningProvider, int index) {
    return learningProvider.isLessonCompleted(widget.chapterId, index - 1);
  }

  bool _isNodeUnlocked(int index, int completedLessons) {
    return index <= completedLessons + 1;
  }

  Widget _buildNode(BuildContext context, int index) {
    final learningProvider = context.watch<LearningProvider>();
    final completedLessons = learningProvider.getCompletedLessonsCount(
      widget.chapterId,
    );
    final node = _nodes[index - 1];
    final unlocked = _isNodeUnlocked(index, completedLessons);
    final completed = index < totalNodes && _isLessonCompleted(learningProvider, index);

    final theme = Theme.of(context);

    final circle = GestureDetector(
      onTap: unlocked ? () => _onNodeTap(index) : null,
      child: Container(
        width: 76,
        height: 76,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Use special quiz icon for the last node, otherwise use locked/unlocked backgrounds
            if (index == totalNodes)
              Opacity(
                opacity: unlocked ? 1.0 : 0.45,
                child: Builder(builder: (ctx) {
                  final quizPassed = learningProvider.isChapterQuizPassed(widget.chapterId);
                  if (quizPassed && !_lastQuizPassed) {
                    _quizCompleteController?.forward(from: 0.0);
                  }
                  _lastQuizPassed = quizPassed;

                  final quizImage = Image.asset(
                    'assets/icons/quizicon.png',
                    width: 76,
                    height: 76,
                    fit: BoxFit.contain,
                  );

                  if (_quizPulseController == null || _quizCompleteController == null || _quizPulseAnim == null) {
                    return quizImage;
                  }

                  return AnimatedBuilder(
                    animation: Listenable.merge([_quizPulseController!, _quizCompleteController!]),
                    builder: (c, child) {
                      final pulse = _quizPulseAnim!.value;
                      final pop = 1.0 + 0.18 * _quizCompleteController!.value;
                      return Transform.scale(scale: pulse * pop, child: child);
                    },
                    child: quizImage,
                  );
                }),
              )
            else
              Image.asset(
                unlocked
                    ? 'assets/icons/unlocknodes.png'
                    : 'assets/icons/locknodes.png',
                width: 76,
                height: 76,
                fit: BoxFit.contain,
              ),
            // Show completion overlay if this node is completed
            if (completed)
              Positioned(
                right: 4,
                bottom: 4,
                child: Image.asset(
                  'assets/icons/COMPLETION_NODE.png',
                  width: 28,
                  height: 28,
                ),
              ),
          ],
        ),
      ),
    );

    // Title + caption under node
    final titleText = Text(
      node.title,
      style: (index == totalNodes)
          ? theme.textTheme.bodySmall
          : theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
    );

    final captionValue = node.caption;
    final captionText = captionValue.isNotEmpty
        ? Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              captionValue,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color?.withOpacity(unlocked ? 0.7 : 0.4),
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        : const SizedBox.shrink();

    // Positioning: per spec: 1-left,2-center,3-right,4-center,5-center
    Alignment alignment;
    switch (index) {
      case 1:
        alignment = const Alignment(-0.7, 0);
        break;
      case 2:
        alignment = Alignment.center;
        break;
      case 3:
        alignment = const Alignment(0.7, 0);
        break;
      case 4:
        alignment = Alignment.center;
        break;
      case 5:
      default:
        alignment = Alignment.center;
        break;
    }

    return SizedBox(
      height: 160,
      child: Stack(
        children: [
          Align(
            alignment: alignment,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                circle,
                const SizedBox(height: 8),
                titleText,
                captionText,
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFFCE82FF),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Sticky header (rectangular corners for Android)
            Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFCE82FF),
                borderRadius: BorderRadius.zero,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: Colors.white,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SECTION',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.chapterTitle,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Image.asset(
                      'assets/icons/lessonheadericon.png',
                      width: 19,
                      height: 19,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Stack(
                  children: [
                    // Positioned painter spanning the full height of the node list
                    Positioned.fill(
                      child: CustomPaint(
                        painter: PathCurvePainter(totalNodes: totalNodes),
                      ),
                    ),
                    // The interactive nodes layer on top
                    Column(
                      children: List.generate(
                        totalNodes,
                        (i) => _buildNode(context, i + 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavigation(),
      ),
    );
  }

  Future<void> _openLesson(BuildContext context, int index) async {
    final chapter = ChapterService.getChapter(widget.chapterId) ??
        ChapterService.getChapters(widget.language).firstWhere(
          (c) => c.id == widget.chapterId,
          orElse: () => ChapterService.getChapters(widget.language).first,
        );

    LessonVocabulary lesson;
    if (_lessons.length > index - 1) {
      lesson = _lessons[index - 1];
    } else {
      lesson = _NodeData.defaultLesson(
        index,
        lessonTitle: _buildLessonCaption(
          chapter: chapter,
          lessons: _lessons,
          index: index - 1,
        ),
      );
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeachingLessonScreen(
          chapter: chapter,
          lessonIndex: index - 1,
          lesson: lesson,
        ),
      ),
    );
  }

  void _openQuiz(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChapterQuizScreen(chapter: _resolveChapter()),
      ),
    );
  }

  ChapterModel _resolveChapter() {
    return ChapterService.getChapter(widget.chapterId) ??
        ChapterModel(
          id: widget.chapterId,
          title: widget.chapterTitle,
          titleEnglish: widget.chapterTitle,
          description: '',
          language: widget.language,
          icon: Icons.menu_book,
          color: Colors.blue,
          isLocked: false,
        );
  }

  String _chapterDisplayName(ChapterModel chapter) {
    final english = chapter.titleEnglish.trim();
    if (english.isNotEmpty) return english;

    final localTitle = chapter.title.trim();
    if (localTitle.isNotEmpty) return localTitle;

    return widget.chapterTitle.trim().isNotEmpty ? widget.chapterTitle.trim() : 'This chapter';
  }

  String _buildLessonCaption({
    required ChapterModel chapter,
    required List<LessonVocabulary>? lessons,
    required int index,
  }) {
    final lesson = (lessons != null && index < lessons.length) ? lessons[index] : null;

    final lessonEnglish = lesson?.titleEnglish.trim() ?? '';
    if (lessonEnglish.isNotEmpty) return lessonEnglish;

    final lessonLocal = lesson?.title.trim() ?? '';
    if (lessonLocal.isNotEmpty) return lessonLocal;

    if (chapter.topics.isNotEmpty && index < chapter.topics.length) {
      final topic = chapter.topics[index].trim();
      if (topic.isNotEmpty) return topic;
    }

    return '${_chapterDisplayName(chapter)} ${index + 1}';
  }
}

class _NodeData {
  final String title;
  final String caption;

  const _NodeData({required this.title, this.caption = ''});

  static LessonVocabulary defaultLesson(
    int index, {
    required String lessonTitle,
  }) {
    return LessonVocabulary(
      lessonNumber: index,
      title: lessonTitle,
      titleEnglish: lessonTitle,
      words: const [],
    );
  }
}

class PathCurvePainter extends CustomPainter {
  final int totalNodes;
  PathCurvePainter({required this.totalNodes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE0E5ED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    const double rowHeight = 160.0;

    final double leftX = size.width * 0.18;
    final double centerX = size.width * 0.5;
    final double rightX = size.width * 0.82;

    final List<Offset> points = [];
    for (int i = 0; i < totalNodes; i++) {
      double x = centerX;
      if (i == 0) x = leftX;
      if (i == 2) x = rightX;

      final double y = (i * rowHeight) + 64.0;
      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];

      final controlX = (p0.dx + p1.dx) / 2;
      final controlY = (p0.dy + p1.dy) / 2;

      path.quadraticBezierTo(p0.dx, controlY, controlX, controlY);
      path.quadraticBezierTo(p1.dx, controlY, p1.dx, p1.dy);
    }

    // Turn the solid curve into an elegant dashed/dotted path
    final dashedPath = Path();
    const dashWidth = 10.0;
    const dashSpace = 8.0;

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        dashedPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
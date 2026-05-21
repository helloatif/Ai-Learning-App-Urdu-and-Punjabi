import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/vocabulary_data.dart';
import '../../providers/learning_provider.dart';
import '../../services/chapter_service.dart';
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

  late List<_NodeData> _nodes;
  AnimationController? _quizPulseController;
  Animation<double>? _quizPulseAnim;
  AnimationController? _quizCompleteController;
  bool _lastQuizPassed = false;

  

  void _initNodes() {
    // Default fallback captions
    final fallback = [
      'Basics: greetings & alphabet',
      'Pronunciation & simple phrases',
      'Everyday vocabulary',
      'Practice exercises',
    ];

    List<LessonVocabulary>? lessons;
    if (widget.language == 'punjabi') {
      lessons = VocabularyData.punjabiLessons[widget.chapterId];
    } else {
      lessons = VocabularyData.urduLessons[widget.chapterId];
    }

    if (lessons != null && lessons.length >= 4) {
      _nodes = [
        _NodeData(title: 'Lesson 1', caption: lessons[0].titleEnglish.isNotEmpty ? lessons[0].titleEnglish : lessons[0].title),
        _NodeData(title: 'Lesson 2', caption: lessons[1].titleEnglish.isNotEmpty ? lessons[1].titleEnglish : lessons[1].title),
        _NodeData(title: 'Lesson 3', caption: lessons[2].titleEnglish.isNotEmpty ? lessons[2].titleEnglish : lessons[2].title),
        _NodeData(title: 'Lesson 4', caption: lessons[3].titleEnglish.isNotEmpty ? lessons[3].titleEnglish : lessons[3].title),
        const _NodeData(title: 'Chapter Quiz', caption: 'Short test of chapter topics'),
      ];
    } else {
      _nodes = [
        _NodeData(title: 'Lesson 1', caption: fallback[0]),
        _NodeData(title: 'Lesson 2', caption: fallback[1]),
        _NodeData(title: 'Lesson 3', caption: fallback[2]),
        _NodeData(title: 'Lesson 4', caption: fallback[3]),
        const _NodeData(title: 'Chapter Quiz', caption: 'Short test of chapter topics'),
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    _initNodes();

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
      child: SizedBox(
        width: 76,
        height: 76,
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
                unlocked ? 'assets/icons/unlocknodes.png' : 'assets/icons/locknodes.png',
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
    final titleText = Text(node.title, style: theme.textTheme.bodySmall);

    final captionValue = node.caption ?? '';
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Sticky header
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: kIsWeb ? Colors.purple : Colors.transparent,
                  image: kIsWeb
                      ? null
                      : const DecorationImage(
                          image: AssetImage('assets/icons/purplebar.png'),
                          fit: BoxFit.fill,
                        ),
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
                        width: 36,
                        height: 36,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: List.generate(totalNodes, (i) => _buildNode(context, i + 1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLesson(BuildContext context, int index) async {
    final chapter = ChapterService.getChapter(widget.chapterId) ??
        ChapterService.getChapters(widget.language).firstWhere(
          (c) => c.id == widget.chapterId,
          orElse: () => ChapterService.getChapters(widget.language).first,
        );

    final lessonsMap = widget.language == 'punjabi'
        ? VocabularyData.punjabiLessons
        : VocabularyData.urduLessons;
    final lessons = lessonsMap[widget.chapterId];

    LessonVocabulary lesson;
    if (lessons != null && lessons.length > index - 1) {
      lesson = lessons[index - 1];
    } else {
      lesson = _NodeData.defaultLesson(index);
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
}

class _NodeData {
  final String title;
  final String caption;

  const _NodeData({required this.title, this.caption = ''});

  static LessonVocabulary defaultLesson(int index) {
    return LessonVocabulary(
      lessonNumber: index,
      title: 'Lesson $index',
      titleEnglish: 'Lesson $index',
      words: const [],
    );
  }
}
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../themes/app_theme.dart';
import '../../services/chapter_service.dart';
import '../../services/voice_service.dart';
import '../../services/ml_vocabulary_service.dart';
import '../../data/vocabulary_data.dart';
import '../../providers/learning_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/user_provider.dart';

/// Dark, stacked deck lesson screen with correct paint z-ordering.
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

class _TeachingLessonScreenState extends State<TeachingLessonScreen> with TickerProviderStateMixin {
  // Premium dark theme configuration matching target high-fidelity views
  static const Color _bg = Color(0xFF0D0D0D);
  static const Color _card = Color(0xFF161616);
  static const Color _accentBlue = Color(0xFF2F80ED);
  static const Color _accentCoral = Color(0xFFFF8A5B);
  static const Color _lavender = Color(0xFF9A84FF);

  int _currentIndex = 0;
  double _dragOffsetX = 0.0;
  bool _isDragging = false;
  bool _isAnimatingSwipe = false;
  List<VocabWord> _lessonWords = [];
  bool _isLoading = true;
  String? _loadError;
  bool _isSpeaking = false;
  bool _lessonDone = false;
  final Set<int> _revealed = <int>{};
  // indices for which the example sentence panel is currently shown
  final Set<int> _shownExampleIndices = <int>{};

  AnimationController? _questionIconController;

  void _toggleExample(int index) {
    setState(() {
      if (_shownExampleIndices.contains(index)) _shownExampleIndices.remove(index);
      else _shownExampleIndices.add(index);
    });
  }

  TextStyle _italic([TextStyle? base]) => (base ?? const TextStyle()).copyWith(fontStyle: FontStyle.italic);

  int get _activeIndex {
    if (_lessonWords.isEmpty) return 0;
    return math.max(0, math.min(_currentIndex, _lessonWords.length - 1));
  }

  @override
  void initState() {
    super.initState();
    VoiceService.initialize();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    _questionIconController ??= AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _loadLessonWords();
    Future.delayed(const Duration(milliseconds: 500), () { 
      if (mounted && _lessonWords.isNotEmpty) _speakAt(0); 
    });
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    _questionIconController?.dispose();
    VoiceService.stop();
    super.dispose();
  }

  Future<void> _loadLessonWords() async {
    try {
      final predictions = await MLVocabularyService.generateVocabularyWithML(
        chapterId: widget.chapter.id,
        lessonIndex: widget.lessonIndex,
        language: widget.chapter.language,
        count: 25,
      );

      if (!mounted) return;

      if (predictions.isNotEmpty) {
        setState(() {
          _lessonWords = predictions
              .map((p) => VocabWord(
                    urdu: p.word,
                    english: p.translation,
                    pronunciation: p.pronunciation,
                    exampleSentence: p.example ?? p.word,
                    exampleEnglish: p.exampleTranslation ?? p.translation,
                  ))
              .toList();
          _isLoading = false;
          _loadError = null;
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _lessonWords.isNotEmpty) _speakAt(0);
        });
        return;
      }

      setState(() {
        _lessonWords = [];
        _isLoading = false;
        _loadError = 'No words returned from server.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _lessonWords = []; _isLoading = false; _loadError = 'Failed to load lesson.'; });
    }
  }

  Future<void> _speakAt(int index) async {
    if (_isSpeaking || index < 0 || index >= _lessonWords.length) return;
    setState(() => _isSpeaking = true);
    HapticFeedback.lightImpact();
    final ok = await VoiceService.speak(_lessonWords[index].urdu, widget.chapter.language);
    if (!ok && mounted && VoiceService.lastTtsError.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(VoiceService.lastTtsError, style: _italic())));
    }
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _speakSentenceAt(int index) async {
    if (_isSpeaking) return;
    if (index < 0 || index >= _lessonWords.length) return;
    final w = _lessonWords[index];
    if (!w.hasSentence) return;
    setState(() => _isSpeaking = true);
    HapticFeedback.lightImpact();
    final ok = await VoiceService.speak(w.exampleSentence!, widget.chapter.language);
    if (!ok && mounted && VoiceService.lastTtsError.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(VoiceService.lastTtsError, style: _italic())));
    }
    if (mounted) setState(() => _isSpeaking = false);
  }

  // navigation is handled directly by Previous/Next buttons and swipe logic

  Future<void> _swipeCard(int direction, {required bool known}) async {
    if (_isAnimatingSwipe || _lessonWords.isEmpty) return;

    final int lastIndex = _lessonWords.length - 1;
    final int nextIndex = direction > 0 ? _activeIndex - 1 : _activeIndex + 1;
    if (nextIndex < 0 || nextIndex >= _lessonWords.length) {
      if (direction < 0 && _activeIndex == lastIndex) {
        _completeLesson();
      }
      setState(() => _dragOffsetX = 0.0);
      return;
    }

    final double screenWidth = MediaQuery.of(context).size.width;

    HapticFeedback.selectionClick();
    setState(() {
      _isAnimatingSwipe = true;
      _isDragging = false;
      _dragOffsetX = direction * screenWidth * 1.2;
    });

    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;

    setState(() {
      _currentIndex = nextIndex;
      _dragOffsetX = 0.0;
      _isAnimatingSwipe = false;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _lessonWords.isNotEmpty) _speakAt(_activeIndex);
    });
  }

  void _completeLesson() async {
    HapticFeedback.heavyImpact();
    final lp = Provider.of<LearningProvider>(context, listen: false);
    final gp = Provider.of<GamificationProvider>(context, listen: false);
    final already = lp.isLessonCompleted(widget.chapter.id, widget.lessonIndex);
    if (!already) { gp.addPoints(10); gp.completeLesson(); gp.updateDailyStreak(); }
    await lp.markLessonCompleted(widget.chapter.id, widget.lessonIndex);
    if (!mounted) return;
    setState(() => _lessonDone = true);
  }

  Widget _buildTopBar() {
    final current = _activeIndex;
    final pct = ((_lessonWords.isEmpty ? 0.0 : (current + 1) / _lessonWords.length) * 100).round();
    final user = Provider.of<UserProvider>(context);
    final chapterTitle = widget.chapter.titleEnglish.isNotEmpty ? widget.chapter.titleEnglish : widget.chapter.title;
    final stepLabel = 'Lesson ${widget.lessonIndex + 1} • ${current + 1}/${_lessonWords.length}';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 12, right: 12, bottom: 14),
      decoration: BoxDecoration(color: _card, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 12)]),
      child: Row(children: [
        IconButton(onPressed: () => _showExitDialog(), icon: const Icon(Icons.close, color: Colors.white)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
                  Text(
                    stepLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                  ),
              const SizedBox(height: 2),
                  Text(
                    chapterTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                  ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(width: 56, height: 56, child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(
            value: _lessonWords.isEmpty ? 0 : ((current + 1) / _lessonWords.length), 
            strokeWidth: 4, 
            backgroundColor: Colors.white12, 
            valueColor: const AlwaysStoppedAnimation(_accentBlue),
          ),
          Text('$pct%', style: const TextStyle(color: Colors.white, fontSize: 12)),
        ])),
        const SizedBox(width: 12),
        _buildAvatar(user),
      ]),
    );
  }

  Widget _buildAvatar(UserProvider userProvider) {
    final selected = userProvider.selectedAvatar;
    if (selected == null) return Container(width:40,height:40,decoration: const BoxDecoration(shape: BoxShape.circle,color: Colors.white10), child: const Icon(Icons.face,color: Colors.white24));
    final path = selected == 'female' ? 'assets/images/10491839.jpg' : 'assets/images/9440461.jpg';
    return Container(width:40,height:40,decoration: const BoxDecoration(shape: BoxShape.circle), child: ClipOval(child: Image.asset(path, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Container(color: Colors.white10, child: const Icon(Icons.face, color: Colors.white24)))));
  }

  Widget _buildLessonCard(int index) {
    if (index < 0 || index >= _lessonWords.length) return const SizedBox.shrink();
    final w = _lessonWords[index];
    final revealed = _revealed.contains(index);

    return Stack(children: [
      Positioned.fill(child: Container(color: const Color(0xFF1E1E1E))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(children: [
            Text(w.urdu, textAlign: TextAlign.center, style: const TextStyle(fontSize: 38, color: Colors.white, fontFamily: 'NotoNastaliqUrdu', height: 1.2)),
            const SizedBox(height: 12),
            Text(w.pronunciation, style: const TextStyle(fontSize: 18, color: _accentCoral, fontStyle: FontStyle.italic)),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => setState(() => revealed ? _revealed.remove(index) : _revealed.add(index)),
              child: Stack(alignment: Alignment.center, children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 260),
                  opacity: revealed ? 1.0 : 0.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        color: Colors.white.withOpacity(0.03),
                        child: Text(
                          w.english,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 20),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!revealed)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                    child: Text('Tap to reveal meaning', style: _italic(const TextStyle(color: Colors.white70))),
                  ),
              ]),
            ),
          ]),
          Column(children: [
            // Example sentence panel (appears above the Listen button)
            if (_shownExampleIndices.contains(index) && w.exampleSentence != null)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: 1.0,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    w.exampleSentence ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.25),
                  ),
                ),
              ),

            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _speakAt(index),
                  icon: const Icon(Icons.volume_up),
                  label: Text('Listen', style: _italic()),
                  style: ElevatedButton.styleFrom(backgroundColor: _lavender),
                ),
              ),
              const SizedBox(width: 12),
                if (w.hasSentence)
                  GestureDetector(
                    onTap: () => _toggleExample(index),
                    child: RotationTransition(
                      turns: _questionIconController ?? const AlwaysStoppedAnimation(0),
                      child: Image.asset('assets/icons/questionmark.png', width: 26, height: 26),
                    ),
                  ),
            ])
          ])
        ]),
      ),
    ]);
  }

  /// Iterates and builds background items underneath the top active card
  List<Widget> _buildDeckVisualStack() {
    if (_lessonWords.isEmpty) return [];

    final int currentIndex = _activeIndex;
    final List<Widget> deckLayers = [];

    // Render the active card plus the next two cards behind it.
    for (int offset = 2; offset >= 0; offset--) {
      final int i = currentIndex + offset;
      if (i < 0 || i >= _lessonWords.length) continue;

      final bool isActiveCard = offset == 0;
      final double translateX = isActiveCard ? _dragOffsetX : (offset == 1 ? 12.0 : 20.0);
      final double depth = isActiveCard ? 0.0 : (offset == 1 ? -40.0 : -80.0);
      final double rotationZ = isActiveCard ? (_dragOffsetX / 240.0).clamp(-0.35, 0.35) : (offset == 1 ? 0.07 : 0.14);
      final double opacity = isActiveCard ? 1.0 : (offset == 1 ? 0.9 : 0.7);
      final double scale = isActiveCard ? 1.0 : (offset == 1 ? 0.985 : 0.97);

      final Matrix4 transform = Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..translate(translateX, 0.0, depth)
        ..rotateZ(rotationZ)
        ..scale(scale, scale, 1.0);

      final Widget card = _buildLessonCard(i);

      deckLayers.add(
        Positioned.fill(
          child: Transform(
            transform: transform,
            alignment: Alignment.center,
            child: Center(
              child: IgnorePointer(
                ignoring: !isActiveCard,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: isActiveCard
                      ? (_) {
                          if (_isAnimatingSwipe) return;
                          setState(() {
                            _isDragging = true;
                            _dragOffsetX = 0.0;
                          });
                        }
                      : null,
                  onHorizontalDragUpdate: isActiveCard
                      ? (details) {
                          if (_isAnimatingSwipe) return;
                          setState(() {
                            _dragOffsetX += details.delta.dx;
                          });
                        }
                      : null,
                  onHorizontalDragEnd: isActiveCard
                      ? (details) {
                          if (_isAnimatingSwipe) return;
                          final double primaryVelocity = details.primaryVelocity ?? 0.0;
                          setState(() => _isDragging = false);
                          final bool swipeRight = _dragOffsetX > 100 || primaryVelocity > 300;
                          final bool swipeLeft = _dragOffsetX < -100 || primaryVelocity < -300;
                          if (swipeRight) {
                            _swipeCard(1, known: true);
                          } else if (swipeLeft) {
                            _swipeCard(-1, known: false);
                          } else {
                            setState(() => _dragOffsetX = 0.0);
                          }
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: _isDragging ? Duration.zero : const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    width: MediaQuery.of(context).size.width * 0.85,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isActiveCard ? const Color(0xFF242424) : const Color(0xFF181818),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF4C4732), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isActiveCard ? 0.45 : 0.25),
                          blurRadius: isActiveCard ? 28 : 18,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    transformAlignment: Alignment.bottomCenter,
                    transform: transform,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Opacity(
                        opacity: opacity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                          child: card,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return deckLayers;
  }

  Widget _buildBottomBar() {
    final bool showPrevious = _activeIndex > 0;
    final textStyle = _italic(const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal:16.0, vertical:12),
      child: Row(children: [
        if (showPrevious)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _swipeCard(1, known: true),
              icon: Image.asset('assets/icons/3dicons-back-front-color.png', width: 20, height: 20),
              label: Text('Previous', style: textStyle),
              style: ElevatedButton.styleFrom(backgroundColor: _lavender, padding: const EdgeInsets.symmetric(vertical:14)),
            ),
          ),
        if (showPrevious) const SizedBox(width:12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _swipeCard(-1, known: false),
            icon: Image.asset('assets/icons/3dicons-next-front-color.png', width: 20, height: 20),
            label: Text('Next', style: textStyle),
            style: ElevatedButton.styleFrom(backgroundColor: _lavender, padding: const EdgeInsets.symmetric(vertical:14)),
          ),
        ),
      ]),
    );
  }

  Widget _buildCompletionOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: FractionallySizedBox(
            widthFactor: 0.92,
            heightFactor: 0.78,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white10, width: 1),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 30, offset: const Offset(0, 16))],
                ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: -180,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SizedBox(
                            width: 520,
                            height: 520,
                            child: Lottie.asset(
                              'assets/icons/animations/c22b3edc-116e-11ee-b29e-6b53b36a56ea.json',
                              fit: BoxFit.contain,
                              repeat: true,
                            ),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 188),
                          Text(
                            'Lesson Complete!',
                            textAlign: TextAlign.center,
                            style: _italic(const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'You learned ${_lessonWords.length} words',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 18),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accentBlue,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              child: Text('Continue', style: _italic(const TextStyle(fontSize: 18))),
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
    );
  }

  void _showExitDialog(){
    showDialog(context: context, builder: (ctx)=> AlertDialog(backgroundColor: _card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), title: Text('Leave Lesson?', style: _italic(const TextStyle(color: Colors.white))), content: Text('Your progress may not be saved.', style: _italic(const TextStyle(color: Colors.white70))), actions: [TextButton(onPressed: ()=> Navigator.pop(ctx), child: Text('Stay', style: _italic())), ElevatedButton(onPressed: (){ Navigator.pop(ctx); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.red), child: Text('Leave', style: _italic()))]));
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    if (_isLoading) return Scaffold(backgroundColor: _bg, body: SafeArea(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height:12), Text('Loading lesson...', style: _italic(const TextStyle(color: Colors.white70)))]))));

    if (!_isLoading && _lessonWords.isEmpty) return Scaffold(backgroundColor: _bg, body: SafeArea(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.error_outline, size:56, color: _accentBlue), const SizedBox(height:12), Text(_loadError ?? 'No lesson content.', style: _italic(const TextStyle(color: Colors.white70))), const SizedBox(height:12), ElevatedButton.icon(onPressed: (){ setState(()=> _isLoading = true); _loadLessonWords(); }, icon: const Icon(Icons.refresh), label: Text('Retry', style: _italic()), style: ElevatedButton.styleFrom(backgroundColor: _accentBlue))]))));

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top + 76),
                  Expanded(
                    child: ClipRect(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ..._buildDeckVisualStack(),
                            if (_lessonDone) _buildCompletionOverlay(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 8),
                    child: _buildBottomBar(),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),
          ],
        ),
      ),
    );
  }
}
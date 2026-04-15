import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../providers/learning_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/voice_service.dart';
import '../../services/chapter_service.dart';
import '../../services/quiz_generator_service.dart';
import '../../services/personalization_service.dart';
import '../../services/huggingface_api_service.dart';
import '../../services/language_detection_service.dart';

/// Question types for the chapter quiz
enum QuestionType {
  writtenInput, // User types the translation
  multipleChoice, // MCQ with 4 options
  fillInBlank, // Fill in the blank
  pronunciation, // Speech-to-text pronunciation check
}

/// Quiz question model
class ChapterQuizQuestion {
  final String id;
  final QuestionType type;
  final String question;
  final String correctAnswer;
  final List<String>? options; // For MCQ
  final String? urduWord; // The original word
  final String? pronunciation; // Pronunciation guide
  String? userAnswer;
  bool? isCorrect;

  ChapterQuizQuestion({
    required this.id,
    required this.type,
    required this.question,
    required this.correctAnswer,
    this.options,
    this.urduWord,
    this.pronunciation,
    this.userAnswer,
    this.isCorrect,
  });
}

class ChapterQuizScreen extends StatefulWidget {
  final ChapterModel chapter;

  const ChapterQuizScreen({super.key, required this.chapter});

  @override
  State<ChapterQuizScreen> createState() => _ChapterQuizScreenState();
}

class _ChapterQuizScreenState extends State<ChapterQuizScreen>
    with TickerProviderStateMixin {
  List<ChapterQuizQuestion> _questions = [];
  bool _isLoadingQuestions = true;
  int _currentQuestionIndex = 0;
  bool _showResult = false;
  bool _isAnswerChecked = false;
  bool _isListening = false;
  String _recognizedText = '';
  String _languageDetectionNote = '';
  String _loadError = '';
  PronunciationAnalysis? _pronunciationAnalysis;
  final LanguageDetectionService _languageDetectionService =
      LanguageDetectionService();

  final TextEditingController _answerController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _generateQuestions();
    VoiceService.initialize();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _answerController.dispose();
    _animationController.dispose();
    VoiceService.stop();
    super.dispose();
  }

  /// Generate chapter quiz questions using ML-enhanced quiz generation
  void _generateQuestions() async {
    final chapterId = widget.chapter.id;
    final language = widget.chapter.language;

    if (mounted) {
      setState(() {
        _isLoadingQuestions = true;
      });
    }

    try {
      // Use ML-enhanced quiz generation with semantic distractors
      final mlQuestions = await QuizGeneratorService.generateChapterReviewQuiz(
        chapterId: chapterId,
        language: language,
        questionCount: chapterQuizQuestionCount,
      );

      debugPrint(
        '✅ Generated ${mlQuestions.length} ML-enhanced quiz questions',
      );

      // Convert to ChapterQuizQuestion format
      if (mlQuestions.isNotEmpty) {
        _questions = mlQuestions.map((q) {
          final mappedType = switch (q.type) {
            QuizType.vocabulary => QuestionType.multipleChoice,
            QuizType.typing => QuestionType.writtenInput,
            QuizType.grammar => QuestionType.fillInBlank,
            QuizType.listening => QuestionType.pronunciation,
            QuizType.comprehension => QuestionType.writtenInput,
            QuizType.matching => QuestionType.writtenInput,
          };

          return ChapterQuizQuestion(
            id: q.id,
            type: mappedType,
            question: q.question,
            correctAnswer: q.correctAnswer,
            options: q.options,
            urduWord: q.questionUrdu ?? '',
            pronunciation: q.hint,
          );
        }).toList();
        _loadError = '';

        setState(() {
          _isLoadingQuestions = false;
        });
        return;
      }

      _questions = [];
      _loadError = 'XLM-RoBERTa did not return chapter quiz questions.';
    } catch (e) {
      debugPrint('⚠️ ML quiz generation failed: $e');
      _questions = [];
      _loadError = 'Failed to load chapter quiz from XLM-RoBERTa.';
    }

    if (mounted) {
      setState(() {
        _isLoadingQuestions = false;
      });
    }
  }

  /// Check the current answer using ML-powered scoring
  void _checkAnswer() async {
    final question = _questions[_currentQuestionIndex];
    final userAnswer = question.type == QuestionType.pronunciation
        ? _recognizedText
        : _answerController.text.trim();

    setState(() {
      question.userAnswer = userAnswer;
    });

    // Use ML-based scoring for written answers
    if (question.type == QuestionType.multipleChoice) {
      // MCQ: Simple exact match
      setState(() {
        question.isCorrect = userAnswer == question.correctAnswer;
        _isAnswerChecked = true;
      });
    } else if (question.type != QuestionType.pronunciation) {
      // Written/Fill-in-blank: Use HuggingFace ML scoring
      try {
        final detection = await _languageDetectionService.detectLanguage(
          userAnswer,
        );
        final scoreResult = await HuggingFaceApiService.scoreAnswer(
          userInput: userAnswer,
          correctAnswer: question.correctAnswer,
        );

        final mismatch =
            detection.language != widget.chapter.language &&
            detection.confidence >= 0.65;

        setState(() {
          question.isCorrect = mismatch ? false : scoreResult.isCorrect;
          _languageDetectionNote =
              'Detected ${detection.language} (${(detection.confidence * 100).round()}%)';
          _isAnswerChecked = true;
        });
        debugPrint(
          '✅ ML Score for "$userAnswer": ${scoreResult.score}% (${scoreResult.feedback})',
        );
      } catch (e) {
        // Fallback: Use string similarity if ML fails
        debugPrint('⚠️ ML scoring failed: $e, using fallback');
        final similarity = _calculateSimilarity(
          question.correctAnswer.toLowerCase(),
          userAnswer.toLowerCase(),
        );
        setState(() {
          question.isCorrect = similarity >= 0.7;
          _languageDetectionNote = '';
          _isAnswerChecked = true;
        });
      }
    } else {
      // Pronunciation: ML + phoneme analysis
      final analysis = await PronunciationService.analyzePronunciation(
        expected: question.correctAnswer,
        spoken: userAnswer,
        language: widget.chapter.language,
      );
      setState(() {
        question.isCorrect = analysis.score >= 65;
        _pronunciationAnalysis = analysis;
        _languageDetectionNote = '';
        _isAnswerChecked = true;
      });
    }

    _animationController.forward().then((_) => _animationController.reverse());

    // Record attempt in personalization service
    _recordPersonalizationData(question, userAnswer);
  }

  /// Record user attempt for personalization
  void _recordPersonalizationData(ChapterQuizQuestion question, String answer) {
    try {
      final userProvider = context.read<UserProvider>();
      if (userProvider.currentUser != null) {
        PersonalizationService().recordWordAttempt(
          word: question.correctAnswer,
          isCorrect: question.isCorrect ?? false,
          language: widget.chapter.language,
        );
      }
    } catch (e) {
      debugPrint('Personalization recording error: $e');
    }
  }

  /// Calculate similarity between two strings
  double _calculateSimilarity(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final longer = s1.length > s2.length ? s1 : s2;
    final shorter = s1.length > s2.length ? s2 : s1;

    if (longer.isEmpty) return 1.0;

    final distance = _levenshteinDistance(longer, shorter);
    return (longer.length - distance) / longer.length;
  }

  /// Levenshtein distance
  int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    final matrix = List.generate(len1 + 1, (_) => List.filled(len2 + 1, 0));

    for (var i = 0; i <= len1; i++) matrix[i][0] = i;
    for (var j = 0; j <= len2; j++) matrix[0][j] = j;

    for (var i = 1; i <= len1; i++) {
      for (var j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }
    return matrix[len1][len2];
  }

  /// Go to next question
  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _isAnswerChecked = false;
        _answerController.clear();
        _recognizedText = '';
        _languageDetectionNote = '';
        _pronunciationAnalysis = null;
      });
    } else {
      _showResults();
    }
  }

  /// Show final results
  void _showResults() {
    if (_questions.isEmpty) return;
    final correctCount = _questions.where((q) => q.isCorrect == true).length;
    final score = (correctCount / _questions.length) * 100;
    final passed = score >= 80;

    setState(() {
      _showResult = true;
    });

    // If passed, unlock next chapter
    if (passed) {
      final learningProvider = context.read<LearningProvider>();
      final gamificationProvider = context.read<GamificationProvider>();

      // Only award XP on first time passing (not on retakes)
      final alreadyPassed = learningProvider.isChapterQuizPassed(
        widget.chapter.id,
      );

      // Mark chapter as completed with quiz passed
      learningProvider.completeChapterQuiz(widget.chapter.id, score);

      // Award 50 XP only on first pass
      if (!alreadyPassed) {
        gamificationProvider.addPoints(50);
      }
    }
  }

  /// Start listening for pronunciation
  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      _recognizedText = '';
    });

    await VoiceService.listen(
      language: widget.chapter.language,
      onResult: (text) {
        setState(() {
          _recognizedText = text;
        });
      },
      onStart: () {},
      onStop: () {
        setState(() {
          _isListening = false;
        });
      },
    );
  }

  /// Speak the word for pronunciation help
  Future<void> _speakWord(String word) async {
    await VoiceService.speak(word, widget.chapter.language);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingQuestions) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chapter Quiz')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError.isNotEmpty
                      ? _loadError
                      : 'No chapter quiz questions available from XLM-RoBERTa.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _generateQuestions,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry ML Load'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_showResult) {
      return _buildResultScreen();
    }

    return Scaffold(
      backgroundColor: AppTheme.lightGray,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textDark),
          onPressed: () => _showExitDialog(),
        ),
        title: Text(
          'Chapter Quiz',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),

            // Question content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildQuestionCard(),
              ),
            ),

            // Bottom buttons
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                style: const TextStyle(
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              _buildQuestionTypeChip(),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _questions.length,
            backgroundColor: AppTheme.textDark.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.orange),
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionTypeChip() {
    final question = _questions[_currentQuestionIndex];
    String label;
    IconData icon;
    Color color;

    switch (question.type) {
      case QuestionType.writtenInput:
        label = 'Written';
        icon = Icons.edit_note;
        color = Colors.blue;
        break;
      case QuestionType.multipleChoice:
        label = 'MCQ';
        icon = Icons.radio_button_checked;
        color = Colors.green;
        break;
      case QuestionType.fillInBlank:
        label = 'Fill Blank';
        icon = Icons.short_text;
        color = Colors.orange;
        break;
      case QuestionType.pronunciation:
        label = 'Pronounce';
        icon = Icons.mic;
        color = Colors.purple;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    final question = _questions[_currentQuestionIndex];

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textDark.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question text
            Text(
              question.question,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textDark,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            // Speak button for pronunciation help
            if (question.urduWord != null) ...[
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => _speakWord(question.urduWord!),
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Listen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Answer input based on type
            _buildAnswerInput(question),

            // Feedback after checking
            if (_isAnswerChecked) _buildFeedback(question),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerInput(ChapterQuizQuestion question) {
    switch (question.type) {
      case QuestionType.writtenInput:
      case QuestionType.fillInBlank:
        return TextField(
          controller: _answerController,
          enabled: !_isAnswerChecked,
          onChanged: (_) => setState(() {}),
          cursorColor: AppTheme.primaryGreen,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
            fontSize: 18,
          ),
          decoration: InputDecoration(
            hintText: question.type == QuestionType.fillInBlank
                ? 'Type the missing word...'
                : 'Type your answer...',
            hintStyle: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
            ),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkSurfaceVariant
                : AppTheme.lightGray,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade600
                    : Colors.grey.shade400,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryGreen,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          textAlign: TextAlign.center,
        );

      case QuestionType.multipleChoice:
        return Column(
          children: question.options!.map((option) {
            final isSelected = question.userAnswer == option;
            final isCorrect = option == question.correctAnswer;

            Color? bgColor;
            Color? borderColor;

            if (_isAnswerChecked) {
              if (isCorrect) {
                bgColor = Colors.green.withOpacity(0.2);
                borderColor = Colors.green;
              } else if (isSelected && !isCorrect) {
                bgColor = Colors.red.withOpacity(0.2);
                borderColor = Colors.red;
              }
            } else if (isSelected) {
              bgColor = AppTheme.orange.withOpacity(0.2);
              borderColor = AppTheme.orange;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: _isAnswerChecked
                    ? null
                    : () {
                        setState(() {
                          question.userAnswer = option;
                          _answerController.text = option;
                        });
                      },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor ?? Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: borderColor ?? AppTheme.textDark.withOpacity(0.2),
                      width: isSelected || (_isAnswerChecked && isCorrect)
                          ? 2
                          : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textDark,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (_isAnswerChecked && isCorrect)
                        const Icon(Icons.check_circle, color: Colors.green),
                      if (_isAnswerChecked && isSelected && !isCorrect)
                        const Icon(Icons.cancel, color: Colors.red),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );

      case QuestionType.pronunciation:
        return Column(
          children: [
            // Recognized text display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _isAnswerChecked
                    ? (question.isCorrect == true
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1))
                    : AppTheme.lightGray,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isListening
                      ? AppTheme.orange
                      : AppTheme.textDark.withOpacity(0.2),
                  width: _isListening ? 2 : 1,
                ),
              ),
              child: Text(
                _recognizedText.isEmpty
                    ? 'Tap the microphone and speak...'
                    : _recognizedText,
                style: TextStyle(
                  fontSize: 18,
                  color: _recognizedText.isEmpty
                      ? Colors.grey
                      : AppTheme.textDark,
                  fontStyle: _recognizedText.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            // Microphone button
            GestureDetector(
              onTap: _isAnswerChecked ? null : _startListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _isListening ? Colors.red : AppTheme.orange,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.red : AppTheme.orange)
                          .withOpacity(0.4),
                      blurRadius: _isListening ? 20 : 10,
                      spreadRadius: _isListening ? 2 : 0,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            if (_isListening)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Listening...',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        );
    }
  }

  Widget _buildFeedback(ChapterQuizQuestion question) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: question.isCorrect == true
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: question.isCorrect == true ? Colors.green : Colors.red,
        ),
      ),
      child: Row(
        children: [
          Icon(
            question.isCorrect == true ? Icons.check_circle : Icons.cancel,
            color: question.isCorrect == true ? Colors.green : Colors.red,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.isCorrect == true ? 'Correct!' : 'Incorrect',
                  style: TextStyle(
                    color: question.isCorrect == true
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (question.isCorrect != true) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Correct answer: ${question.correctAnswer}',
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 14,
                    ),
                  ),
                ],
                if (_languageDetectionNote.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _languageDetectionNote,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
                if (question.type == QuestionType.pronunciation &&
                    _pronunciationAnalysis != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Pronunciation: ${_pronunciationAnalysis!.score}% | ML ${_pronunciationAnalysis!.mlSimilarity}% | Phoneme ${_pronunciationAnalysis!.phonemeAccuracy}%',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    _pronunciationAnalysis!.feedback,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    final question = _questions[_currentQuestionIndex];
    final canCheck = question.type == QuestionType.multipleChoice
        ? question.userAnswer != null && question.userAnswer!.isNotEmpty
        : question.type == QuestionType.pronunciation
        ? _recognizedText.isNotEmpty
        : _answerController.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: _isAnswerChecked
            ? ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: Text(
                  _currentQuestionIndex < _questions.length - 1
                      ? 'Next Question'
                      : 'See Results',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : ElevatedButton(
                onPressed: canCheck ? _checkAnswer : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canCheck
                      ? AppTheme.textDark
                      : AppTheme.textDark.withOpacity(0.3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text(
                  'Check Answer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final correctCount = _questions.where((q) => q.isCorrect == true).length;
    final score = (correctCount / _questions.length) * 100;
    final passed = score >= 80;

    return Scaffold(
      backgroundColor: AppTheme.lightGray,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Result icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: passed
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    passed ? Icons.emoji_events : Icons.refresh,
                    size: 60,
                    color: passed ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(height: 24),

                // Result title
                Text(
                  passed ? 'Congratulations! 🎉' : 'Keep Practicing!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Score
                Text(
                  'You scored',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textDark.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${score.toInt()}%',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: passed ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$correctCount out of ${_questions.length} correct',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textDark.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),

                // Pass/Fail message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: passed
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: passed
                          ? Colors.green.withOpacity(0.3)
                          : Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    passed
                        ? '✅ You passed! The next chapter is now unlocked.'
                        : '⚠️ You need 80% to pass and unlock the next chapter. Review the lessons and try again!',
                    style: TextStyle(
                      color: passed ? Colors.green[800] : Colors.orange[800],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                if (passed) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: AppTheme.orange),
                        const SizedBox(width: 8),
                        Text(
                          '+50 XP Earned!',
                          style: TextStyle(
                            color: Colors.amber[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Action buttons
                if (!passed)
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentQuestionIndex = 0;
                        _showResult = false;
                        _isAnswerChecked = false;
                        _answerController.clear();
                        _recognizedText = '';
                        _generateQuestions(); // Regenerate questions
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    passed ? 'Continue Learning' : 'Review Lessons',
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Quiz?'),
        content: const Text(
          'Your progress will be lost. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit quiz
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../providers/learning_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/huggingface_api_service.dart';
import '../../services/quiz_generator_service.dart' as mlquiz;
import '../../services/language_detection_service.dart';

/// Quiz Types for different question styles
enum QuizType { vocabulary, grammar, comprehension, mixed }

/// Answer types for quiz questions
enum AnswerType { multipleChoice, fillInBlank, trueFalse, freeText }

/// Enhanced Quiz Question Model
class EnhancedQuizQuestion {
  final String id;
  final String question;
  final List<String>? options;
  final String correctAnswer;
  final String? wordToTranslate;
  final QuizType questionType;
  final AnswerType answerType;
  final String? explanation;
  String selectedAnswer;

  EnhancedQuizQuestion({
    required this.id,
    required this.question,
    this.options,
    required this.correctAnswer,
    this.wordToTranslate,
    this.questionType = QuizType.vocabulary,
    this.answerType = AnswerType.multipleChoice,
    this.explanation,
    this.selectedAnswer = '',
  });
}

class QuizScreen extends StatefulWidget {
  final Chapter chapter;

  const QuizScreen({super.key, required this.chapter});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  List<EnhancedQuizQuestion> _questions = [];
  bool _isLoadingQuestions = true;
  bool _questionsLoaded = false;
  int _currentQuestionIndex = 0;
  int _score = 0;
  int _totalPoints = 0;
  bool _showResult = false;
  bool _isCheckingAnswer = false;
  QuizScoreResult? _lastScoreResult;
  String _languageDetectionNote = '';
  String _loadError = '';
  final TextEditingController _answerController = TextEditingController();
  final LanguageDetectionService _languageDetectionService =
      LanguageDetectionService();

  late AnimationController _feedbackAnimationController;
  late Animation<double> _feedbackAnimation;

  // ML-only mode: local hardcoded/content fallbacks are intentionally disabled.

  @override
  void initState() {
    super.initState();
    _feedbackAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _feedbackAnimation = CurvedAnimation(
      parent: _feedbackAnimationController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _answerController.dispose();
    _feedbackAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_questionsLoaded) return;
    _questionsLoaded = true;
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final language = userProvider.currentUser?.selectedLanguage ?? 'urdu';

    setState(() {
      _isLoadingQuestions = true;
    });

    try {
      final mlQuestions =
          await mlquiz.QuizGeneratorService.generateMLEnhancedQuiz(
            chapterId: widget.chapter.id,
            lessonIndex: 0,
            language: language,
            questionCount: 12,
            useSemanticDistractors: true,
          );

      if (mlQuestions.isNotEmpty) {
        _questions = mlQuestions.map(_convertMlQuestion).toList();
        _loadError = '';
      } else {
        _questions = [];
        _loadError =
            'XLM-RoBERTa did not return quiz questions for this chapter.';
      }
    } catch (e) {
      _questions = [];
      _loadError = 'Failed to load quiz from XLM-RoBERTa.';
      debugPrint('Quiz ML-only load error: $e');
    }

    if (!mounted) return;
    setState(() {
      _isLoadingQuestions = false;
    });
  }

  EnhancedQuizQuestion _convertMlQuestion(mlquiz.QuizQuestion q) {
    final answerType = q.isMultipleChoice
        ? AnswerType.multipleChoice
        : AnswerType.freeText;

    final qType = switch (q.type) {
      mlquiz.QuizType.grammar => QuizType.grammar,
      mlquiz.QuizType.comprehension => QuizType.comprehension,
      _ => QuizType.vocabulary,
    };

    return EnhancedQuizQuestion(
      id: q.id,
      question: q.question,
      options: q.options,
      correctAnswer: q.correctAnswer,
      wordToTranslate: q.questionUrdu,
      questionType: qType,
      answerType: answerType,
      explanation: q.hint,
    );
  }

  Future<void> _answerQuestion(String selectedAnswer) async {
    final currentQuestion = _questions[_currentQuestionIndex];
    currentQuestion.selectedAnswer = selectedAnswer;
    final expectedLanguage =
        Provider.of<UserProvider>(
          context,
          listen: false,
        ).currentUser?.selectedLanguage ??
        'urdu';

    setState(() {
      _isCheckingAnswer = true;
    });

    try {
      // Use ML scoring for free text and fill-in-blank
      if (currentQuestion.answerType == AnswerType.freeText ||
          currentQuestion.answerType == AnswerType.fillInBlank) {
        final detected = await _languageDetectionService.detectLanguage(
          selectedAnswer,
        );

        _lastScoreResult = await HuggingFaceApiService.scoreAnswer(
          userInput: selectedAnswer,
          correctAnswer: currentQuestion.correctAnswer,
        );

        final hasLanguageMismatch =
            detected.language != expectedLanguage &&
            detected.confidence >= 0.65;

        if (hasLanguageMismatch) {
          final penalizedScore = (_lastScoreResult!.score - 20).clamp(0, 100);
          _lastScoreResult = QuizScoreResult(
            score: penalizedScore,
            feedback:
                'Language mismatch detected (${detected.language}). ${_lastScoreResult!.feedback}',
            feedbackUrdu: _lastScoreResult!.feedbackUrdu,
            emoji: '🚨',
            isCorrect: penalizedScore >= 80,
            confidence: _lastScoreResult!.confidence,
            userInput: _lastScoreResult!.userInput,
            correctAnswer: _lastScoreResult!.correctAnswer,
          );
          _languageDetectionNote =
              'Detected ${detected.language} with ${(detected.confidence * 100).round()}% confidence.';
        } else {
          _languageDetectionNote =
              'Detected ${detected.language} (${(detected.confidence * 100).round()}%).';
        }

        if (_lastScoreResult!.isCorrect) {
          _score++;
        }
        _totalPoints += _lastScoreResult!.score;
      } else {
        // Simple comparison for MCQ and True/False
        if (selectedAnswer == currentQuestion.correctAnswer) {
          _score++;
          _totalPoints += 100;
          _lastScoreResult = QuizScoreResult(
            score: 100,
            feedback: 'Perfect!',
            feedbackUrdu: 'بالکل درست!',
            emoji: '✅',
            isCorrect: true,
            confidence: 100,
            userInput: selectedAnswer,
            correctAnswer: currentQuestion.correctAnswer,
          );
          _languageDetectionNote = '';
        } else {
          _lastScoreResult = QuizScoreResult(
            score: 0,
            feedback: 'Incorrect',
            feedbackUrdu: 'غلط',
            emoji: '❌',
            isCorrect: false,
            confidence: 100,
            userInput: selectedAnswer,
            correctAnswer: currentQuestion.correctAnswer,
          );
          _languageDetectionNote = '';
        }
      }
    } catch (e) {
      // Fallback if API fails
      if (selectedAnswer == currentQuestion.correctAnswer) {
        _score++;
        _totalPoints += 100;
      }
    }

    setState(() {
      _showResult = true;
      _isCheckingAnswer = false;
    });

    _feedbackAnimationController.forward(from: 0);

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        if (_currentQuestionIndex < _questions.length - 1) {
          setState(() {
            _currentQuestionIndex++;
            _showResult = false;
            _lastScoreResult = null;
            _languageDetectionNote = '';
            _answerController.clear();
          });
        } else {
          _showCompletionDialog();
        }
      }
    });
  }

  void _showCompletionDialog() {
    final percentage = ((_score / _questions.length) * 100).toInt();

    // Calculate XP based on accuracy: Max 10 XP scaled by correctness (e.g. 80% → 8 XP)
    int earnedXP = percentage ~/ 10;
    if (earnedXP > 10) earnedXP = 10;
    if (earnedXP < 0) earnedXP = 0;

    debugPrint(
      '📊 Quiz completed: $_score/${_questions.length} correct ($percentage%) → $earnedXP XP',
    );

    Provider.of<GamificationProvider>(
      context,
      listen: false,
    ).addPoints(earnedXP);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (context, value, child) =>
            Transform.scale(scale: value, child: child),
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  percentage >= 80
                      ? AppTheme.primaryGreen.withOpacity(0.08)
                      : Colors.orange.withOpacity(0.08),
                  Colors.white,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated trophy/star
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: percentage >= 80
                            ? [AppTheme.primaryGreen, const Color(0xFF34A853)]
                            : percentage >= 60
                            ? [AppTheme.orange, Colors.amber]
                            : [Colors.red.shade400, Colors.orange],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (percentage >= 80
                                      ? AppTheme.primaryGreen
                                      : AppTheme.orange)
                                  .withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      percentage >= 80
                          ? Icons.emoji_events
                          : percentage >= 60
                          ? Icons.stars
                          : Icons.school,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  percentage >= 90
                      ? 'Outstanding!'
                      : percentage >= 80
                      ? 'Great Job!'
                      : percentage >= 60
                      ? 'Good Effort!'
                      : 'Keep Practicing!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getFeedbackMessage(percentage),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 24),
                // Score ring
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: percentage / 100),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 8,
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.darkSurfaceVariant
                                : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(
                              percentage >= 80
                                  ? AppTheme.primaryGreen
                                  : percentage >= 60
                                  ? Colors.amber
                                  : Colors.orange,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(value * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _getGradeLabel(percentage),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Stats row
                Row(
                  children: [
                    _buildCompletionStat(
                      Icons.check_circle,
                      '$_score/${_questions.length}',
                      'Correct',
                      Colors.green,
                    ),
                    _buildCompletionStat(
                      Icons.star,
                      '$_totalPoints',
                      'Points',
                      AppTheme.orange,
                    ),
                    _buildCompletionStat(
                      Icons.bolt,
                      '+$earnedXP',
                      'XP',
                      AppTheme.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _currentQuestionIndex = 0;
                            _score = 0;
                            _totalPoints = 0;
                            _showResult = false;
                            _lastScoreResult = null;
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Done'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionStat(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  String _getGradeLabel(int percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    return 'D';
  }

  String _getFeedbackMessage(int percentage) {
    if (percentage >= 90) return '🌟 Outstanding! You\'ve mastered this!';
    if (percentage >= 80) return '👏 Great job! Keep it up!';
    if (percentage >= 70) return '👍 Good progress! Practice more.';
    if (percentage >= 60) return '💪 Not bad! Review and try again.';
    return '📚 Keep practicing!';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingQuestions) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError.isNotEmpty
                      ? _loadError
                      : 'No quiz questions available from XLM-RoBERTa.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _loadQuestions,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry ML Load'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Premium top bar
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: isDark
                              ? AppTheme.textLight.withOpacity(0.78)
                              : Colors.black54,
                        ),
                        onPressed: () => _showExitConfirmation(),
                      ),
                      Expanded(
                        child: Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurfaceVariant
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            width:
                                MediaQuery.of(context).size.width *
                                0.6 *
                                ((_currentQuestionIndex + 1) /
                                    _questions.length),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.primaryGreen,
                                  AppTheme.lightGreen,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: AppTheme.orange,
                              size: 16,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$_totalPoints',
                              style: const TextStyle(
                                color: AppTheme.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '  Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.textLight.withOpacity(0.78)
                              : Colors.grey.shade600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          currentQuestion.questionType.name.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.purple,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Question Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Question Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getQuestionIcon(currentQuestion.questionType),
                              color: AppTheme.primaryGreen,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            currentQuestion.question,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (currentQuestion.wordToTranslate != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryGreen.withOpacity(0.08),
                                    AppTheme.primaryGreen.withOpacity(0.04),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.primaryGreen.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                currentQuestion.wordToTranslate!,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryGreen,
                                  fontFamily: 'NotoNastaliqUrdu',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAnswerSection(currentQuestion),
                    if (_showResult && _lastScoreResult != null) ...[
                      const SizedBox(height: 24),
                      _buildFeedbackCard(),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Button for text input
            if (currentQuestion.answerType == AnswerType.freeText ||
                currentQuestion.answerType == AnswerType.fillInBlank)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _showResult ||
                            _isCheckingAnswer ||
                            _answerController.text.isEmpty
                        ? null
                        : () => _answerQuestion(_answerController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: isDark
                          ? AppTheme.darkSurfaceVariant
                          : Colors.grey.shade300,
                    ),
                    child: _isCheckingAnswer
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Check Answer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerSection(EnhancedQuizQuestion question) {
    switch (question.answerType) {
      case AnswerType.multipleChoice:
        return _buildMultipleChoice(question);
      case AnswerType.trueFalse:
        return _buildTrueFalse(question);
      case AnswerType.freeText:
      case AnswerType.fillInBlank:
        return _buildTextInput(question);
    }
  }

  Widget _buildMultipleChoice(EnhancedQuizQuestion question) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children:
          question.options?.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isCorrect = option == question.correctAnswer;
            final isSelected = question.selectedAnswer == option;

            Color backgroundColor = isDark ? AppTheme.darkSurface : Colors.white;
            Color borderColor = AppTheme.lightGreen;

            if (_showResult) {
              if (isCorrect) {
                backgroundColor = Colors.green.withOpacity(0.15);
                borderColor = Colors.green;
              } else if (isSelected && !isCorrect) {
                backgroundColor = Colors.red.withOpacity(0.15);
                borderColor = Colors.red;
              }
            } else if (isSelected) {
              backgroundColor = AppTheme.primaryGreen.withOpacity(0.15);
              borderColor = AppTheme.primaryGreen;
            }

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 300 + (index * 80)),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(30 * (1 - value), 0),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: GestureDetector(
                onTap: _showResult || _isCheckingAnswer
                    ? null
                    : () => _answerQuestion(option),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor,
                      width: isSelected || (_showResult && isCorrect) ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected || (_showResult && isCorrect)
                              ? borderColor
                              : (isDark
                                    ? AppTheme.darkSurfaceVariant
                                    : Colors.grey.shade200),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: _showResult
                              ? Icon(
                                  isCorrect
                                      ? Icons.check
                                      : (isSelected ? Icons.close : null),
                                  color: Colors.white,
                                  size: 20,
                                )
                              : Text(
                                  String.fromCharCode(65 + index),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                              ? AppTheme.textLight.withOpacity(
                                                  0.78,
                                                )
                                              : Colors.grey.shade600),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          option,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList() ??
          [],
    );
  }

  Widget _buildTrueFalse(EnhancedQuizQuestion question) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: ['True', 'False'].map((option) {
        final isCorrect = option == question.correctAnswer;
        final isSelected = question.selectedAnswer == option;
        final isTrue = option == 'True';

        Color backgroundColor = isDark ? AppTheme.darkSurface : Colors.white;
        Color borderColor = isTrue ? Colors.green : Colors.red;

        if (_showResult) {
          if (isCorrect) {
            backgroundColor = Colors.green.withOpacity(0.15);
          } else if (isSelected && !isCorrect) {
            backgroundColor = Colors.red.withOpacity(0.15);
          }
        }

        return Expanded(
          child: GestureDetector(
            onTap: _showResult || _isCheckingAnswer
                ? null
                : () => _answerQuestion(option),
            child: Container(
              margin: EdgeInsets.only(
                right: isTrue ? 8 : 0,
                left: isTrue ? 0 : 8,
              ),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? borderColor
                      : (isDark
                            ? AppTheme.darkSurfaceVariant
                            : Colors.grey.shade300),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isTrue ? Icons.check_circle : Icons.cancel,
                    color: isSelected
                        ? borderColor
                        : (isDark
                              ? AppTheme.textLight.withOpacity(0.72)
                              : Colors.grey),
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    option,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? borderColor
                          : (isDark
                                ? AppTheme.textLight.withOpacity(0.72)
                                : Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextInput(EnhancedQuizQuestion question) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkSurfaceVariant : Colors.grey.shade300,
        ),
      ),
      child: TextField(
        controller: _answerController,
        enabled: !_showResult,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        cursorColor: AppTheme.primaryGreen,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 24,
          fontFamily: 'NotoNastaliqUrdu',
        ),
        decoration: InputDecoration(
          hintText: 'Type your answer in ${widget.chapter.language}...',
          hintStyle: TextStyle(
            color: isDark
                ? Colors.grey.shade400
                : Colors.grey.shade600,
            fontSize: 16,
          ),
          filled: true,
          fillColor: isDark ? AppTheme.darkBackground : AppTheme.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppTheme.primaryGreen,
              width: 2,
            ),
          ),
          suffixIcon: _showResult && _lastScoreResult != null
              ? Icon(
                  _lastScoreResult!.isCorrect
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: _lastScoreResult!.isCorrect
                      ? Colors.green
                      : Colors.orange,
                  size: 28,
                )
              : null,
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildFeedbackCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = _lastScoreResult!;
    final isGood = result.score >= 60;

    return ScaleTransition(
      scale: _feedbackAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isGood
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isGood ? Colors.green : Colors.orange),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(result.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.feedback,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isGood ? Colors.green : Colors.orange,
                        ),
                      ),
                      Text(
                        'Score: ${result.score}%',
                        style: TextStyle(
                          color: isGood
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isGood ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${result.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            if (!result.isCorrect) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Correct: ',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Expanded(
                      child: Text(
                        result.correctAnswer,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontFamily: 'NotoNastaliqUrdu',
                          fontSize: 18,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_languageDetectionNote.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _languageDetectionNote,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getQuestionIcon(QuizType type) {
    switch (type) {
      case QuizType.vocabulary:
        return Icons.text_fields;
      case QuizType.grammar:
        return Icons.spellcheck;
      case QuizType.comprehension:
        return Icons.menu_book;
      case QuizType.mixed:
        return Icons.shuffle;
    }
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Quiz?'),
        content: const Text('Your progress will be lost. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

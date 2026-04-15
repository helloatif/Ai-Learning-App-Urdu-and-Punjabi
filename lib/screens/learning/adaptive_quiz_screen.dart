import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../providers/learning_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/adaptive_learning_provider.dart';
import '../../providers/user_provider.dart';
import '../../data/vocabulary_data.dart';

class AdaptiveQuizScreen extends StatefulWidget {
  final Chapter chapter;
  final LessonVocabulary lessonData;
  final int lessonNumber;

  const AdaptiveQuizScreen({
    super.key,
    required this.chapter,
    required this.lessonData,
    required this.lessonNumber,
  });

  @override
  State<AdaptiveQuizScreen> createState() => _AdaptiveQuizScreenState();
}

class _AdaptiveQuizScreenState extends State<AdaptiveQuizScreen>
    with SingleTickerProviderStateMixin {
  late List<QuizQuestion> _questions;
  int _currentQuestionIndex = 0;
  int _score = 0;
  final List<String> _missedWords = [];
  bool _showResult = false;
  String? _selectedAnswer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _generateQuestions();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _generateQuestions() {
    _questions = [];
    final words = widget.lessonData.words;

    // Get language from user provider
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final language = userProvider.currentUser?.selectedLanguage ?? 'urdu';
    final languageLabel = language == 'urdu' ? 'Urdu' : 'Punjabi';

    // Generate 5 questions from lesson vocabulary
    final selectedWords = words.length <= 5
        ? words
        : (words.toList()..shuffle()).take(5).toList();

    for (var word in selectedWords) {
      // Create other options from the same lesson
      final otherWords = words.where((w) => w.english != word.english).toList();
      otherWords.shuffle();

      final options = [
        word.english,
        ...otherWords.take(3).map((w) => w.english),
      ]..shuffle();

      _questions.add(
        QuizQuestion(
          id: word.urdu,
          question: 'What is the English translation of "${word.urdu}"?',
          options: options,
          correctAnswer: word.english,
          urduWord: word.urdu,
          languageLabel: languageLabel,
        ),
      );
    }
  }

  void _answerQuestion(String selectedAnswer) {
    if (_showResult) return;

    setState(() {
      _selectedAnswer = selectedAnswer;
      _showResult = true;
    });

    final isCorrect =
        selectedAnswer == _questions[_currentQuestionIndex].correctAnswer;

    if (isCorrect) {
      _score++;
      Provider.of<GamificationProvider>(context, listen: false).addPoints(10);
    } else {
      _missedWords.add(_questions[_currentQuestionIndex].urduWord);
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
          _showResult = false;
          _selectedAnswer = null;
        });
        _animationController.reset();
        _animationController.forward();
      } else {
        _showCompletionDialog();
      }
    });
  }

  void _showCompletionDialog() {
    final percentage = ((_score / _questions.length) * 100).round();
    final adaptive = Provider.of<AdaptiveLearningProvider>(
      context,
      listen: false,
    );
    final gamification = Provider.of<GamificationProvider>(
      context,
      listen: false,
    );

    // Create lesson ID from chapter and lesson number
    final lessonId = '${widget.chapter.id}_lesson${widget.lessonNumber}';

    // Process quiz results through adaptive learning
    final action = adaptive.processQuizScore(
      lessonId,
      percentage,
      _missedWords,
    );

    // Calculate XP based on accuracy: Max 10 XP scaled by correctness
    // Example: 15/15 = 100% = 10 XP, 10/15 = 66.7% = 6.67 ≈ 7 XP
    final earnedXP = ((_score / _questions.length) * 10).round();

    debugPrint(
      '📊 Adaptive quiz completed: $_score/${_questions.length} correct ($percentage%) → $earnedXP XP',
    );

    gamification.addPoints(earnedXP);
    gamification.updateDailyStreak();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildResultDialog(percentage, action),
    );
  }

  Widget _buildResultDialog(int percentage, QuizAction action) {
    String title;
    String message;
    IconData icon;
    Color color;

    if (action == QuizAction.relearn) {
      title = 'Need More Practice';
      message =
          'Score: $percentage%\n\nYou scored below 60%. Let\'s review this lesson again to strengthen your understanding.';
      icon = Icons.refresh_rounded;
      color = AppTheme.red;
    } else if (action == QuizAction.reviewInNext) {
      title = 'Good Progress!';
      message =
          'Score: $percentage%\n\nYou\'re doing well! We\'ll review the words you missed (${_missedWords.length}) in the next lesson.';
      icon = Icons.trending_up_rounded;
      color = AppTheme.orange;
    } else {
      title = 'Excellent Work!';
      message =
          'Score: $percentage%\n\nOutstanding! You\'ve mastered this lesson. Ready for the next one?';
      icon = Icons.emoji_events_rounded;
      color = AppTheme.primaryGreen;
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 50, color: color),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textDark,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Action Buttons
          if (action == QuizAction.relearn) ...[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                // Navigate back to chapter to review
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.red,
                foregroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded),
                  SizedBox(width: 8),
                  Text(
                    'Review Chapter',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: AppTheme.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward_rounded),
                  SizedBox(width: 8),
                  Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(child: Text('No questions available')),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.backgroundGradientStart,
              AppTheme.backgroundGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: AppTheme.textDark,
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation(
                                AppTheme.primaryGreen,
                              ),
                              minHeight: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_currentQuestionIndex + 1}/${_questions.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: AppTheme.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Score: $_score/${_questions.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Question Card
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: AppTheme.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.translate_rounded,
                                size: 48,
                                color: AppTheme.blue,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                currentQuestion.question,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                currentQuestion.urduWord,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryGreen,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Answer Options
                        ...currentQuestion.options.asMap().entries.map((entry) {
                          final index = entry.key;
                          final option = entry.value;
                          final isSelected = _selectedAnswer == option;
                          final isCorrect =
                              option == currentQuestion.correctAnswer;

                          Color cardColor = AppTheme.white;
                          Color borderColor = Colors.grey.shade300;

                          if (_showResult && isSelected) {
                            if (isCorrect) {
                              cardColor = AppTheme.primaryGreen.withValues(alpha: 0.1);
                              borderColor = AppTheme.primaryGreen;
                            } else {
                              cardColor = AppTheme.red.withValues(alpha: 0.1);
                              borderColor = AppTheme.red;
                            }
                          } else if (_showResult && isCorrect) {
                            cardColor = AppTheme.primaryGreen.withOpacity(0.1);
                                                        cardColor = AppTheme.primaryGreen.withValues(alpha: 0.1);
                            borderColor = AppTheme.primaryGreen;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: _showResult
                                  ? null
                                  : () => _answerQuestion(option),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: borderColor,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color:
                                            _showResult &&
                                                (isSelected || isCorrect)
                                            ? (isCorrect
                                                  ? AppTheme.primaryGreen
                                                  : AppTheme.red)
                                            : Colors.grey.shade200,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child:
                                            _showResult &&
                                                (isSelected || isCorrect)
                                            ? Icon(
                                                isCorrect
                                                    ? Icons.check
                                                    : Icons.close,
                                                color: AppTheme.white,
                                                size: 20,
                                              )
                                            : Text(
                                                String.fromCharCode(65 + index),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        option,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String urduWord;
  final String languageLabel;

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.urduWord,
    this.languageLabel = 'Urdu',
  });
}

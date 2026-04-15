import 'package:flutter/foundation.dart';
import 'ml_vocabulary_service.dart';

/// Service for generating learning content using AI
class ContentGenerationService {
  // API credentials for future integration
  // static const String _apiUrl = 'https://api-inference.huggingface.co/models/facebook/mbart-large-50-many-to-many-mmt';
  // static const String _apiToken = 'YOUR_HUGGING_FACE_API_TOKEN';

  /// Generate vocabulary words for a topic
  static Future<List<VocabularyWord>> generateVocabulary(
    String topic,
    String language,
    int count,
  ) async {
    try {
      // First try ML-backed vocabulary source.
      final chapterHint = _topicToChapterId(topic, language);
      final mlWords = await MLVocabularyService.generateVocabularyWithML(
        chapterId: chapterHint,
        lessonIndex: 0,
        language: language,
        count: count,
      );

      if (mlWords.isNotEmpty) {
        return mlWords
            .map(
              (w) => VocabularyWord(
                word: w.word,
                translation: w.translation,
                pronunciation: w.pronunciation,
                example: w.example ?? w.word,
                exampleTranslation: w.translation,
              ),
            )
            .toList();
      }

      return _getOfflineVocabulary(topic, language, count);
    } catch (e) {
      debugPrint('Content Generation Error: $e');
      return _getOfflineVocabulary(topic, language, count);
    }
  }

  static String _topicToChapterId(String topic, String language) {
    final normalized = topic.toLowerCase();
    final prefix = language == 'urdu' ? 'urdu_' : 'punjabi_';

    if (normalized.contains('emotion')) return '${prefix}ch11';
    if (normalized.contains('sport')) return '${prefix}ch12';
    if (normalized.contains('islam') ||
        normalized.contains('ramazan') ||
        normalized.contains('ramadan') ||
        normalized.contains('eid')) {
      return '${prefix}ch13';
    }
    if (normalized.contains('nature') || normalized.contains('environment')) {
      return '${prefix}ch14';
    }
    if (normalized.contains('home') ||
        normalized.contains('house') ||
        normalized.contains('furniture') ||
        normalized.contains('room')) {
      return '${prefix}ch15';
    }
    return '${prefix}ch1';
  }

  /// Generate contextual sentences for practice
  static Future<List<PracticeSentence>> generateSentences(
    String topic,
    String language,
    int count,
  ) async {
    try {
      return _getOfflineSentences(topic, language, count);
    } catch (e) {
      debugPrint('Content Generation Error: $e');
      return _getOfflineSentences(topic, language, count);
    }
  }

  /// Generate quiz questions
  static Future<List<QuizQuestion>> generateQuiz(
    String topic,
    String language,
    int questionCount,
  ) async {
    try {
      return _getOfflineQuiz(topic, language, questionCount);
    } catch (e) {
      debugPrint('Content Generation Error: $e');
      return _getOfflineQuiz(topic, language, questionCount);
    }
  }

  // ============================================================================
  // OFFLINE CONTENT GENERATION
  // ============================================================================

  static List<VocabularyWord> _getOfflineVocabulary(
    String topic,
    String language,
    int count,
  ) {
    final allWords = <VocabularyWord>[];

    if (language == 'urdu') {
      allWords.addAll(_urduVocabulary[topic] ?? _urduVocabulary['basics']!);
    } else if (language == 'punjabi') {
      allWords.addAll(
        _punjabiVocabulary[topic] ?? _punjabiVocabulary['basics']!,
      );
    }

    return allWords.take(count).toList();
  }

  static List<PracticeSentence> _getOfflineSentences(
    String topic,
    String language,
    int count,
  ) {
    final allSentences = <PracticeSentence>[];

    if (language == 'urdu') {
      allSentences.addAll(_urduSentences[topic] ?? _urduSentences['basics']!);
    } else if (language == 'punjabi') {
      allSentences.addAll(
        _punjabiSentences[topic] ?? _punjabiSentences['basics']!,
      );
    }

    return allSentences.take(count).toList();
  }

  static List<QuizQuestion> _getOfflineQuiz(
    String topic,
    String language,
    int count,
  ) {
    final allQuestions = <QuizQuestion>[];

    if (language == 'urdu') {
      allQuestions.addAll(_urduQuizzes[topic] ?? _urduQuizzes['basics']!);
    } else if (language == 'punjabi') {
      allQuestions.addAll(_punjabiQuizzes[topic] ?? _punjabiQuizzes['basics']!);
    }

    return allQuestions.take(count).toList();
  }

  // ============================================================================
  // URDU CONTENT DATABASE
  // ============================================================================

  static final Map<String, List<VocabularyWord>> _urduVocabulary = {
    'basics': [
      VocabularyWord(
        word: 'سلام',
        translation: 'Hello',
        pronunciation: 'Salaam',
        example: 'سلام! آپ کیسے ہیں؟',
        exampleTranslation: 'Hello! How are you?',
      ),
      VocabularyWord(
        word: 'شکریہ',
        translation: 'Thank you',
        pronunciation: 'Shukriya',
        example: 'آپ کا بہت شکریہ',
        exampleTranslation: 'Thank you very much',
      ),
      VocabularyWord(
        word: 'الوداع',
        translation: 'Goodbye',
        pronunciation: 'Alwida',
        example: 'الوداع، جلد ملیں گے',
        exampleTranslation: 'Goodbye, see you soon',
      ),
      VocabularyWord(
        word: 'ہاں',
        translation: 'Yes',
        pronunciation: 'Haan',
        example: 'ہاں، میں سمجھ گیا',
        exampleTranslation: 'Yes, I understood',
      ),
      VocabularyWord(
        word: 'نہیں',
        translation: 'No',
        pronunciation: 'Nahi',
        example: 'نہیں، یہ ٹھیک نہیں',
        exampleTranslation: 'No, this is not okay',
      ),
      VocabularyWord(
        word: 'براہ کرم',
        translation: 'Please',
        pronunciation: 'Barah-e-karam',
        example: 'براہ کرم مدد کریں',
        exampleTranslation: 'Please help',
      ),
      VocabularyWord(
        word: 'معاف کیجیے',
        translation: 'Sorry/Excuse me',
        pronunciation: 'Maaf kijiye',
        example: 'معاف کیجیے، میں دیر سے آیا',
        exampleTranslation: 'Sorry, I came late',
      ),
      VocabularyWord(
        word: 'نام',
        translation: 'Name',
        pronunciation: 'Naam',
        example: 'آپ کا نام کیا ہے؟',
        exampleTranslation: 'What is your name?',
      ),
    ],
    'family': [
      VocabularyWord(
        word: 'ماں',
        translation: 'Mother',
        pronunciation: 'Maa',
        example: 'میری ماں گھر پر ہیں',
        exampleTranslation: 'My mother is at home',
      ),
      VocabularyWord(
        word: 'باپ',
        translation: 'Father',
        pronunciation: 'Baap',
        example: 'میرے باپ ڈاکٹر ہیں',
        exampleTranslation: 'My father is a doctor',
      ),
      VocabularyWord(
        word: 'بھائی',
        translation: 'Brother',
        pronunciation: 'Bhai',
        example: 'میرا ایک بھائی ہے',
        exampleTranslation: 'I have one brother',
      ),
      VocabularyWord(
        word: 'بہن',
        translation: 'Sister',
        pronunciation: 'Behan',
        example: 'میری دو بہنیں ہیں',
        exampleTranslation: 'I have two sisters',
      ),
      VocabularyWord(
        word: 'دادا',
        translation: 'Grandfather (paternal)',
        pronunciation: 'Dada',
        example: 'میرے دادا لاہور میں رہتے ہیں',
        exampleTranslation: 'My grandfather lives in Lahore',
      ),
      VocabularyWord(
        word: 'دادی',
        translation: 'Grandmother (paternal)',
        pronunciation: 'Dadi',
        example: 'میری دادی کہانیاں سناتی ہیں',
        exampleTranslation: 'My grandmother tells stories',
      ),
    ],
    'food': [
      VocabularyWord(
        word: 'کھانا',
        translation: 'Food',
        pronunciation: 'Khana',
        example: 'کھانا تیار ہے',
        exampleTranslation: 'Food is ready',
      ),
      VocabularyWord(
        word: 'پانی',
        translation: 'Water',
        pronunciation: 'Pani',
        example: 'مجھے پانی چاہیے',
        exampleTranslation: 'I need water',
      ),
      VocabularyWord(
        word: 'چائے',
        translation: 'Tea',
        pronunciation: 'Chai',
        example: 'ایک کپ چائے دیں',
        exampleTranslation: 'Give me a cup of tea',
      ),
      VocabularyWord(
        word: 'روٹی',
        translation: 'Bread',
        pronunciation: 'Roti',
        example: 'یہ روٹی گرم ہے',
        exampleTranslation: 'This bread is hot',
      ),
      VocabularyWord(
        word: 'چاول',
        translation: 'Rice',
        pronunciation: 'Chawal',
        example: 'میں چاول پسند کرتا ہوں',
        exampleTranslation: 'I like rice',
      ),
    ],
  };

  static final Map<String, List<PracticeSentence>> _urduSentences = {
    'basics': [
      PracticeSentence(
        original: 'میرا نام احمد ہے',
        translation: 'My name is Ahmad',
        pronunciation: 'Mera naam Ahmad hai',
        difficulty: 'easy',
      ),
      PracticeSentence(
        original: 'آپ کا دن اچھا گزرے',
        translation: 'Have a good day',
        pronunciation: 'Aap ka din acha guzray',
        difficulty: 'easy',
      ),
      PracticeSentence(
        original: 'میں پاکستان سے ہوں',
        translation: 'I am from Pakistan',
        pronunciation: 'Main Pakistan se hoon',
        difficulty: 'easy',
      ),
    ],
    'conversation': [
      PracticeSentence(
        original: 'آپ کیسے ہیں؟',
        translation: 'How are you?',
        pronunciation: 'Aap kaise hain?',
        difficulty: 'easy',
      ),
      PracticeSentence(
        original: 'میں ٹھیک ہوں، شکریہ',
        translation: 'I am fine, thank you',
        pronunciation: 'Main theek hoon, shukriya',
        difficulty: 'easy',
      ),
    ],
  };

  static final Map<String, List<QuizQuestion>> _urduQuizzes = {
    'basics': [
      QuizQuestion(
        question: 'How do you say "Hello" in Urdu?',
        options: ['سلام', 'الوداع', 'شکریہ', 'ہاں'],
        correctAnswer: 0,
        explanation: 'سلام (Salaam) means "Hello" in Urdu',
      ),
      QuizQuestion(
        question: 'What does "شکریہ" mean?',
        options: ['Goodbye', 'Thank you', 'Please', 'Sorry'],
        correctAnswer: 1,
        explanation: 'شکریہ (Shukriya) means "Thank you"',
      ),
      QuizQuestion(
        question: 'Translate: "My name is Ahmad"',
        options: [
          'میرا نام احمد ہے',
          'آپ کا نام کیا ہے',
          'میں احمد ہوں',
          'احمد میرا دوست ہے',
        ],
        correctAnswer: 0,
        explanation: 'میرا نام احمد ہے is the correct translation',
      ),
    ],
  };

  // ============================================================================
  // PAKISTANI PUNJABI CONTENT DATABASE (Shahmukhi Script)
  // ============================================================================

  static final Map<String, List<VocabularyWord>> _punjabiVocabulary = {
    'basics': [
      VocabularyWord(
        word: 'السلام علیکم',
        translation: 'Hello',
        pronunciation: 'Assalam-o-Alaikum',
        example: 'السلام علیکم! تسیں کیویں او؟',
        exampleTranslation: 'Hello! How are you?',
      ),
      VocabularyWord(
        word: 'شکریہ',
        translation: 'Thank you',
        pronunciation: 'Shukriya',
        example: 'تہاڈا بہت شکریہ',
        exampleTranslation: 'Thank you very much',
      ),
      VocabularyWord(
        word: 'الوداع',
        translation: 'Goodbye',
        pronunciation: 'Alwida',
        example: 'الوداع، فیر ملاں گے',
        exampleTranslation: 'Goodbye, see you again',
      ),
      VocabularyWord(
        word: 'ہاں',
        translation: 'Yes',
        pronunciation: 'Haan',
        example: 'ہاں، میں سمجھ گیا',
        exampleTranslation: 'Yes, I understood',
      ),
      VocabularyWord(
        word: 'نئیں',
        translation: 'No',
        pronunciation: 'Nai',
        example: 'نئیں، ایہہ ٹھیک نئیں',
        exampleTranslation: 'No, this is not okay',
      ),
      VocabularyWord(
        word: 'مہربانی',
        translation: 'Please',
        pronunciation: 'Mehrbani',
        example: 'مہربانی کر کے مدد کرو',
        exampleTranslation: 'Please help',
      ),
      VocabularyWord(
        word: 'معاف کرنا',
        translation: 'Sorry',
        pronunciation: 'Maaf karna',
        example: 'معاف کرنا، میں دیر نال آیا',
        exampleTranslation: 'Sorry, I came late',
      ),
      VocabularyWord(
        word: 'ناں',
        translation: 'Name',
        pronunciation: 'Naa',
        example: 'تہاڈا ناں کی اے؟',
        exampleTranslation: 'What is your name?',
      ),
    ],
    'family': [
      VocabularyWord(
        word: 'ماں',
        translation: 'Mother',
        pronunciation: 'Maa',
        example: 'میری ماں گھر وچ اے',
        exampleTranslation: 'My mother is at home',
      ),
      VocabularyWord(
        word: 'ابا',
        translation: 'Father',
        pronunciation: 'Abba',
        example: 'میرے ابا ڈاکٹر نیں',
        exampleTranslation: 'My father is a doctor',
      ),
      VocabularyWord(
        word: 'بھرا',
        translation: 'Brother',
        pronunciation: 'Bhra',
        example: 'میرا اک بھرا اے',
        exampleTranslation: 'I have one brother',
      ),
      VocabularyWord(
        word: 'بھین',
        translation: 'Sister',
        pronunciation: 'Bhain',
        example: 'میریاں دو بھیناں نیں',
        exampleTranslation: 'I have two sisters',
      ),
      VocabularyWord(
        word: 'دادا',
        translation: 'Grandfather (paternal)',
        pronunciation: 'Dada',
        example: 'میرے دادا لہور وچ رہندے نیں',
        exampleTranslation: 'My grandfather lives in Lahore',
      ),
      VocabularyWord(
        word: 'دادی',
        translation: 'Grandmother (paternal)',
        pronunciation: 'Dadi',
        example: 'میری دادی کہانیاں سناندی اے',
        exampleTranslation: 'My grandmother tells stories',
      ),
    ],
    'food': [
      VocabularyWord(
        word: 'کھانا',
        translation: 'Food',
        pronunciation: 'Khana',
        example: 'کھانا تیار اے',
        exampleTranslation: 'Food is ready',
      ),
      VocabularyWord(
        word: 'پانی',
        translation: 'Water',
        pronunciation: 'Pani',
        example: 'مینوں پانی چاہیدا اے',
        exampleTranslation: 'I need water',
      ),
      VocabularyWord(
        word: 'چاہ',
        translation: 'Tea',
        pronunciation: 'Cha',
        example: 'اک کپ چاہ دے دیو',
        exampleTranslation: 'Give me a cup of tea',
      ),
      VocabularyWord(
        word: 'روٹی',
        translation: 'Bread',
        pronunciation: 'Roti',
        example: 'ایہہ روٹی گرم اے',
        exampleTranslation: 'This bread is hot',
      ),
      VocabularyWord(
        word: 'چاول',
        translation: 'Rice',
        pronunciation: 'Chawal',
        example: 'میں چاول پسند کردا ہاں',
        exampleTranslation: 'I like rice',
      ),
    ],
  };

  static final Map<String, List<PracticeSentence>> _punjabiSentences = {
    'basics': [
      PracticeSentence(
        original: 'میرا ناں احمد اے',
        translation: 'My name is Ahmad',
        pronunciation: 'Mera naa Ahmad ae',
        difficulty: 'easy',
      ),
      PracticeSentence(
        original: 'تہاڈا دن چنگا لنگھے',
        translation: 'Have a good day',
        pronunciation: 'Tuhada din changa langhe',
        difficulty: 'easy',
      ),
      PracticeSentence(
        original: 'میں پاکستان توں ہاں',
        translation: 'I am from Pakistan',
        pronunciation: 'Main Pakistan ton haan',
        difficulty: 'easy',
      ),
    ],
    'conversation': [
      PracticeSentence(
        original: 'تسیں کیویں او؟',
        translation: 'How are you?',
        pronunciation: 'Tusi kiwe o?',
        difficulty: 'easy',
      ),
      PracticeSentence(
        original: 'میں ٹھیک ہاں، شکریہ',
        translation: 'I am fine, thank you',
        pronunciation: 'Main theek haan, shukriya',
        difficulty: 'easy',
      ),
    ],
  };

  static final Map<String, List<QuizQuestion>> _punjabiQuizzes = {
    'basics': [
      QuizQuestion(
        question: 'How do you say "Hello" in Pakistani Punjabi?',
        options: ['السلام علیکم', 'الوداع', 'شکریہ', 'ہاں'],
        correctAnswer: 0,
        explanation:
            'السلام علیکم (Assalam-o-Alaikum) is used as "Hello" in Pakistani Punjabi',
      ),
      QuizQuestion(
        question: 'What does "شکریہ" mean?',
        options: ['Goodbye', 'Thank you', 'Please', 'Sorry'],
        correctAnswer: 1,
        explanation: 'شکریہ (Shukriya) means "Thank you" in Punjabi',
      ),
      QuizQuestion(
        question: 'Translate: "My name is Ahmad"',
        options: [
          'میرا ناں احمد اے',
          'تہاڈا ناں کی اے',
          'میں احمد ہاں',
          'احمد میرا دوست اے',
        ],
        correctAnswer: 0,
        explanation:
            'میرا ناں احمد اے is the correct translation in Shahmukhi script',
      ),
    ],
  };
}

/// Vocabulary word model
class VocabularyWord {
  final String word;
  final String translation;
  final String pronunciation;
  final String example;
  final String exampleTranslation;

  VocabularyWord({
    required this.word,
    required this.translation,
    required this.pronunciation,
    required this.example,
    required this.exampleTranslation,
  });
}

/// Practice sentence model
class PracticeSentence {
  final String original;
  final String translation;
  final String pronunciation;
  final String difficulty;

  PracticeSentence({
    required this.original,
    required this.translation,
    required this.pronunciation,
    required this.difficulty,
  });
}

/// Quiz question model
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswer;
  final String explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });
}

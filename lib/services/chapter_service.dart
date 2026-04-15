import 'package:flutter/material.dart';
import 'ml_vocabulary_service.dart';
import '../data/vocabulary_data.dart';

/// Chapter model for organizing learning content
class ChapterModel {
  final String id;
  final String title;
  final String titleEnglish;
  final String description;
  final String language;
  final IconData icon;
  final Color color;
  final int lessonCount;
  final List<String> topics;
  bool isLocked;
  double progress;
  int completedLessons;

  ChapterModel({
    required this.id,
    required this.title,
    required this.titleEnglish,
    required this.description,
    required this.language,
    required this.icon,
    required this.color,
    this.lessonCount = 4,
    this.topics = const [],
    this.isLocked = true,
    this.progress = 0.0,
    this.completedLessons = 0,
  });

  /// Legacy sync API disabled in ML-only mode.
  @Deprecated('Use getLessonsFromMl() for XLM-RoBERTa-only content.')
  List<LessonVocabulary> getLessons() => const [];

  /// Legacy sync API disabled in ML-only mode.
  @Deprecated('Use getLessonFromMl() for XLM-RoBERTa-only content.')
  LessonVocabulary? getLesson(int index) => null;

  /// Get chapter lessons from XLM-RoBERTa only.
  Future<List<LessonVocabulary>> getLessonsFromMl({
    int wordsPerLesson = 25,
  }) async {
    final lessons = <LessonVocabulary>[];

    for (int lessonIdx = 0; lessonIdx < lessonCount; lessonIdx++) {
      final predictions = await MLVocabularyService.generateVocabularyWithML(
        chapterId: id,
        lessonIndex: lessonIdx,
        language: language,
        count: wordsPerLesson,
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

      lessons.add(
        LessonVocabulary(
          lessonNumber: lessonIdx + 1,
          title: 'ML Lesson ${lessonIdx + 1}',
          titleEnglish: topics.length > lessonIdx
              ? topics[lessonIdx]
              : 'Lesson ${lessonIdx + 1}',
          words: words,
        ),
      );
    }

    return lessons;
  }

  /// Get one lesson from XLM-RoBERTa only.
  Future<LessonVocabulary?> getLessonFromMl(int index) async {
    if (index < 0 || index >= lessonCount) return null;

    final predictions = await MLVocabularyService.generateVocabularyWithML(
      chapterId: id,
      lessonIndex: index,
      language: language,
      count: 25,
    );

    if (predictions.isEmpty) return null;

    return LessonVocabulary(
      lessonNumber: index + 1,
      title: 'ML Lesson ${index + 1}',
      titleEnglish: topics.length > index
          ? topics[index]
          : 'Lesson ${index + 1}',
      words: predictions
          .map(
            (p) => VocabWord(
              urdu: p.word,
              english: p.translation,
              pronunciation: p.pronunciation,
              exampleSentence: p.example ?? p.word,
              exampleEnglish: p.translation,
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'titleEnglish': titleEnglish,
    'description': description,
    'language': language,
    'lessonCount': lessonCount,
    'isLocked': isLocked,
    'progress': progress,
    'completedLessons': completedLessons,
  };
}

/// Service to manage chapter-wise learning content
class ChapterService {
  /// Get all Urdu chapters
  static List<ChapterModel> getUrduChapters() {
    return [
      ChapterModel(
        id: 'urdu_ch1',
        title: 'بنیادی الفاظ',
        titleEnglish: 'Basic Words & Greetings',
        description: 'Learn greetings, numbers, colors, and basic vocabulary',
        language: 'urdu',
        icon: Icons.waving_hand,
        color: Colors.green,
        topics: ['Greetings', 'Numbers 1-100', 'Colors', 'Days & Months'],
        isLocked: false,
      ),
      ChapterModel(
        id: 'urdu_ch2',
        title: 'روزمرہ گفتگو',
        titleEnglish: 'Daily Conversation',
        description: 'Common phrases for everyday communication',
        language: 'urdu',
        icon: Icons.chat_bubble,
        color: Colors.blue,
        topics: ['Introductions', 'Questions', 'Directions', 'Weather'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'urdu_ch3',
        title: 'گرامر کی بنیاد',
        titleEnglish: 'Grammar Basics',
        description: 'Pronouns, verbs, and sentence structure',
        language: 'urdu',
        icon: Icons.menu_book,
        color: Colors.purple,
        topics: ['Pronouns', 'Verbs', 'Tenses', 'Sentence Structure'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'urdu_ch4',
        title: 'سفر اور ٹرانسپورٹ',
        titleEnglish: 'Travel & Transport',
        description: 'Vocabulary for traveling and transportation',
        language: 'urdu',
        icon: Icons.directions_car,
        color: Colors.orange,
        topics: ['Vehicles', 'Places', 'Directions', 'Tickets'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'urdu_ch5',
        title: 'کھانا پینا',
        titleEnglish: 'Food & Drinks',
        description: 'Food items, cooking, and restaurant vocabulary',
        language: 'urdu',
        icon: Icons.restaurant,
        color: Colors.red,
        topics: ['Vegetables', 'Fruits', 'Dishes', 'Restaurant'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'urdu_ch6',
        title: 'صحت و طب',
        titleEnglish: 'Health & Body',
        description: 'Body parts, health, and medical terms',
        language: 'urdu',
        icon: Icons.medical_services,
        color: Colors.teal,
        topics: ['Body Parts', 'Symptoms', 'Medicine', 'Hospital'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'urdu_ch7',
        title: 'تعلیم',
        titleEnglish: 'Education',
        description: 'School, studies, and academic vocabulary',
        language: 'urdu',
        icon: Icons.school,
        color: Colors.indigo,
        topics: ['School', 'Subjects', 'Stationery', 'Exams'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'urdu_ch8',
        title: 'کام اور پیشے',
        titleEnglish: 'Work & Professions',
        description: 'Jobs, workplace, and business vocabulary',
        language: 'urdu',
        icon: Icons.work,
        color: Colors.brown,
        topics: ['Professions', 'Office', 'Business', 'Money'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'urdu_ch9',
        title: 'ٹیکنالوجی',
        titleEnglish: 'Technology',
        description: 'Modern technology and digital vocabulary',
        language: 'urdu',
        icon: Icons.computer,
        color: Colors.cyan,
        topics: ['Devices', 'Internet', 'Social Media', 'Apps'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'urdu_ch10',
        title: 'ثقافت و روایات',
        titleEnglish: 'Culture & Traditions',
        description: 'Festivals, family, and cultural vocabulary',
        language: 'urdu',
        icon: Icons.celebration,
        color: Colors.pink,
        topics: ['Festivals', 'Family', 'Traditions', 'Celebrations'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'urdu_ch11',
        title: 'جذبات و احساسات',
        titleEnglish: 'Emotions & Feelings',
        description: 'Learn how to understand and express emotions naturally',
        language: 'urdu',
        icon: Icons.emoji_emotions,
        color: Colors.deepOrange,
        topics: [
          'Basic Emotions',
          'Intensity',
          'Social Feelings',
          'Expression',
        ],
        isLocked: true,
      ),
      ChapterModel(
        id: 'urdu_ch12',
        title: 'کھیل کود',
        titleEnglish: 'Sports & Games',
        description: 'Sports vocabulary, actions, and match expressions',
        language: 'urdu',
        icon: Icons.sports_soccer,
        color: Colors.lightBlue,
        topics: ['Sports Names', 'Actions', 'Equipment', 'Match Terms'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'urdu_ch13',
        title: 'اسلامی اصطلاحات',
        titleEnglish: 'Islamic Terms & Months',
        description: 'Ramadan, Eid, worship terms, and Islamic calendar months',
        language: 'urdu',
        icon: Icons.mosque,
        color: Colors.green,
        topics: ['Worship', 'Ramadan', 'Eid', 'Islamic Months'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'urdu_ch14',
        title: 'فطرت و ماحول',
        titleEnglish: 'Nature & Environment',
        description: 'Weather, nature, and environmental awareness vocabulary',
        language: 'urdu',
        icon: Icons.eco,
        color: Colors.teal,
        topics: ['Weather', 'Nature', 'Environmental Issues', 'Protection'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'urdu_ch15',
        title: 'گھر اور فرنیچر',
        titleEnglish: 'Home & Furniture',
        description: 'Rooms, furniture, and daily household expressions',
        language: 'urdu',
        icon: Icons.chair,
        color: Colors.deepPurple,
        topics: ['Rooms', 'Furniture', 'Home Items', 'Household Phrases'],
        isLocked: true,
      ),
    ];
  }

  /// Get all Punjabi chapters
  static List<ChapterModel> getPunjabiChapters() {
    return [
      ChapterModel(
        id: 'punjabi_ch1',
        title: 'بنیادی الفاظ',
        titleEnglish: 'Basic Words & Greetings',
        description: 'Learn greetings, numbers, colors, and basic vocabulary',
        language: 'punjabi',
        icon: Icons.waving_hand,
        color: Colors.green,
        topics: ['Greetings', 'Numbers 1-100', 'Colors', 'Days & Months'],
        isLocked: false,
      ),
      ChapterModel(
        id: 'punjabi_ch2',
        title: 'روزانہ گل بات',
        titleEnglish: 'Daily Conversation',
        description: 'Common phrases for everyday communication',
        language: 'punjabi',
        icon: Icons.chat_bubble,
        color: Colors.blue,
        topics: ['Introductions', 'Questions', 'Directions', 'Weather'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'punjabi_ch3',
        title: 'گرامر دی بنیاد',
        titleEnglish: 'Grammar Basics',
        description: 'Pronouns, verbs, and sentence structure',
        language: 'punjabi',
        icon: Icons.menu_book,
        color: Colors.purple,
        topics: ['Pronouns', 'Verbs', 'Tenses', 'Sentence Structure'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'punjabi_ch4',
        title: 'سفر تے آوا جائی',
        titleEnglish: 'Travel & Transport',
        description: 'Vocabulary for traveling and transportation',
        language: 'punjabi',
        icon: Icons.directions_car,
        color: Colors.orange,
        topics: ['Vehicles', 'Places', 'Directions', 'Tickets'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'punjabi_ch5',
        title: 'کھانا پینا',
        titleEnglish: 'Food & Drinks',
        description: 'Food items, cooking, and restaurant vocabulary',
        language: 'punjabi',
        icon: Icons.restaurant,
        color: Colors.red,
        topics: ['Vegetables', 'Fruits', 'Dishes', 'Restaurant'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'punjabi_ch6',
        title: 'صحت تے جسم',
        titleEnglish: 'Health & Body',
        description: 'Body parts, health, and medical terms',
        language: 'punjabi',
        icon: Icons.medical_services,
        color: Colors.teal,
        topics: ['Body Parts', 'Symptoms', 'Medicine', 'Hospital'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'punjabi_ch7',
        title: 'پڑھائی',
        titleEnglish: 'Education',
        description: 'School, studies, and academic vocabulary',
        language: 'punjabi',
        icon: Icons.school,
        color: Colors.indigo,
        topics: ['School', 'Subjects', 'Stationery', 'Exams'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'punjabi_ch8',
        title: 'کم کاج تے پیشے',
        titleEnglish: 'Work & Professions',
        description: 'Jobs, workplace, and business vocabulary',
        language: 'punjabi',
        icon: Icons.work,
        color: Colors.brown,
        topics: ['Professions', 'Office', 'Business', 'Money'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'punjabi_ch9',
        title: 'ٹیکنالوجی',
        titleEnglish: 'Technology',
        description: 'Modern technology and digital vocabulary',
        language: 'punjabi',
        icon: Icons.computer,
        color: Colors.cyan,
        topics: ['Devices', 'Internet', 'Social Media', 'Apps'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'punjabi_ch10',
        title: 'سبھیاچار تے رواج',
        titleEnglish: 'Culture & Traditions',
        description: 'Festivals, family, and cultural vocabulary',
        language: 'punjabi',
        icon: Icons.celebration,
        color: Colors.pink,
        topics: ['Festivals', 'Family', 'Traditions', 'Celebrations'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'punjabi_ch11',
        title: 'جذبات تے احساسات',
        titleEnglish: 'Emotions & Feelings',
        description: 'Learn to identify and express emotions in Punjabi',
        language: 'punjabi',
        icon: Icons.emoji_emotions,
        color: Colors.deepOrange,
        topics: [
          'Basic Emotions',
          'Intensity',
          'Social Feelings',
          'Expression',
        ],
        isLocked: true,
      ),
      ChapterModel(
        id: 'punjabi_ch12',
        title: 'کھیڈاں تے کھیل',
        titleEnglish: 'Sports & Games',
        description: 'Punjabi sports vocabulary, actions, and match terms',
        language: 'punjabi',
        icon: Icons.sports_soccer,
        color: Colors.lightBlue,
        topics: ['Sports Names', 'Actions', 'Equipment', 'Match Terms'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'punjabi_ch13',
        title: 'اسلامی اصطلاحات',
        titleEnglish: 'Islamic Terms & Months',
        description: 'Ramadan, Eid, and Islamic months in Punjabi context',
        language: 'punjabi',
        icon: Icons.mosque,
        color: Colors.green,
        topics: ['Worship', 'Ramadan', 'Eid', 'Islamic Months'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'punjabi_ch14',
        title: 'فطرت تے ماحول',
        titleEnglish: 'Nature & Environment',
        description: 'Weather and environmental vocabulary in Punjabi',
        language: 'punjabi',
        icon: Icons.eco,
        color: Colors.teal,
        topics: ['Weather', 'Nature', 'Environmental Issues', 'Protection'],
        isLocked: true,
      ),
      ChapterModel(
        id: 'punjabi_ch15',
        title: 'گھر تے فرنیچر',
        titleEnglish: 'Home & Furniture',
        description: 'Rooms, furniture, and household conversation in Punjabi',
        language: 'punjabi',
        icon: Icons.chair,
        color: Colors.deepPurple,
        topics: ['Rooms', 'Furniture', 'Home Items', 'Household Phrases'],
        isLocked: true,
      ),
    ];
  }

  /// Get chapters by language
  static List<ChapterModel> getChapters(String language) {
    if (language == 'urdu') {
      return getUrduChapters();
    } else {
      return getPunjabiChapters();
    }
  }

  /// Get specific chapter
  static ChapterModel? getChapter(String chapterId) {
    final allChapters = [...getUrduChapters(), ...getPunjabiChapters()];
    try {
      return allChapters.firstWhere((c) => c.id == chapterId);
    } catch (e) {
      return null;
    }
  }

  /// Unlock next chapter
  static void unlockNextChapter(
    List<ChapterModel> chapters,
    String currentChapterId,
  ) {
    for (int i = 0; i < chapters.length - 1; i++) {
      if (chapters[i].id == currentChapterId) {
        chapters[i + 1].isLocked = false;
        break;
      }
    }
  }

  /// Calculate overall progress
  static double calculateOverallProgress(List<ChapterModel> chapters) {
    if (chapters.isEmpty) return 0.0;

    double totalProgress = 0;
    for (var chapter in chapters) {
      totalProgress += chapter.progress;
    }
    return totalProgress / chapters.length;
  }
}

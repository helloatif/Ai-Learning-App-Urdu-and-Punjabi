// Urdu & Punjabi Learning Vocabulary Dataset
// 10 chapters per language, 4 lessons per chapter, 25 words per lesson
// Total: 2000 unique words/phrases (1000 Urdu + 1000 Punjabi)
// All content is curated and aligned to chapter/lesson topics

part 'urdu_vocab_part1.dart';
part 'urdu_vocab_part2.dart';
part 'urdu_vocab_part3.dart';
part 'punjabi_vocab_part1.dart';
part 'punjabi_vocab_part2.dart';
part 'punjabi_vocab_part3.dart';

class VocabWord {
  final String urdu;
  final String english;
  final String pronunciation;
  final String? exampleSentence;
  final String? exampleEnglish;

  const VocabWord({
    required this.urdu,
    required this.english,
    required this.pronunciation,
    this.exampleSentence,
    this.exampleEnglish,
  });

  Map<String, dynamic> toMap() {
    return {
      'urdu': urdu,
      'english': english,
      'pronunciation': pronunciation,
      'exampleSentence': exampleSentence,
      'exampleEnglish': exampleEnglish,
    };
  }

  bool get hasSentence => exampleSentence != null && exampleEnglish != null;
}

class LessonVocabulary {
  final int lessonNumber;
  final String title;
  final String titleEnglish;
  final List<VocabWord> words;

  const LessonVocabulary({
    required this.lessonNumber,
    required this.title,
    required this.titleEnglish,
    required this.words,
  });
}

class VocabularyData {
  // URDU - 10 chapters × 4 lessons × 25 words = 1000 words
  static final Map<String, List<LessonVocabulary>> urduLessons = {
    ..._urduChapters1to5,
    ..._urduChapters6to10,
    ..._urduChapters11to15,
  };

  // PUNJABI - 10 chapters × 4 lessons × 25 words = 1000 words
  static final Map<String, List<LessonVocabulary>> punjabiLessons = {
    ..._punjabiChapters1to5,
    ..._punjabiChapters6to10,
    ..._punjabiChapters11to15,
  };
}

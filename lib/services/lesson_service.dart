import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/vocabulary_data.dart';

class LessonService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<LessonVocabulary>> getLessons(
    String chapterId,
    String language,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('chapters')
          .doc(chapterId)
          .collection('lessons')
          .orderBy('lessonNumber')
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          final words = (data['words'] as List<dynamic>? ?? const [])
              .map((word) {
                final map = Map<String, dynamic>.from(word as Map);
                return VocabWord(
                  urdu: (map['urdu'] ?? '').toString(),
                  english: (map['english'] ?? '').toString(),
                  pronunciation: (map['pronunciation'] ?? '').toString(),
                  exampleSentence: (map['exampleSentence'] ?? '').toString().trim().isEmpty
                      ? null
                      : (map['exampleSentence'] ?? '').toString(),
                  exampleEnglish: (map['exampleEnglish'] ?? '').toString().trim().isEmpty
                      ? null
                      : (map['exampleEnglish'] ?? '').toString(),
                );
              })
              .toList();

          final lessonNumber = (data['lessonNumber'] as num?)?.toInt() ?? 0;

          return LessonVocabulary(
            lessonNumber: lessonNumber,
            title: (data['title'] ?? '').toString(),
            titleEnglish: (data['titleEnglish'] ?? '').toString(),
            words: words,
          );
        }).toList();
      }
    } catch (_) {
      // Fall back to hardcoded lessons below.
    }

    final lessonsMap = language == 'punjabi'
        ? VocabularyData.punjabiLessons
        : VocabularyData.urduLessons;
    return lessonsMap[chapterId] ?? const [];
  }
}
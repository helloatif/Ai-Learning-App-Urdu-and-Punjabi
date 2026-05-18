import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageOnboardingService {
  static String selectedLanguageKey(String userId) => 'language_selected_flag_$userId';
  static String levelCompletedKey(String userId) => 'language_level_completed_$userId';
  static String timeSelectionCompletedKey(String userId) => 'time_selection_completed_$userId';
  static String preparingScreenCompletedKey(String userId) => 'preparing_screen_completed_$userId';

  static Future<String> getSelectedLanguage(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final localValue = prefs.getString(selectedLanguageKey(userId))?.trim() ?? '';
    if (localValue.isNotEmpty) {
      return localValue;
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final remoteValue = (doc.data()?['selectedLanguage'] ?? '').toString().trim();
    if (remoteValue.isNotEmpty) {
      await prefs.setString(selectedLanguageKey(userId), remoteValue);
    }
    return remoteValue;
  }

  static Future<bool> isLevelCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final localValue = prefs.getBool(levelCompletedKey(userId));
    if (localValue == true) {
      return true;
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final remoteValue = (doc.data()?['languageLevelCompleted'] ?? false) == true;
    if (remoteValue) {
      await prefs.setBool(levelCompletedKey(userId), true);
    }
    return remoteValue;
  }

  static Future<void> saveSelectedLanguage(String userId, String languageCode) async {
    final normalized = languageCode.trim().toLowerCase();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(selectedLanguageKey(userId), normalized);

    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'selectedLanguage': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> markLevelCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(levelCompletedKey(userId), true);

    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'languageLevelCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<bool> isTimeSelectionCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final localValue = prefs.getBool(timeSelectionCompletedKey(userId));
    if (localValue == true) {
      return true;
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final remoteValue = (doc.data()?['timeSelectionCompleted'] ?? false) == true;
    if (remoteValue) {
      await prefs.setBool(timeSelectionCompletedKey(userId), true);
    }
    return remoteValue;
  }

  static Future<void> savePracticeGoal(
    String userId,
    int minutes,
    String label,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('practice_goal_minutes_$userId', minutes);
    await prefs.setString('practice_goal_label_$userId', label);

    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'practiceGoalMinutes': minutes,
      'practiceGoalLabel': label,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> markTimeSelectionCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(timeSelectionCompletedKey(userId), true);

    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'timeSelectionCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<bool> isPreparingScreenCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final localValue = prefs.getBool(preparingScreenCompletedKey(userId));
    if (localValue == true) {
      return true;
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final remoteValue = (doc.data()?['preparingScreenCompleted'] ?? false) == true;
    if (remoteValue) {
      await prefs.setBool(preparingScreenCompletedKey(userId), true);
    }
    return remoteValue;
  }

  static Future<void> markPreparingScreenCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(preparingScreenCompletedKey(userId), true);

    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'preparingScreenCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String displayLanguageName(String languageCode) {
    switch (languageCode.trim().toLowerCase()) {
      case 'urdu':
        return 'Urdu';
      case 'punjabi':
        return 'Punjabi';
      default:
        return languageCode;
    }
  }
}
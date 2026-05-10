import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final String id;
  final String email;
  final String name;
  final String selectedLanguage; // 'urdu', 'punjabi'
  final int points;
  final int level;
  final List<String> unlockedBadges;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.selectedLanguage = 'urdu',
    this.points = 0,
    this.level = 1,
    this.unlockedBadges = const [],
    required this.createdAt,
  });
}

class UserProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isAuthenticated = false;
  String? _selectedAvatar;

  User? get currentUser => _currentUser;
  User? get user => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  String? get selectedAvatar => _selectedAvatar;

  String _avatarPrefsKey(String userId) => 'selected_avatar_$userId';

  Future<void> loadSelectedAvatar() async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_avatarPrefsKey(firebaseUser.uid));

    String? normalized;
    if (saved == 'male' || saved == 'female') {
      normalized = saved;
    } else {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        final firestoreValue = (userDoc.data()?['selectedAvatar'] ?? '')
            .toString()
            .trim();
        if (firestoreValue == 'male' || firestoreValue == 'female') {
          normalized = firestoreValue;
        }
      } catch (e) {
        debugPrint('⚠️ Failed to load avatar from Firestore: $e');
      }
    }

    if (_selectedAvatar == normalized) return;

    _selectedAvatar = normalized;
    await _syncLeaderboardAvatarOnly(firebaseUser.uid, normalized ?? '');
    notifyListeners();
  }

  Future<void> setSelectedAvatar(String? value) async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final normalized = value == 'male' || value == 'female' ? value : null;
    final prefs = await SharedPreferences.getInstance();

    if (normalized == null) {
      await prefs.remove(_avatarPrefsKey(firebaseUser.uid));
    } else {
      await prefs.setString(_avatarPrefsKey(firebaseUser.uid), normalized);
    }

    await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).set({
      'selectedAvatar': normalized ?? '',
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('leaderboard').doc(firebaseUser.uid).set({
      'selectedAvatar': normalized ?? '',
    }, SetOptions(merge: true));

    if (_selectedAvatar == normalized) return;

    _selectedAvatar = normalized;
    notifyListeners();
  }

  void setUser(User user) {
    _currentUser = user;
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> loadUserFromFirebase() async {
    try {
      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        // Get user data from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data()!;
          final emailPrefix = firebaseUser.email?.split('@')[0] ?? 'User';

          _currentUser = User(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            name: data['displayName'] ?? emailPrefix,
            selectedLanguage: (data['selectedLanguage'] ?? '').toString().trim().toLowerCase(),
            unlockedBadges: List<String>.from(data['unlockedBadges'] ?? []),
            points: (data['totalXP'] ?? data['totalPoints'] ?? 0) as int,
            level:
                data['currentLevel'] ??
                ((data['totalXP'] ?? 0) / 100).floor() + 1,
            createdAt:
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
          _isAuthenticated = true;
          notifyListeners();

          await _syncLeaderboardEntry(
            firebaseUser.uid,
            _currentUser!.name,
            _currentUser!.points,
            _currentUser!.level,
            _currentUser!.selectedLanguage.trim().toLowerCase(),
          );

          await loadSelectedAvatar();
        } else {
          // User doc doesn't exist, create basic user object
          final fallbackName = firebaseUser.email?.split('@')[0] ?? 'User';
          await FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .set({
                'email': firebaseUser.email ?? '',
                'displayName': fallbackName,
                'selectedLanguage': '',
                'selectedAvatar': '',
                'totalXP': 0,
                'totalPoints': 0,
                'currentLevel': 1,
                'createdAt': FieldValue.serverTimestamp(),
                'lastLoginAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

          _currentUser = User(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            name: fallbackName,
            selectedLanguage: '',
            points: 0,
            level: 1,
            unlockedBadges: [],
            createdAt: DateTime.now(),
          );
          _isAuthenticated = true;
          notifyListeners();

          await _syncLeaderboardEntry(
            firebaseUser.uid,
            fallbackName,
            0,
            1,
            'urdu',
          );

          await loadSelectedAvatar();
        }
      }
    } catch (e) {
      debugPrint('Error loading user from Firebase: $e');
    }
  }

  Future<void> setSelectedLanguage(String language) async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      debugPrint('❌ No Firebase user logged in, cannot save language');
      return;
    }
    // Normalize the language value
    final normalizedLanguage = language.toString().trim().toLowerCase();

    // Update local user object if exists
    if (_currentUser != null) {
      _currentUser = User(
        id: _currentUser!.id,
        email: _currentUser!.email,
        name: _currentUser!.name,
        selectedLanguage: normalizedLanguage,
        points: _currentUser!.points,
        level: _currentUser!.level,
        unlockedBadges: _currentUser!.unlockedBadges,
        createdAt: _currentUser!.createdAt,
      );
    }

    // CRITICAL: Save language selection to Firestore so it persists
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid);

      // Always use set with merge to create or update
      await userRef.set({
        'selectedLanguage': normalizedLanguage,
        'email': firebaseUser.email ?? '',
        'displayName': firebaseUser.email?.split('@')[0] ?? 'User',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(), // For new users
      }, SetOptions(merge: true));

      if (_currentUser != null) {
        await _syncLeaderboardEntry(
          firebaseUser.uid,
          _currentUser!.name,
          _currentUser!.points,
          _currentUser!.level,
          normalizedLanguage,
        );
      }

      debugPrint(
        '✅ Language "$normalizedLanguage" saved to Firestore for user ${firebaseUser.uid}',
      );
    } catch (e) {
      debugPrint('❌ Failed to save language to Firestore: $e');
      rethrow; // Let calling code know there was an error
    }

    notifyListeners();
  }

  Future<void> updateLanguage(String language) async {
    await setSelectedLanguage(language);
  }

  void logout() {
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> _syncLeaderboardEntry(
    String userId,
    String displayName,
    int totalXP,
    int currentLevel,
    String selectedLanguage,
  ) async {
    try {
      final selectedAvatar = _selectedAvatar ?? '';
      await FirebaseFirestore.instance.collection('leaderboard').doc(userId).set({
        'displayName': displayName,
        'totalXP': totalXP,
        'currentLevel': currentLevel,
        'selectedLanguage': selectedLanguage.toString().trim().toLowerCase(),
        'selectedAvatar': selectedAvatar,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Failed to sync leaderboard entry: $e');
    }
  }

  Future<void> _syncLeaderboardAvatarOnly(String userId, String selectedAvatar) async {
    try {
      await FirebaseFirestore.instance.collection('leaderboard').doc(userId).set({
        'selectedAvatar': selectedAvatar,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Failed to sync leaderboard avatar: $e');
    }
  }
}

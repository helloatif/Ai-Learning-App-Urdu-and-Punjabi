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
  String? _selectedAvatarPath;

  User? get currentUser => _currentUser;
  User? get user => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  String? get selectedAvatar => _selectedAvatar;
  String? get selectedAvatarPath => _selectedAvatarPath;

  String? _avatarPathForSelection(String? selection) {
    if (selection == 'male') return 'assets/icons/AvatarBoy.png';
    if (selection == 'female') return 'assets/icons/AvatarGirl.png';
    return null;
  }

  String? _selectionForAvatarPath(String? path) {
    final normalized = path?.trim();
    if (normalized == 'assets/icons/AvatarBoy.png') return 'male';
    if (normalized == 'assets/icons/AvatarGirl.png') return 'female';
    return null;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
      final doubleParsed = double.tryParse(value.trim());
      if (doubleParsed != null) return doubleParsed.round();
    }
    return fallback;
  }

  String _avatarPrefsKey(String userId) => 'selected_avatar_$userId';

  Future<void> loadSelectedAvatar({String? userId}) async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final resolvedUserId = userId ?? firebaseUser?.uid;
    if (resolvedUserId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_avatarPrefsKey(resolvedUserId));

    String? normalized;
    String? normalizedPath;
    if (saved == 'male' || saved == 'female') {
      normalized = saved;
      normalizedPath = _avatarPathForSelection(saved);
    } else {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(resolvedUserId)
            .get();
        final data = userDoc.data();
        final firestorePath = (data?['selectedAvatarPath'] ?? '')
            .toString()
            .trim();
        final firestoreValue = (data?['selectedAvatar'] ?? '')
            .toString()
            .trim();
        normalizedPath = firestorePath.isNotEmpty
            ? firestorePath
            : _avatarPathForSelection(firestoreValue);
        normalized = _selectionForAvatarPath(normalizedPath) ??
            (firestoreValue == 'male' || firestoreValue == 'female'
                ? firestoreValue
                : null);
        if (normalized == null && firestoreValue.isNotEmpty) {
          normalized = firestoreValue;
        }
      } catch (e) {
        debugPrint('⚠️ Failed to load avatar from Firestore: $e');
      }
    }

    if (_selectedAvatar == normalized && _selectedAvatarPath == normalizedPath) return;

    _selectedAvatar = normalized;
    _selectedAvatarPath = normalizedPath;
    await _syncLeaderboardAvatarOnly(
      resolvedUserId,
      normalized ?? '',
      normalizedPath ?? '',
    );
    notifyListeners();
  }

  Future<void> setSelectedAvatar(String? value) async {
    final path = _avatarPathForSelection(value);
    await setSelectedAvatarPath(path);
  }

  Future<void> setSelectedAvatarPath(String? path) async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final normalizedPath = path != null && path.trim().isNotEmpty ? path.trim() : null;
    final normalized = _selectionForAvatarPath(normalizedPath);
    final prefs = await SharedPreferences.getInstance();

    if (normalized == null) {
      await prefs.remove(_avatarPrefsKey(firebaseUser.uid));
    } else {
      await prefs.setString(_avatarPrefsKey(firebaseUser.uid), normalized);
    }

    await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).set({
      'selectedAvatar': normalized ?? '',
      'selectedAvatarPath': normalizedPath ?? '',
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance.collection('leaderboard').doc(firebaseUser.uid).set({
      'selectedAvatar': normalized ?? '',
      'selectedAvatarPath': normalizedPath ?? '',
    }, SetOptions(merge: true));

    if (_selectedAvatar == normalized && _selectedAvatarPath == normalizedPath) return;

    _selectedAvatar = normalized;
    _selectedAvatarPath = normalizedPath;
    notifyListeners();
  }

  void setUser(User user) {
    _currentUser = user;
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> loadUserFromFirebase({String? userId}) async {
    try {
      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      final resolvedUserId = userId ?? firebaseUser?.uid;
      if (resolvedUserId != null) {
        // Get user data from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(resolvedUserId)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data()!;
          final emailPrefix = firebaseUser?.email?.split('@')[0] ?? 'User';

          _currentUser = User(
            id: resolvedUserId,
            email: firebaseUser?.email ?? '',
            name: data['displayName'] ?? emailPrefix,
            selectedLanguage: (data['selectedLanguage'] ?? '').toString().trim().toLowerCase(),
            unlockedBadges: List<String>.from(data['unlockedBadges'] ?? []),
            points: _asInt(data['totalXP'] ?? data['totalPoints'] ?? 0),
            level: _asInt(
              data['currentLevel'] ??
                (_asInt(data['totalXP'] ?? 0) / 100).floor() + 1,
              fallback: 1,
            ),
            createdAt:
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
          _isAuthenticated = true;
          notifyListeners();

          await _syncLeaderboardEntry(
            resolvedUserId,
            _currentUser!.name,
            _currentUser!.points,
            _currentUser!.level,
            _currentUser!.selectedLanguage.trim().toLowerCase(),
          );

          await loadSelectedAvatar(userId: resolvedUserId);
        } else {
          // User doc doesn't exist, create basic user object
          final fallbackName = firebaseUser?.email?.split('@')[0] ?? 'User';
          await FirebaseFirestore.instance
              .collection('users')
              .doc(resolvedUserId)
              .set({
                'email': firebaseUser?.email ?? '',
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
            id: resolvedUserId,
            email: firebaseUser?.email ?? '',
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
            resolvedUserId,
            fallbackName,
            0,
            1,
            'urdu',
          );

          await loadSelectedAvatar(userId: resolvedUserId);
        }
      }
    } catch (e) {
      debugPrint('Error loading user from Firebase: $e');
    }
  }

  Future<void> fetchUserData({String? userId}) async {
    await loadUserFromFirebase(userId: userId);
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
    _selectedAvatar = null;
    _selectedAvatarPath = null;
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
        'selectedAvatarPath': _selectedAvatarPath ?? '',
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Failed to sync leaderboard entry: $e');
    }
  }

  Future<void> _syncLeaderboardAvatarOnly(
    String userId,
    String selectedAvatar,
    String selectedAvatarPath,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('leaderboard').doc(userId).set({
        'selectedAvatar': selectedAvatar,
        'selectedAvatarPath': selectedAvatarPath,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Failed to sync leaderboard avatar: $e');
    }
  }
}

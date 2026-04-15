import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final String id;
  final String email;
  final String name;
  final String? profileImageUrl;
  final String selectedLanguage; // 'urdu', 'punjabi'
  final int points;
  final int level;
  final List<String> unlockedBadges;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.profileImageUrl,
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
  String? _localProfileImagePath; // local file path for instant preview

  User? get currentUser => _currentUser;
  User? get user => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  String? get localProfileImagePath => _localProfileImagePath;

  /// Show a local file immediately as the avatar while upload is in progress.
  void setLocalProfileImage(String path) {
    _localProfileImagePath = path;
    notifyListeners();
  }

  void clearLocalProfileImage() {
    _localProfileImagePath = null;
    // no notify needed — called after remote URL is set
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
        // Show cached profile image immediately (before Firestore round-trip)
        final prefs = await SharedPreferences.getInstance();
        final cachedUrl = prefs.getString(
          'profileImageUrl_${firebaseUser.uid}',
        );
        if (cachedUrl != null && _currentUser == null) {
          _currentUser = User(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            name: firebaseUser.email?.split('@')[0] ?? 'User',
            profileImageUrl: cachedUrl,
            selectedLanguage: 'urdu',
            points: 0,
            level: 1,
            unlockedBadges: [],
            createdAt: DateTime.now(),
          );
          notifyListeners();
        }

        // Get user data from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data()!;
          final emailPrefix = firebaseUser.email?.split('@')[0] ?? 'User';
          final remoteUrl = data['profileImageUrl'] as String?;

          // Keep cache in sync
          if (remoteUrl != null) {
            await prefs.setString(
              'profileImageUrl_${firebaseUser.uid}',
              remoteUrl,
            );
          }

          _currentUser = User(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            name: data['displayName'] ?? emailPrefix,
            profileImageUrl: remoteUrl ?? cachedUrl,
            selectedLanguage: data['selectedLanguage'] ?? 'urdu',
            points: (data['totalXP'] ?? data['totalPoints'] ?? 0) as int,
            level:
                data['currentLevel'] ??
                ((data['totalXP'] ?? 0) / 100).floor() + 1,
            unlockedBadges: List<String>.from(data['unlockedBadges'] ?? []),
            createdAt:
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
          _isAuthenticated = true;
          notifyListeners();
        } else {
          // User doc doesn't exist, create basic user object
          final fallbackName = firebaseUser.email?.split('@')[0] ?? 'User';
          await FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .set({
                'email': firebaseUser.email ?? '',
                'displayName': fallbackName,
                'selectedLanguage': 'urdu',
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
            profileImageUrl: null,
            selectedLanguage: 'urdu',
            points: 0,
            level: 1,
            unlockedBadges: [],
            createdAt: DateTime.now(),
          );
          _isAuthenticated = true;
          notifyListeners();
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

    // Update local user object if exists
    if (_currentUser != null) {
      _currentUser = User(
        id: _currentUser!.id,
        email: _currentUser!.email,
        name: _currentUser!.name,
        profileImageUrl: _currentUser!.profileImageUrl,
        selectedLanguage: language,
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
        'selectedLanguage': language,
        'email': firebaseUser.email ?? '',
        'displayName': firebaseUser.email?.split('@')[0] ?? 'User',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(), // For new users
      }, SetOptions(merge: true));

      debugPrint(
        '✅ Language "$language" saved to Firestore for user ${firebaseUser.uid}',
      );
    } catch (e) {
      debugPrint('❌ Failed to save language to Firestore: $e');
      rethrow; // Let calling code know there was an error
    }

    notifyListeners();
  }

  Future<void> updateProfileImage(String imageUrl) async {
    if (_currentUser != null) {
      // Cache URL locally for instant display on next open
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profileImageUrl_${_currentUser!.id}', imageUrl);

      _currentUser = User(
        id: _currentUser!.id,
        email: _currentUser!.email,
        name: _currentUser!.name,
        profileImageUrl: imageUrl,
        selectedLanguage: _currentUser!.selectedLanguage,
        points: _currentUser!.points,
        level: _currentUser!.level,
        unlockedBadges: _currentUser!.unlockedBadges,
        createdAt: _currentUser!.createdAt,
      );

      notifyListeners(); // Update UI immediately with new URL

      clearLocalProfileImage(); // remote URL is set — drop the local file path

      // Persist to Firestore in the background
        FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.id)
          .update({'profileImageUrl': imageUrl})
          .catchError(
            (e) => debugPrint('⚠ Firestore profile update error: $e'),
          );
    }
  }

  Future<void> updateLanguage(String language) async {
    await setSelectedLanguage(language);
  }

  void logout() {
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}

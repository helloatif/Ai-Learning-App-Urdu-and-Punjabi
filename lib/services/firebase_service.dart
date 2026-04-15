import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize Firebase
  static Future<void> initialize() async {
    try {
      // Firebase is already initialized by platform channel
      print('Firebase initialized successfully');
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  }

  /// Sign up user with email and password
  static Future<String?> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      // Check if email is valid format
      if (!email.contains('@')) {
        print('Invalid email format');
        return null;
      }

      // Check password length
      if (password.length < 6) {
        print('Password must be at least 6 characters');
        return null;
      }

      // Create user with just email and password
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        print('User creation failed - no user returned');
        return null;
      }

      // Send email verification (fire and forget - don't wait)
      user.sendEmailVerification().catchError((e) => print('Email error: $e'));

      // Create Firestore document - WAIT for this to complete
      final userName = (displayName != null && displayName.isNotEmpty)
          ? displayName
          : email.split('@')[0];
      await _firestore.collection('users').doc(user.uid).set({
        'email': email,
        'displayName': userName,
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': false,
        'selectedLanguage': 'urdu',
        'totalXP': 0,
        'totalPoints': 0,
        'currentLevel': 1,
        'totalLessonsCompleted': 0,
        'totalQuizzesCompleted': 0,
        'streak': 0,
        'currentStreak': 0,
        'accuracy': 0.0,
        'unlockedBadges': [],
      });

      print('✅ User account created: ${user.uid}');
      return user.uid;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      throw Exception(e.code);
    } catch (e) {
      print('Unexpected error during signup: $e');

      // Check if user was created despite error
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('✓ User created despite error: ${currentUser.uid}');

        // Fire and forget
        currentUser.sendEmailVerification().catchError(
          (e) => print('Email error: $e'),
        );

        return currentUser.uid;
      }

      throw Exception('signup-failed');
    }
  }

  /// Helper method to send verification email (fire and forget - no blocking)
  static void _sendVerificationEmailAsync(User user) {
    print('🔄 Attempting to send verification email to ${user.email}...');

    // Fire and forget - don't block the signup flow
    user
        .sendEmailVerification()
        .then((_) {
          print('✅ SUCCESS: Verification email sent to ${user.email}');
        })
        .catchError((error) {
          print('❌ Email send failed: $error');
          print('⚠️ User can use resend button in verification screen');
        });
  }

  /// Sign in user with email and password
  static Future<String?> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        print('❌ Sign in failed - no user returned');
        return null;
      }

      // Check email verification
      await user.reload();
      final refreshedUser = _auth.currentUser;

      if (refreshedUser == null || !refreshedUser.emailVerified) {
        print('🚫 EMAIL NOT VERIFIED - BLOCKING LOGIN');
        await _auth.signOut();
        throw Exception('email-not-verified');
      }

      // Ensure user document exists for leaderboard/profile visibility.
      _firestore
          .collection('users')
          .doc(user.uid)
          .set({
            'email': user.email ?? email,
            'displayName': (user.displayName ?? '').trim().isNotEmpty
                ? user.displayName
                : (user.email ?? email).split('@')[0],
            'emailVerified': true,
            'lastLoginAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'selectedLanguage': 'urdu',
            'totalXP': 0,
            'totalPoints': 0,
            'currentLevel': 1,
          }, SetOptions(merge: true))
          .catchError((e) => print('Firestore update error: $e'));

      print('✅ User signed in successfully: ${user.uid}');
      return user.uid;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      throw Exception(e.code);
    } catch (e) {
      print('Sign in error: $e');

      // Re-throw email-not-verified errors
      if (e.toString().contains('email-not-verified')) {
        throw e;
      }

      // Check if user is actually logged in despite error
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        try {
          await currentUser.reload();
        } catch (_) {}

        if (!currentUser.emailVerified) {
          await _auth.signOut();
          throw Exception('email-not-verified');
        }

        return currentUser.uid;
      }

      throw Exception('signin-failed');
    }
  }

  /// Get current user
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Check if current user's email is verified
  static bool isEmailVerified() {
    final user = _auth.currentUser;
    return user?.emailVerified ?? false;
  }

  /// Send email verification
  static Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        print('📧 Sending verification email to ${user.email}...');
        await user.sendEmailVerification();
        print('✅ Verification email sent successfully!');
      } else if (user != null && user.emailVerified) {
        print('✓ Email already verified');
      }
    } catch (e) {
      print('❌ Error sending verification email: $e');
      throw Exception('verification-email-failed');
    }
  }

  /// Reload user to check email verification status
  static Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      print('Error reloading user: $e');
    }
  }

  /// Save user progress
  static Future<void> saveProgress(
    String userId,
    Map<String, dynamic> progress,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'totalXP': progress['totalXP'] ?? progress['totalPoints'] ?? 0,
        'totalPoints': progress['totalPoints'] ?? 0,
        'currentLevel': progress['currentLevel'] ?? 1,
        'totalLessonsCompleted': progress['totalLessonsCompleted'] ?? 0,
        'totalQuizzesCompleted': progress['totalQuizzesCompleted'] ?? 0,
        'accuracy': progress['accuracy'] ?? 0.0,
        'lastUpdated': DateTime.now(),
      });
    } catch (e) {
      print('Save progress error: $e');
    }
  }

  /// Get user progress
  static Future<Map<String, dynamic>?> getProgress(String userId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get progress error: $e');
      return null;
    }
  }

  /// Sign out user
  /// Set clearRememberMe to true when user explicitly logs out
  static Future<void> signOut({bool clearRememberMe = true}) async {
    try {
      if (clearRememberMe) {
        // Clear Remember Me preference when user explicitly logs out
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rememberMe', false);
        await prefs.remove('rememberedEmail');
        await prefs.remove('rememberedPassword');
        print('✓ Remember Me cleared - user will need to login again');
      }
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  /// Check if user is authenticated
  static bool isUserAuthenticated() {
    return _auth.currentUser != null;
  }

  /// Reset password
  static Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      print('Reset password error: $e');
      return false;
    }
  }
}

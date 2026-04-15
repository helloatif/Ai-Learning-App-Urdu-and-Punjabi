import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Badge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final DateTime unlockedAt;

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.unlockedAt,
  });
}

class GamificationProvider extends ChangeNotifier {
  int _totalPoints = 0;
  int _currentLevel = 1;
  int _pointsForNextLevel = 100;
  final List<Badge> _unlockedBadges = [];
  int _streak = 0;
  int _currentStreak = 0;
  DateTime? _lastActiveDate;
  int _totalLessonsCompleted = 0;
  int _totalQuizzesCompleted = 0;
  double _xpMultiplier = 1.0;
  bool _isLoaded = false;

  int get totalPoints => _totalPoints;
  int get currentLevel => _currentLevel;
  int get pointsForNextLevel => _pointsForNextLevel;
  List<Badge> get unlockedBadges => _unlockedBadges;
  int get streak => _streak;
  int get currentStreak => _currentStreak;
  DateTime? get lastActiveDate => _lastActiveDate;
  int get totalLessonsCompleted => _totalLessonsCompleted;
  int get totalQuizzesCompleted => _totalQuizzesCompleted;
  double get xpMultiplier => _xpMultiplier;
  bool get isLoaded => _isLoaded;

  /// Load user progress from Firestore
  Future<void> loadFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _totalPoints = (data['totalXP'] ?? data['totalPoints'] ?? 0) as int;
        _currentLevel =
            data['currentLevel'] ?? ((_totalPoints / 100).floor() + 1);
        _streak = data['streak'] ?? 0;
        _currentStreak = data['currentStreak'] ?? _streak;
        _totalLessonsCompleted = data['totalLessonsCompleted'] ?? 0;
        _totalQuizzesCompleted = data['totalQuizzesCompleted'] ?? 0;

        // Load last active date
        if (data['lastActiveDate'] != null) {
          _lastActiveDate = (data['lastActiveDate'] as Timestamp).toDate();
        }

        // Load badges
        final badgesList = data['unlockedBadges'] as List<dynamic>?;
        if (badgesList != null) {
          _unlockedBadges.clear();
          for (var badgeData in badgesList) {
            if (badgeData is Map<String, dynamic>) {
              _unlockedBadges.add(
                Badge(
                  id: badgeData['id'] ?? '',
                  name: badgeData['name'] ?? '',
                  description: badgeData['description'] ?? '',
                  icon: badgeData['icon'] ?? '🏆',
                  unlockedAt: badgeData['unlockedAt'] != null
                      ? (badgeData['unlockedAt'] as Timestamp).toDate()
                      : DateTime.now(),
                ),
              );
            }
          }
        }

        // Calculate points needed for next level correctly
        final pointsForNextLevel = _currentLevel * 100;
        _pointsForNextLevel = pointsForNextLevel - _totalPoints;

        _updateXPMultiplier();
        _isLoaded = true;
        debugPrint(
          '✓ Loaded gamification data: $_totalPoints XP, Level $_currentLevel, Streak $_streak',
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠ Error loading gamification data: $e');
    }
  }

  /// Save progress to Firestore
  Future<void> _saveToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final badgesData = _unlockedBadges
          .map(
            (b) => {
              'id': b.id,
              'name': b.name,
              'description': b.description,
              'icon': b.icon,
              'unlockedAt': Timestamp.fromDate(b.unlockedAt),
            },
          )
          .toList();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'totalXP': _totalPoints,
        'currentLevel': _currentLevel,
        'streak': _streak,
        'currentStreak': _currentStreak,
        'lastActiveDate': _lastActiveDate != null
            ? Timestamp.fromDate(_lastActiveDate!)
            : null,
        'totalLessonsCompleted': _totalLessonsCompleted,
        'totalQuizzesCompleted': _totalQuizzesCompleted,
        'unlockedBadges': badgesData,
      }, SetOptions(merge: true));

      debugPrint('✓ Saved progress: $_totalPoints XP, Level $_currentLevel');
    } catch (e) {
      debugPrint('⚠ Error saving progress: $e');
    }
  }

  void addPoints(int points) {
    final multipliedPoints = (points * _xpMultiplier).round();
    _totalPoints += multipliedPoints;
    _checkLevelUp();
    updateDailyStreak();
    _saveToFirestore(); // Save after adding points
    notifyListeners();
  }

  void updateDailyStreak() {
    // Made public
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastActiveDate == null) {
      _streak = 1;
      _currentStreak = 1;
      _lastActiveDate = today;
      _updateXPMultiplier();
    } else {
      final lastActive = DateTime(
        _lastActiveDate!.year,
        _lastActiveDate!.month,
        _lastActiveDate!.day,
      );

      final difference = today.difference(lastActive).inDays;

      if (difference == 0) {
        // Same day, no change
        return;
      } else if (difference == 1) {
        // Consecutive day
        _streak++;
        _currentStreak++;
        _lastActiveDate = today;
        _checkStreakBadges();
        _updateXPMultiplier();
      } else {
        // Streak broken
        _streak = 1;
        _currentStreak = 1;
        _lastActiveDate = today;
        _xpMultiplier = 1.0;
      }
    }
  }

  void _updateXPMultiplier() {
    if (_streak >= 30) {
      _xpMultiplier = 2.0;
    } else if (_streak >= 14) {
      _xpMultiplier = 1.5;
    } else if (_streak >= 7) {
      _xpMultiplier = 1.25;
    } else {
      _xpMultiplier = 1.0;
    }
  }

  void _checkLevelUp() {
    // Calculate what level user should be based on total points
    final calculatedLevel = (_totalPoints / 100).floor() + 1;

    if (calculatedLevel > _currentLevel) {
      _currentLevel = calculatedLevel;
    }

    // Calculate points needed for next level
    final pointsForCurrentLevel = (_currentLevel - 1) * 100;
    final pointsForNextLevel = _currentLevel * 100;
    _pointsForNextLevel = pointsForNextLevel - _totalPoints;
  }

  void _checkStreakBadges() {
    if (_streak == 3) {
      _unlockBadge(
        Badge(
          id: 'streak_3',
          name: '🔥 تین دن کی شروعات',
          description: '3 دن کی مسلسل تربیت',
          icon: '🔥',
          unlockedAt: DateTime.now(),
        ),
      );
    }
    if (_streak == 7) {
      _unlockBadge(
        Badge(
          id: 'streak_7',
          name: '⭐ ایک ہفتہ کی یادیں',
          description: '7 دن کی مسلسل تربیت',
          icon: '⭐',
          unlockedAt: DateTime.now(),
        ),
      );
    }
    if (_streak == 14) {
      _unlockBadge(
        Badge(
          id: 'streak_14',
          name: '💪 دو ہفتے کا جنگجو',
          description: '14 دن کی مسلسل تربیت - 1.5x XP!',
          icon: '💪',
          unlockedAt: DateTime.now(),
        ),
      );
    }
    if (_streak == 30) {
      _unlockBadge(
        Badge(
          id: 'streak_30',
          name: '👑 ایک ماہ کا چیمپیئن',
          description: '30 دن کی مسلسل تربیت - 2x XP!',
          icon: '👑',
          unlockedAt: DateTime.now(),
        ),
      );
    }
    if (_streak == 100) {
      _unlockBadge(
        Badge(
          id: 'streak_100',
          name: '🏆 سو دن کا لیجنڈ',
          description: '100 دن کی مسلسل تربیت - ماسٹر!',
          icon: '🏆',
          unlockedAt: DateTime.now(),
        ),
      );
    }
  }

  void completeLesson() {
    _totalLessonsCompleted++;
    // Note: Points are added separately in lesson completion based on accuracy

    if (_totalLessonsCompleted == 10) {
      _unlockBadge(
        Badge(
          id: 'lessons_10',
          name: '📚 نوآموز طالب علم',
          description: '10 سبق مکمل کیے',
          icon: '📚',
          unlockedAt: DateTime.now(),
        ),
      );
    }
    if (_totalLessonsCompleted == 50) {
      _unlockBadge(
        Badge(
          id: 'lessons_50',
          name: '🎓 وقف علم',
          description: '50 سبق مکمل کیے',
          icon: '🎓',
          unlockedAt: DateTime.now(),
        ),
      );
    }
    notifyListeners();
  }

  void completeQuiz(double score) {
    _totalQuizzesCompleted++;
    final points = (score * 100).round();
    addPoints(points);

    if (score >= 0.9 && _totalQuizzesCompleted >= 10) {
      _unlockBadge(
        Badge(
          id: 'quiz_expert',
          name: '⚡ کوئز ماہر',
          description: '10 کوئز میں 90%+ اسکور',
          icon: '⚡',
          unlockedAt: DateTime.now(),
        ),
      );
    }
    notifyListeners();
  }

  void resetStreak() {
    _streak = 0;
    notifyListeners();
  }

  void _unlockBadge(Badge badge) {
    if (!_unlockedBadges.any((b) => b.id == badge.id)) {
      _unlockedBadges.add(badge);
      // Add bonus points for badge unlock
      addPoints(50);
    }
  }

  void unlockQuizMaster() {
    _unlockBadge(
      Badge(
        id: 'quiz_master',
        name: 'کوئز ماسٹر',
        description: '10 کوئز کو 90% سے زیادہ اسکور کریں',
        icon: '🎓',
        unlockedAt: DateTime.now(),
      ),
    );
  }

  void unlockVocabularyChampion() {
    _unlockBadge(
      Badge(
        id: 'vocab_champion',
        name: 'الفاظ کا سپاہی',
        description: '100 نئے الفاظ سیکھیں',
        icon: '📚',
        unlockedAt: DateTime.now(),
      ),
    );
  }

  void unlockPolyglot() {
    _unlockBadge(
      Badge(
        id: 'polyglot',
        name: 'بہو لسانی',
        description: 'اردو اور پنجابی دونوں میں 1000 پوائنٹس حاصل کریں',
        icon: '🌍',
        unlockedAt: DateTime.now(),
      ),
    );
  }
}

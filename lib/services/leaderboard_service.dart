import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LeaderboardUser {
  final String id;
  final String displayName;
  final int totalXP;
  final int currentLevel;
  final String selectedLanguage;
  final String selectedAvatar;
  final int rank;

  LeaderboardUser({
    required this.id,
    required this.displayName,
    required this.totalXP,
    required this.currentLevel,
    required this.selectedLanguage,
    required this.selectedAvatar,
    required this.rank,
  });

  factory LeaderboardUser.fromMap(Map<String, dynamic> data, int rank) {
    return LeaderboardUser(
      id: data['id'] ?? '',
      displayName: data['displayName'] ?? 'Unknown User',
      totalXP: (data['totalXP'] ?? data['totalPoints'] ?? 0) as int,
      currentLevel: (data['currentLevel'] ?? 1) as int,
      selectedLanguage: (data['selectedLanguage'] ?? '').toString().trim().toLowerCase(),
      selectedAvatar: (data['selectedAvatar'] ?? '').toString().trim().toLowerCase(),
      rank: rank,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'totalXP': totalXP,
      'currentLevel': currentLevel,
      'selectedLanguage': selectedLanguage,
      'selectedAvatar': selectedAvatar,
      'rank': rank,
    };
  }

  LeaderboardUser copyWith({
    String? id,
    String? displayName,
    int? totalXP,
    int? currentLevel,
    String? selectedLanguage,
    String? selectedAvatar,
    int? rank,
  }) {
    return LeaderboardUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      totalXP: totalXP ?? this.totalXP,
      currentLevel: currentLevel ?? this.currentLevel,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      selectedAvatar: selectedAvatar ?? this.selectedAvatar,
      rank: rank ?? this.rank,
    );
  }
}

class LeaderboardService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _cacheKey = 'leaderboard_cache';
  static const String _cacheTimeKey = 'leaderboard_cache_time';
  static const Duration _cacheDuration = Duration(minutes: 5);
  static const int _pageSize = 100; // Limit to top 100 for cost efficiency

  static String _normalizeLanguage(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase();
  }

  /// Legacy no-op kept for compatibility.
  static Future<void> initializeLeaderboard() async {
    return;
  }

  /// Get leaderboard users with optional caching
  static Future<List<LeaderboardUser>> getLeaderboard({
    bool forceRefresh = false,
    String languageFilter = 'all',
  }) async {
    try {
      final normalizedFilter = _normalizeLanguage(languageFilter);
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // Check if cache is valid
      if (!forceRefresh) {
        final cachedTime = prefs.getInt(_cacheTimeKey);
        if (cachedTime != null) {
          final cacheDate = DateTime.fromMillisecondsSinceEpoch(cachedTime);
          if (now.difference(cacheDate) < _cacheDuration) {
            final cached = prefs.getString(_cacheKey);
            if (cached != null) {
              return _deserializeLeaderboard(cached);
            }
          }
        }
      }

      // Fetch from Firestore
      final snapshot = await _firestore
          .collection('leaderboard')
          .orderBy('totalXP', descending: true)
          .limit(_pageSize)
          .get();

      final leaderboard = <LeaderboardUser>[];
      for (int i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data();
        data['id'] = doc.id;

        leaderboard.add(LeaderboardUser.fromMap(data, i + 1));
      }

      if (languageFilter != 'all') {
        leaderboard.removeWhere((user) => user.selectedLanguage != normalizedFilter);
      }

      for (int i = 0; i < leaderboard.length; i++) {
        leaderboard[i] = LeaderboardUser(
          id: leaderboard[i].id,
          displayName: leaderboard[i].displayName,
          totalXP: leaderboard[i].totalXP,
          currentLevel: leaderboard[i].currentLevel,
          selectedLanguage: leaderboard[i].selectedLanguage,
          selectedAvatar: leaderboard[i].selectedAvatar,
          rank: i + 1,
        );
      }

      // Cache the result
      await prefs.setInt(_cacheTimeKey, now.millisecondsSinceEpoch);
      await prefs.setString(_cacheKey, _serializeLeaderboard(leaderboard));

      return leaderboard;
    } catch (e) {
      print('Error fetching leaderboard: $e');
      // Return cached data if fetch fails
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        return _deserializeLeaderboard(cached);
      }
      return [];
    }
  }

  /// Get user's rank in leaderboard
  static Future<int?> getUserRank(String userId) async {
    try {
      // Get user's XP first
      final userDoc = await _firestore.collection('leaderboard').doc(userId).get();
      if (!userDoc.exists) return null;

      final userXP = (userDoc.data()?['totalXP'] ?? userDoc.data()?['totalPoints'] ?? 0) as int;

      // Count how many users have more XP
      final countSnapshot = await _firestore
          .collection('leaderboard')
          .where('totalXP', isGreaterThan: userXP)
          .count()
          .get();

      final count = countSnapshot.count ?? 0;
      return count + 1;
    } catch (e) {
      print('Error fetching user rank: $e');
      return null;
    }
  }

  /// Get user info for leaderboard display
  static Future<LeaderboardUser?> getUserLeaderboardInfo(String userId) async {
    try {
      final userDoc = await _firestore.collection('leaderboard').doc(userId).get();
      if (!userDoc.exists) return null;

      final data = userDoc.data()!;
      data['id'] = userDoc.id;

      final rank = await getUserRank(userId);
      if (rank == null) return null;

      return LeaderboardUser.fromMap(data, rank);
    } catch (e) {
      print('Error fetching user info: $e');
      return null;
    }
  }

  /// Stream leaderboard updates in real-time (with limit to control costs)
  static Stream<List<LeaderboardUser>> streamLeaderboard() {
    return _firestore
        .collection('leaderboard')
        .orderBy('totalXP', descending: true)
        .limit(_pageSize)
        .snapshots()
        .asyncMap((snapshot) async {
      try {
        final debugList = snapshot.docs.map((d) {
          final raw = _normalizeLanguage(d.data()['selectedLanguage']);
          return '${d.id}:${raw.isEmpty ? '<missing>' : raw}';
        }).toList();
        print('Leaderboard top docs languages: $debugList');
      } catch (e, stackTrace) {
        print('Error printing leaderboard debug info: $e');
        print(stackTrace);
      }

      final enrichedDocs = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;

        final leaderboardLanguage = _normalizeLanguage(data['selectedLanguage']);
        final leaderboardAvatar = _normalizeLanguage(data['selectedAvatar']);

        try {
          final userDoc = await _firestore.collection('users').doc(doc.id).get();
          final userData = userDoc.data() == null ? <String, dynamic>{} : Map<String, dynamic>.from(userDoc.data()!);
          final userLanguage = _normalizeLanguage(userData['selectedLanguage']);
          final userAvatar = _normalizeLanguage(userData['selectedAvatar']);
            final userDisplayName = (userData['displayName'] ?? '').toString().trim();
            final userEmail = (userData['email'] ?? '').toString().trim();

            // If leaderboard displayName is missing or looks like an email-prefix, prefer the users.displayName
            final lbDisplay = (data['displayName'] ?? '').toString().trim();
            final emailPrefix = userEmail.isNotEmpty ? userEmail.split('@')[0] : '';
            if ((lbDisplay.isEmpty || lbDisplay.contains('@') || lbDisplay == emailPrefix) && userDisplayName.isNotEmpty) {
              data['displayName'] = userDisplayName;
              await _firestore.collection('leaderboard').doc(doc.id).set({
                'displayName': userDisplayName,
              }, SetOptions(merge: true));
              print('Leaderboard displayName synced for ${doc.id}: "$userDisplayName"');
            }

          if (leaderboardLanguage.isEmpty && userLanguage.isNotEmpty) {
            data['selectedLanguage'] = userLanguage;
            await _firestore.collection('leaderboard').doc(doc.id).set({
              'selectedLanguage': userLanguage,
            }, SetOptions(merge: true));
            print('Leaderboard sync from users/${doc.id}: selectedLanguage="$userLanguage"');
          } else if (leaderboardLanguage.isNotEmpty && leaderboardLanguage != userLanguage && userLanguage.isNotEmpty) {
            print('LANG MISMATCH for ${doc.id}: leaderboard="$leaderboardLanguage" users="$userLanguage"');
          }

          if (leaderboardAvatar.isEmpty && userAvatar.isNotEmpty) {
            data['selectedAvatar'] = userAvatar;
            await _firestore.collection('leaderboard').doc(doc.id).set({
              'selectedAvatar': userAvatar,
            }, SetOptions(merge: true));
            print('Leaderboard sync from users/${doc.id}: selectedAvatar="$userAvatar"');
          }

          if (userLanguage.isEmpty && leaderboardLanguage.isEmpty) {
            print('LANG MISSING for ${doc.id}: no language found in leaderboard or users');
          }
        } catch (e, stackTrace) {
          print('Error enriching leaderboard doc ${doc.id} from users: $e');
          print(stackTrace);
        }

        enrichedDocs.add(data);
      }

      return enrichedDocs.asMap().entries.map((entry) {
        final index = entry.key;
        final data = entry.value;
        return LeaderboardUser.fromMap(data, index + 1);
      }).toList();
    }).handleError((Object error, StackTrace stackTrace) {
      print('Firestore leaderboard stream error: $error');
      print(stackTrace);
    });
  }

  /// Clear cache
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
  }

  static String _serializeLeaderboard(List<LeaderboardUser> leaderboard) {
    return jsonEncode(leaderboard.map((u) => u.toMap()).toList());
  }

  static List<LeaderboardUser> _deserializeLeaderboard(String json) {
    final data = jsonDecode(json) as List;
    return data
        .map((item) => LeaderboardUser.fromMap(
              Map<String, dynamic>.from(item),
              item['rank'] as int,
            ))
        .toList();
  }

  /// Backfill missing selectedLanguage fields in leaderboard top results
  /// Limits to top `_pageSize` to control cost.
  static Future<void> backfillSelectedLanguages() async {
    try {
      final snapshot = await _firestore.collection('leaderboard').limit(_pageSize).get();
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final rawLang = (data['selectedLanguage'] ?? '').toString();
        if (rawLang.trim().isEmpty) {
          final userDoc = await _firestore.collection('users').doc(doc.id).get();
          final userLang = (userDoc.data()?['selectedLanguage'] ?? '').toString().trim().toLowerCase();
          if (userLang.isNotEmpty) {
            await _firestore.collection('leaderboard').doc(doc.id).set({
              'selectedLanguage': userLang,
            }, SetOptions(merge: true));
          }
        }
      }
    } catch (e) {
      print('Error backfilling leaderboard languages: $e');
    }
  }

  /// Full backfill for all leaderboard documents. Runs once per device.
  /// Beware: this may incur Firestore read/write costs for large collections.
  static Future<void> backfillAllSelectedLanguages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('leaderboard_full_backfill_done') == true) return;

      const int batchSize = 500;
      DocumentSnapshot? lastDoc;
      while (true) {
        Query query = _firestore.collection('leaderboard').orderBy('totalXP', descending: true).limit(batchSize);
        if (lastDoc != null) query = query.startAfterDocument(lastDoc);

        final snapshot = await query.get();
        if (snapshot.docs.isEmpty) break;

        final WriteBatch batch = _firestore.batch();
        int pendingWrites = 0;
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final rawLang = (data['selectedLanguage'] ?? '').toString().trim();
          if (rawLang.isEmpty) {
            final userDoc = await _firestore.collection('users').doc(doc.id).get();
            final userLang = (userDoc.data()?['selectedLanguage'] ?? '').toString().trim().toLowerCase();
            if (userLang.isNotEmpty) {
              batch.set(doc.reference, {'selectedLanguage': userLang}, SetOptions(merge: true));
              pendingWrites++;
            }
          }
        }

        if (pendingWrites > 0) {
          await batch.commit();
        }

        lastDoc = snapshot.docs.last;
        if (snapshot.docs.length < batchSize) break;
      }

      await prefs.setBool('leaderboard_full_backfill_done', true);
    } catch (e) {
      print('Error in full leaderboard backfill: $e');
    }
  }

  /// Debug helper: find leaderboard docs where displayName contains `query` (case-insensitive)
  /// and print the leaderboard doc and corresponding users doc for inspection.
  static Future<void> debugInspectDisplayName(String query) async {
    try {
      final q = await _firestore
          .collection('leaderboard')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      if (q.docs.isEmpty) {
        // Try a broader scan (inefficient but acceptable for debug)
        final all = await _firestore.collection('leaderboard').get();
        for (final d in all.docs) {
          final dn = (d.data()['displayName'] ?? '').toString().toLowerCase();
          if (dn.contains(query.toLowerCase())) {
            print('DEBUG FOUND leaderboard doc: ${d.id} -> ${d.data()}');
            final userDoc = await _firestore.collection('users').doc(d.id).get();
            print('DEBUG CORRESPONDING users doc: ${userDoc.id} -> ${userDoc.data()}');
          }
        }
        return;
      }

      for (final d in q.docs) {
        print('DEBUG FOUND leaderboard doc: ${d.id} -> ${d.data()}');
        final userDoc = await _firestore.collection('users').doc(d.id).get();
        print('DEBUG CORRESPONDING users doc: ${userDoc.id} -> ${userDoc.data()}');
      }
    } catch (e) {
      print('Error in debugInspectDisplayName: $e');
    }
  }
}

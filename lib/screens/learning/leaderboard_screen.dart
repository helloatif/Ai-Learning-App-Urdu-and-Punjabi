import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../services/leaderboard_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // Use lowercase 'all' as the default internal state
  String _selectedLanguageFilter = 'all'; 

  // Helper to ensure we are always comparing apples to apples
  String _normalize(String? value) {
    if (value == null || value.isEmpty) return '';
    return value.trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final currentUserId = userProvider.currentUser?.id ?? '';

    return Scaffold(
      body: Column(
        children: [
          // --- HEADER SECTION ---
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events, size: 60, color: Colors.amber),
                    const SizedBox(height: 16),
                    const Text(
                      'Leaderboard',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Top learners this week',
                      style: TextStyle(fontSize: 16, color: AppTheme.white),
                    ),
                    const SizedBox(height: 16),
                    
                    // --- TAB FILTER ---
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildFilterTab('All', 'all'),
                          _buildFilterTab('Urdu', 'urdu'),
                          _buildFilterTab('Punjabi', 'punjabi'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- LIST SECTION ---
          Expanded(
            child: StreamBuilder<List<LeaderboardUser>>(
              stream: LeaderboardService.streamLeaderboard(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
                }

                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                // 1. Get raw list
                List<LeaderboardUser> users = snapshot.data ?? [];

                // 2. Apply Case-Insensitive Filtering
                final filter = _normalize(_selectedLanguageFilter);
                if (filter != 'all') {
                  users = users.where((u) {
                    print('Checking user: ${u.displayName}, Lang: "${u.selectedLanguage}"');
                    return u.selectedLanguage.trim().toLowerCase() == filter;
                  }).toList();
                }

                // 3. Assign Ranks based on the filtered list
                for (int i = 0; i < users.length; i++) {
                  users[i] = users[i].copyWith(rank: i + 1);
                }

                if (users.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _LeaderboardCard(
                      rank: user.rank,
                      name: user.displayName,
                      xp: user.totalXP,
                      level: user.currentLevel,
                      isCurrentUser: user.id == currentUserId,
                      language: _normalize(user.selectedLanguage),
                      selectedAvatar: _normalize(user.selectedAvatar),
                      selectedAvatarPath: user.selectedAvatarPath,
                      showLanguage: _selectedLanguageFilter == 'all',
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, String value) {
    final isSelected = _selectedLanguageFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedLanguageFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 64, color: AppTheme.primaryGreen),
          const SizedBox(height: 16),
          const Text('No users yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Be the first to start learning $_selectedLanguageFilter!',
              style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text('Error: $error', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  final int rank;
  final String name;
  final int xp;
  final int level;
  final bool isCurrentUser;
  final String language;
  final String selectedAvatar;
  final String selectedAvatarPath;
  final bool showLanguage;

  const _LeaderboardCard({
    required this.rank,
    required this.name,
    required this.xp,
    required this.level,
    required this.isCurrentUser,
    required this.language,
    required this.selectedAvatar,
    required this.selectedAvatarPath,
    required this.showLanguage,
  });

  @override
  Widget build(BuildContext context) {
    // Determine badge text and color based on normalized language string
    String badgeText = '';
    Color badgeColor = Colors.grey;
    
    if (language == 'urdu') {
      badgeText = 'Urdu';
      badgeColor = Colors.blue;
    } else if (language == 'punjabi') {
      badgeText = 'Punjabi';
      badgeColor = Colors.purple;
    }

    // Show avatar image when we have a path or legacy male/female selection.
    Widget leading;
    final String avatarAssetPath = selectedAvatarPath.isNotEmpty
        ? selectedAvatarPath
        : (selectedAvatar == 'female'
            ? 'assets/icons/AvatarGirl.png'
            : selectedAvatar == 'male'
                ? 'assets/icons/AvatarBoy.png'
                : '');

    if (avatarAssetPath.isNotEmpty) {
      leading = CircleAvatar(
        radius: 22,
        backgroundColor: _getRankColor(rank).withOpacity(0.2),
        backgroundImage: AssetImage(avatarAssetPath),
      );
    } else {
      leading = CircleAvatar(
        backgroundColor: _getRankColor(rank).withOpacity(0.2),
        child: Text('#$rank', style: TextStyle(color: _getRankColor(rank), fontWeight: FontWeight.bold)),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isCurrentUser ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrentUser ? const BorderSide(color: AppTheme.primaryGreen, width: 2) : BorderSide.none,
      ),
      child: ListTile(
        leading: leading,
        title: Row(
          children: [
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            if (isCurrentUser) _buildBadge('You', AppTheme.primaryGreen),
            if (showLanguage && badgeText.isNotEmpty) ...[
              const SizedBox(width: 4),
              _buildBadge(badgeText, badgeColor),
            ],
          ],
        ),
        subtitle: Text('Level $level • $xp XP'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.blueGrey;
    if (rank == 3) return Colors.brown;
    return Colors.grey;
  }
}
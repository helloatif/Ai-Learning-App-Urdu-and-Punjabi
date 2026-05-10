import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/leaderboard_service.dart';
import '../../themes/app_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<LeaderboardUser>> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = LeaderboardService.getLeaderboard();
  }

  Future<void> _refreshLeaderboard() async {
    setState(() {
      _leaderboardFuture = LeaderboardService.getLeaderboard(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Global Leaderboard',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF4575FA),
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshLeaderboard,
        child: FutureBuilder<List<LeaderboardUser>>(
          future: _leaderboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFF4575FA)),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Failed to load leaderboard'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshLeaderboard,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final leaderboard = snapshot.data ?? [];

            if (leaderboard.isEmpty) {
              return const Center(
                child: Text('No leaderboard data yet'),
              );
            }

            return CustomScrollView(
              slivers: [
                // Top 3 medal podium
                SliverToBoxAdapter(
                  child: _buildPodium(leaderboard, currentUser?.id),
                ),
                // Rest of leaderboard
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final user = leaderboard[index];
                        final isCurrentUser = user.id == currentUser?.id;

                        return _buildLeaderboardCard(
                          user: user,
                          isCurrentUser: isCurrentUser,
                          index: index,
                        );
                      },
                      childCount: leaderboard.length,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPodium(List<LeaderboardUser> leaderboard, String? currentUserId) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Title
          const Text(
            'Top Performers',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4575FA),
            ),
          ),
          const SizedBox(height: 24),
          // Podium
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd place (left)
              if (leaderboard.length >= 2)
                _buildPodiumPosition(
                  user: leaderboard[1],
                  rank: 2,
                  medal: '🥈',
                  height: 100,
                  isCurrentUser: leaderboard[1].id == currentUserId,
                )
              else
                const SizedBox(width: 80, height: 100),
              const SizedBox(width: 16),
              // 1st place (center, taller)
              _buildPodiumPosition(
                user: leaderboard[0],
                rank: 1,
                medal: '🥇',
                height: 140,
                isCurrentUser: leaderboard[0].id == currentUserId,
              ),
              const SizedBox(width: 16),
              // 3rd place (right)
              if (leaderboard.length >= 3)
                _buildPodiumPosition(
                  user: leaderboard[2],
                  rank: 3,
                  medal: '🥉',
                  height: 80,
                  isCurrentUser: leaderboard[2].id == currentUserId,
                )
              else
                const SizedBox(width: 80, height: 80),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPosition({
    required LeaderboardUser user,
    required int rank,
    required String medal,
    required double height,
    required bool isCurrentUser,
  }) {
    return Column(
      children: [
        // Medal
        Text(medal, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        // Name
        SizedBox(
          width: 80,
          child: Text(
            user.displayName,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Podium block
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: isCurrentUser ? const Color(0xFFFFC107) : const Color(0xFF4575FA),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$rank',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${user.totalXP} XP',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardCard({
    required LeaderboardUser user,
    required bool isCurrentUser,
    required int index,
  }) {
    final backgroundColor = isCurrentUser
        ? const Color(0xFFFFC107).withOpacity(0.1)
        : Colors.white;
    final borderColor = isCurrentUser ? const Color(0xFFFFC107) : Colors.transparent;

    String getRankMedal(int rank) {
      switch (rank) {
        case 1:
          return '🥇';
        case 2:
          return '🥈';
        case 3:
          return '🥉';
        default:
          return '#${rank}';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF4575FA),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              getRankMedal(user.rank),
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.displayName,
                style: TextStyle(
                  fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          'Level ${user.currentLevel}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${user.totalXP}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF4575FA),
              ),
            ),
            const Text(
              'XP',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

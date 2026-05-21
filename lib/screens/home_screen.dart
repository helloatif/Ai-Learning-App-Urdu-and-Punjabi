import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../themes/app_theme.dart';
import '../providers/gamification_provider.dart';
import '../providers/user_provider.dart';
import 'learning/learn_screen.dart';
import 'learning/practice_screen.dart';
import 'profile/profile_screen.dart';
import 'settings/settings_screen.dart';
import 'learning/leaderboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 1;
  late AnimationController _streakPulse;
  late AnimationController _xpGlow;

  final List<Widget> _screens = [
    const ProfileScreen(), // placeholder
    const LearnScreen(),
    const LeaderboardScreen(),
    const PracticeScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _streakPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _xpGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      () async {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.fetchUserData();

        final gamification = Provider.of<GamificationProvider>(
          context,
          listen: false,
        );
        await gamification.loadFromFirestore();
      }();
    });
  }

  @override
  void dispose() {
    _streakPulse.dispose();
    _xpGlow.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Premium top bar
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 20,
              right: 20,
              bottom: 16,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // App icon + title
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/icons/app_icon1.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                const Spacer(),
                // Streak badge
                Consumer<GamificationProvider>(
                  builder: (context, g, _) => AnimatedBuilder(
                    animation: _streakPulse,
                    builder: (context, child) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.withValues(
                              alpha: 0.1 + _streakPulse.value * 0.08,
                            ),
                            Colors.deepOrange.withValues(alpha: 0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.scale(
                            scale: 1.0 + _streakPulse.value * 0.15,
                            child: const Text(
                              '🔥',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${g.currentStreak}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // XP badge
                Consumer<GamificationProvider>(
                  builder: (context, g, _) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.purple.withOpacity(0.1),
                          AppTheme.purple.withValues(alpha: 0.1),
                          AppTheme.purple.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt,
                          color: AppTheme.purple,
                          size: 18,
                        ),
                        const SizedBox(width: 2),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Text(
                            '${g.totalPoints}',
                            key: ValueKey(g.totalPoints),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Screen content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_currentIndex),
                child: _screens[_currentIndex],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Consumer<UserProvider>(
                    builder: (context, userProvider, _) {
                      final avatarPath = userProvider.selectedAvatarPath;
                      if (avatarPath == null || avatarPath.isEmpty) {
                        return const Icon(Icons.person_rounded);
                      }

                      return CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.transparent,
                        backgroundImage: AssetImage(avatarPath),
                      );
                    },
                  ),
                  label: 'Profile',
                  isActive: _currentIndex == 0,
                  onTap: () => _onTabTap(0),
                  color: AppTheme.purple,
                ),
                _NavItem(
                  icon: Image.asset('assets/icons/learnicon.png'),
                  label: 'Learn',
                  isActive: _currentIndex == 1,
                  onTap: () => _onTabTap(1),
                  color: AppTheme.primaryGreen,
                ),
                _NavItem(
                  icon: const Icon(Icons.emoji_events_rounded),
                  label: 'Leaderboard',
                  isActive: _currentIndex == 2,
                  onTap: () => _onTabTap(2),
                  color: AppTheme.orange,
                ),
                _NavItem(
                  icon: Image.asset('assets/icons/practiceicon.png'),
                  label: 'Practice',
                  isActive: _currentIndex == 3,
                  onTap: () => _onTabTap(3),
                  color: AppTheme.blue,
                ),
                _NavItem(
                  icon: Image.asset(
                    'assets/icons/settingnavbutton.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.settings),
                  ),
                  label: 'Settings',
                  isActive: _currentIndex == 4,
                  onTap: () => _onTabTap(4),
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color color;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: IconTheme(
                data: IconThemeData(
                  color: isActive ? color : Colors.grey.shade400,
                  size: 24,
                ),
                child: icon,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

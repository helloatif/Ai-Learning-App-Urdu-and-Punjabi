import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../themes/app_theme.dart';
import '../providers/gamification_provider.dart';
import '../providers/user_provider.dart';
import '../providers/learning_provider.dart';
import 'learning/learn_screen.dart';
import 'learning/practice_screen.dart';
import 'profile/profile_screen.dart';
import 'settings/settings_screen.dart';
import 'learning/leaderboard_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 1});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _streakPulse;
  late AnimationController _xpGlow;
  late Future<void> _initialDataFuture;

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
    _currentIndex = widget.initialIndex;
    _streakPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _xpGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initialDataFuture = _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final authUser = FirebaseAuth.instance.currentUser;
    final userId = authUser?.uid;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.fetchUserData(userId: userId);

    final gamification = Provider.of<GamificationProvider>(
      context,
      listen: false,
    );
    await gamification.loadFromFirestore(userId: userId);

    final learningProvider = Provider.of<LearningProvider>(
      context,
      listen: false,
    );
    await learningProvider.loadProgressFromFirestore(userId: userId);
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
    return FutureBuilder<void>(
      future: _initialDataFuture,
      builder: (context, snapshot) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: isDark
                ? AppTheme.darkBackground
                : const Color(0xFFF5F7FA),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          backgroundColor: isDark
              ? AppTheme.darkBackground
              : const Color(0xFFF5F7FA),
          body: Column(
            children: [
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
                      icon: Image.asset(
                        'assets/icons/3dicons-crown-dynamic-color.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                      label: 'Leaderboard',
                      isActive: _currentIndex == 2,
                      onTap: () => _onTabTap(2),
                      color: AppTheme.orange,
                    ),
                    _NavItem(
                      icon: Image.asset(
                        'assets/icons/3dicons-skull-candle-dynamic-color.png',
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                      label: 'Practice',
                      isActive: _currentIndex == 3,
                      onTap: () => _onTabTap(3),
                      color: AppTheme.blue,
                    ),
                    _NavItem(
                      icon: Image.asset(
                        'assets/icons/3dicons-setting-dynamic-color.png',
                        width: 28,
                        height: 28,
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
      },
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
    final activeColor = AppTheme.orange;
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
          color: isActive ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(
                color: isActive ? activeColor : Colors.black54,
                size: 24,
              ),
              child: SizedBox(width: 24, height: 24, child: icon),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? activeColor : Colors.black54,
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

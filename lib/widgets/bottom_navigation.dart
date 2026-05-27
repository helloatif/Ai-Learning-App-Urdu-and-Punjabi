import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../themes/app_theme.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const AppBottomNavigation({Key? key, this.currentIndex = 1, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
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

                    return CircleAvatar(radius: 12, backgroundColor: Colors.transparent, backgroundImage: AssetImage(avatarPath));
                  },
                ),
                label: 'Profile',
                isActive: currentIndex == 0,
                onTap: () => _handleTap(context, 0),
                color: AppTheme.purple,
              ),
            _NavItem(
              icon: Image.asset('assets/icons/learnicon.png'),
              label: 'Learn',
              isActive: currentIndex == 1,
              onTap: () => _handleTap(context, 1),
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
              isActive: currentIndex == 2,
              onTap: () => _handleTap(context, 2),
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
              isActive: currentIndex == 3,
              onTap: () => _handleTap(context, 3),
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
              isActive: currentIndex == 4,
              onTap: () => _handleTap(context, 4),
              color: Colors.grey,
            ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, int index) {
    if (onTap != null) {
      onTap!.call(index);
      return;
    }

    // Default behavior: navigate to Home and set selected tab
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false, arguments: index);
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
        padding: EdgeInsets.symmetric(horizontal: isActive ? 16 : 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(
                color: isActive ? activeColor : Colors.black54,
                size: 28,
              ),
              child: SizedBox(width: 28, height: 28, child: icon),
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

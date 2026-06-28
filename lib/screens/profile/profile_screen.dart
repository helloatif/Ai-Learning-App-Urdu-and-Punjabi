import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/gamification_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/firebase_service.dart';
import '../../themes/app_theme.dart';
import '../grammar/grammar_checker_screen.dart';
import '../learning/ai_assistant_screen.dart';
import '../learning/leaderboard_screen.dart';
import '../learning/learn_screen.dart';
import '../learning/folk_stories_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _backgroundBlue = AppTheme.primaryGreen;

  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    final nextValue = _scrollController.offset > 12;
    if (nextValue != _scrolled && mounted) {
      setState(() => _scrolled = nextValue);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _showAccountSheet(
    BuildContext context,
    UserProvider userProvider,
    String displayName,
    String? email,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111316),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              CircleAvatar(
                radius: 34,
                backgroundColor: const Color(0xFFFFC0D8),
                backgroundImage: userProvider.selectedAvatarPath != null &&
                        userProvider.selectedAvatarPath!.isNotEmpty
                    ? AssetImage(userProvider.selectedAvatarPath!)
                    : null,
                child: userProvider.selectedAvatarPath == null ||
                        userProvider.selectedAvatarPath!.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        color: Color(0xFFE56F64),
                        size: 32,
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (email != null && email.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _signOut(userProvider);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF1C3),
                    foregroundColor: const Color(0xFF111316),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _signOut(UserProvider userProvider) async {
    await FirebaseService.signOut();
    userProvider.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _showComingSoonSnack(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title tapped'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, GamificationProvider>(
      builder: (context, userProvider, gamification, _) {
        final user = userProvider.currentUser;
        final displayName =
            user?.name.trim().isNotEmpty == true ? user!.name.trim() : 'Learner';
        final email = user?.email.trim();
        final avatarPath = userProvider.selectedAvatarPath?.trim();

        final totalPoints = gamification.totalPoints;
        final currentLevel = gamification.currentLevel;
        final streak = gamification.currentStreak > 0
            ? gamification.currentStreak
            : gamification.streak;
        final pointsToNextLevel = gamification.pointsForNextLevel;
        final progress = ((totalPoints % 100) / 100.0).clamp(0.0, 1.0);

        // Always enforce sky-blue status bar when this screen is visible
        final Color _statusBarColor = AppTheme.primaryGreen;
        // Also set it imperatively when the screen mounts to ensure it's applied
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
          statusBarColor: AppTheme.primaryGreen,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ));

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: AppTheme.primaryGreen,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: _backgroundBlue,
            body: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DotGridPainter(
                      baseColor: _backgroundBlue,
                    ),
                  ),
                ),
                // add a colored bar behind the system status area to match header
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: MediaQuery.of(context).padding.top,
                    color: _statusBarColor,
                  ),
                ),

                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryGreen,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(32),
                            bottomRight: Radius.circular(32),
                          ),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: DefaultTextStyle(
                                style: const TextStyle(color: AppTheme.white),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _scrolled
                                      ? AppTheme.white.withOpacity(0.10)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: _scrolled
                                        ? AppTheme.white.withOpacity(0.12)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _TopIconButton(
                                      icon: Image.asset(
                                        'assets/icons/3dicons-thumb-up-dynamic-color.png',
                                        width: 20,
                                        height: 20,
                                        fit: BoxFit.contain,
                                      ),
                                      onPressed: () => _showAccountSheet(
                                        context,
                                        userProvider,
                                        displayName,
                                        email,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: _StatPill(
                                        icon: Image.asset(
                                          'assets/icons/3dicons-fire-dynamic-color.png',
                                          width: 20,
                                          height: 20,
                                          fit: BoxFit.contain,
                                        ),
                                        value: '$totalPoints',
                                      ),
                                    ),
                                    const Spacer(),
                                    _AvatarButton(
                                      avatarPath: avatarPath,
                                      onPressed: () => _showAccountSheet(
                                        context,
                                        userProvider,
                                        displayName,
                                        email,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: _EnergyPill(
                                        icon: Image.asset(
                                          'assets/icons/3dicons-flash-dynamic-color.png',
                                          fit: BoxFit.contain,
                                        ),
                                        label: '$streak',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    _TopIconButton(
                                      icon: Image.asset(
                                        'assets/icons/3dicons-bell-dynamic-color.png',
                                        width: 24,
                                        height: 24,
                                        fit: BoxFit.contain,
                                      ),
                                      onPressed: () => _showComingSoonSnack('Notifications'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PremiumBanner(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LearnScreen(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.92,
                                children: [
                                  _BentoCard(
                                    title: 'AI Assistant',
                                    subtitle: '',
                                    color: const Color(0xFFD78CFF),
                                    icon: Icons.play_arrow_rounded,
                                    accentIcon: null,
                                    accentAsset: 'assets/icons/Futuristic Glowing Cube.png',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const AiAssistantScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  _BentoCard(
                                    title: 'Stories',
                                    subtitle: '',
                                    color: const Color(0xFF82EEFD),
                                    icon: Icons.add_rounded,
                                    iconAsset: 'assets/icons/Cloud-3-zap.png',
                                    accentIcon: null,
                                    centerAsset: 'assets/icons/storiesicon.png',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const FolkStoriesScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  _BentoCard(
                                    title: 'Leaderboard',
                                    subtitle: '',
                                    color: const Color(0xFFF06292),
                                    icon: null,
                                    iconAsset: 'assets/icons/3dicons-crown-dynamic-color.png',
                                    accentIcon: null,
                                    accentAsset: 'assets/icons/3dicons-crown-dynamic-color.png',
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => const LeaderboardScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  _BentoCard(
                                    title: 'Grammar\nchecking',
                                    subtitle: '',
                                    color: const Color(0xFFE56F64),
                                    icon: null,
                                    accentIcon: null,
                                    showTopIcon: false,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const GrammarCheckerScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Discover card removed
                              const SizedBox(height: 12),
                              _ProfileSummaryCard(
                                displayName: displayName,
                                email: email,
                                avatarPath: avatarPath,
                                currentLevel: currentLevel,
                                totalPoints: totalPoints,
                                pointsToNextLevel: pointsToNextLevel,
                                progress: progress,
                                streak: streak,
                                onSignOut: () => _showAccountSheet(
                                  context,
                                  userProvider,
                                  displayName,
                                  email,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PremiumBanner extends StatelessWidget {
  final VoidCallback onPressed;

  const _PremiumBanner({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          height: 194,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFB347), Color(0xFFFFCC33)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 0,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 190,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Explore chapters, take quizzes, and earn rewards.',
                        maxLines: 3,
                        softWrap: true,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Text(
                          'START LEARNING',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: AppTheme.primaryGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Transform.translate(
                  offset: const Offset(18, 0),
                  child: SizedBox(
                    width: 170,
                    height: 170,
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Image.asset(
                        'assets/icons/3dicons-rocket-dynamic-color.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              // (Storm icon removed)
            ],
          ),
        ),
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final IconData? icon;
  final String? iconAsset;
  final IconData? accentIcon;
  final String? accentAsset;
  final String? centerAsset;
  final String? buttonLabel;
  final bool showTopIcon;
  final VoidCallback onTap;

  const _BentoCard({
    required this.title,
    required this.subtitle,
    required this.color,
    this.icon,
    this.iconAsset,
    this.accentIcon,
    this.accentAsset,
    this.centerAsset,
    this.showTopIcon = true,
    required this.onTap,
    this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Top-left small icon for center-asset cards (e.g., Stories)
              if (centerAsset != null && iconAsset != null)
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(2),
                      child: Image.asset(
                        iconAsset!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

              if (centerAsset != null)
                Positioned.fill(
                  child: Stack(
                    children: [
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Transform.translate(
                            offset: const Offset(8, 0),
                            child: SizedBox(
                              width: 120,
                              height: 120,
                              child: Image.asset(
                                centerAsset!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 6,
                        child: Text(
                          title,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                            fontSize: 18,
                            height: 1.0,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                if (showTopIcon)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: iconAsset == null
                          ? Icon(
                              icon ?? Icons.circle,
                              color: Colors.white,
                              size: 15,
                            )
                          : Padding(
                              padding: const EdgeInsets.all(2),
                              child: Image.asset(
                                iconAsset!,
                                fit: BoxFit.contain,
                              ),
                            ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 120,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.0,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 66,
                    child: Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withOpacity(0.72),
                        fontSize: 9,
                        height: 1.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (buttonLabel != null)
                  Positioned(
                    left: 0,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        buttonLabel!,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
              if (accentAsset != null)
                Positioned(
                  right: 8,
                  top: 15,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 92,
                        height: 92,
                        child: Image.asset(
                          accentAsset!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                )
              else if (accentIcon != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      accentIcon,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  final VoidCallback onPressed;

  const _DiscoverCard({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          height: 164,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF7CFC00),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 162,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Discover',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Play either Solo,\nagainst Randoms or\nagainst your Friends',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withOpacity(0.92),
                          fontSize: 11,
                          height: 1.15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'show all',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(
                    Icons.calculate_rounded,
                    color: Colors.white,
                    size: 46,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  final String displayName;
  final String? email;
  final String? avatarPath;
  final int currentLevel;
  final int totalPoints;
  final int pointsToNextLevel;
  final double progress;
  final int streak;
  final VoidCallback onSignOut;

  const _ProfileSummaryCard({
    required this.displayName,
    required this.email,
    required this.avatarPath,
    required this.currentLevel,
    required this.totalPoints,
    required this.pointsToNextLevel,
    required this.progress,
    required this.streak,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF7CFC00).withOpacity(0.10),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF7CFC00).withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFFFC0D8),
                backgroundImage: avatarPath != null && avatarPath!.isNotEmpty
                    ? AssetImage(avatarPath!)
                    : null,
                child: avatarPath == null || avatarPath!.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        color: Color(0xFFE56F64),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (email != null && email!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        email!,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withOpacity(0.70),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: onSignOut,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(
            leftLabel: 'Level',
            leftValue: '$currentLevel',
            rightLabel: 'Points',
            rightValue: '$totalPoints',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            leftLabel: 'Streak',
            leftValue: '$streak days',
            rightLabel: 'Next level',
            rightValue: '$pointsToNextLevel XP left',
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFFFF1C3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  const _InfoRow({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TinyStat(
            label: leftLabel,
            value: leftValue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TinyStat(
            label: rightLabel,
            value: rightValue,
            alignRight: true,
          ),
        ),
      ],
    );
  }
}

class _TinyStat extends StatelessWidget {
  final String label;
  final String value;
  final bool alignRight;

  const _TinyStat({
    required this.label,
    required this.value,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.white.withOpacity(0.62),
            fontSize: 11,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onPressed;

  const _TopIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.10),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(child: icon),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final Widget icon;
  final String value;

  const _StatPill({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity;
      final compact = maxW < 100.0;
      final horizontalPadding = compact ? 8.0 : 14.0;
      final iconSize = compact ? 14.0 : 22.0;

      return Container(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints.tight(Size(iconSize, iconSize)),
              child: icon,
            ),
            SizedBox(width: compact ? 6 : 8),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _EnergyPill extends StatelessWidget {
  final Widget icon;
  final String label;

  const _EnergyPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : double.infinity;
      final compact = maxW < 100.0;
      final horizontalPadding = compact ? 8.0 : 14.0;
      final iconSize = compact ? 14.0 : 22.0;

      return Container(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints.tight(Size(iconSize, iconSize)),
              child: icon,
            ),
            SizedBox(width: compact ? 4 : 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _AvatarButton extends StatelessWidget {
  final String? avatarPath;
  final VoidCallback onPressed;

  const _AvatarButton({
    required this.avatarPath,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: ClipOval(
            child: avatarPath != null && avatarPath!.isNotEmpty
                ? Image.asset(
                    avatarPath!,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: const Color(0xFFFFC0D8),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFFE56F64),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color baseColor;

  _DotGridPainter({required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.05);
    const spacing = 20.0;
    const radius = 1.2;

    for (double y = 0; y < size.height + spacing; y += spacing) {
      final rowOffset = (((y / spacing).floor()) % 2 == 0) ? 0.0 : spacing / 2;
      for (double x = rowOffset; x < size.width + spacing; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => false;
}

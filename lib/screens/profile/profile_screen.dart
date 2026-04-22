import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/learning_provider.dart';
import '../grammar/grammar_checker_screen.dart';
import '../learning/translation_practice_screen.dart';
import '../voice/voice_assistant_screen.dart';
import '../../services/firebase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _maleAvatarPath = 'assets/images/9440461.jpg';
  static const String _femaleAvatarPath = 'assets/images/10491839.jpg';

  @override
  void initState() {
    super.initState();
    // Load user data if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final gamificationProvider = Provider.of<GamificationProvider>(
          context,
          listen: false,
        );

        // Load both in parallel for faster loading
        await Future.wait([
          if (userProvider.currentUser == null)
            userProvider.loadUserFromFirebase(),
          if (!gamificationProvider.isLoaded)
            gamificationProvider.loadFromFirestore(),
        ]);
      } catch (e) {
        debugPrint('⚠ Profile load error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : const Color(0xFFF5F7FA),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          if (userProvider.currentUser == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryGreen),
                  SizedBox(height: 16),
                  Text('Loading profile...'),
                ],
              ),
            );
          }

          return Consumer<GamificationProvider>(
            builder: (context, gamification, _) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    // Profile Header
                    Container(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 16,
                        bottom: 32,
                        left: 24,
                        right: 24,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF8B4DFF), Color(0xFF6C3CE7)],
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.white,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipOval(child: _buildAvatar(userProvider)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            userProvider.currentUser!.name,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(color: AppTheme.white),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            userProvider.currentUser!.email,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.accentGreen),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Stats
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _buildStatCard(
                            'Level',
                            gamification.currentLevel.toString(),
                            '🎯',
                            context,
                          ),
                          const SizedBox(width: 16),
                          _buildStatCard(
                            'Points',
                            gamification.totalPoints.toString(),
                            '⭐',
                            context,
                          ),
                          const SizedBox(width: 16),
                          _buildStatCard(
                            'Streak',
                            gamification.streak.toString(),
                            '🔥',
                            context,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Progress
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Points to Next Level',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                '${gamification.pointsForNextLevel} remaining',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value:
                                  gamification.totalPoints /
                                  gamification.pointsForNextLevel,
                              minHeight: 8,
                              backgroundColor: AppTheme.lightGreen.withValues(
                                alpha: 0.3,
                              ),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Badges Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Badges Earned',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: AppTheme.primaryGreen),
                          ),
                          const SizedBox(height: 12),
                          if (gamification.unlockedBadges.isEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    'No badges earned yet',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 1,
                                  ),
                              itemCount: gamification.unlockedBadges.length,
                              itemBuilder: (context, index) {
                                final badge =
                                    gamification.unlockedBadges[index];
                                return _buildBadgeCard(badge, context);
                              },
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Settings
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Settings',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: AppTheme.primaryGreen),
                          ),
                          const SizedBox(height: 12),
                          _buildEmailVerificationStatus(context),
                          const SizedBox(height: 8),
                          _buildThemeToggle(context),
                          const SizedBox(height: 8),
                          _buildLanguageSwitcher(context, userProvider),
                          const SizedBox(height: 8),
                          _buildAvatarSelectorInSettings(userProvider),
                          const SizedBox(height: 8),
                          _buildAitoolsCard(context),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Logout Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Logout'),
                                content: const Text(
                                  'Are you sure you want to logout?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: const Text('Logout'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && mounted) {
                              // Reset theme to light mode for next user
                              final themeProvider = Provider.of<ThemeProvider>(
                                context,
                                listen: false,
                              );
                              await themeProvider.resetForLogout();

                              // Clear chapter progress so next user starts fresh
                              final learningProvider =
                                  Provider.of<LearningProvider>(
                                    context,
                                    listen: false,
                                  );
                              await learningProvider.clearProgressOnLogout();

                              await FirebaseService.signOut();
                              if (mounted) {
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/login',
                                  (route) => false,
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Builds the selected avatar shown in the profile circle.
  Widget _buildAvatar(UserProvider userProvider) {
    final selected = userProvider.selectedAvatar;

    if (selected == null) {
      return Container(
        color: AppTheme.accentGreen.withValues(alpha: 0.25),
        child: const Icon(Icons.face, size: 64, color: AppTheme.primaryGreen),
      );
    }

    return _buildAvatarImage(
      selected == 'female' ? _femaleAvatarPath : _maleAvatarPath,
      fallbackIcon: selected == 'female' ? Icons.face_3 : Icons.face_6,
      width: double.infinity,
      height: double.infinity,
    );
  }

  Widget _buildAvatarSelectorInSettings(UserProvider userProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Avatar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildAvatarChoice(
                    userProvider: userProvider,
                    value: 'male',
                    label: 'Male',
                    assetPath: _maleAvatarPath,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildAvatarChoice(
                    userProvider: userProvider,
                    value: 'female',
                    label: 'Female',
                    assetPath: _femaleAvatarPath,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAitoolsCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Tools',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildToolButton(
              context,
              label: 'Grammar Checker',
              icon: Icons.rule,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GrammarCheckerScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildToolButton(
              context,
              label: 'Translation Practice',
              icon: Icons.translate,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TranslationPracticeScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildToolButton(
              context,
              label: 'Voice Assistant',
              icon: Icons.mic,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const VoiceAssistantScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }

  Widget _buildAvatarImage(
    String path, {
    required IconData fallbackIcon,
    required double width,
    required double height,
  }) {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        color: AppTheme.accentGreen.withValues(alpha: 0.25),
        child: Icon(fallbackIcon, size: 46, color: AppTheme.primaryGreen),
      ),
    );
  }

  Widget _buildAvatarChoice({
    required UserProvider userProvider,
    required String value,
    required String label,
    required String assetPath,
  }) {
    final bool isSelected = userProvider.selectedAvatar == value;

    return GestureDetector(
      onTap: () => userProvider.setSelectedAvatar(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryGreen
                : Colors.grey.withValues(alpha: 0.35),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppTheme.primaryGreen.withValues(alpha: 0.20),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: _buildAvatarImage(
                  assetPath,
                  fallbackIcon: value == 'female' ? Icons.face_3 : Icons.face_6,
                  width: 60,
                  height: 60,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.primaryGreen : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String emoji,
    BuildContext context,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeCard(dynamic badge, BuildContext context) {
    return Card(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(badge.icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              badge.name,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    String title,
    IconData icon,
    VoidCallback onTap,
    BuildContext context,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryGreen),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildEmailVerificationStatus(BuildContext context) {
    final isVerified = FirebaseService.isEmailVerified();
    return Card(
      color: isVerified
          ? AppTheme.lightGreen.withValues(alpha: 0.2)
          : Colors.orange.withValues(alpha: 0.2),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              isVerified ? Icons.verified : Icons.warning,
              color: isVerified ? AppTheme.primaryGreen : Colors.orange,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVerified ? 'Email Verified ✓' : 'Email Not Verified',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (!isVerified)
                    const Text(
                      'Please check your email',
                      style: TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
            if (!isVerified)
              TextButton(
                onPressed: () async {
                  try {
                    await FirebaseService.sendEmailVerification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Verification email sent!'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    }
                  }
                },
                child: const Text('Resend'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Card(
          child: SwitchListTile(
            secondary: Icon(
              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: AppTheme.primaryGreen,
            ),
            title: const Text(
              'Dark Mode',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              themeProvider.isDarkMode ? 'On' : 'Off',
              style: const TextStyle(fontSize: 12),
            ),
            value: themeProvider.isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme();
            },
            activeThumbColor: AppTheme.primaryGreen,
          ),
        );
      },
    );
  }

  Widget _buildLanguageSwitcher(
    BuildContext context,
    UserProvider userProvider,
  ) {
    final currentLanguage =
        userProvider.currentUser?.selectedLanguage ?? 'urdu';
    final languageDisplay = currentLanguage == 'urdu' ? 'Urdu' : 'Punjabi';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
      child: ListTile(
        leading: const Icon(Icons.language, color: AppTheme.primaryGreen),
        title: const Text(
          'Change Language',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('Current: $languageDisplay'),
        trailing: const Icon(Icons.swap_horiz, color: AppTheme.primaryGreen),
        onTap: () {
          _showLanguageDialog(context, userProvider, currentLanguage);
        },
      ),
    );
  }

  void _showLanguageDialog(
    BuildContext context,
    UserProvider userProvider,
    String currentLanguage,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇵🇰', style: TextStyle(fontSize: 32)),
              title: const Text('Urdu'),
              subtitle: const Text('اردو - Official language'),
              selected: currentLanguage == 'urdu',
              selectedTileColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
              onTap: () {
                userProvider.setSelectedLanguage('urdu');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Language changed to Urdu')),
                );
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Text('🇵🇰', style: TextStyle(fontSize: 32)),
              title: const Text('Pakistani Punjabi'),
              subtitle: const Text('پنجابی - Shahmukhi script'),
              selected: currentLanguage == 'punjabi',
              selectedTileColor: AppTheme.primaryGreen.withOpacity(0.1),
              onTap: () {
                userProvider.setSelectedLanguage('punjabi');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Language changed to Punjabi')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

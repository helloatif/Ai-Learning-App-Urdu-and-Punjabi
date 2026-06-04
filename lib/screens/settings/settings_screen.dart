import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/gamification_provider.dart';
import '../../providers/learning_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/firebase_service.dart';
import '../../themes/app_theme.dart';
import '../grammar/grammar_checker_screen.dart';
import '../learning/translation_practice_screen.dart';
import '../voice/voice_assistant_screen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class SettingsScreen extends SettingScreen {
  const SettingsScreen({super.key});
}

class _SettingScreenState extends State<SettingScreen> {
  static const String _boyAvatarPath = 'assets/icons/AvatarBoy.png';
  static const String _girlAvatarPath = 'assets/icons/AvatarGirl.png';

  // Background gradient: switched from purple to app sky-blue
  static const Color _topPurple = Color(0xFF4F84FF);
  static const Color _bottomPurple = Color(0xFF82EEFD);
  static const Color _accentPurple = Color(0xFF4F84FF);
  static const Color _textPrimary = Color(0xFF374151);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _divider = Color(0xFFF3F4F6);
  static const Color _danger = Color(0xFFEF4444);

  bool _darkModeEnabled = true;
  bool _themeSynced = false;

  TextStyle get _baseFont =>
      const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        letterSpacing: 0,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final gamificationProvider = Provider.of<GamificationProvider>(
          context,
          listen: false,
        );
        final userId = FirebaseAuth.instance.currentUser?.uid;

        await Future.wait([
          userProvider.loadUserFromFirebase(userId: userId),
          gamificationProvider.loadFromFirestore(userId: userId),
        ]);
      } catch (e) {
        debugPrint('Settings load error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppTheme.primaryGreen,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.primaryGreen,
        body: Stack(
          children: [
            const _BackgroundPattern(),
            SafeArea(
              child: Consumer<UserProvider>(
                builder: (context, userProvider, _) {
                  if (userProvider.currentUser == null) {
                    return const _LoadingSettings();
                  }

                  return Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) {
                      if (!_themeSynced) {
                        _darkModeEnabled = themeProvider.isDarkMode;
                        _themeSynced = true;
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              20,
                              14,
                              20,
                              24 + MediaQuery.paddingOf(context).bottom,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight - 38,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 430,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const _TopNavigation(),
                                      const SizedBox(height: 12),
                                      _ProfileHeader(
                                        name: userProvider.currentUser!.name,
                                        subtitle: '',
                                        avatar: _buildAvatar(userProvider),
                                        baseFont: _baseFont,
                                      ),
                                      const SizedBox(height: 30),
                                      _SettingsCard(
                                        title: 'GENERAL SETTINGS',
                                        titleIcon: Icons.settings_outlined,
                                        baseFont: _baseFont,
                                        children: [
                                          _SettingsRow(
                                            icon: Icons.alternate_email_rounded,
                                            iconColor: const Color(0xFF7C3AED),
                                            title: 'Email Verified',
                                            baseFont: _baseFont,
                                            trailing: _VerifiedBadge(
                                              verified:
                                                  FirebaseService.isEmailVerified(),
                                            ),
                                            onTap:
                                                FirebaseService.isEmailVerified()
                                                ? null
                                                : () => _sendVerificationEmail(
                                                    context,
                                                  ),
                                          ),
                                          _SettingsRow(
                                            icon: Icons.dark_mode_rounded,
                                            iconColor: const Color(0xFFFFA726),
                                            title: 'Dark Mode',
                                            baseFont: _baseFont,
                                            trailing: _PurpleSwitch(
                                              value: _darkModeEnabled,
                                              onChanged: (value) {
                                                setState(() {
                                                  _darkModeEnabled = value;
                                                });
                                                if (themeProvider.isDarkMode !=
                                                    value) {
                                                  themeProvider.toggleTheme();
                                                }
                                              },
                                            ),
                                          ),
                                          _SettingsRow(
                                            icon: Icons.language_rounded,
                                            iconColor: const Color(0xFF0EA5E9),
                                            title: 'App Language',
                                            baseFont: _baseFont,
                                            statusText: _languageDisplay(
                                              userProvider,
                                            ),
                                            onTap: () => _showLanguageDialog(
                                              context,
                                              userProvider,
                                            ),
                                          ),
                                          _SettingsRow(
                                            icon: Icons.person_rounded,
                                            iconColor: const Color(0xFF4F46E5),
                                            title: 'Change Avatar',
                                            baseFont: _baseFont,
                                            statusText: _avatarDisplay(
                                              userProvider,
                                            ),
                                            onTap: () => _showAvatarSheet(
                                              context,
                                              userProvider,
                                            ),
                                            showDivider: false,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      _SettingsCard(
                                        title: 'ADVANCED AI TOOLS',
                                        titleIcon: Icons.smart_toy_outlined,
                                        baseFont: _baseFont,
                                        children: [
                                          _SettingsRow(
                                            icon: Icons.edit_note_rounded,
                                            iconColor: const Color(0xFFFF9800),
                                            title: 'Grammar Checker',
                                            baseFont: _baseFont,
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const GrammarCheckerScreen(),
                                                ),
                                              );
                                            },
                                          ),
                                          _SettingsRow(
                                            icon:
                                                Icons.record_voice_over_rounded,
                                            iconColor: const Color(0xFF6D28D9),
                                            title: 'Translation Practice',
                                            baseFont: _baseFont,
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const TranslationPracticeScreen(),
                                                ),
                                              );
                                            },
                                          ),
                                          _SettingsRow(
                                            icon: Icons.mic_rounded,
                                            iconColor: const Color(0xFF1F2937),
                                            title: 'Voice Assistant',
                                            baseFont: _baseFont,
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const VoiceAssistantScreen(),
                                                ),
                                              );
                                            },
                                            showDivider: false,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      _LogoutButton(
                                        baseFont: _baseFont,
                                        onTap: () => _confirmLogout(context),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(UserProvider userProvider) {
    final selectedPath = userProvider.selectedAvatarPath;

    if (selectedPath == null || selectedPath.isEmpty) {
      return const _AvatarPlaceholder();
    }

    return Image.asset(
      selectedPath,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorBuilder: (_, __, ___) => const _AvatarPlaceholder(),
    );
  }

  String _languageDisplay(UserProvider userProvider) {
    final language = userProvider.currentUser?.selectedLanguage ?? 'urdu';
    return language == 'punjabi' ? 'Punjabi' : 'Urdu';
  }

  String _avatarDisplay(UserProvider userProvider) {
    return userProvider.selectedAvatarPath == _boyAvatarPath ? 'BOY' : 'GIRL';
  }

  Future<void> _sendVerificationEmail(BuildContext context) async {
    try {
      await FirebaseService.sendEmailVerification();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  void _showLanguageDialog(BuildContext context, UserProvider userProvider) {
    final currentLanguage =
        userProvider.currentUser?.selectedLanguage ?? 'urdu';

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Select Language',
            style: _baseFont.copyWith(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogChoiceTile(
                icon: Icons.language_rounded,
                title: 'Urdu',
                subtitle: 'Official language',
                selected: currentLanguage == 'urdu',
                baseFont: _baseFont,
                onTap: () {
                  userProvider.setSelectedLanguage('urdu');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Language changed to Urdu')),
                  );
                },
              ),
              const SizedBox(height: 8),
              _DialogChoiceTile(
                icon: Icons.translate_rounded,
                title: 'Pakistani Punjabi',
                subtitle: 'Shahmukhi script',
                selected: currentLanguage == 'punjabi',
                baseFont: _baseFont,
                onTap: () {
                  userProvider.setSelectedLanguage('punjabi');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Language changed to Punjabi'),
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: _baseFont),
            ),
          ],
        );
      },
    );
  }

  void _showAvatarSheet(BuildContext context, UserProvider userProvider) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Choose Avatar',
                  textAlign: TextAlign.center,
                  style: _baseFont.copyWith(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _AvatarChoice(
                        label: 'Boy',
                        assetPath: _boyAvatarPath,
                        selected:
                            userProvider.selectedAvatarPath == _boyAvatarPath,
                        fallbackIcon: Icons.face_6_rounded,
                        baseFont: _baseFont,
                        onTap: () {
                          userProvider.setSelectedAvatarPath(_boyAvatarPath);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AvatarChoice(
                        label: 'Girl',
                        assetPath: _girlAvatarPath,
                        selected:
                            userProvider.selectedAvatarPath == _girlAvatarPath,
                        fallbackIcon: Icons.face_3_rounded,
                        baseFont: _baseFont,
                        onTap: () {
                          userProvider.setSelectedAvatarPath(_girlAvatarPath);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Logout',
            style: _baseFont.copyWith(fontWeight: FontWeight.w800),
          ),
          content: Text('Are you sure you want to logout?', style: _baseFont),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: _baseFont),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _danger,
                foregroundColor: Colors.white,
              ),
              child: Text('Logout', style: _baseFont),
            ),
          ],
        );
      },
    );

    if (confirm != true || !context.mounted) {
      return;
    }

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final learningProvider = Provider.of<LearningProvider>(
      context,
      listen: false,
    );
    final navigator = Navigator.of(context);

    await themeProvider.resetForLogout();
    await learningProvider.clearProgressOnLogout();
    await FirebaseService.signOut();

    if (mounted) {
      navigator.pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}

class _TopNavigation extends StatelessWidget {
  const _TopNavigation();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white.withValues(alpha: 0.20),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.maybePop(context),
          child: const SizedBox(
            height: 38,
            width: 38,
            child: Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.subtitle,
    required this.avatar,
    required this.baseFont,
  });

  final String name;
  final String subtitle;
  final Widget avatar;
  final TextStyle baseFont;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HexagonAvatar(child: avatar),
        const SizedBox(height: 16),
        Text(
          'Hi, $name',
          textAlign: TextAlign.center,
          style: baseFont.copyWith(
            color: Colors.white,
            fontSize: 24,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: baseFont.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class HexagonAvatar extends StatelessWidget {
  const HexagonAvatar({super.key, required this.child, this.size = 96});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipPath(
        clipper: HexagonClipper(),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(4),
          child: ClipPath(clipper: HexagonClipper(), child: child),
        ),
      ),
    );
  }
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * 0.25, size.height * 0.05)
      ..lineTo(size.width * 0.75, size.height * 0.05)
      ..lineTo(size.width, size.height * 0.50)
      ..lineTo(size.width * 0.75, size.height * 0.95)
      ..lineTo(size.width * 0.25, size.height * 0.95)
      ..lineTo(0, size.height * 0.50)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF4ECFF),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: _SettingScreenState._accentPurple,
          size: 48,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.titleIcon,
    required this.children,
    required this.baseFont,
  });

  final String title;
  final IconData titleIcon;
  final List<Widget> children;
  final TextStyle baseFont;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.075),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
              children: [
                Icon(
                  titleIcon,
                  size: 14,
                  color: _SettingScreenState._textMuted,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: baseFont.copyWith(
                      color: _SettingScreenState._textMuted,
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.baseFont,
    this.trailing,
    this.statusText,
    this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final TextStyle baseFont;
  final Widget? trailing;
  final String? statusText;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          SizedBox(width: 23, child: Icon(icon, color: iconColor, size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: baseFont.copyWith(
                color: _SettingScreenState._textPrimary,
                fontSize: 16,
                height: 1.25,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(width: 10),
          trailing ??
              _DefaultTrailing(statusText: statusText, baseFont: baseFont),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(
                    bottom: BorderSide(
                      color: _SettingScreenState._divider,
                      width: 1,
                    ),
                  )
                : null,
          ),
          child: row,
        ),
      ),
    );
  }
}

class _DefaultTrailing extends StatelessWidget {
  const _DefaultTrailing({required this.statusText, required this.baseFont});

  final String? statusText;
  final TextStyle baseFont;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (statusText != null) ...[
          Text(
            statusText!,
            style: baseFont.copyWith(
              color: _SettingScreenState._textMuted,
              fontSize: 11,
              height: 1.1,
              fontWeight: FontWeight.w800,
               fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
        ],
        const Icon(
          Icons.chevron_right_rounded,
          color: _SettingScreenState._textMuted,
          size: 20,
        ),
      ],
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 23,
      width: 23,
      decoration: BoxDecoration(
        color: verified ? const Color(0xFFDCFCE7) : const Color(0xFFFFF7ED),
        shape: BoxShape.circle,
      ),
      child: Icon(
        verified ? Icons.check_rounded : Icons.priority_high_rounded,
        color: verified ? const Color(0xFF22C55E) : const Color(0xFFF97316),
        size: 17,
      ),
    );
  }
}

class _PurpleSwitch extends StatelessWidget {
  const _PurpleSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 44,
          height: 24,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value
                ? _SettingScreenState._accentPurple
                : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(24),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.baseFont, required this.onTap});

  final TextStyle baseFont;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      shadowColor: Colors.black.withValues(alpha: 0.08),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.logout_rounded,
                color: _SettingScreenState._danger,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Logout',
                style: baseFont.copyWith(
                  color: _SettingScreenState._danger,
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogChoiceTile extends StatelessWidget {
  const _DialogChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.baseFont,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final TextStyle baseFont;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? _SettingScreenState._accentPurple.withValues(alpha: 0.10)
          : const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: _SettingScreenState._accentPurple),
        title: Text(
          title,
          style: baseFont.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle, style: baseFont.copyWith(fontSize: 12)),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E))
            : null,
      ),
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.label,
    required this.assetPath,
    required this.selected,
    required this.fallbackIcon,
    required this.baseFont,
    required this.onTap,
  });

  final String label;
  final String assetPath;
  final bool selected;
  final IconData fallbackIcon;
  final TextStyle baseFont;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? _SettingScreenState._accentPurple.withValues(alpha: 0.08)
          : const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? _SettingScreenState._accentPurple
                  : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                width: 78,
                height: 78,
                child: ClipOval(
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: const Color(0xFFF4ECFF),
                      child: Icon(
                        fallbackIcon,
                        color: _SettingScreenState._accentPurple,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: baseFont.copyWith(
                  color: selected
                      ? _SettingScreenState._accentPurple
                      : _SettingScreenState._textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundPattern extends StatelessWidget {
  const _BackgroundPattern();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -58,
              right: -64,
                child: Container(
                height: 300,
                width: 300,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: 92,
              left: -92,
                child: Container(
                height: 250,
                width: 250,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.035),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingSettings extends StatelessWidget {
  const _LoadingSettings();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}

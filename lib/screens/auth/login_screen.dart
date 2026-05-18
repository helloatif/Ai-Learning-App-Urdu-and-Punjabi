import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../services/firebase_service.dart';
import '../../services/language_onboarding_service.dart';
import '../../localization/app_strings.dart';
import '../../providers/user_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/learning_provider.dart';
import '../../providers/theme_provider.dart';
import 'congratulations_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
    _loadRememberMePreference();
  }

  Future<void> _loadRememberMePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('rememberMe') ?? false;
    final savedEmail = prefs.getString('rememberedEmail') ?? '';
    final savedPassword = prefs.getString('rememberedPassword') ?? '';

    setState(() {
      _rememberMe = rememberMe;
      if (rememberMe && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Coming soon',
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.enterEmail)),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = await FirebaseService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (userId != null && mounted) {
        final user = FirebaseService.getCurrentUser();

        if (user == null) {
          // Proceed anyway
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Login successful!'),
                backgroundColor: Color(0xFF3C404A),
                duration: Duration(seconds: 1),
              ),
            );
            Navigator.of(context).pushReplacementNamed('/language-selection');
          }
          return;
        }

        if (!user.emailVerified) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🚫 Please verify your email first!'),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.of(context).pushReplacementNamed('/email-verification');
          }
          return;
        }

        // Save Remember Me preference
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rememberMe', _rememberMe);
        if (_rememberMe) {
          await prefs.setString('rememberedEmail', _emailController.text.trim());
          await prefs.setString('rememberedPassword', _passwordController.text);
        } else {
          await prefs.remove('rememberedEmail');
          await prefs.remove('rememberedPassword');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Login successful!'),
              backgroundColor: Color(0xFF3C404A),
              duration: Duration(seconds: 1),
            ),
          );

          // Load user data
          try {
            final themeProvider = Provider.of<ThemeProvider>(
              context,
              listen: false,
            );
            await themeProvider.loadForUser(userId);

            final userProvider = Provider.of<UserProvider>(
              context,
              listen: false,
            );
            await userProvider.loadUserFromFirebase();

            final gamificationProvider = Provider.of<GamificationProvider>(
              context,
              listen: false,
            );
            await gamificationProvider.loadFromFirestore();

            final learningProvider = Provider.of<LearningProvider>(
              context,
              listen: false,
            );
            await learningProvider.loadProgressFromFirestore();

            // Check language selection and one-time level onboarding
            final localLanguage = await LanguageOnboardingService.getSelectedLanguage(userId);

            if (localLanguage.isNotEmpty) {
              final levelCompleted = await LanguageOnboardingService.isLevelCompleted(userId);
              final timeCompleted = levelCompleted
                  ? await LanguageOnboardingService.isTimeSelectionCompleted(userId)
                  : false;
              final preparingCompleted = timeCompleted
                  ? await LanguageOnboardingService.isPreparingScreenCompleted(userId)
                  : false;
              if (mounted) {
                Navigator.of(context).pushReplacementNamed(
                  !levelCompleted
                      ? '/language-level'
                      : (!timeCompleted ? '/time-selection' : (preparingCompleted ? '/home' : '/preparing')),
                  arguments: localLanguage,
                );
              }
              return;
            }

            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();

            if (!mounted) return;

            // If user hasn't seen congratulations yet, show it once
            final congratsShown = (doc.data()?['congratsShown'] ?? false) as bool;
            if (!congratsShown) {
              // Mark as shown and navigate to CongratulationsScreen
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .set({'congratsShown': true}, SetOptions(merge: true)).catchError((e) {
                debugPrint('Error setting congratsShown: $e');
              });

              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => CongratulationsScreen(userId: userId),
                  ),
                );
              }
              return;
            }

            final selectedLanguage = (doc.data()?['selectedLanguage'] ?? '').toString().trim();

            if (selectedLanguage.isNotEmpty) {
              await LanguageOnboardingService.saveSelectedLanguage(userId, selectedLanguage);
              final levelCompleted = (doc.data()?['languageLevelCompleted'] ?? false) == true;
              final timeCompleted = (doc.data()?['timeSelectionCompleted'] ?? false) == true;
              final preparingCompleted = (doc.data()?['preparingScreenCompleted'] ?? false) == true;
              if (mounted) {
                Navigator.of(context).pushReplacementNamed(
                  !levelCompleted
                      ? '/language-level'
                      : (!timeCompleted ? '/time-selection' : (preparingCompleted ? '/home' : '/preparing')),
                  arguments: selectedLanguage,
                );
              }
            } else {
              if (mounted) Navigator.of(context).pushReplacementNamed('/language-selection');
            }
          } catch (e) {
            print('⚠️ Login: Error checking language: $e');
            if (mounted) Navigator.of(context).pushReplacementNamed('/language-selection');
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login failed. Please check your credentials.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // CRITICAL FIX: For web errors, check if user is actually logged in
        final user = FirebaseService.getCurrentUser();

        if (user != null) {
          // User is logged in despite the error!
          if (!user.emailVerified) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🚫 Please verify your email first!'),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.of(context).pushReplacementNamed('/email-verification');
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Login successful!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
          Navigator.of(context).pushReplacementNamed('/language-selection');
          return;
        }

        // No user logged in — show error message
        String errorMessage = 'Login failed: ${e.toString()}';
        if (e.toString().contains('user-not-found')) {
          errorMessage = '❌ No account found with this email. Please sign up first.';
        } else if (e.toString().contains('wrong-password')) {
          errorMessage = '❌ Incorrect password. Please try again.';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = '❌ Invalid email format.';
        } else if (e.toString().contains('invalid-credential')) {
          errorMessage = '❌ Invalid email or password. Please try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.of(context).size.height / 812;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final uiScale = scale.clamp(0.84, 1.0);

            return AnimatedPadding(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24 * uiScale),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 10 * uiScale),
                        Row(
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.arrow_back,
                                size: 28 * uiScale,
                                color: const Color(0xFF2E3A46),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            Expanded(
                              child: Text(
                                'Sign in',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24 * uiScale,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2E3A46),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            SizedBox(width: 28 * uiScale),
                          ],
                        ),
                        SizedBox(height: 50 * uiScale),
                        Center(
                          child: Text(
                            'Welcome',
                            style: TextStyle(
                              fontSize: 42 * uiScale,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryGreen,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        SizedBox(height: 34 * uiScale),
                        _LoginField(
                          controller: _emailController,
                          hintText: 'Email',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        SizedBox(height: 18 * uiScale),
                        _LoginField(
                          controller: _passwordController,
                          hintText: 'Password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: const Color(0xFF4A4A4A),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        SizedBox(height: 18 * uiScale),
                        SizedBox(
                          height: 52 * uiScale,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                                    ),
                                  )
                                : Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 16 * uiScale,
                                      fontWeight: FontWeight.w700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: 18 * uiScale),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Forgot your password? ',
                              style: TextStyle(
                                fontSize: 15 * uiScale,
                                color: const Color(0xFF2E3A46),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Reset your password',
                                      style: const TextStyle(fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Reset your password',
                                style: TextStyle(
                                  fontSize: 15 * uiScale,
                                  color: AppTheme.primaryGreen,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 22 * uiScale),
                        Row(
                          children: [
                            const Expanded(child: Divider(color: Color(0xFFE6E6E6), thickness: 1)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14 * uiScale),
                              child: Text(
                                'OR',
                                style: TextStyle(
                                  color: const Color(0xFFA5A5A5),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12 * uiScale,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: Color(0xFFE6E6E6), thickness: 1)),
                          ],
                        ),
                        SizedBox(height: 18 * uiScale),
                        _AuthSocialButton(
                          label: 'Sign up with Apple',
                          icon: Icon(Icons.apple, size: 24 * uiScale, color: const Color(0xFF1F2A3A)),
                          onTap: _showComingSoon,
                        ),
                        SizedBox(height: 12 * uiScale),
                        _AuthSocialButton(
                          label: 'Sign in with Google',
                          icon: Image.asset(
                            'assets/icons/google-logo-transparent-free-png.webp',
                            width: 24 * uiScale,
                            height: 24 * uiScale,
                            fit: BoxFit.contain,
                          ),
                          onTap: _showComingSoon,
                        ),
                        SizedBox(height: 12 * uiScale),
                        _AuthSocialButton(
                          label: 'Sign in with SMS',
                          icon: Image.asset(
                            'assets/icons/smslogo.jpg',
                            width: 22 * uiScale,
                            height: 22 * uiScale,
                            fit: BoxFit.contain,
                          ),
                          onTap: _showComingSoon,
                        ),
                        SizedBox(height: 22 * uiScale),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Are you not registered? ',
                              style: TextStyle(
                                fontSize: 15 * uiScale,
                                color: const Color(0xFF2E3A46),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pushNamed('/signup');
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Register',
                                style: TextStyle(
                                  fontSize: 15 * uiScale,
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8 * uiScale),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(
        fontSize: 16,
        color: Color(0xFF2E3A46),
        fontStyle: FontStyle.italic,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFF2E3A46),
          fontSize: 16,
          fontStyle: FontStyle.italic,
        ),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF4A4A4A)),
        suffixIcon: suffix,
        filled: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
    );
  }
}

class _AuthSocialButton extends StatelessWidget {
  const _AuthSocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Material(
        color: const Color(0xFFEFF2FC),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 30, child: Center(child: icon)),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1F2A3A),
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
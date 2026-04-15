import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../services/firebase_service.dart';
import '../../localization/app_strings.dart';
import '../../providers/user_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/learning_provider.dart';
import '../../providers/theme_provider.dart';

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

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.enterEmail)));
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

      // Stop loading immediately after API call
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (userId != null && mounted) {
        // CRITICAL: Double-check email verification before proceeding
        final user = FirebaseService.getCurrentUser();
        if (user == null || !user.emailVerified) {
          // This should never happen, but as a safety net
          // Don't clear Remember Me - just need to verify email
          await FirebaseService.signOut(clearRememberMe: false);
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

        // Save Remember Me preference, email, and password
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rememberMe', _rememberMe);
        if (_rememberMe) {
          await prefs.setString(
            'rememberedEmail',
            _emailController.text.trim(),
          );
          await prefs.setString('rememberedPassword', _passwordController.text);
        } else {
          await prefs.remove('rememberedEmail');
          await prefs.remove('rememberedPassword');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Login successful!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );

          // Load user data first
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

            // Load gamification in background
            final gamificationProvider = Provider.of<GamificationProvider>(
              context,
              listen: false,
            );
            await gamificationProvider.loadFromFirestore();

            // Load learning progress (chapter completions, quiz scores)
            final learningProvider = Provider.of<LearningProvider>(
              context,
              listen: false,
            );
            await learningProvider.loadProgressFromFirestore();

            // First check SharedPreferences (fastest)
            final prefs = await SharedPreferences.getInstance();
            final localLanguage = prefs.getString(
              'language_selected_flag_$userId',
            );

            if (localLanguage != null && localLanguage.isNotEmpty) {
              print(
                '✅ Login: Language found in local storage (\"$localLanguage\"), going to home',
              );
              if (mounted) Navigator.of(context).pushReplacementNamed('/home');
              return;
            }

            // Fallback to Firestore check
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();

            if (!mounted) return;

            final selectedLanguage = doc.data()?['selectedLanguage'] as String?;
            print('🔍 Login: Checking Firestore for user $userId');
            print('🔍 Login: Language in Firestore = \"$selectedLanguage\"');

            if (selectedLanguage != null && selectedLanguage.isNotEmpty) {
              // Save to local storage for next time
              await prefs.setString(
                'language_selected_flag_$userId',
                selectedLanguage,
              );
              print('✅ Login: Language exists, going to home');
              if (mounted) Navigator.of(context).pushReplacementNamed('/home');
            } else {
              // No language selected - go to language selection
              print('✅ Login: No language, going to selection');
              if (mounted)
                Navigator.of(
                  context,
                ).pushReplacementNamed('/language-selection');
            }
          } catch (e) {
            print('⚠️ Login: Error checking language: $e');
            // On error, default to language selection
            if (mounted)
              Navigator.of(context).pushReplacementNamed('/language-selection');
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
        String errorMessage = 'Login failed: ${e.toString()}';
        if (e.toString().contains('user-not-found')) {
          errorMessage =
              '❌ No account found with this email. Please sign up first.';
        } else if (e.toString().contains('wrong-password')) {
          errorMessage = '❌ Incorrect password. Please try again.';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = '❌ Invalid email format.';
        } else if (e.toString().contains('invalid-credential')) {
          errorMessage = '❌ Invalid email or password. Please try again.';
        } else if (e.toString().contains('email-not-verified')) {
          // Show error message and navigate to verification screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '🚫 Email Not Verified!\n\nYou must verify your email before logging in.\nCheck your inbox (and spam folder) for the verification link.\n\nClick it to verify, then try logging in again.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 7),
            ),
          );
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/email-verification');
          }
          return; // Exit early
        } else if (e.toString().contains('List<Object') ||
            e.toString().contains('PigeonUserInfo') ||
            e.toString().contains('type cast')) {
          // This is a Firebase plugin bug - check if user is actually logged in
          final user = FirebaseService.getCurrentUser();
          if (user != null && user.emailVerified) {
            // User is actually logged in successfully
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Login successful!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            Navigator.of(context).pushReplacementNamed('/language-selection');
            return;
          } else if (user != null && !user.emailVerified) {
            // User exists but email not verified
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🚫 Please verify your email first!'),
                backgroundColor: Colors.red,
              ),
            );
            Navigator.of(context).pushReplacementNamed('/email-verification');
            return;
          }
          errorMessage = '❌ Login error. Please try again.';
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
    return Scaffold(
      resizeToAvoidBottomInset: true, // Fix keyboard overflow
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(scale: value, child: child);
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: Image.asset(
                            'assets/icons/app_icon.png',
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    Center(
                      child: Text(
                        AppStrings.login,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(color: AppTheme.primaryGreen),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        AppStrings.learnUrduPunjabi,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Email Field
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: 'Enter email (ای میل درج کریں)',
                        labelText: 'Email (ای میل)',
                        prefixIcon: const Icon(
                          Icons.email,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        hintText: 'Enter password (پاس ورڈ درج کریں)',
                        labelText: 'Password (پاس ورڈ)',
                        prefixIcon: const Icon(
                          Icons.lock,
                          color: AppTheme.primaryGreen,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppTheme.primaryGreen,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                    ),
                    const SizedBox(height: 16),

                    // Remember Me Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                          activeColor: AppTheme.primaryGreen,
                        ),
                        const Text(
                          'Remember Me (مجھے یاد رکھیں)',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.darkGray,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Login Button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Sign In (داخل ہوں)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sign Up Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No account? (اکاؤنٹ نہیں ہے؟)',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/signup');
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Sign Up (رجسٹر کریں)',
                            style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ), // Close Column
              ), // Close SlideTransition
            ), // Close FadeTransition
          ), // Close Padding
        ), // Close SingleChildScrollView
      ), // Close SafeArea
    ); // Close Scaffold
  }
}

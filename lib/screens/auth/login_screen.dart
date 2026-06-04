import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart' as rive;
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
  Future<rive.File?>? _riveFileFuture;
  String? _riveLoadError;

  @override
  void initState() {
    super.initState();
    _loadRememberMePreference();
    _riveFileFuture = _loadRiveFileSafely();
  }

  Future<rive.File?> _loadRiveFileSafely() async {
    try {
      final file = await rive.File.asset(
        'assets/icons/animations/16499-31053-bubble-gum-boy.riv',
        riveFactory: rive.Factory.rive,
      );
      debugPrint('Rive file loaded successfully: bubble-gum-boy.riv');
      return file;
    } catch (e, st) {
      debugPrint('Rive load error: $e');
      _riveLoadError = e.toString();
      return null;
    }
  }

  Future<void> _loadRememberMePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('rememberedEmail') ?? '';
    final savedPassword = prefs.getString('rememberedPassword') ?? '';
    final rememberMe = prefs.getBool('rememberMe') ?? false;

    setState(() {
      _rememberMe = rememberMe;
      if (rememberMe && savedEmail.isNotEmpty) {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
      }
    });
  }

  Future<void> _loadUserDataAfterSignIn(String userId) async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    await themeProvider.loadForUser(userId);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.fetchUserData(userId: userId);

    final gamificationProvider = Provider.of<GamificationProvider>(
      context,
      listen: false,
    );
    await gamificationProvider.loadFromFirestore(userId: userId);

    final learningProvider = Provider.of<LearningProvider>(
      context,
      listen: false,
    );
    await learningProvider.loadProgressFromFirestore(userId: userId);
  }

  @override
  void dispose() {
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
    debugPrint('Login: start attempt for email=${_emailController.text.trim()}');
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

      debugPrint('Login: FirebaseService.signIn returned userId=$userId');

      if (!mounted) return;

      if (userId != null && mounted) {
        final user = FirebaseService.getCurrentUser();
        debugPrint('Login: FirebaseService.getCurrentUser -> $user');

        if (user == null) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login failed. Please check your credentials.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        if (!user.emailVerified) {
          debugPrint('Login: user email not verified');
          if (mounted) {
              setState(() {
                _isLoading = false;
              });
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
        if (!mounted) return;
        await prefs.setBool('rememberMe', _rememberMe);
        if (_rememberMe) {
          await prefs.setString('rememberedEmail', _emailController.text.trim());
          await prefs.setString('rememberedPassword', _passwordController.text);
        } else {
          await prefs.remove('rememberedEmail');
          await prefs.remove('rememberedPassword');
        }

        if (!mounted) return;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Login successful!'),
              backgroundColor: Color(0xFF3C404A),
              duration: Duration(seconds: 1),
            ),
          );

          try {
            await _loadUserDataAfterSignIn(userId);

            debugPrint('Login: _loadUserDataAfterSignIn completed for $userId');

            if (!mounted) return;

            // Check language selection and one-time level onboarding
            final localLanguage = await LanguageOnboardingService.getSelectedLanguage(userId);

            if (!mounted) return;

            if (localLanguage.isNotEmpty) {
              final levelCompleted = await LanguageOnboardingService.isLevelCompleted(userId);
              if (!mounted) return;
              final timeCompleted = levelCompleted
                  ? await LanguageOnboardingService.isTimeSelectionCompleted(userId)
                  : false;
              if (!mounted) return;
              final preparingCompleted = timeCompleted
                  ? await LanguageOnboardingService.isPreparingScreenCompleted(userId)
                  : false;
              if (!mounted) return;
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
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
                setState(() {
                  _isLoading = false;
                });
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
              if (!mounted) return;
              final levelCompleted = (doc.data()?['languageLevelCompleted'] ?? false) == true;
              final timeCompleted = (doc.data()?['timeSelectionCompleted'] ?? false) == true;
              final preparingCompleted = (doc.data()?['preparingScreenCompleted'] ?? false) == true;
              if (!mounted) return;
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
                Navigator.of(context).pushReplacementNamed(
                  !levelCompleted
                      ? '/language-level'
                      : (!timeCompleted ? '/time-selection' : (preparingCompleted ? '/home' : '/preparing')),
                  arguments: selectedLanguage,
                );
              }
            } else {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
                Navigator.of(context).pushReplacementNamed('/language-selection');
              }
            }
          } catch (e) {
            print('⚠️ Login: Error checking language: $e');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              Navigator.of(context).pushReplacementNamed('/language-selection');
            }
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

        final errorText = e.toString();
        String errorMessage = 'Login failed: $errorText';
        if (errorText.contains('user-not-found')) {
          errorMessage = '❌ No account found with this email. Please sign up first.';
        } else if (errorText.contains('wrong-password')) {
          errorMessage = '❌ Incorrect password. Please try again.';
        } else if (errorText.contains('invalid-email')) {
          errorMessage = '❌ Invalid email format.';
        } else if (errorText.contains('invalid-credential')) {
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
    _riveFileFuture ??= _loadRiveFileSafely();

    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
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
                          child: SizedBox(
                            height: 260 * uiScale,
                            child: FutureBuilder<rive.File?>(
                              future: _riveFileFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Container(
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Loading Rive...',
                                      style: TextStyle(
                                        color: Colors.blueGrey,
                                        fontSize: 14 * uiScale,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                }

                                if (snapshot.hasError || snapshot.data == null) {
                                  final errorText = _riveLoadError ?? snapshot.error.toString();
                                  return Container(
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Rive Load Error: $errorText',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 12 * uiScale,
                                      ),
                                    ),
                                  );
                                }

                                return rive.RiveWidgetBuilder(
                                  fileLoader: rive.FileLoader.fromFile(
                                    snapshot.data!,
                                    riveFactory: rive.Factory.rive,
                                  ),
                                  artboardSelector: rive.ArtboardSelector.byName('Artboard'),
                                  stateMachineSelector:
                                      rive.StateMachineSelector.byName('State Machine 1'),
                                  onLoaded: (state) {
                                    debugPrint('Rive loaded: ${state.controller.runtimeType}');
                                  },
                                  onFailed: (error, stackTrace) {
                                    debugPrint('Rive render failed: $error');
                                  },
                                  builder: (context, state) {
                                    if (state is rive.RiveLoaded) {
                                      return rive.RiveWidget(
                                        controller: state.controller,
                                        fit: rive.Fit.contain,
                                        useSharedTexture: false,
                                      );
                                    }

                                    if (state is rive.RiveFailed) {
                                      return Container(
                                        alignment: Alignment.center,
                                        child: Text(
                                          'Rive Load Error: ${state.error}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: 12 * uiScale,
                                          ),
                                        ),
                                      );
                                    }

                                    return Container(
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Loading Rive...',
                                        style: TextStyle(
                                          color: Colors.blueGrey,
                                          fontSize: 14 * uiScale,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 34 * uiScale),
                        _LoginField(
                          controller: _emailController,
                          hintText: 'Email',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          uiScale: uiScale,
                        ),
                        SizedBox(height: 18 * uiScale),
                        _LoginField(
                          controller: _passwordController,
                          hintText: 'Password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          uiScale: uiScale,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: const Color(0xFF4A4A4A),
                              size: 24 * uiScale,
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
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (val) {
                                setState(() {
                                  _rememberMe = val ?? false;
                                });
                              },
                              activeColor: Colors.blue,
                            ),
                            SizedBox(width: 8 * uiScale),
                            Text(
                              'Remember me',
                              style: TextStyle(
                                fontSize: 15 * uiScale,
                                color: const Color(0xFF2E3A46),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12 * uiScale),
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
    required this.uiScale,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final double uiScale;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(
        fontSize: 16 * uiScale,
        color: const Color(0xFF2E3A46),
        fontStyle: FontStyle.italic,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: const Color(0xFF2E3A46),
          fontSize: 16 * uiScale,
          fontStyle: FontStyle.italic,
        ),
        prefixIcon: Icon(
          prefixIcon,
          color: const Color(0xFF4A4A4A),
          size: 24 * uiScale,
        ),
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
        contentPadding: EdgeInsets.symmetric(
          vertical: 16 * uiScale,
          horizontal: 12 * uiScale,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/onboarding_screen_fixed.dart';
import 'screens/home_screen.dart';
import 'screens/learning/ai_assistant_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'providers/user_provider.dart';
import 'providers/learning_provider.dart';
import 'providers/gamification_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/adaptive_learning_provider.dart';
import 'screens/learning/language_selection_screen.dart';
import 'screens/learning/language_level_screen.dart';
import 'screens/learning/time_selection_screen.dart';
import 'screens/learning/preparing_screen.dart';
import 'services/adaptive_quiz_service.dart';
import 'services/language_onboarding_service.dart';
import 'themes/app_theme.dart';

// Global variable to store initial theme preference
bool _initialDarkMode = false;

// Global variable to store initial userId (used by ThemeProvider at startup)
String _initialUserId = '';

Future<void>? _firebaseInitFuture;

Future<void> _ensureFirebaseInitialized() {
  _firebaseInitFuture ??= () async {
    try {
      debugPrint('🔄 Initializing Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      }

      debugPrint('✅ Firebase initialized successfully');
    } catch (e) {
      debugPrint('❌ Firebase initialization error: $e');
    }
  }();

  return _firebaseInitFuture!;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _ensureFirebaseInitialized();

  // Render the first Flutter frame immediately to reduce native splash hold time.
  runApp(const MyApp());
}

// Helper function to determine initial screen based on auth state
Future<Widget> _determineInitialScreen() async {
  await _ensureFirebaseInitialized();
  // Priority gating:
  // 1) FIRST-TIME OPEN -> show onboarding (local flag `isFirstTime`)
  // 2) RETURNING UNAUTHENTICATED -> show Login
  // 3) AUTHENTICATED -> show Home
  try {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool('isFirstTime');

    // If never set or explicitly true, treat as first-time open
    if (isFirstTime == null || isFirstTime == true) {
      return const OnboardingScreen();
    }
  } catch (e) {
    debugPrint('Warning: could not read SharedPreferences: $e');
    // Fall through to normal checks below
  }

  // If a Firebase user is present, go to Home. Otherwise show Login.
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    return const HomeScreen();
  }

  return const LoginScreen();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => LearningProvider()),
        ChangeNotifierProvider(create: (_) => GamificationProvider()),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(
            initialDarkMode: _initialDarkMode,
            userId: _initialUserId,
          ),
        ),
        ChangeNotifierProvider(create: (_) => AdaptiveQuizService()),
        ChangeNotifierProvider(create: (_) => AdaptiveLearningProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Urdu Punjabi Tutor',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const _AuthGate(),
            onGenerateRoute: (settings) {
              // Add page transitions to all routes
              Widget page;
              switch (settings.name) {
                case '/login':
                  page = const LoginScreen();
                  break;
                case '/signup':
                  page = const SignupScreen();
                  break;
                case '/email-verification':
                  page = const EmailVerificationScreen();
                  break;
                case '/language-selection':
                  page = const LanguageSelectionScreen();
                  break;
                case '/language-level':
                  final selectedLanguage = (settings.arguments as String?) ?? 'urdu';
                  page = LanguageLevelScreen(
                    languageCode: selectedLanguage,
                    languageName: LanguageOnboardingService.displayLanguageName(selectedLanguage),
                    mascotAsset: 'assets/icons/caticon.png',
                  );
                  break;
                case '/time-selection':
                  page = const TimeSelectionScreen();
                  break;
                case '/preparing':
                  page = const PreparingScreen();
                  break;
                case '/home':
                  final rawIdx = settings.arguments;
                  final idx = rawIdx is int
                      ? rawIdx
                      : int.tryParse(rawIdx?.toString() ?? '') ?? 1;
                  page = HomeScreen(initialIndex: idx);
                  break;
                case '/ai-assistant':
                  page = AiAssistantScreen();
                  break;
                case '/profile':
                  page = const ProfileScreen();
                  break;
                default:
                  page = const LoginScreen();
              }

              return PageRouteBuilder(
                settings: settings,
                pageBuilder: (context, animation, secondaryAnimation) => page,
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOutCubic;

                      var tween = Tween(
                        begin: begin,
                        end: end,
                      ).chain(CurveTween(curve: curve));
                      var offsetAnimation = animation.drive(tween);

                      return SlideTransition(
                        position: offsetAnimation,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                transitionDuration: const Duration(milliseconds: 400),
              );
            },
            routes: {
              '/profile': (context) => const ProfileScreen(),
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignupScreen(),
              '/email-verification': (context) =>
                  const EmailVerificationScreen(),
                '/language-selection': (context) => const LanguageSelectionScreen(),
                  '/language-level': (context) {
                      final route = ModalRoute.of(context);
                      final rawLang = route == null ? null : route.settings.arguments;
                      final selectedLanguage =
                        (rawLang is String ? rawLang : rawLang?.toString()) ?? 'urdu';
                  return LanguageLevelScreen(
                    languageCode: selectedLanguage,
                    languageName: LanguageOnboardingService.displayLanguageName(selectedLanguage),
                    mascotAsset: 'assets/icons/caticon.png',
                  );
                },
              '/time-selection': (context) => const TimeSelectionScreen(),
              '/preparing': (context) => const PreparingScreen(),
              '/home': (context) {
                final route = ModalRoute.of(context);
                final rawIdx = route == null ? null : route.settings.arguments;
                final idx = rawIdx is int
                  ? rawIdx
                  : int.tryParse(rawIdx?.toString() ?? '') ?? 1;
                return HomeScreen(initialIndex: idx);
              },
              '/ai-assistant': (context) => AiAssistantScreen(),
            },
          );
        },
      ),
    );
  }
}

// Auth gate widget that shows appropriate screen based on auth state
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late Future<Widget> _initialScreenFuture;
  bool _providersLoaded = false;

  @override
  void initState() {
    super.initState();
    _initialScreenFuture = _determineInitialScreen();
  }

  Future<void> _loadProviders() async {
    if (_providersLoaded) return;
    _providersLoaded = true;

    await _ensureFirebaseInitialized();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted && user.emailVerified) {
      // Load user-specific theme FIRST so dark mode switches instantly
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      await themeProvider.loadForUser(user.uid);

      // Load user provider data
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUserFromFirebase(userId: user.uid);

      // Load gamification data
      final gamificationProvider = Provider.of<GamificationProvider>(
        context,
        listen: false,
      );
      await gamificationProvider.loadFromFirestore(userId: user.uid);

      // Load learning progress data
      final learningProvider = Provider.of<LearningProvider>(
        context,
        listen: false,
      );
      await learningProvider.loadProgressFromFirestore(userId: user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreenFuture,
      builder: (context, snapshot) {
        // No loading screen - just return the target screen immediately
        // Native splash will show during the brief wait
        if (snapshot.hasData) {
          // Load providers when we have the screen ready
          _loadProviders();
          return snapshot.data!;
        }

        if (snapshot.hasError) {
          return const LoginScreen();
        }

        // While waiting, show login screen (better than blank/green screen)
        return const LoginScreen();
      },
    );
  }
}

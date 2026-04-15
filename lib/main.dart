import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/home_screen.dart';
import 'screens/learning/ai_assistant_screen.dart';
import 'screens/learning/language_selection_screen.dart';
import 'providers/user_provider.dart';
import 'providers/learning_provider.dart';
import 'providers/gamification_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/adaptive_learning_provider.dart';
import 'services/adaptive_quiz_service.dart';
import 'themes/app_theme.dart';

// Global flag for language selection
const String _languageSelectedKey = 'language_selected_flag';

// Global variable to store initial theme preference
bool _initialDarkMode = false;

// Global variable to store initial userId (used by ThemeProvider at startup)
String _initialUserId = '';

Future<void>? _firebaseInitFuture;

Future<void> _ensureFirebaseInitialized() {
  _firebaseInitFuture ??= () async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
      }
    } catch (e) {
      // Firebase initialization error - continue gracefully
    }
  }();

  return _firebaseInitFuture!;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Render the first Flutter frame immediately to reduce native splash hold time.
  runApp(const MyApp());
}

// Helper function to determine initial screen based on auth state
Future<Widget> _determineInitialScreen() async {
  await _ensureFirebaseInitialized();

  final user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;

    if (refreshedUser != null && refreshedUser.emailVerified) {
      // First check SharedPreferences (fastest, local)
      try {
        final prefs = await SharedPreferences.getInstance();
        final localFlag = prefs.getString(
          '${_languageSelectedKey}_${refreshedUser.uid}',
        );

        if (localFlag != null && localFlag.isNotEmpty) {
          return const HomeScreen();
        }
      } catch (e) {}

      // Fallback to Firestore check
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(refreshedUser.uid)
            .get();

        final selectedLanguage = doc.data()?['selectedLanguage'] as String?;

        if (selectedLanguage != null && selectedLanguage.isNotEmpty) {
          // Save to local storage for next time
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            '${_languageSelectedKey}_${refreshedUser.uid}',
            selectedLanguage,
          );
          return const HomeScreen();
        } else {
          return const LanguageSelectionScreen();
        }
      } catch (e) {
        return const LanguageSelectionScreen();
      }
    } else if (refreshedUser != null && !refreshedUser.emailVerified) {
      return const EmailVerificationScreen();
    }
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
            home: _AuthGate(),
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
                case '/home':
                  page = const HomeScreen();
                  break;
                case '/ai-assistant':
                  page = const AIAssistantScreen();
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
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignupScreen(),
              '/email-verification': (context) =>
                  const EmailVerificationScreen(),
              '/language-selection': (context) =>
                  const LanguageSelectionScreen(),
              '/home': (context) => const HomeScreen(),
              '/ai-assistant': (context) => const AIAssistantScreen(),
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
      await userProvider.loadUserFromFirebase();

      // Load gamification data
      final gamificationProvider = Provider.of<GamificationProvider>(
        context,
        listen: false,
      );
      await gamificationProvider.loadFromFirestore();

      // Load learning progress data
      final learningProvider = Provider.of<LearningProvider>(
        context,
        listen: false,
      );
      await learningProvider.loadProgressFromFirestore();
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

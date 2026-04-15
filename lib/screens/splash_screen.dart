import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _navigateToHome();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  _navigateToHome() async {
    // Show native splash for 500ms only (fast)
    await Future.delayed(const Duration(milliseconds: 500), () {});

    if (!mounted) return;

    try {
      // Firebase is already initialized in main(), safe to use now
      final user = FirebaseAuth.instance.currentUser;
      print('🔍 Splash: Checking user... user=$user');

      if (user != null) {
        // Reload user to get latest verification status (fast check)
        await user.reload();
        final refreshedUser = FirebaseAuth.instance.currentUser;
        print(
          '🔍 Splash: Refreshed user, emailVerified=${refreshedUser?.emailVerified}',
        );

        if (refreshedUser != null && refreshedUser.emailVerified) {
          // User is verified - check if language was already selected
          final prefs = await SharedPreferences.getInstance();
          final languageSelected =
              prefs.getBool('languageSelected_${refreshedUser.uid}') ?? false;
          print('🔍 Splash: Language selected=$languageSelected');

          if (languageSelected) {
            // Language was already selected before - go straight to home
            print('✅ Splash: Navigating to /home');
            if (mounted) Navigator.of(context).pushReplacementNamed('/home');
          } else {
            // First time login - show language selection
            print('✅ Splash: Navigating to /language-selection');
            if (mounted)
              Navigator.of(context).pushReplacementNamed('/language-selection');
          }
        } else if (refreshedUser != null && !refreshedUser.emailVerified) {
          // User exists but NOT verified - send to verification screen
          print(
            '✅ Splash: User not verified, navigating to /email-verification',
          );
          if (mounted)
            Navigator.of(context).pushReplacementNamed('/email-verification');
        } else {
          // No user - go to login
          print('✅ Splash: No user logged in, navigating to /login');
          if (mounted) Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        // No user logged in - go to login screen
        print('✅ Splash: No user, navigating to /login');
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      print('❌ Splash Error: $e');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }

    // Safety timeout - if navigation hasn't happened after 3 seconds, force go to login
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        print('⚠️ Splash: Navigation timeout, forcing /login');
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking auth state and navigating
    // Native splash was already shown for 500ms before this
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF58CC02), Color(0xFF34A853)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated app icon
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) => Transform.scale(
                  scale: 1.0 + _pulseController.value * 0.08,
                  child: child,
                ),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.language,
                        size: 48,
                        color: Color(0xFF58CC02),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Urdu • Punjabi • English',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.9),
                  ),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

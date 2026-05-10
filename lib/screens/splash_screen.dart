import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../themes/app_theme.dart';
import '../services/firebase_service.dart';
import 'auth/login_screen.dart';
import 'auth/onboarding_screen.dart';
import 'auth/email_verification_screen.dart';
import 'home_screen.dart';
import 'learning/language_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Future<Widget> _nextScreenFuture;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _nextScreenFuture = _determineNextScreen();
    _navigateToHome();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<Widget> _determineNextScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding =
        prefs.getBool(OnboardingScreen.hasSeenOnboardingKey) ?? false;

    if (!hasSeenOnboarding) {
      return const OnboardingScreen();
    }

    return const LoginScreen();
  }

  Route _buildTransitionRoute(Widget child) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final slide = Tween<Offset>(
          begin: const Offset(0.0, 0.04),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 450),
    );
  }

  Future<void> _navigateToHome() async {
    await Future.wait([
      Future.delayed(const Duration(seconds: 2)),
      _nextScreenFuture,
    ]);

    if (!mounted) return;

    final nextScreen = await _nextScreenFuture;
    Navigator.of(context).pushReplacement(_buildTransitionRoute(nextScreen));
  }

  @override
  Widget build(BuildContext context) {
    const vividBlue = Color(0xFF4575FA);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: vividBlue,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) => Transform.scale(
                  scale: 0.95 + (_pulseController.value * 0.06),
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Image.asset(
                    'assets/icons/app_icon1.png',
                    width: 210,
                    height: 210,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.language,
                      size: 96,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'signup_screen.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;

  final List<OnboardingData> _onboardingData = [
    const OnboardingData(
      headline: 'Lesson on demand',
      description:
          'Now, It\'s your turn to choose the subject of your course. In SpeakUp, you will learn vocabulary, phrases, pronunciations, and grammar patterns through several courses with various topics. Try it and find its efficiency.',
      imagePath: 'assets/images/homescreen1logo.png',
    ),
    const OnboardingData(
      headline: 'It\'s gamified!',
      description:
          'The smart competitive ones, or those who look for the fun side of everything, will have a great learning experience here. Every step you take, any progress you make, SpeakUp has a reward to encourage your achievement.',
      imagePath: 'assets/images/homescreen2logo.png',
    ),
    const OnboardingData(
      headline: 'Take learning beyond the classroom walls',
      description: 'Find certified teachers, personalize your own English learning plan.',
      imagePath: 'assets/images/homescreen3logo.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigate(bool isSignup) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return isSignup ? const SignupScreen() : const LoginScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  final data = _onboardingData[index];
                  return _OnboardingPageContent(data: data);
                },
              ),
            ),

            // Actions (fixed at bottom)
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _navigate(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("Let's go!", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already got an account? ', style: TextStyle(fontSize: 16, color: Color(0xFF666666), fontStyle: FontStyle.italic)),
                      GestureDetector(onTap: () => _navigate(false), child: const Text('LOGIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue, fontStyle: FontStyle.italic))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SmoothPageIndicator(
                    controller: _pageController,
                    count: _onboardingData.length,
                    effect: WormEffect(
                      activeDotColor: Colors.blue,
                      dotColor: Colors.grey.shade300,
                      dotHeight: 8,
                      dotWidth: 24,
                      spacing: 8,
                    ),
                    onDotClicked: (i) => _pageController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageContent extends StatelessWidget {
  const _OnboardingPageContent({required this.data});

  final OnboardingData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          SizedBox(
            height: 315,
            width: double.infinity,
            child: Image.asset(
              data.imagePath,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            data.headline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
              fontFamily: 'Nunito',
              height: 1.1,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
              fontFamily: 'Nunito',
              height: 1.25,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String headline;
  final String description;
  final String imagePath;

  const OnboardingData({
    required this.headline,
    required this.description,
    required this.imagePath,
  });
}

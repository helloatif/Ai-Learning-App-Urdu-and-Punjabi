import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/language_onboarding_service.dart';

class PreparingScreen extends StatefulWidget {
  const PreparingScreen({super.key});

  @override
  State<PreparingScreen> createState() => _PreparingScreenState();
}

class _PreparingScreenState extends State<PreparingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  bool _isComplete = false;
  bool _isContinuing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // Animate from 0.75 (75%) to 1.0 (100%)
    _progressAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutCubic),
    );

    _animationController.addListener(_checkProgress);
    _animationController.forward();
  }

  void _checkProgress() {
    if (_progressAnimation.value >= 1.0 && !_isComplete) {
      setState(() => _isComplete = true);
      // stop animation once complete to keep value stable
      _animationController.stop();
    }
  }

  Future<void> _navigateToHome() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        await LanguageOnboardingService.markPreparingScreenCompleted(userId);
      } catch (e) {
        debugPrint('Error marking preparing screen completed: $e');
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Back button + progress track placeholder
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 18, 8),
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: const Color(0xFF9EA3AE),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Center content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    // Icon
                    Image.asset(
                      'assets/icons/caticon.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/icons/app_icon1.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Text(
                        'We\'re preparing your\ncustom practice plan...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2B2E36),
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Progress bar with percentage
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedBuilder(
                                animation: _progressAnimation,
                                builder: (context, child) {
                                  return LinearProgressIndicator(
                                    value: _progressAnimation.value,
                                    minHeight: 8,
                                    backgroundColor: const Color(0xFFE7ECF3),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          AnimatedBuilder(
                            animation: _progressAnimation,
                            builder: (context, child) {
                              final percentage =
                                  (_progressAnimation.value * 100).toInt();
                              return Text(
                                '$percentage%',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2B2E36),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Continue button (appears only after progress reaches 100%)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: !_isComplete || _isContinuing
                      ? null
                      : () async {
                          setState(() => _isContinuing = true);
                          await _navigateToHome();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F84FF),
                    disabledBackgroundColor: const Color(0xFFD9E4FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(
                    _isContinuing ? 'Saving...' : 'Continue',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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

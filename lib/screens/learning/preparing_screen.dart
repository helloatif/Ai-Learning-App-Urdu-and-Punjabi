import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

    // Keep status bar icons visible over our background and make the
    // status bar area transparent so UI can bleed behind it.
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutCubic),
    );

    _animationController.addListener(_checkProgress);
    _animationController.forward();
  }

  void _checkProgress() {
    if (_progressAnimation.value >= 1.0 && !_isComplete) {
      setState(() => _isComplete = true);
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
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: const Color(0xFF9EA3AE),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Preparing',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B2E36),
          ),
        ),
        centerTitle: false,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // (AppBar added) header row removed from body

            // Center content (mascot above the speech bubble)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Mascot
                        Image.asset(
                          'assets/icons/caticon.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              'assets/icons/app_icon1.png',
                              width: 100,
                              height: 100,
                              fit: BoxFit.contain,
                            );
                          },
                        ),
                        const SizedBox(height: 28),

                        // Speech bubble
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F8FC),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text(
                            'We\'re preparing your\ncustom practice plan...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              height: 1.3,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2B2E36),
                            ),
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Centered progress bar and percentage under it
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  height: 8,
                                  width: double.infinity,
                                  child: AnimatedBuilder(
                                    animation: _progressAnimation,
                                    builder: (context, child) {
                                      return LinearProgressIndicator(
                                        value: _progressAnimation.value,
                                        backgroundColor: const Color(0xFFE7ECF3),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                          Colors.black,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              AnimatedBuilder(
                                animation: _progressAnimation,
                                builder: (context, child) {
                                  final percentage =
                                      (_progressAnimation.value * 100).toInt();
                                  return Text(
                                    '$percentage%',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2B2E36),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Continue button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
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

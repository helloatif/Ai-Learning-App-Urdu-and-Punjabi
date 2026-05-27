import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../services/firebase_service.dart';
import '../../services/language_onboarding_service.dart';
import '../../providers/user_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/learning_provider.dart';
import '../../providers/theme_provider.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _timer;
  Timer? _cooldownTimer;
  bool _isCheckingVerification = false;
  bool _isLoadingPostVerification = false;
  bool _canResend = false; // Start as false - email was just sent on signup
  int _resendCooldown = 60; // Start with 60 second cooldown
  bool _isResending = false;

  @override
  void initState() {
    super.initState();

    // Start cooldown timer immediately (email was sent during signup)
    _startCooldownTimer();

    // Check verification status every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkEmailVerification();
    });
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        if (mounted) {
          setState(() {
            _resendCooldown--;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _canResend = true;
          });
        }
        timer.cancel();
      }
    });
  }

  Future<void> _loadUserDataAfterVerification(String userId) async {
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
    _timer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerification() async {
    if (_isCheckingVerification) return;

    setState(() {
      _isCheckingVerification = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (user.emailVerified) {
          // Email verified! Check if user has selected a language
          _timer?.cancel();
          if (mounted) {
            setState(() {
              _isLoadingPostVerification = true;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Email verified successfully!'),
                backgroundColor: Colors.green,
              ),
            );

            // Check if user has already selected a language
            try {
              await _loadUserDataAfterVerification(user.uid);

              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();

              final selectedLanguage = (doc.data()?['selectedLanguage'] ?? '').toString().trim();
              final levelCompleted = (doc.data()?['languageLevelCompleted'] ?? false) == true;
              final timeCompleted = (doc.data()?['timeSelectionCompleted'] ?? false) == true;
              final preparingCompleted = (doc.data()?['preparingScreenCompleted'] ?? false) == true;

              if (selectedLanguage.isNotEmpty && mounted) {
                Navigator.of(context).pushReplacementNamed(
                  !levelCompleted
                      ? '/language-level'
                      : (!timeCompleted ? '/time-selection' : (preparingCompleted ? '/home' : '/preparing')),
                  arguments: selectedLanguage,
                );
              } else if (mounted) {
                // No language selected yet - go to language selection
                Navigator.of(
                  context,
                ).pushReplacementNamed('/language-selection');
              }
            } catch (e) {
              // If Firestore check fails, default to language selection
              if (mounted) {
                Navigator.of(
                  context,
                ).pushReplacementNamed('/language-selection');
              }
            } finally {
              if (mounted) {
                setState(() {
                  _isLoadingPostVerification = false;
                });
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error checking verification: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingVerification = false;
        });
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('No user logged in');
      }

      if (user.emailVerified) {
        // Already verified, check language selection and navigate accordingly
        if (mounted) {
          setState(() {
            _isLoadingPostVerification = true;
          });
          try {
            await _loadUserDataAfterVerification(user.uid);

            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

            final selectedLanguage = (doc.data()?['selectedLanguage'] ?? '').toString().trim();
            final levelCompleted = (doc.data()?['languageLevelCompleted'] ?? false) == true;
            final timeCompleted = (doc.data()?['timeSelectionCompleted'] ?? false) == true;
            final preparingCompleted = (doc.data()?['preparingScreenCompleted'] ?? false) == true;

            if (mounted) {
              if (selectedLanguage.isEmpty) {
                Navigator.of(context).pushReplacementNamed('/language-selection');
              } else {
                Navigator.of(context).pushReplacementNamed(
                  !levelCompleted
                      ? '/language-level'
                      : (!timeCompleted ? '/time-selection' : (preparingCompleted ? '/home' : '/preparing')),
                  arguments: selectedLanguage,
                );
              }
            }
          } catch (e) {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          } finally {
            if (mounted) {
              setState(() {
                _isLoadingPostVerification = false;
              });
            }
          }
        }
        return;
      }

      // Send verification email directly
      print('📧 Resending verification email to ${user.email}...');
      await user.sendEmailVerification();
      print('✅ Verification email resent successfully!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✉️ Verification email sent to ${user.email}!\nCheck your inbox and spam folder.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Reset cooldown
        setState(() {
          _canResend = false;
          _resendCooldown = 60;
        });

        // Start cooldown timer
        _startCooldownTimer();
      }
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase error resending email: ${e.code} - ${e.message}');
      if (mounted) {
        String errorMessage = 'Failed to send email';
        if (e.code == 'too-many-requests') {
          errorMessage =
              'Too many requests. Please wait a few minutes and try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('❌ Error resending verification email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    // Don't clear Remember Me - user just needs to verify email
    await FirebaseService.signOut(clearRememberMe: false);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Verify Your Email',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign out',
            color: Colors.black,
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
              SizedBox(
                height: 220,
                child: Image.asset(
                  'assets/images/Authentication_amico.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify Your Email',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontStyle: FontStyle.italic,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                user?.email ?? '',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Text(
                'We\'ve sent a verification email to your inbox. Please click the link in the email to verify your account.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.darkGray,
                      fontStyle: FontStyle.italic,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.78,
                child: ElevatedButton.icon(
                  onPressed: (_canResend && !_isResending) ? _resendVerificationEmail : null,
                  icon: _isResending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.refresh, size: 20),
                  label: Text(
                    _isResending
                        ? 'Sending...'
                        : _canResend
                            ? 'Resend Verification Email'
                            : 'Resend in $_resendCooldown seconds',
                    style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.78,
                child: ElevatedButton(
                  onPressed: () {
                    _timer?.cancel();
                    FirebaseService.signOut(clearRememberMe: false);
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to Login', style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Didn\'t receive the email? Check your spam folder or resend.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.darkGray,
                      fontStyle: FontStyle.italic,
                    ),
                textAlign: TextAlign.center,
              ),
                ],
              ),
            ),
          ),
          if (_isLoadingPostVerification || _isCheckingVerification)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.12),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ),
        ],
        ),
    );
  }
}
